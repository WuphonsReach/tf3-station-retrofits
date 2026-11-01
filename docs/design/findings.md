# Findings

## In short

- **Status.** Probe 1 ran in game (test results at the bottom): a `loadScript` wrapper levelled a rail station, a street terminal and a harbour by rebuilding them, and every value landed as the formulas say. Not yet tested: the window card, rebuilds the game starts, kerbside stops, and more than one game day of play. The station facts below come from reading the base game's station scripts (`base/content/stations/*.zip`, `scripts.zip`, `game_mechanics.zip`, `gui.zip`). The method is the one [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) uses, released and tested in game; its findings ([docs/design/findings.md](https://github.com/WuphonsReach/tf3-depot-retrofits/blob/main/docs/design/findings.md)) are the evidence for everything marked "from Depot Retrofits" below.
- **Where the values come from.** A modular station's waiting capacity, comfort, catchment circles and emissions are all set by its construction's update script, in a `result.terminateConstructionHook` that the game runs after every module's own update script. The values are sums of the modules' `metadata` (`moreCapacity`, `comfortFactor`, `catchmentPassenger`/`catchmentCargo`, `emissionConfig`), which the hook reads from `params.modules`. So a wrapper that runs the original update script, then wraps the hook it returns, sees the station's final values and can scale them. Unlike the Roundhouse depot in Depot Retrofits, no module adds to these values after the wrapper.
- **How a level would be applied.** As for depots: hidden level params on the construction, and a rebuild (`createProposalReplaceConstruction`) to apply a new level. Unlike depots, the station script should be wrapped through a `loadScript` modifier, not by rewriting the construction's `updateScript`, and the window should get a card, not a tab (see "Seen in other mods' code"). No game command changes a station's capacity, catchment or comfort at run time (`api/tealdef/api/cmd.d.tl` has none).
- **Upkeep scales directly.** After a modular station's hook has run, `result.maintenanceCost` already holds the modules' upkeep (probe 1: it equalled their sum), and the game charges 1.25 × whatever the script leaves there (this save's settings). So every tree, the upkeep tree included, works by multiplying that value; no negative upkeep is needed.
- **Kerbside stops are edge objects.** The six base bus and tram stops (`street/small_stops/*.con.lua`) declare `edgeObject` and put a `streetTerminal` on the street. Depot Retrofits skips edge objects on purpose. Whether a replace proposal works on one is unknown.
- **Other mods already change these values.** Several script mods on mod.io set station catchment, waiting capacity or pollution, or add to the station window. Station Retrofits differs by being per station, bought and rank-gated, but it has to stack with them; how they apply their values is not checked (unknown 12). Notes on them are kept outside the repo.
- **A rebuild is cheap and keeps the station** (probe 1): no charge, same construction and station ids, same line stops, the one waiting passenger kept. The station's emitter reads 0 right after a rebuild and is back, scaled, within a game day.
- **Biggest unknowns** (see the end): what a rebuild does to a crowded station and to vehicles at the platforms, how often the game refuses one (stations have more track and road connections than depots), the window card, and rebuilds the game starts.

## Station types in the base game

Sources: the `.con.lua` and `.script.lua` files in `base/content/stations/{rail,street,water,air}.zip` and `base/content/warehouses.zip`.

| Construction | File | Modular | Upkeep from | Values set in |
|---|---|---|---|---|
| Train station (passenger and cargo) | `rail/modular_station/modular_station.con.lua` | yes | modules only (script: `cost = 0`) | `terminateConstructionHook` |
| Road station, bus and truck terminal, tram station | `street/modular_street_station/modular_terminal.con.lua` | yes | modules only (script: `cost = 0`) | `terminateConstructionHook` |
| Harbour (passenger and cargo) | `water/harbor_modular.con.lua` | yes | modules only (script: `cost = 0`) | `terminateConstructionHook` |
| Airport, airfield | `air/airport.con.lua`, `air/airfield.con.lua` | yes | modules only (script: `cost = 0`) | `terminateConstructionHook` |
| Heliport | `air/heliport.con.lua` | yes (landing modules) | script 50k + modules | the update script and a hook |
| Helipad | `air/helipad.con.lua` | no | script 25k | the update script |
| Underground station | `street/underground_station/underground_station.con.lua` | no | script 150k (build cost 6 ×) | the update script |
| Kerbside stops (6 variants) | `street/small_stops/small_*.con.lua` | no, `edgeObject` | capture params, 5k (build cost 6 ×) | the update script (`streetTerminal`) |
| Warehouse | `warehouses/warehouse.con.lua` | yes | modules only | `terminateConstructionHook` (stocks, not a station pool) |

Notes:

- The airport's and airfield's hangar modules (`air/airport/ap_hangar.module.lua`, `air/airfield/af_hangar.module.lua`) add a depot (`maintenancePool` 16, radius 550 for the airport's) and the heliport's script adds one too. These constructions are both a station and a depot. Depot Retrofits does not wrap them today: its test is the depot HUD icons, a depot `constructionType` or a `depots/` folder, and airports have none of these. If both mods ever wrapped the same construction, each would wrap the other's wrapper; keep them apart.
- A warehouse is not a passenger or cargo station in the same sense: it holds `stocks`. Leave it out of a first version.
- The engine's `ConstructionType` has station values (`STREET_STATION`, `RAIL_STATION`, `AIRPORT`, `HARBOR`, `STREET_STATION_CARGO`, `RAIL_STATION_CARGO`, `HARBOR_CARGO`, `AIRPORT_CARGO`; `api/tealdef/api/type.d.tl`). Whether the base station `.con` files set it is not checked; base depots did not. Stations from other mods may follow any shape, so detection should look at what the update script returns (a subconstruction with a `station` table, or a `streetTerminal`), as Depot Retrofits falls back to the `VEHICLE_DEPOT` component.
- Only the rail station and the street terminal declare an `upgradeScript` (catenary swaps and module swaps, `modular_station.script.lua` `upgradeFn`). Whether it returns the other params unchanged, as the depots' upgrade scripts do, is not checked. Depot Retrofits found that the depot upgrade scripts kept its hidden params; this has to be checked for stations (probe 3).
- No base station declares `entityWindowScript`. Setting one, as Depot Retrofits does for depots, would stop the station window from opening (see "Seen in other mods' code").

## What the update script sets

For the modular stations (rail is `rail/modular_station/modular_station.script.lua`, the hook from about line 855; the street terminal's hook is at about line 2918 of `street/modular_street_station/modular_terminal.script.lua`; the harbour's at about line 285 of `water/harbor_modular.script.lua`; the airport's at about line 841 of `air/airport.script.lua`):

- **Waiting capacity.** `station.pool.capacity` = the modules' `moreCapacity.passenger` (rail, street: plus cargo) from `modulesutil.getStationPoolCapacities` (`scripts/construction/modulesutil.lua`), then `constructionutil.addStationCapacities` (`scripts/construction/constructionutil.lua`) adds a count worked out from the pool's lane edges (lane length and width in 1.2 m cells) and sets each terminal's capacity from its own edges.
- **Comfort.** Each terminal's `comfortFactor` = 1 + the modules' `comfortFactor` sum (`modulesutil.getStationPoolComfortFactor`). What comfort does is decided in the engine; no script in `game_mechanics.zip` reads it back (only `towns/town_react_util.tl` mentions comfort; `gui.zip` is not searched). Its effect on passengers is unknown.
- **Load speed.** Rail: each terminal's `cargoTransferSpeeds` gets a `loadSpeedModifier` per cargo class from the platform's specialization. The effect size is engine-side (`LoadSpeedModifiers.getTotalPenalty` in `api/tealdef/api/engine.d.tl`).
- **Catchment.** `constructionutil.addCatchmentCircles` adds one circle per module that has `catchmentPassenger` or `catchmentCargo`, at the module's slot position with the module's radius, to `station.catchmentAreas`. Platforms have none: on a rail station the catchment comes from the main and side buildings (50 to 200 m) and stairs (100 m); on a street terminal from entrances and exits (175 m); on a harbour from docks (150 to 250 m). A station with no such module gets no circle and a log warning, unless the script passes a default.
- **Emissions.** `metadata.emissions` has two states: base = the modules' `emissionConfig` sum (`modulesutil.getModulesEmissions`), crowded = 2 × base.
- **Upkeep and build price.** The script sets `result.cost = 0` and no `maintenanceCost`; the game adds each module's `metadata.price` and `metadata.maintenanceCost`. In 80 of the 81 base station modules with an upkeep, the price is exactly 6 × the upkeep (the one exception is `water/passenger_dock_100_50.module.lua`), the same ratio as every base depot. So Depot Retrofits' price rule (build price = 6 × the upkeep the game charges, rounded to $100) should carry over.

For the kerbside stops (`street/small_stops/small_stops.script.lua`): a `streetTerminal` with `capacity = 50`, one `catchmentArea` with `radius = captureParams.catchmentAreaRadius` (160 m on `small_new`), `cost = buildCost or 6 × maintenanceCost`, `maintenanceCost` from the capture params (5,000), and `edgeObjectEmissionEmitter = {noise 1, pollution 5}`.

## How the game uses them at run time

- **Emissions follow crowding.** `game_mechanics/emission/emissions.script.tl` updates every station's emitter (offset 2 in its update cycle). It reads `api.engine.util.station.calculateStationUsage(entity)` and slides between the two emission states by `totalUsed / (poolCapacity + terminalCapacity)`, clamped to 0..1. So a station with more capacity is less crowded and emits less, as a depot with a larger pool does. The eco factor is 1 for stations: the Industry Greenification tool cannot reach them (from Depot Retrofits).
- **Station window.** A click on a station opens the construction window, whose tabs are the construction's subconstructions; for a station the content is `gui/entity_window/station_group/station_group.tl`, and the window takes `customTabs` (`gui/entity_window/make_entity_window.tl`, around line 130). Depot Retrofits' window script returns this base window with a Retrofit tab added, but for stations that route hides the station window; a card in the station window's plugin extension point is the alternative (see "Seen in other mods' code", probe 2). Seen in game (test results): the base window has no tab bar; it shows a Waiting Hall row (waiting / pool capacity) on stations with a pool, then one row per terminal (cargo type, length in m, waiting / capacity on passenger terminals only, the lines that stop), a Loaded/Unloaded graph, the upkeep per year and a Configure button. Selecting a station draws its catchment circle and highlights the buildings inside it.

## Base module values

From each module's `metadata` (`price`, `maintenanceCost`, `moreCapacity`, `catchmentPassenger`/`catchmentCargo`, `emissionConfig`, `comfortFactor`). Ranges across the era variants (a, b, c).

| Module group | Price | Upkeep | Passenger capacity | Catchment (m) | Noise / pollution | Comfort |
|---|---|---|---|---|---|---|
| Rail main building 1 / 2 / 3 | 18k / 30k / 60k | 3k / 5k / 10k | 20–30 / 40–50 / 100–200 | 150 / 175 / 200 | 1 / 2, 6, 10 | 0.1 / 0.2 / 0.3 |
| Rail side building 1 / 2 / 3 | 12k / 24k / 48k | 2k / 4k / 8k | 10–20 / 30–40 / 80–150 | 50 / 60 / 70 | none | 0.05 / 0.1 / 0.15 |
| Rail cargo main and side buildings | 6k–60k | 1k–10k | 0 | 50–200 (cargo) | 1 / 2–10 | none |
| Rail platform, passenger | 60k | 10k | none | none | 1 / 5 | none |
| Rail platform, cargo (universal / specialised) | 30k / 60k | 5k / 10k | none | none | 1 / 5, 10 | none |
| Rail stairs | 12k | 2k | none | 100 | 1 / 5 | none |
| Street terminal entrance, exit | 6k | 1k | none | 175 (both) | 1 / 10 | none |
| Street terminal passenger building 10×10 / 20×20 | 60k / 120k | 10k / 20k | 8 / 27 | none | 1 / 5, 10 | 0.05 / 0.1 |
| Street terminal platform (passenger, cargo) | 30k–60k | 5k–10k | none | none | 1 / 5, 10 | none |
| Harbour passenger docks | 12k–90k | 2k–15k | 25–150 | 150–250 | 2–4 / 10–20 | 0.1–0.25 |
| Harbour piers | 60k / 90k | 10k / 15k | none | none | 1–2 / 10–20 | none |
| Airport modules | 900k | 150k | 100 (terminals) | none | 20 / 80 | none |
| Airfield modules | 600k | 100k | 20–100 | 250 (main) | 10 / 40 | none |
| Heliport landing module | 180k | 30k | none | none | 20 / 40 | none |
| Warehouse modules | 150k / 300k | 25k / 50k | none | none | 20 / 25, 50 | none |

For scale (from Depot Retrofits): a rail depot gives off 100 to 120 pollution, a road depot 80 to 100. A ten-platform rail station with a large main building gives off about 60 to 110 base, twice that when crowded. In Depot Retrofits' Dereham test, stations and tracks gave off about half of a town's pollution, which the depot mod cannot reach.

## Carried over from Depot Retrofits (tested on depots, not on stations)

Each of these held for depots and maintenance buildings in game; each needs a check on stations.

- `addModifier("loadConstruction", fn)` in `runFn` can wrap any construction's `updateScript`; `scripts/util.tl` `useFn` loads the original from an absolute `file@function` reference. A relative reference needs resolving against the `.con` file's folder (base stations use paths like `/stations/rail/modular_station/modular_station.script@updateFn`).
- Hidden level params: declared with `yearFrom = 9999`, they stay out of the build menu, are not passed when a building is placed, but are stored by a rebuild and passed to the update script.
- A rebuild with `createProposalReplaceConstruction(entity, params)`, sent from the game script's `update` with `makeWorldBuildProposalCmd(proposal, nil, false, false, false)`, kept the construction and depot entity ids, kept vehicles' lines, cost nothing, and survived save and load. It cleared every vehicle's maintenance link (the game reassigned them within a day).
- The game refuses a rebuild that collides with something built since (a house on the next lot; a road rebuilt to the depot's exit). Nothing is charged then. `builtin.ProposalViewer` with the real proposal, placed through `setActionFn`, shows what is in the way in red; `makeProposalData` with a `SimpleProposal` stand-in disagreed with the game too often.
- Rebuilds the game starts (catenary, module edits through the depot's upgrade script) went through the wrapper and kept the levels.
- `loadModule` modifiers are called by TF3 (Depot Retrofits wraps module update scripts with one). Probably not needed for stations, since the hook runs after the modules.
- Upkeep: the construction's `MAINTENANCE_COST` component holds the script's `maintenanceCost`; the charged figure is that × the base config's `infrastructureMaintenanceScale` (`calcMaintenanceForSubconstruction`).
- Charging: a `JournalEntry` of type `CONSTRUCTION`, booked with `makeJournalBookAssetCmd` from the game script. Depot Retrofits uses `JournalEntry.Construction.DEPOT`; which value suits a station is not checked.
- The game script's state is written from the simulation thread (`handleEvent`) and from about ten worker threads (`update`), each with its own copy; module variables do not persist. A pending buy counts as landed once the stored level is at least the bought one.
- Rank: base `company_progression_util.tl` gives the claimed rank.

## Seen in other mods' code (not tested by us)

From a read-only survey of the station, catchment, capacity and emission script mods on mod.io (2026-11-01). Names and per-mod notes are kept outside the repo. Each point is what those mods' code does or says; none is tested here.

- **Wrap the script, not the construction.** Several mods register a `loadScript` modifier keyed on the base station script paths and replace the script's `updateFn` with a wrapper. The base game loads station scripts with `util.useFn` (`scripts/construction/construction.script.tl:53`), so a `loadScript` wrapper runs whichever way the construction is reached, and it nests inside every `loadConstruction` wrapper. Rewriting a station's `updateScript` (Depot Retrofits' method) breaks other mods that recognise stations by `updateScript.fileName`, and mods that wrap with `loadConstruction` each need to be the outermost wrapper for their own window card to work. A `loadScript` wrapper avoids both. One mod reports that a `loadConstruction` modifier registered in a preRunScript had no effect.
- **The hook runs only on modular stations.** The game calls `terminateConstructionHook` only when `params.modules ~= nil and result.slots ~= nil`; otherwise the values must be scaled straight away (helipads, kerbside stops). The hook can also be called more than once for one result, and a base hook is not repeatable (a second run adds lanes again: "Duplicate edge detected", then a crash): run the original once, cache its returns, and scale once. Harbours copy every result field, the hook included, into their station tables, so a wrapper must point those copies at itself too.
- **Multiply what is there.** Every mod surveyed multiplies the values it finds (or adds a bonus); none recomputes from a base. Scaling the values present after the inner hook, never setting absolute values, stacks multiplicatively with all of them. Scale copies, never write scaled values back into params: the game may hand the same tables to several builds, which compounds.
- **Copy all params on a rebuild.** The mods that rebuild stations deep-copy every existing param and set only their own keys, so foreign hidden params (ours included) survive their rebuilds. We must do the same. Some mods rebuild many stations by themselves (on first load, when their settings change, or after any nearby build), so a levelled station can be rebuilt, and get a new construction id, without our doing.
- **The station window.** `gui/entity_window/view_manager_util.tl:158` (`wouldCreateView`) opens the construction instead of the station group when the construction has an `entityWindowScript`, so setting one on a station would stop the base station window, and other mods' cards in it, from opening. Mods add to the station window with a react plugin instead: a `.res.lua` with `type = "react-plugin ::StationGroupEowExtensionPoint"`, gathered by `station_group.tl:864` (`usePlugins`) and shown as cards after the notifications. Plugins stack. The same exists for depots (`::MaintenanceStationEowExtensionPoint`) and warehouses.
- **Kerbside stops can be rebuilt in place**: two mods do it with `replaceSegment(edge)` and a new `SimpleStreetProposal.EdgeObject` carrying the copied params, with `context.player = -1`.
- **Commands.** Two mods call `sendCommand` from `handleEvent` or with a callback, which Depot Retrofits found not to work; others queue in `handleEvent` and send from `postUpdate`. Either the Depot Retrofits finding is narrower than written, or those calls fail.
- **Other APIs seen.** `api.engine.util.proposal.refreshConstruction(entity)` (rebuild with the same params); `api.cmd.makeEntitySetEmissionsCmd(entity, noise, pollution, radius, pollutionRadius)` (how the base emissions script sets a station's emitter); `api.engine.util.station.isStationOfType`; `streetConnectorSystem.getConstructionEntityForStation` (station group to construction).
- **Buildings that are both.** Some modded depots contain stations (and the base airports and heliports contain hangar depots). Station Retrofits must skip any construction Depot Retrofits already wraps.

## Unknowns

1. What a rebuild does to many waiting passengers and cargo (probe 1 had at most one waiting) and to vehicles loading at the platforms or a train halfway into one. Ids and lines are kept (probe 1).
2. Whether the Finances tab shows the levelled upkeep as the station window does (probe 1 checked the window and `calcMaintenanceForSubconstruction`).
5. How often the game refuses a station rebuild, compared with depots. (Probe 1, then play.)
6. Whether the base station window takes a Retrofit tab the way the depot window does. (Probe 2.)
7. Whether module edits, catenary swaps and the rail and street upgrade scripts keep the hidden params. (Probe 3.)
8. Whether a kerbside stop (an edge object) can be replaced with new params. (Probe 4.)
9. How much comfort and load speed change in play. Leave both out until measured.
10. Which `JournalEntry.Construction` value fits a station charge.
11. How stations from popular mods are shaped (whether they return a `station` table, use `terminateConstructionHook`, set `constructionType`).
12. Whether the levels stack with other mods that change the same values. Read from their code (next section): they do if we wrap through `loadScript` and multiply the values we find; untested in game.
13. Whether two stations shown in one building (two windows, two entity ids, see the test results) are one construction or two; levels belong to a construction.

## Test results

### 2026-11-01: scaffold load, base station windows, mod.io search

Save `WR26A Giga-Tv3 1915 1031-1920 more mods` (29 mods, 110 stations, Jan 1915, rank Director), Station Retrofits 0.1-dev activated in its Mods tab, then saved as a new manual save. The scaffold only logs its start-up line.

- **Load.** `STATION_RETROFITS version 0.1-dev logLevel=summary` on every load and sim pool, next to Depot Retrofits 1.3-dev and Best Before 1.4-dev. No `Error while loading game script`; the only errors were base texture and network (mod.io image) warnings.
- **Base station windows** (no Retrofit tab yet; entity ids from the log's `Selected entity` lines, matched by time):

| Station | Entity | Kind | Waiting hall | Terminals (length, waiting / capacity) | Upkeep / year |
|---|---|---|---|---|---|
| Peterlee Oil Refinery Station | 255628 | rail cargo | none shown | 80 m all cargo; 4 × 400 m liquid; no capacity shown | $531,250 |
| Peterlee Refinery N Oil Delivery | 340363 | truck cargo | none shown | 4 × 20 m liquid | $101,250 |
| Peterlee Refinery N Port Stop | 334446 | truck cargo | none shown | 4 × 30 m liquid | $151,250 |
| Peterlee Refinery N Port | 78577 | harbour | 0 / 300 | 3 × passenger and cargo, 0 / 50 each | $122,500 |
| Peterlee Station Transfer | 240471 | bus | 0 / 27 | 20 m, 1 / 48 | $51,250 |
| Peterlee Refinery W Oil Delivery | 328109 | truck cargo | none shown | 4 × 20 m liquid | $101,250 |
| Lower Peterlee Station | 44612 | tram | none shown | 2 × 30 m, 0 / 72 each | $77,500 |
| Peterlee Station North | 331278 | tram, in the rail station's building | none shown | 90 m, 19 / 216 | $113,750 |
| Upper Peterlee Station | 175556 | rail passenger | 0 / 310 | 160 m 1 / 256; 80 m 0 / 128 | $160,000 |

  Cargo stations show no capacity at all, so the capacity tree has nothing in the base window to point at on them. Peterlee Station North and Upper Peterlee Station open from the same building with different ids (unknown 13).
- **mod.io search** (Script Mod, "station", 30 results, and the in-game Mod Hub): no mod named Station Retrofits or close to it. Several change catchment, waiting capacity or pollution, or add to the station window (unknown 12).

### 2026-11-01: probe 1, rebuild with fixed levels

Test copies of `WR26A Giga-Tv3 1915 1101-1134 more mods` (Jan 1915, 110 stations), logLevel `"full"`. The probe picked three stations, rebuilt the rail station and the street terminal with every level at 5 and the harbour with upkeep level 10 only, and one game day later rebuilt the rail station again unchanged. A first run had an upkeep formula that counted the modules twice; it was fixed and the probe run again on a fresh copy. The values below are from the second and third runs (identical), the circles and catchables from the third. Played one game day; saved as `WR26A Giga-Tv3 1915 1101-1236-test`.

- **Wrapper.** `loadScript` reached all three base scripts (`wrapScript` lines); the hook was guarded on each, and copies of it relinked: rail 0, street 1, harbour 2. No `hookAgain` line, no errors.
- **Values, from the game's own components after the rebuild:**

| Station | Catchment circles (`STATION` component) | Buildings in reach (passenger) | Waiting hall / terminals | Emitter noise / pollution | Upkeep script → charged |
|---|---|---|---|---|---|
| Upper Peterlee (rail, all 5) | 7 × 60 → 85 m, 200 → 230 m | 10 → 12 | 310 → 465 / 384 → 576 | 7.01 / 44.86 → 0 at 1 h → 5.26 / 33.63 at 1 d | 128,000 → 312,000; $160,000 → $390,000 |
| Lower Peterlee (street, all 5) | 2 × 175 → 201.25 m | 72 → 85 | – / 144 → 216 | 8 / 50 → 0 at 1 h → 6 / 37.5 at 1 d | 62,000 → 151,125; $77,500 → $188,906 |
| Refinery N Port (harbour, upkeep 10) | 250 m (unchanged) | 0 (cargo 1) | 300 / 150 (unchanged) | – | 98,000 → 49,000; $122,500 → $61,250 |

- **The station window** showed the same: waiting hall 465 and terminals 384 + 192 at Upper Peterlee, terminals 108 + 108 at Lower Peterlee, and the three upkeep figures.
- **Rebuilds** landed within a second, cost nothing (balance unchanged, also for the unchanged rebuild), and kept the construction id, the station ids and the line stops. The game script ran while the game was paused.
- **Catchment centres.** The circles sit on the station's modules (the main building, stairs, entrances), not on the construction's marker: a station window's circle is not centred on the beam of light. A map of the saves drawn with `tf3map`, with the logged circles on top, shows the 230 m main-building circle doing nearly all the work at the rail station; the 85 m circles lie mostly inside it.
- **Not seen:** a crowded station (at most one passenger waiting), a vehicle at a platform during the rebuild, a refusal, 7 and 30 days.
