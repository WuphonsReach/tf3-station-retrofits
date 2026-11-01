# Findings

## In short

- **Status.** Nothing here has been tested in game yet. The station facts below come from reading the base game's station scripts (`base/content/stations/*.zip`, `scripts.zip`, `game_mechanics.zip`, `gui.zip`). The method is the one [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) uses, released and tested in game; its findings ([docs/design/findings.md](https://github.com/WuphonsReach/tf3-depot-retrofits/blob/main/docs/design/findings.md)) are the evidence for everything marked "from Depot Retrofits" below.
- **Where the values come from.** A modular station's waiting capacity, comfort, catchment circles and emissions are all set by its construction's update script, in a `result.terminateConstructionHook` that the game runs after every module's own update script. The values are sums of the modules' `metadata` (`moreCapacity`, `comfortFactor`, `catchmentPassenger`/`catchmentCargo`, `emissionConfig`), which the hook reads from `params.modules`. So a wrapper that runs the original update script, then wraps the hook it returns, sees the station's final values and can scale them. Unlike the Roundhouse depot in Depot Retrofits, no module adds to these values after the wrapper.
- **How a level would be applied.** As for depots: hidden level params on the construction, and a rebuild (`createProposalReplaceConstruction`) to apply a new level. No game command changes a station's capacity, catchment or comfort at run time (`api/tealdef/api/cmd.d.tl` has none).
- **Upkeep is the hard tree.** A base modular station's own script sets `cost = 0` and no upkeep: all its upkeep is the modules' `metadata.maintenanceCost`, which the game adds afterwards. Depot Retrofits cuts upkeep by lowering the script's own `maintenanceCost` and stops at 0, so on a modular station an upkeep level would do nothing. Whether the game accepts a negative `maintenanceCost` is unknown (probe in [probe-plan.md](probe-plan.md)).
- **Kerbside stops are edge objects.** The six base bus and tram stops (`street/small_stops/*.con.lua`) declare `edgeObject` and put a `streetTerminal` on the street. Depot Retrofits skips edge objects on purpose. Whether a replace proposal works on one is unknown.
- **Biggest unknowns** (see the end): what a station rebuild does to waiting passengers and cargo and to vehicles at the platforms, whether it costs anything, how often the game refuses it (stations have more track and road connections than depots), and whether a negative upkeep works.

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
- No base station declares `entityWindowScript`, so the mod can set one, as Depot Retrofits does for depots.

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
- **Station window.** A click on a station opens the construction window, whose tabs are the construction's subconstructions; for a station the content is `gui/entity_window/station_group/station_group.tl`, and the window takes `customTabs` (`gui/entity_window/make_entity_window.tl`, around line 130). Depot Retrofits' window script returns this base window with a Retrofit tab added; the same should work here (probe 2).

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

## Unknowns

1. What a station rebuild does to: the station and terminal entity ids; lines that stop there; passengers and cargo waiting; vehicles loading at the platforms; a train halfway into a platform. (Probe 1.)
2. Whether a station rebuild that changes nothing costs money. (Probe 1.)
3. Whether wrapping `terminateConstructionHook` works: the game must call the hook from the returned table, after the modules, on every rebuild and preview. (Probe 1.)
4. Whether the game accepts a negative `maintenanceCost` from the script, and whether the upkeep footer and the Finances tab then show the lower figure. Fallback: drop the upkeep tree for modular stations. (Probe 1.)
5. How often the game refuses a station rebuild, compared with depots. (Probe 1, then play.)
6. Whether the base station window takes a Retrofit tab the way the depot window does. (Probe 2.)
7. Whether module edits, catenary swaps and the rail and street upgrade scripts keep the hidden params. (Probe 3.)
8. Whether a kerbside stop (an edge object) can be replaced with new params. (Probe 4.)
9. How much comfort and load speed change in play. Leave both out until measured.
10. Which `JournalEntry.Construction` value fits a station charge.
11. How stations from popular mods are shaped (whether they return a `station` table, use `terminateConstructionHook`, set `constructionType`).

## Test results

None yet.
