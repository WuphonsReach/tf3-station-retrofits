# Findings

## In short

- **Status.** Tested in game (test results at the bottom): a `loadScript` wrapper levels rail stations, road and tram stations and harbours by rebuilding them, and every value lands as the formulas say and held for 30 days (probe 1); a Retrofit card in the base station window shows the levels (probe 2); several hundred buys and removals from the card, on rail, road, tram, cargo and harbour stations, were each charged or refunded once at the card's price. Configure (the module editor) kept the levels on road, tram and passenger rail stations, and module adds, removals and moves on a cargo rail station kept them (probe 3). Levelled stations survive save and load: three saves came back with each station's levels, circles and upkeep as left, and the station script is not run on load (2026-11-10 to 2026-11-13). With TRM: Industry Emissions the levels needed a shim, now tested ([docs/compatibility.md](../compatibility.md)). Two rebuilds the game refused (">|" buys on the mod.io save "333") were dropped uncharged, with the "Not rebuilt" banner on the card (2026-11-15). Not yet tested: era swaps, catenary, a vehicle at a platform during a rebuild, and a refused ">" buy or removal. The station facts below come from reading the base game's station scripts (`base/content/stations/*.zip`, `scripts.zip`, `game_mechanics.zip`, `gui.zip`). The method is the one [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) uses, released and tested in game; its findings ([docs/design/findings.md](https://github.com/WuphonsReach/tf3-depot-retrofits/blob/main/docs/design/findings.md)) are the evidence for everything marked "from Depot Retrofits" below.
- **Where the values come from.** A modular station's waiting capacity, comfort, catchment circles and emissions are all set by its construction's update script, in a `result.terminateConstructionHook` that the game runs after every module's own update script. The values are sums of the modules' `metadata` (`moreCapacity`, `comfortFactor`, `catchmentPassenger`/`catchmentCargo`, `emissionConfig`), which the hook reads from `params.modules`. So a wrapper that runs the original update script, then wraps the hook it returns, sees the station's final values and can scale them. Unlike the Roundhouse depot in Depot Retrofits, no module adds to these values after the wrapper.
- **How a level would be applied.** As for depots: hidden level params on the construction, and a rebuild (`createProposalReplaceConstruction`) to apply a new level. Unlike depots, the station script should be wrapped through a `loadScript` modifier, not by rewriting the construction's `updateScript`, and the window should get a card, not a tab (see "Seen in other mods' code"). No game command changes a station's capacity, catchment or comfort at run time (`api/tealdef/api/cmd.d.tl` has none).
- **Upkeep scales directly.** After a modular station's hook has run, `result.maintenanceCost` already holds the modules' upkeep (probe 1: it equalled their sum), and the game charges 1.25 × whatever the script leaves there (this save's settings). So every tree, the upkeep tree included, works by multiplying that value; no negative upkeep is needed.
- **A port emits no pollution or noise of its own.** Every harbour's station emitter read 0 / 0 before its first level, and in the pollution and noise overlays a harbour, expanded or not, shows no halo (2026-11-05); only its ships smoke, and ships are vehicles. So harbours get only the catchment and upkeep trees (spec).
- **Kerbside stops are out of scope** (decided 2026-11-05). They are edge objects. The six base bus and tram stops (`street/small_stops/*.con.lua`) declare `edgeObject` and put a `streetTerminal` on the street. Depot Retrofits skips edge objects on purpose. Whether a replace proposal works on one is unknown.
- **Other mods already change these values.** Several script mods on mod.io set station catchment, waiting capacity or pollution, or add to the station window. Station Retrofits differs by being per station, bought and rank-gated, but it has to stack with them; how they apply their values is read from their code, not tested in game (unknown 12). Notes on them are kept outside the repo.
- **A rebuild is cheap and keeps the station** (probe 1): no charge, same construction and station ids, same line stops, the one waiting passenger kept. The station's emitter reads 0 right after a rebuild and is back, scaled, within a game day.
- **The window card works** (probe 2): a react plugin for `::StationGroupEowExtensionPoint` adds a card to the base station window, which stays as it was. One card per station group; a tram terminal in a rail station's building is its own construction and group, so it gets its own card and levels.
- **Air buildings are next** (desk check, 2026-11-16; "Air buildings" below). This mod owns airports, airfields, heliports and helipads, hangar depots included; Depot Retrofits never wraps them. Their values are set the same way: the station's in the hook, each hangar's depot table by the hangar module before the hook. An airport's window has tabs, a "Runway" tab with the station window (where the card would show) and a "Depot" tab per hangar with the depot window. Nothing about them is tested in game.
- **Biggest unknowns** (see the end): what a rebuild does to vehicles at the platforms, how often the game refuses one (stations have more track and road connections than depots), and era and catenary swaps.

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

- The airport's and airfield's hangar modules and the heliport's script add a depot, so these constructions are both a station and a depot ("Air buildings" below). They belong to this mod, hangar included (decided 2026-11-16). Depot Retrofits does not wrap them: its test is the depot HUD icons, a depot `constructionType` or a `depots/` folder, and they have none of these. If both mods ever wrapped the same construction, each would wrap the other's wrapper.
- A warehouse is not a passenger or cargo station in the same sense: it holds `stocks`. Leave it out of a first version.
- The engine's `ConstructionType` has station values (`STREET_STATION`, `RAIL_STATION`, `AIRPORT`, `HARBOR`, `STREET_STATION_CARGO`, `RAIL_STATION_CARGO`, `HARBOR_CARGO`, `AIRPORT_CARGO`; `api/tealdef/api/type.d.tl`). No base station `.con` sets it (below); base depots do not either. Stations from other mods may follow any shape, so detection should look at what the update script returns (a subconstruction with a `station` table, or a `streetTerminal`), as Depot Retrofits falls back to the `VEHICLE_DEPOT` component.
- Only the rail station and the street terminal declare an `upgradeScript` (catenary swaps and module swaps, `modular_station.script.lua` `upgradeFn`). Configure kept the hidden level params through every module change on road and tram stations, and through module adds, removals and moves on a cargo rail station (test results, probe 3); era swaps and catenary are not checked yet. Depot Retrofits found the same for the depot upgrade scripts.
- No base station declares `entityWindowScript`. Setting one, as Depot Retrofits does for depots, would stop the station window from opening (see "Seen in other mods' code").

## What the update script sets

For the modular stations (rail is `rail/modular_station/modular_station.script.lua`, the hook from about line 855; the street terminal's hook is at about line 2918 of `street/modular_street_station/modular_terminal.script.lua`; the harbour's at about line 285 of `water/harbor_modular.script.lua`; the airport's at about line 841 of `air/airport.script.lua`):

- **Waiting capacity.** `station.pool.capacity` = the modules' `moreCapacity.passenger` (rail, street: plus cargo) from `modulesutil.getStationPoolCapacities` (`scripts/construction/modulesutil.lua`), then `constructionutil.addStationCapacities` (`scripts/construction/constructionutil.lua`) adds a count worked out from the pool's lane edges (lane length and width in 1.2 m cells) and sets each terminal's capacity from its own edges.
- **Comfort.** Each terminal's `comfortFactor` = 1 + the modules' `comfortFactor` sum (`modulesutil.getStationPoolComfortFactor`). What comfort does is decided in the engine; no script in `game_mechanics.zip` reads it back (only `towns/town_react_util.tl` mentions comfort; `gui.zip` is not searched). Its effect on passengers is unknown.
- **Load speed.** Rail: each terminal's `cargoTransferSpeeds` gets a `loadSpeedModifier` per cargo class from the platform's specialization. The effect size is engine-side (`LoadSpeedModifiers.getTotalPenalty` in `api/tealdef/api/engine.d.tl`).
- **Catchment.** `constructionutil.addCatchmentCircles` adds one circle per module that has `catchmentPassenger` or `catchmentCargo`, at the module's slot position with the module's radius, to `station.catchmentAreas`. Platforms have none: on a rail station the catchment comes from the main and side buildings (50 to 200 m) and stairs (100 m); on a street terminal from entrances and exits (175 m); on a harbour from docks (150 to 250 m). A station with no such module gets no circle and a log warning, unless the script passes a default.
- **Emissions.** `metadata.emissions` has two states: base = the modules' `emissionConfig` sum (`modulesutil.getModulesEmissions`), crowded = 2 × base.
- **Upkeep and build price.** The script sets `result.cost = 0` and no `maintenanceCost`; the game adds each module's `metadata.price` and `metadata.maintenanceCost`. In 80 of the 81 base station modules with an upkeep, the price is exactly 6 × the upkeep (the one exception is `water/passenger_dock_100_50.module.lua`), the same ratio as every base depot. So Depot Retrofits' price rule (build price = 6 × the upkeep the game charges, rounded to $100) should carry over.
- **`upgradeFn` keeps the other params** (desk check, 2026-11-05). The rail station's (`stations/rail/modular_station/modular_station.script.lua`, `upgradeFn`) copies the params with `table_util.copy`, changes only module names (era and catenary swaps) and returns the copy, or returns the params untouched when the slot holds no module. The road terminal's (`stations/street/modular_street_station/modular_terminal.script.lua`, `upgradeFn`) sets only `tramCatenary` and `tramTrack` and returns the same table. The harbour and the airports have none. So the hidden level params pass through a swap on the script's side; whether the game keeps them is what probe 3 still checks for era swaps and catenary.
- **No base station sets `constructionType`** (desk check, 2026-11-05): none of the 14 `.con` files under `stations/{rail,street,water,air}.zip` (stations, harbour, underground station, kerbside stops, airports, heliports) sets it, and the word is in no script there. Nothing in the base game keys on it for stations.

For the kerbside stops (`street/small_stops/small_stops.script.lua`): a `streetTerminal` with `capacity = 50`, one `catchmentArea` with `radius = captureParams.catchmentAreaRadius` (160 m on `small_new`), `cost = buildCost or 6 × maintenanceCost`, `maintenanceCost` from the capture params (5,000), and `edgeObjectEmissionEmitter = {noise 1, pollution 5}`.

## How the game uses them at run time

- **Emissions follow crowding.** `game_mechanics/emission/emissions.script.tl` updates every station's emitter (offset 2 in its update cycle). It reads `api.engine.util.station.calculateStationUsage(entity)` and slides between the two emission states by `totalUsed / (poolCapacity + terminalCapacity)`, clamped to 0..1. So a station with more capacity is less crowded and emits less, as a depot with a larger pool does. The eco factor is 1 for stations: the Industry Greenification tool cannot reach them (from Depot Retrofits).
- **Station window.** A click on a station opens the construction window, whose tabs are the construction's subconstructions; for a station the content is `gui/entity_window/station_group/station_group.tl`, and the window takes `customTabs` (`gui/entity_window/make_entity_window.tl`, around line 130). Depot Retrofits' window script returns this base window with a Retrofit tab added, but for stations that route hides the station window; a card in the station window's plugin extension point is the alternative (see "Seen in other mods' code", probe 2). Seen in game (test results): the base window has no tab bar; it shows a Waiting Hall row (waiting / pool capacity) on stations with a pool, then one row per terminal (cargo type, length in m, waiting / capacity on passenger terminals only, the lines that stop), a Loaded/Unloaded graph, the upkeep per year and a Configure button. Selecting a station draws its catchment circle and highlights the buildings inside it.
- **No action area for plugin cards.** The station window hands its plugin cards the entity, its ownership, the game context, the callout side and the collapse functions (`gui/entity_window/eow_extension_util.d.tl`, `IEowWidgetsExtensionParams`; filled in `station_group.tl` around line 849), but no `setActionFn`. So a card cannot place the proposal viewer in the window's action area as Depot Retrofits' tab does, and Depot Retrofits found that the viewer placed among a window's own widgets stops the game (`Assertion !IsTransformWithContext(node.recipeId)`). For now the card only says that a rebuild was refused.
- **Tram tracks.** A road station with tram tracks has the construction param `tramTrack` above 1, which adds the tram transport modes (`street/modular_street_station/modules.script.lua`); the buy books its price under TRAM then, else ROAD.

## Air buildings

Desk check, 2026-11-16, from `base/content/stations/air.zip` and `gui.zip`; nothing here is tested in game. This mod owns these buildings, hangar depots included (spec, "Air buildings").

| Building | Script | Station values set in | Hangar depot | Upkeep and price |
|---|---|---|---|---|
| Airport (1950 and 1980 templates) | `air/airport.script.lua` | hook, about line 841 | one per hangar module (`air/airport/ap_hangar.module.lua`): pool 16, radius 550 m, capacity 5 | modules only (`cost = 0`); a hangar is $900,000, $150,000 a year, noise 20 / pollution 80 |
| Airfield (eras A, B, C) | `air/airfield.script.lua` | hook, about line 559 | one for all hangar modules (`air/airfield/af_hangar.module.lua`): pool 16, radius 550 m | modules only (`cost = 0`); a hangar is $600,000, $100,000 a year, from 1920 |
| Heliport | `air/heliport/heliport.script.lua` | update script; hook adds the landing modules' emissions | one, made by the script (about line 300): pool 4, radius 800 m at {0, 15, 0}, capacity 5, `HELICOPTER` | script $300,000 and $50,000 a year, plus $180,000 and $30,000 per landing module |
| Helipad | `air/helipad/helipad.script.lua` | update script (not modular, no hook) | none | script $180,000 and $25,000 a year |

- **Whether there is a hangar.** The airport's and airfield's construction param `hangar` ("Depot": Yes or No) decides whether the template places one; Configure can add more. The airport has up to two rows of 25 hangar slots (`hangar1SlotId` 2000, `hangar2SlotId` 2500; the second row only with a second runway and taxiway).
- **One depot per airport hangar, one per airfield.** The airport hangar has `constructionTag = nil`, so every hangar gets its own subconstruction and its own depot (`air/airport/airport_modules.script.lua`). The airfield hangar has `constructionTag = "hangar"`, so all hangars share one subconstruction, and the last hangar's depot table replaces the others (`air/airfield/airfield_modules.script.lua`, about line 47).
- **The depot table is handed over by reference.** `subconstructionResult.depot = subconstruction.depot` takes the module file's own table, and the base code then writes `catchmentArea.position` into it. Scale a copy: written back, the levels could stack on every preview if the game does not hand out fresh module tables each build (not known).
- **What the hooks keep.** The airport hook rebuilds `result.subconstructions`, keeping those with no `station` or with at least one terminal; hangar subconstructions have no station, so they stay with their depot. The airfield hook keeps every subconstruction and sets `station = nil` on those without terminals. Both overwrite each station subconstruction's `metadata.emissions` with the full module sums, so scale emissions after the original hook, as for the other stations. The heliport hook adds to `result.subconstructions[2].metadata.emissions` in place, so it must not run twice (the wrapper already runs a hook once).
- **A hangar's upkeep and emissions are the station's.** They are part of the module sums (`maintenanceCost`, `getModulesEmissions`), so the station's upkeep and emission trees already cover the hangars. A depot table carries only pool, radius, capacity and modes.
- **Levelling the depots needs no module wrapper.** The hook runs after every module's update script, so the wrapped hook sees each depot table in full and can scale pool and radius in one pass. Depot Retrofits' module re-level path (`relevelModule`) does not apply: it does nothing when a module makes the depot itself.
- **Params through Configure.** The airport's `preProcessFn` (`air/airport.script.lua`) changes only `params.modules` and returns the same `params`, so hidden level params should pass through it. The airports have no `upgradeFn`. Not tested.
- **Era templates.** Airports come as 1950 and 1980 templates, airfields as eras A, B and C (`air/airport.tl` `makeAirport`, year coefficient 1, 3 or 9). The templates only fill the params at placement; a rebuild runs the construction's own script with the copied params. Not tested.
- **The window has tabs.** A click on any part of an air building, a hangar included, goes to the construction (`gui/entity_window/view_manager_util.tl`, `wouldCreateView`). `make_entity_window.tl` (`makeEntityWindowContent`) counts the subconstructions that have a station or a depot, and with more than one it opens the `ConstructionWindow`, one tab per subconstruction. The tab names come from `getSubconstructionDescriptionAndSortKey`: "Runway" for an air station ("Helipad" for helicopters), "Depot" for a vehicle depot. A station tab holds the base station window, with the `::StationGroupEowExtensionPoint` cards, the Retrofit card included. A depot tab holds the base depot window (`MaintenanceStationWindowContent`, for a depot with a pool), which has its own plugin point, `::MaintenanceStationEowExtensionPoint` (`gui/entity_window/maintenance_station/maintenance_station.tl`). So an airport with three hangars should show a "Runway" tab and three "Depot" tabs, an airfield one "Depot" tab, a heliport a "Helipad" and a "Depot" tab; a click on a hangar probably opens its own tab (the clicked subconstruction is passed on as `initialSubconstruction`). An airport or airfield without a hangar, and a helipad, have one subconstruction and open the station window with no tabs, as the other stations do. How many station subconstructions an airport has (passenger and cargo, one or two runways) is not checked.

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
| Airport modules | 900k | 150k | 100 (terminals) | 300 (main building, below) | 20 / 80 | none |
| Airfield modules | 600k | 100k | 20–100 | 300 (main building, below) | 10 / 40 | none |
| Heliport landing module | 180k | 30k | none | none | 20 / 40 | none |

The air buildings' catchment does not come from the modules' `catchmentPassenger`: no air script calls `addCatchmentCircles`. The main building's module carries a subconstruction `catchmentArea` (300 m on both), which `airport_modules.script.lua` and `airfield_modules.script.lua` add to the station's `catchmentAreas` at the slot's position; the airfield main building's `catchmentPassenger` of 250 is not read. The heliport's script sets one 175 m circle, the helipad's one 100 m circle.
| Warehouse modules | 150k / 300k | 25k / 50k | none | none | 20 / 25, 50 | none |

For scale (from Depot Retrofits): a rail depot gives off 100 to 120 pollution, a road depot 80 to 100. A ten-platform rail station with a large main building gives off about 60 to 110 base, twice that when crowded. In Depot Retrofits' Dereham test, stations and tracks gave off about half of a town's pollution, which the depot mod cannot reach.

## Carried over from Depot Retrofits

Each of these held for depots and maintenance buildings in game. Where it is now seen on stations too, the point says so.

- `addModifier("loadConstruction", fn)` in `runFn` can wrap any construction's `updateScript`; `scripts/util.tl` `useFn` loads the original from an absolute `file@function` reference. A relative reference needs resolving against the `.con` file's folder (base stations use paths like `/stations/rail/modular_station/modular_station.script@updateFn`).
- Hidden level params: declared with `yearFrom = 9999`, they stay out of the build menu, are not passed when a building is placed, but are stored by a rebuild and passed to the update script. Seen on stations (probe 1).
- A rebuild with `createProposalReplaceConstruction(entity, params)`, sent from the game script's `update` with `makeWorldBuildProposalCmd(proposal, nil, false, false, false)`, kept the construction and depot entity ids, kept vehicles' lines, cost nothing, and survived save and load. It cleared every vehicle's maintenance link (the game reassigned them within a day). On stations: ids, line stops and waiting passengers kept, no charge, and the levels survive save and load (probe 1, 2026-11-05, 2026-11-10 to 2026-11-13).
- The game refuses a rebuild that collides with something built since (a house on the next lot; a road rebuilt to the depot's exit). Nothing is charged then. `builtin.ProposalViewer` with the real proposal, placed through `setActionFn`, shows what is in the way in red; `makeProposalData` with a `SimpleProposal` stand-in disagreed with the game too often. On stations: two rebuilds refused on the mod.io save "333", a collision at a passenger rail station and "Place on Shoreline" at a harbour, nothing charged (2026-11-15).
- Rebuilds the game starts (catenary, module edits through the depot's upgrade script) went through the wrapper and kept the levels. On stations: Configure does, on road, tram and rail stations (probe 3); catenary and era swaps not yet tested.
- `loadModule` modifiers are called by TF3 (Depot Retrofits wraps module update scripts with one). Probably not needed for stations, since the hook runs after the modules.
- Upkeep: the construction's `MAINTENANCE_COST` component holds the script's `maintenanceCost`; the charged figure is that × the base config's `infrastructureMaintenanceScale` (`calcMaintenanceForSubconstruction`). Seen on stations (probe 1, 1.25 in that save).
- Charging: a `JournalEntry` of type `CONSTRUCTION`, booked with `makeJournalBookAssetCmd` from the game script. Depot Retrofits uses `JournalEntry.Construction.DEPOT`; the list (`scripts/journal.d.tl`) also has `STATION`, which the station buy uses. The Finances tab shows it under Investments, Infrastructure, whatever the carrier (buy test).
- The game script's state is written from the simulation thread (`handleEvent`) and from about ten worker threads (`update`), each with its own copy; module variables do not persist. A pending buy counts as landed once the stored level is at least the bought one.
- Rank: base `company_progression_util.tl` gives the claimed rank. Seen in the station game script (`rankSource=util`).

## Seen in other mods' code (not tested by us)

From a read-only survey of the station, catchment, capacity and emission script mods on mod.io (2026-11-01). Names and per-mod notes are kept outside the repo. Each point is what those mods' code does or says; none is tested here.

- **Wrap the script, not the construction.** Several mods register a `loadScript` modifier keyed on the base station script paths and replace the script's `updateFn` with a wrapper. The base game loads station scripts with `util.useFn` (`scripts/construction/construction.script.tl:53`), so a `loadScript` wrapper runs whichever way the construction is reached, and it nests inside every `loadConstruction` wrapper. Rewriting a station's `updateScript` (Depot Retrofits' method) breaks other mods that recognise stations by `updateScript.fileName`, and mods that wrap with `loadConstruction` each need to be the outermost wrapper for their own window card to work. A `loadScript` wrapper avoids both. It misses only a wrapper that runs the base script file itself instead of through the game's loader: TRM: Industry Emissions does, and lost every level on road and tram stations and harbours until a shim was added ([docs/compatibility.md](../compatibility.md), seen in game 2026-11-07). One mod reports that a `loadConstruction` modifier registered in a preRunScript had no effect.
- **The hook runs only on modular stations.** The game calls `terminateConstructionHook` only when `params.modules ~= nil and result.slots ~= nil`; otherwise the values must be scaled straight away (helipads, kerbside stops). The hook can also be called more than once for one result, and a base hook is not repeatable (a second run adds lanes again: "Duplicate edge detected", then a crash): run the original once, cache its returns, and scale once. Harbours copy every result field, the hook included, into their station tables, so a wrapper must point those copies at itself too.
- **Multiply what is there.** Every mod surveyed multiplies the values it finds (or adds a bonus); none recomputes from a base. Scaling the values present after the inner hook, never setting absolute values, stacks multiplicatively with all of them. Scale copies, never write scaled values back into params: the game may hand the same tables to several builds, which compounds.
- **Copy all params on a rebuild.** The mods that rebuild stations deep-copy every existing param and set only their own keys, so foreign hidden params (ours included) survive their rebuilds. We must do the same. Some mods rebuild many stations by themselves (on first load, when their settings change, or after any nearby build), so a levelled station can be rebuilt, and get a new construction id, without our doing.
- **The station window.** `gui/entity_window/view_manager_util.tl:158` (`wouldCreateView`) opens the construction instead of the station group when the construction has an `entityWindowScript`, so setting one on a station would stop the base station window, and other mods' cards in it, from opening. Mods add to the station window with a react plugin instead: a `.res.lua` with `type = "react-plugin ::StationGroupEowExtensionPoint"`, gathered by `station_group.tl:864` (`usePlugins`) and shown as cards after the notifications. Plugins stack. The same exists for depots (`::MaintenanceStationEowExtensionPoint`) and warehouses.
- **Kerbside stops can be rebuilt in place**: two mods do it with `replaceSegment(edge)` and a new `SimpleStreetProposal.EdgeObject` carrying the copied params, with `context.player = -1`.
- **Commands.** Two mods call `sendCommand` from `handleEvent` or with a callback, which Depot Retrofits found not to work; others queue in `handleEvent` and send from `postUpdate`. Either the Depot Retrofits finding is narrower than written, or those calls fail.
- **Other APIs seen.** `api.engine.util.proposal.refreshConstruction(entity)` (rebuild with the same params); `api.cmd.makeEntitySetEmissionsCmd(entity, noise, pollution, radius, pollutionRadius)` (how the base emissions script sets a station's emitter); `api.engine.util.station.isStationOfType`; `streetConnectorSystem.getConstructionEntityForStation` (station group to construction).
- **Buildings that are both.** Some modded depots contain stations. The base airports, airfields and heliports contain hangar depots too, but they are this mod's (decided 2026-11-16) and Depot Retrofits never wraps them. Station Retrofits must skip any construction Depot Retrofits already wraps. The marker that holds in either load order is `updateScript.params.depotRetrofits ~= nil` (a `{ fileName, ref, owner }` table): its wrapper is `depot_retrofits_1::/construction_wrapper.script@update` since 1.3-dev, and with TRM: Industry Emissions outside it the `fileName` is TRM's (Depot Retrofits' `runsWrapper` in `retrofits.script.tl`). No check yet: only the three base station scripts are wrapped, which Depot Retrofits never wraps; the air scripts, when added, are not wrapped by it either.

## Unknowns

1. What a rebuild does to vehicles loading at the platforms or a train halfway into one. Waiting passengers are kept: 102 of 144 at a terminal stayed through six rebuilds (2026-11-05); waiting cargo is not seen. Ids and lines are kept (probe 1). A train on the station's track outside the platforms steps back onto the next segment (buy test); a train at a platform stayed.
2. Whether the Finances tab shows the levelled upkeep as the station window does (probe 1 checked the window and `calcMaintenanceForSubconstruction`), and how it shows a removal's refund.
5. How often the game refuses a station rebuild, compared with depots. 2 of 64 clicks on the mod.io save "333", a save whose depots the game often refuses too (2026-11-15); none in the other saves, several hundred clicks. Not known what the rail station collided with: the card has no proposal viewer.
7. Whether era swaps and catenary swaps keep the hidden params. Configure on road stations and a passenger rail station, and module edits on a cargo rail station, do (probe 3).
9. How much comfort and load speed change in play. Leave both out until measured.
11. How stations from popular mods are shaped (whether they return a `station` table, use `terminateConstructionHook`, set `constructionType`).
12. Whether the levels stack with other mods that change the same values. Read from their code (next section): they do if we wrap through `loadScript` and multiply the values we find; untested in game.
13. Where a harbour's pollution and noise are emitted: nowhere that the station reaches (settled enough for the spec: harbours get no pollution or noise trees). Both harbours in the pollution test, Nürnberg Hafen, and (2026-11-05) another port read 0 / 0 on the station entity's emitter, though the scaled `metadata.emissions` hold 34 / 210 and 68 / 420, and the overlays show no pollution or noise at a port. Harbours therefore get no pollution or noise trees. Not known: whether a ship loading at the quay adds anything to the station; the shots show none (ships emit as vehicles). A different source of the 34 / 210 figures is not found.
14. Air buildings, all untested: the tabbed window and where the card shows (probe 5); whether the game hands out a fresh depot table per build or the module's own one each time; whether Configure (`preProcessFn`) and a rebuild keep the hidden params and the era template's params on airports and airfields; how many station subconstructions an airport has.

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

  Cargo stations show no capacity at all, so the capacity tree has nothing in the base window to point at on them. Peterlee Station North and Upper Peterlee Station open from the same building with different ids: two constructions, a rail station and a street terminal, each in its own station group (probe 2).
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
- **Not seen:** a crowded station (at most one passenger waiting), a vehicle at a platform during the rebuild, a refusal.

### 2026-11-01: probe 2, Retrofit card; probe 1 again for 30 days

A fresh copy of `WR26A Giga-Tv3 1915 1101-1134 more mods`, logLevel `"full"`, with the card added. The probe 1 game script ran again on load (it acts once per save) and repeated the second run's values exactly. Played on at high speed past every watch; saved as `WR26A Giga-Tv3 1915 1101-1303-test`.

- **Load.** `card loaded ready=true styleutil=true` on the first station window. No `Recipe not found`, no `card … Error` line, no `Error while loading game script`, no `ProposalData error`.
- **Card, by window** (screenshots matched to the log's `Selected entity` and `card shown` lines):

| Window | Construction | Kind | Card |
|---|---|---|---|
| Upper Peterlee Station | 175556 | rail passenger | 5/5/5/5/5, first card above the waiting hall; footer $390,000 |
| Peterlee Station North | 331166 | tram, in the rail station's building | 0/0/0/0/0 |
| Lower Peterlee Station | 216491 | tram | 5/5/5/5/5; footer $188,906 |
| Peterlee Refinery N Port | 305819 | harbour | 0/0/0/0/10; footer $61,250 |
| Peterlee Refinery N Port Stop, … N Oil Delivery, Peterlee Station | 324497, 340363, 191943 | truck cargo | 0/0/0/0/0 |
| Thornwick Station, Holbeach Station Sidings | 125335, 15416 | rail passenger | 0/0/0/0/0 |
| Lower Holbeach Station, Holbeach Station Central, Holbeach Station Halt | 117761, 95594, 323674 | tram | 0/0/0/0/0 |
| Holbeach Station, Mill Lane, Highfield Road | none | kerbside stops | no card; base window as before |
| Holbeach Tram Depot | 348469 | depot | no card; Depot Retrofits' tab as before |

  The rest of each window (waiting hall, terminals, graph, upkeep footer, Configure) was unchanged. Every group seen held one construction. Not seen: a station placed during the session, a group of two constructions, another mod's station, another mod's card beside ours.
- **30 days** (watch offsets in game clock, 4,000 a day at calendar speed 1x): the levels, circles, capacities and upkeep held at 1 day, 7 days and 30 days. Buildings in reach stayed 12 (rail) and 85 (street, 72 before). Emitters at 30 days: rail 5.32 / 34.02, street 6.14 / 38.37 (base × 0.75 plus a little crowding). Waiting passengers grew to 13 (rail) and 5 (street), well under the levelled capacity. Every rebuild, the unchanged one included, cost $0.
- **Beam and circles.** A `tf3map` map of the 1303 save, with the logged circles and the construction's origin (`origin=` in the probe snapshot) on top: the origin sits on the rail station's tracks, on the tram terminal and on the harbour's building, which is where the beam of light stands in the screenshots. The circle centres are elsewhere: the rail station's 230 m circle is 72 m from the origin, the street terminal's two circles 15 m and 35 m, the harbour's circle 33 m (on the quay edge). So the beam marks the construction's origin, and the circles centre on the modules that carry catchment.


### 2026-11-01: collapsible card on a larger save

A copy of a large save from mod.io (May 1969, 229 stations, 153 lines, rank 13), logLevel `"full"`, with the collapsible card. The probe 1 game script levelled three stations when the save first loaded, as on the other saves.

- **First try.** Expanding the card raised the red "Reloading UI" screen: `Recipe child must be a layout`, in the recipe that draws the expanded rows. A recipe's root must be a layout (`builtin.BoxLayout`, as in `gui/entity_window/warehouse/warehouse_eow.script.tl`), not a `builtin.Component` holding one. Fixed; the collapsed card had been fine.
- **After the fix**, seven windows (two rail, three harbour, two road stations), no error line and no lag the player could see:
  - Collapsed: five rows, 13 open and 2 locked boxes at rank 13; tooltips as the spec says ("Catchment radius: Level 0/13 (max 15)").
  - Expanded: "Level 1: 200 -> 206 m", "4,503 -> 4,952", "0% -> -5%", and on the right the upkeep after that level, matching the shares (Hannover Station Ost, footer $2,358,400: catchment and capacity $2,712,160, pollution $2,476,320, noise $2,594,240, upkeep $2,240,480).
  - Window height: when the window is full (8 terminals; a bus terminal under an overcrowding notice) it keeps its height and the terminal list scrolls in less space; otherwise the window grows. Each window keeps its own open or closed card; a new window starts collapsed.
  - A cargo-only truck station showed waiting capacity "0" and "Level 1: 0 -> 0"; that row is now left out on stations with no waiting places (spec, "Buying a level").
- **Second run**, with that row left out (no error line): the truck station shows four rows, collapsed and expanded; the passenger stations still show five. The two cargo stations the probe levelled to 5/5/5/5/5 (a rail station with four "All Cargo Types" terminals, a bulk truck station) show the levelled card for the first time: five white boxes per row, "200 -> 230 m" and "175 -> 201 m", "-25%", "-25% of total", and expanded "Level 6: 230 -> 236 m" with the upkeep after it. Their waiting capacity row showed "0 -> 0" and offered "Level 6: 0 -> 0" for 15% more upkeep; the row is now left out there too, levels or not, and waiting capacity levels add no upkeep while a station has no waiting places (spec, "Price and upkeep"; the `applied` log line now has `charged=` beside `levels=`).

### 2026-11-01: buy buttons, first look

The `Deutschland 20` save copy as in the card tests, logLevel `"full"`, with the buy build (game script, buttons, banner). Log: `local/logs/stdout-2026-11-01-buy1.txt`.

- Loaded with no `Error while loading game script`; the game script logged `rank=13 earnedRank=13 rankSource=util`.
- Hannover Station Ost (8 terminals, levels 0): upkeep $2,358,400, build price $14,150,400, next prices $2,830,080 catchment, $1,132,032 pollution, $1,698,048 noise, $3,537,600 upkeep, as the formulas give.
- Expanded, "Level 1: 0% -> -5% of total", the upkeep and the button did not fit: the upkeep row's button ran past the card's edge ("$3,537,60"), and the upkeep figures started at a different place on each row. The rows now leave out "Level 1:" and "of total" and centre the upkeep between the effect and the button (not yet seen in game).
- **11 buys on Hannover Station Ost** (construction 116227), the game paused throughout (May 9, 1969): upkeep 1 to 3, noise 1 to 3, pollution 1 and 2, catchment 1 to 3, one click every 2 to 6 seconds. Log: `local/logs/stdout-2026-11-01-buy2.txt`.
  - Each buy landed and was charged within a second (`buy sent`, then `buy charged` with the stored levels as bought); no `notLanded`, no refusal, no "Not rebuilt". The construction id stayed 116227.
  - Each price was the one the card showed (`shownPrice` = `price`), and the balance before each buy was the one before it less that price. The bottom bar's earnings went from $97,838,672 to $67,396,563, down $30,442,109, the 11 prices to the dollar. Carrier RAIL (`carrierSource=kind`).
  - The build price held at $14,150,400 throughout (6 × upkeep ÷ the levels' factor), so later prices rose only by the 1.15 ladder: upkeep $3,537,600, $4,068,240, $4,678,476.
  - Upkeep: each level landed at the upkeep the card had shown for it ($2,358,400 to $2,240,480 for upkeep 1; noise 1 $2,205,104; catchment 1 $3,107,190 against $3,107,192 shown, a $2 rounding difference). Script upkeep 737,000 × the factor (`applied` lines).
  - Catchment: the largest circle 200, 206, 212, 218 m; the circle on the map grew.
  - The emitters read 0 after the first rebuild and stayed 0 while paused (`noisePower=0 pollutionPower=0` in every later line), as probe 1 saw: the game's emissions script sets them again once time runs.
  - Waiting passengers: as before each rebuild (the user watched; the waiting hall read 0 / 535 throughout).
  - A train just outside the platforms, on the station's own track, stepped back to the next track segment at the first rebuild, with the game paused, and stayed there through the next ten; a train at a platform did not move. As when a road segment is removed: the game moves a vehicle on a replaced edge onto an adjacent one.
  - The four Finances shots were taken before the first buy. Investments there has Roads, Tracks, Infrastructure, Warehouses and Vehicles, no Stations row; which row the charges went to is not seen yet.

### 2026-11-01: buys on six stations

A fresh load of the same `Deutschland 20` copy, logLevel `"full"`, with the three-part rows. Log: `local/logs/stdout-2026-11-01-buy3.txt`; 26 screenshots (18:04 to 18:10 local).

- **70 buys, all charged once** at the price the card showed: Hannover Station Ost (rail, 13, RAIL), Hannover Station Umstieg (road station with tram tracks, 22, TRAM), Hannover Station Abzweigung (cargo rail, 9, RAIL), Köln Station Anbau (cargo road, 5, ROAD), Köln Station Ost (cargo road, 13, ROAD), Nürnberg Hafen (harbour, 8, WATER).
- **Finances**: the charges land under Investments, Infrastructure. Its 3/69 to 5/69 figure grew by $119,521,852 by the first shot and $133,335,195 by the last, the sums of the logged prices at those times to the dollar; earnings fell by the same. The carrier shows nowhere there (Investments is not split by carrier).
- **The three-part rows fit** on every station: effect at the left, upkeep in the middle, button at the right edge. At rank 13 a tree at level 13 shows a greyed "Rank 14" button, and its tooltip "Level 13/13 (max 15)".
- **Harbours land slower.** Rail and road station rebuilds landed within a second of `buy sent`; the harbour's took 2 to 3 seconds (noise 3: sent 23:09:34, charged 23:09:37). The card waited 2 os.time ticks before calling a buy refused, so the "Not rebuilt" banner showed for a moment before four of the eight harbour levels landed (`card notRebuilt`, then the level). The game script gave up after 3 ticks: noise 3 was charged only because the landed check runs first. The card now waits 5 ticks and the game script 30 seconds.
- The tram terminal's waiting hall read 283 / 70 before any buy (the base game's own overflow; untouched by the levels).

### 2026-11-01: rapid buys with the processor busy

The same save, logLevel `"full"`, with the shared button width and the 5-tick wait; the processor saturated by other work, so the game ran slowly even at 4x. Log: `local/logs/stdout-2026-11-01-buy4.txt`.

- 52 buys on three stations (Hannover Station Ost 19, Nürnberg Hafen 24, construction 142527 9), all charged once; one more refused as stale (below).
- **The wait runs from the click, and the game script can be slow to take a buy up.** Harbour pollution 7: clicked 23:23:01, taken up (`buy queued`, `buy sent`) at 23:23:04, landed 23:23:06. The 5-tick wait ran out the same second, so the banner showed for a moment (`card notRebuilt waited=5`), as the user saw once. The card now waits 10 ticks.
- **A level of another tree let a second click through.** Two noise clicks at 23:23:06, one on each side of the card seeing pollution 7 land: the card took any change of the levels as the click having landed, so both went out with noise 0. The game script built the first and refused the second (`buy refused reason=stale stored=1`); one charge. The card now waits for the clicked tree to go up.
- **The buttons share a width** (25 screenshots): the stylesheet rule `Button!station-retrofits-buy { minSize = { 120, -1 } }` loaded, every buy button is the same width ("$556,800" as wide as "$222,720"), the price sits in the middle of it, and the upkeep figures end in one column before the buttons.

### 2026-11-01: pollution levels across a town

Save `WR26A Giga-Tv3 1915 1101-1134 more mods` (a fresh copy, rank 9, Jan 1915, balance about $484 million), logLevel `"full"`. Log: `local/logs/stdout-2026-11-01-pollution1.txt`; 24 screenshots (18:34 to 18:50 local), with the pollution layer and the Peterlee town window.

- **207 buys on 16 stations** in and around Peterlee (2 rail, 12 road of which 5 with tram tracks, 2 harbours), all charged once; no refusal, no "Not rebuilt". Every station to pollution 9 (−45%), 7 of them to upkeep 9 as well. $29.8 million in all. Carriers RAIL, ROAD, TRAM and WATER as the stations' kinds.
- **The town window's pollution sources** (date Jan 12, 1915 in every shot):

| Time (local) | Stations levelled | Stations | Industries | Company vehicles | Tracks | Rating |
|---|---|---|---|---|---|---|
| 18:40:18 | 5 of 16 | 23% | 20% | 18% | 15% | Poor |
| 18:43:25 | 13 | 17% | 21% | 21% | 16% | Poor |
| 18:47:10 to 18:50:44 | 16 | 15% | 21 to 22% | 20 to 22% | 17% | Poor |

- **What that means.** With every station's own pollution at 55%, a 15% share means the stations started near 24% of the town's pollution (0.55 × 24 / (100 − 0.45 × 24) = 14.8). The other sources' shares grew by the expected 1/0.89 (tracks 15 to 17%). So the town's pollution fell by about 11%, and its rating stayed Poor: industries, company vehicles and tracks make up the rest. At level 15 (−75%) the stations would fall to about 7% and the town's pollution by about 18%.
- **Pollution of the stations before their first level** (`pollutionPower` on the station entity): road stations 30 to 130, Upper Peterlee 45, Peterlee rail station 258, the two harbours 0 (unknown 13).
- **Price against effect.** Pollution 1 to 9 costs 1.34 × the build price (8.06 × the base upkeep) and adds 45% of the base upkeep a year. Per unit of station pollution removed: Upper Peterlee $63,861 once and $3,567 a year; the Peterlee rail station $36,868 and $2,059; a large road station $20,832 and $1,163; a small one $15,667 and $875. Level 9 alone costs $25,700 to $105,000 a unit. For scale only, the game's Cleaning Plant (`game_mechanics/emission/pollution_cleanup_facility.con.lua` and `.script.lua`; rank 10, $100 million, $10 million a year, needs machines) sets its own emitter to −10,000 pollution within 700 m while producing, a negative source in the emission grid that every emitter feeds: $10,000 a unit once and $1,000 a year. Whether a town's pollution rating reads that grid, or only sums the polluting sources its window lists (the plant is not among them), is not known: the rating is worked out in the engine. The eco level (Industry Greenification) does reach only industries (`ecoFactor` in `emissions.script.tl`).

### 2026-11-01: probe 3, first part: Configure on two road stations

Save `WR26A Giga-Tv3 1915 1101-1134 more mods` (a fresh copy, rank 9, Jan 12, 1915), logLevel `"full"`. Log: `local/logs/stdout-20261102-002722.txt`; 6 screenshots (19:25 to 19:26 local). Each station was bought to 0/9/9/9 (pollution, noise and upkeep 9) from the card, then changed in its Configure editor.

| Station | Before Configure | Change | After | Card after |
|---|---|---|---|---|
| Brentford Station (construction 228481, tram tracks) | 0/9/9/9 | platforms added: 120 to 192 terminal places, module upkeep $52,000 to $82,000 | two 40 m terminals, 96 places each; $132,481 a year | 0/9/9/9, "-45% of total" |
| Fairwater Station (construction 230660) | 0/9/9/9; one 20 m terminal, 48 places, $35,543 a year | one module ($75,308 in the editor): module upkeep $22,000 to $32,000 | one 30 m terminal, 72 places; $51,700 a year | 0/9/9/9, "-45% of total" |

- **The levels came through.** Every build the editor ran went through the wrapper with the stored levels (`applied kind=street levels=0/9/9/9`), and the station kept them afterwards. The upkeep after is the new modules' upkeep × the levels' factor × 1.25: $82,000 × 1.2925 × 1.25 = $132,481; $32,000 × 1.2925 × 1.25 = $51,700.
- **The editor runs in its own script state.** Opening Configure logged the start-up line again (`version 0.1-dev`, `wrapScript`), and every editor build ran on the Main Thread, one `applied` line per preview (a module under the cursor counts: Fairwater's log reached $42,000 of modules, the station kept $32,000). No separate build is logged when the change is accepted, and none on the simulation threads.
- **No charge from the mod.** No `buy` line during either edit; the editor's cost is the game's own module price.
- A kerbside stop's window (Manchester Road) showed no Retrofit card, as intended.


### 2026-11-02: a long play session

A new game (`WR26A Giga-Tv3 1900`, from Jan 1900, rank 1 to 2), played with the mod for about 6.5 hours (04:10 to 10:46 UTC), logLevel `"full"`. Log: `local/logs/stdout-20261102-play1.txt`.

- No `Error while loading game script`, no error from the mod; the four stack traces in the log come from the base game's GUI (`gui/main/selector_react_util.tl`, `gui/main/engine_react_util.tl`).
- 56 buys on 22 stations, all charged once, none refused, no "Not rebuilt". The game grew from 20 to 118 vehicles meanwhile.

### 2026-11-02: "Not bought" for a buy refused for money

Save `WR26A Giga-Tv3 1907 1102-2020` (Feb 1907, rank 7 then 8), with Depot Retrofits' matching fix, logLevel `"full"`. Log: `local/logs/stdout-20261102-notbought1.txt` (01:22 to 01:29 UTC); 9 screenshots (20:22 to 20:29 local).

- The money refusals before the fix: the 2026-11-02 evening log (`local/logs/stdout-20261102-play2.txt`, the same file as Depot Retrofits' `2026-11-02-1949-stdout.txt`) had two on tram station 308068, both shown as "Not rebuilt" 10 seconds later. The balance there falls by hundreds of thousands at once and climbs back within 5 to 15 seconds, so the refusals were right; only the banner was wrong.
- Oakheart Port (harbour 187686, levels 7/7/0/7): the card read the pollution buy as affordable at 01:25:31 (`affordable=nyyn`); the click at 01:25:32 was refused (`noMoney balance=-756596 price=49108`), and the card logged `card notBought reason=noMoney waited=0` in the same second, without waiting for the 10 seconds. The screenshots show the yellow note with the dollar icon above the level rows, "Not bought: not enough money at the time of the buy. Nothing was charged.", with the buy buttons greyed out (balance −$746,372). It stayed until the next click: at 01:28:04 the balance was back ($2,540,322, all four buttons enabled) and the note still up; the upkeep buy at 01:28:10 cleared it, landed and was charged. Two more buys followed, charged at the shown prices.
- No `card scriptStateError`: the card reads the game script's state. No `Error while loading game script`.
- How long the note stays, tried later with a temporary edit that refused every noise buy as `noMoney`: 30 seconds was too long; 10 seconds was right for reading it. It now shows for 10 seconds, then goes once the money covers the level again (spec).
- Depot Retrofits' fix showed the same in the same session: two `window notBought reason=noMoney` (road depot 254563, Oakheart Ship Depot 241189), the note in the depot's tab.

### 2026-11-03: buys at 2x to 4x, pending buys bounded by real seconds

Save `WR26A Giga-Tv3 1911 1103-1109` (1911, rank 11), logLevel `"full"`, with the game script giving up a pending buy after 30 real seconds only (a game day had bounded it too). Log: `local/logs/stdout-20261103-pending1.txt` (16:09 to 16:27 UTC).

- **132 buys on 13 stations, all charged once:** 3 harbours (28 buys, WATER), 9 road stations (2 of them with tram tracks, TRAM), 1 rail station (13 buys, RAIL). No `notLanded`, no refusal, no `card notRebuilt` or `card notBought`.
- **The game ran at about 1.5x to 4x.** Other mods' lines carry the game time: the clock ran at 1,500 to 4,000 units a real second while buying, so a game day passed in 1 to 3 seconds.
- **The harbours landed within a second** of `buy sent` this time, not the 2 to 3 seconds of 2026-11-01, so no buy needed the longer wait: a game-day bound would most likely have let these through too. A harbour that lands slower than a game day at 4x is still to be seen.
- No `Error while loading game script`, no error from the mod; the one stack trace comes from the base game's GUI (`gui/main/selector_react_util.tl`). No `hookAgain`.

### 2026-11-05: ports in the overlays, tram and cargo rail stations, emitter refill

Save `WR26A Giga-Tv3 1917 1104-2359` (Jan to Apr 1917, rank 13), logLevel `"full"`. Log: `local/logs/stdout-2026-11-05.txt` (01:49 to 02:08 UTC). Shots 20:50 to 21:07 local, read through the screenshot index. No `Error while loading game script`; the only errors are `ProposalData error: Collision` lines from the base game.

- **Ports emit nothing.** The pollution overlay at three harbours (Jan 13, 15, 16) showed the strongest rings on nearby industry, tanks and a quarry, never on the quay. A port in a quiet place, read in both overlays at Feb 11 to 19 and again after it was expanded (Feb 28, several wharf arms and a building), was flat grey in pollution and in noise, while a quarry-like site and a road beside it, in the same frames, lit up in both. No ship was at the quay in those shots. This matches the emitter reads of 0 on every harbour (unknown 13). The log has no `scale` or `buy` line for a harbour this session, so these were base ports. Result: pollution and noise trees removed for harbours.
- **The emitter reads 0 right after a rebuild.** Thornwick Station West (street terminal with tram tracks, construction 390832), 21 buys in about 45 seconds: every `buy charged` line read `noisePower=0 pollutionPower=0`, and the next `buy sent` line, a second later, read the station's real values again: noise 5 throughout, pollution 30 stepping down by 1.5 a level (28.5, 27, … 13.5 at level 12), the `scale` lines' `emissions` going 30 to 10.5 at level 13. So the 0 is the moment before the game refills the emitter. The station at 290199 did not recover in the log: 35 `buy sent` reads over about 30 seconds stayed 0 / 0 while its `scale` lines set the emitter correctly (for example 12 / 35 at pollution 13). How long the refill takes is not measured and does not matter to the mod; the overlays showed Thornwick West's final values after the buys.
- **Overlay hover figure, Thornwick, not a measure of the station.** The number beside the cursor on the overlay was pollution 10 (Mar 23, before any buy), 10 (Apr 7, pollution 13 bought) and 9 (Apr 20); noise 4 each time. It adds every source in range, including vehicle smoke, which the levels do not touch, and the field spreads slowly.
- **Probe 3, cargo rail station and a tram terminal.** Normanton Cargo Station (construction 13660, levels 11/11/11/11, 5 terminals) went through 14 rebuilds in 15 seconds (01:53:02 to 01:53:13) that the game started, no `buy` line among them. The wrapper applied 11/11/11/11 to each; the circle count went 5, 5, 4, then 5 again, with the modules' upkeep going from $293,000 to $288,000 and back (a $5,000 module removed and added again) and the circle order changing (a module moved or swapped). The card read 4 circles and a $2,175,000 build price before, and 5 circles and $2,197,500 after (+$22,500, the Small Main Building shown in the build menu at 20:53), the levels, radius (200 to 266 m) and the scaling unchanged; upkeep $701,437 to $708,693. A street terminal with tram tracks (Upper Normanton, 5/5/5/5, pool 27) was rebuilt twice with no `buy` line (01:52:03 and 01:52:10), the wrapper applying 5/5/5/5 to identical modules both times (radius 175 to 201.2 m, upkeep base $141,000). So on a rail station adding, removing and moving a module kept the levels. Not done: an era swap, catenary (the shots at 20:52 show the track tool, no rebuild).
- **Waiting passengers survive rebuilds.** Holbeach Station (construction 274638) had 102 / 144 waiting at terminal 1 and 1 / 144 at terminal 2 (Feb 2, 1917); six buys in five seconds (catchment, pollution and upkeep levels 12 and 13, 01:57:45 to 01:57:50) left 102 / 144 and 1 / 144, the same date. Peterlee South-Central Tram Station (290199) had 12 / 144 and 24 / 144 and a waiting hall at 0 / 54; 35 buys (01:56:40 to 01:57:09) left every figure unchanged in four shots (Jan 30). The game date did not move in either series, so this shows a rebuild keeping the waiting passengers, not how they behave over days. A vehicle at a platform during a rebuild is not covered.
- **Kerbside stop.** George Street (a tram stop) has no card, as expected: kerbside stops are out of scope.
- **Prices lowered after the pollution test** (spec): seen in game, for example Thornwick's first pollution level $12,300 on a $307,500 build price (share 0.04).
- **Ports in game, 2026-11-05 evening** (seven ports, shots of the same session): the card shows only the catchment and upkeep rows. The upkeep tree costs half: with the build price taken from each port's catchment price (0.20 × build price × 1.15^(level−1)), the upkeep price is 0.08 × build price × 1.15^(level−1) to the dollar on Normanton Port ($825,799 and $287,235), Peterlee Refinery North Port ($237,140 and $441,307), Refinery West Port ($227,840 and $424,000), Oakheart Port ($455,489 and $182,195) and Wigton Port ($531,413 and $212,565). Normanton's footer ($196,000/Year at catchment level 11, upkeep level 10) gives a build price of $887,500, as the catchment price did.

### 2026-11-07: a buy clicked as an autosave started

Save `WR26A Giga-Tv3 1919 1107-0627` (May 1919, rank 13), logLevel `"full"`. Log: `local/logs/stdout-20261107-115220.txt` (11:37 to 11:52 UTC). Not a planned test: the autosave fell in the middle of a run of buys.

- **The click waited out the save.** Street terminal 422978 (levels 6/0/0/0): `card buy … from=6 shownPrice=72861` at 11:49:17; the autosave started in the same second and took 3.7 seconds (11:49:17 to 11:49:21). The game script, which runs on the thread that saves, queued the buy at 11:49:21, right after `Saving game complete`, then sent the rebuild, and it landed and was charged once at the shown price (levels 7/0/0/0, radius 206.5 to 211.8 m). The card refreshed, and the next buys (pollution 1, catchment 8 to 11) went through as usual.
- **The autosave holds the state from before the click:** 6/0/0/0 on 422978, paid for 6 levels, and no buy half done. It also holds levels on street terminal 433784 (catchment 12, bought at 11:49:09).
- **The 30-second wait was not used.** It starts at `buy sent`, after the save here. Not covered: a save that starts between `buy sent` and the rebuild landing; that buy would be given up only if the save took over 30 seconds (this 266 MB save took 3.7).
- No `Error while loading game script`; the only errors are the base game's `ProposalData error: Collision` lines.

### 2026-11-07: TRM: Industry Emissions drops the levels on road and tram stations and harbours

TRM: Industry Emissions and TRM: Infrastructure Upkeep active, loaded after Station Retrofits, "Transport Building Emissions" at "Rebalanced" (logs `local/logs/stdout-2026-11-07-late.txt`, `stdout-2026-11-07-trm3.txt`; screenshots 20261107_174039 to 174106 and 181420 to 181631). No `applied` line in either session.

| Station | Bought | Before | After |
|---|---|---|---|
| Tram station (construction 390832, 1919 save) | catchment 8 to 14, $1,646,839 | levels 8/13/0/0, radius 217 m, upkeep (script) $116,850 | levels 14/13/0/0, radius 175 m, upkeep $20,500 |
| Peterlee Station Halt (road, 1974 save) | upkeep 1 to 11, catchment 1 to 11 (22 buys) | radius 175 m, upkeep $202,500/Year (after the first rebuild) | unchanged through every rebuild |
| Peterlee Oil Refinery East Port (harbour, 1974 save) | upkeep 1 to 11 | $496,000/Year, then $248,000 after the first rebuild (TRM: Infrastructure Upkeep catching up) | unchanged by levels 2 to 11 |

A rail station in the same sessions was levelled as usual (22 `applied kind=rail` lines; pollution 63 -> 56.7 for one level with TRM's factor on top). Cause and fix in [docs/compatibility.md](../compatibility.md).

### 2026-11-07: the ">|" button and the one-line card

logLevel `"full"`. Logs: `local/logs/stdout-2026-11-07-maxbutton.txt`, `stdout-2026-11-07-oneline.txt`, `stdout-2026-11-07-narrow.txt`.

- **">|" buys** on road, tram, rail and harbour stations: 21 buys in the first two sessions, each charged once, every charge equal to the tooltip's price (the sum of the single prices), several levels in one rebuild.
- **The one-line card** ("<", ">", ">|", prices in the tooltips) fits on each of those stations, a harbour included; the upkeep figures end in one column.
- **Money in the game's format.** With the narrower buttons and money through `api.util.formatMoney` (full setting), 6 more buys, no errors. Switching the game's money setting changes the card's figures at once.
- Not seen: a larger font setting, a refused rebuild.

### 2026-11-07: removing a level

logLevel `"full"`, TRM: Infrastructure Upkeep active. Log: `local/logs/stdout-2026-11-07-remove.txt`; screenshot 20261107_170221 (the "<" tooltip).

- **18 removals and 4 buys on a cargo rail station** (construction 340874), each booked once, when the level had moved; every refund and price equal to the card's (`buy refunded`, `direction=down`, carrier RAIL).
- A 14-level ">|" catchment buy for $7,806,875, removed level by level, refunded $6,245,716: 80%, with per-level rounding.
- A removal then ">" on the same tree works; the tooltip's upkeep after removal matched the station's.
- The first removal refunded $159,982 where the level then cost $99,984: the station still had the upkeep it was built with before TRM: Infrastructure Upkeep was switched on, and the rebuild halved it ([docs/compatibility.md](../compatibility.md), "Overlapping mods").

### 2026-11-07 and 2026-11-08: the TRM fix, both load orders

1974 test saves with TRM: Industry Emissions and TRM: Infrastructure Upkeep at their defaults. Logs: `local/logs/stdout-2026-11-07-trmfirst.txt` (TRM before us), `stdout-2026-11-08-next.txt` (TRM after us). Results and log lines in [docs/compatibility.md](../compatibility.md).

- **162 buys and removals** on road stations, harbours and rail stations, each equal to the card's amount, an `applied` line for every rebuild, no load errors.
- **Removals beyond rail:** 11 catchment and 9 upkeep removals on a harbour (329843, WATER; its upkeep tree refunds half), 11 catchment removals on a road station (408411), 4 pollution removals on another (463985, ROAD).
- **Stations placed in session** (a road station and a harbour) showed their cards at once and took levels.

### 2026-11-10 to 2026-11-13: levelled saves loaded, Configure on a passenger rail station

Saves `WR26B Giga Dry v1 PLAY 1908 1108-2217`, `WR26C-Giga-Dry-v1 PLAY 1907 1112-0710` and `WR26C-Giga-Dry-v1 PLAY 1911 1113-0645` (rank 4 to 8), logLevel `"full"`, Depot Retrofits 1.4-dev active. Logs: `local/logs/stdout-20261110-235658.txt`, `stdout-20261114-013915.txt`. No `Error while loading game script` after any load; `trmRedirected=0`.

- **Levels survive save and load.** Each save came back with its levelled stations as they were left, read by the card when their windows were opened:

| Station | Levels | Read after loading | Formula |
|---|---|---|---|
| Rail station 327566 (bought 2026-11-08 23:51 UTC, then saved as `1108-2217`) | 4/0/0/4 | radius 224 m, upkeep $320,000, build price $1,500,000 | 200 m × 1.12; base $250,000 × 1.6 × 0.8; 6 × $250,000 |
| Road station 300298 (`1112-0710`) | 4/4/0/4 | radius 196 m, upkeep $59,040 | 175 m × 1.12; $41,000 × 1.8 × 0.8 |
| Rail station at 0/4/0/4 (`1112-0710`) | 0/4/0/4 | levels and scaled emissions applied in its next edit | |
| Road station 300298 (`1113-0645`, after modules added) | 6/6/0/6 | radius 206.5 m, upkeep $186,340 | 175 m × 1.18; $121,000 × 2.2 × 0.7 |

- **The station script is not run on load.** No `applied` line follows a load: in each session the first one comes with the first buy or edit, minutes later. The save keeps the scaled result (probe 1, point 9).
- **Configure on levelled stations, 207 rebuilds with no buy** (2026-11-12 23:36 to 2026-11-13 00:33 UTC), one `applied` line per editor preview: rail station 19745 (0/5/0/5, main and side buildings, 7 to 11 circles of 50 to 175 m), the rail station at 0/4/0/4, and road stations at 6/6/0/6, 5/5/0/5 and 0/5/0/5. Every preview applied the stored levels; the base upkeep moved with the modules (rail $175,000 to $240,000 and $268,000 to $405,000, road $51,000 to $121,000) and was multiplied by the levels' factor. The cards afterwards showed the same levels.
- **Script upkeep below the modules' sum during an edit.** In 18 previews over about 10 seconds on the 0/4/0/4 rail station, the script's `maintenanceCost` ($390,000, `upkeepBase`) was $8,000 below the sum of the modules' upkeep ($398,000, `upkeepModules`); the previews before and after agreed ($403,000, then $405,000 at the end). Likely a module under the cursor not counted by the game. The wrapper scales the script's figure, so the charge follows the game's.
- **Buys and removals.** 80 buys and 13 removals across both logs, on road, rail and harbour stations, catchment up to level 8 and noise included, each booked once at the card's amount. Radii as the formula: 175 m to 201.2, 206.5, 211.8 and 217 m at levels 5 to 8; a harbour's 150 m circle to 175 m at catchment 5 (the 5 m floor). Refunds are 80% of today's price: pollution 4 and 3 on rail station 338346 refunded $67,210 and $61,100, and buying both back cost $160,388.
- **The rank cap follows the rank.** The company went from rank 5 to 8 during the session; the card's highest level went 5, 6, 7, 8 with it.
- **Base game lines, not the mod's.** `no catchment areas generated for station` (1,548 lines on 2026-11-10), in bursts while a station window is open or just closed; a Depot Retrofits log of 2026-10-29, before this mod existed, has it too. `Ignoring Set() on expired ReactRefWrap` stack traces from `gui/main/selector_react_util.tl`.

### 2026-11-15: refused rebuilds, level 13 in one rebuild, removals on a tram station

Two saves, logLevel `"full"`, Depot Retrofits 1.4-dev active, no TRM in either save's "Active mods" (`trmRedirected=0`). Log: `local/logs/stdout-20261115-114300.txt` (09:54 to 11:44 UTC). No `Error while loading game script`; no error from the mod.

- **The mod.io save "333"** (a copy; Apr 2000, rank 13). First loaded without Station Retrofits, then again at 10:00 UTC with it switched on: every station built before the mod was added showed its card at 0/0/0/0 and took levels.
- **Two rebuilds refused, nothing charged.** Both were ">|" upkeep buys to level 13:

| Station | Price | The game's error | Card | Game script |
|---|---|---|---|---|
| Fordwich Station Transfer (passenger rail, 76670) | $51,610,321 | `ProposalData error: Collision` | `card notRebuilt` 10 s after the click | `buy notLanded seconds=30 stored=0/0/0/0 charged=false` |
| Pickering Port (harbour, 93314) | $14,180,470 | `ProposalData error: Place on Shoreline` | same | same |

  Screenshots 20261115_050224 and 20261115_050706 show the yellow banner on each: "Not rebuilt: a building, road or track is in the way. Nothing was charged. Clear it and buy again.", levels and footer unchanged. For the harbour the cause it names is wrong: the game's error is about the shoreline, not something in the way. Why the port's place fails that check now is not known; Depot Retrofits found that save was first written by a pre-release build, which may be the cause.
- **Level 13 in one rebuild** (">|" from 0 to 13, rank 13) landed on rail stations 66198, 101190 and 103579 ($49,961,430 to $106,023,758), road station 147589, tram station 123615 and harbour 108540. Harbour 108540 at catchment 1, upkeep 13: radius 257.5 m (250 m × 1.03), upkeep $237,475 ($590,000 × 1.15 × 0.35; screenshots 20261115_050612 and 20261115_050624).
- **Removals on a tram station** (197132, a road station with tram track, carrier TRAM): upkeep 13 to 10, refunds $2,075,041, $1,804,383 and $1,569,029, each 80% of the level's price (steps of 1.15). Rail station 92517: upkeep 13 to 10, $11,274,523 in all.
- **The WR26D save** (`WR26D-Giga-Dry-v1 1900`, a new 1900 game, about 30 other mods active, among them Town Zoning, Industry Upgrades and Bus and Truck Bay): 17 stations levelled at rank 5, then rank 6 at 11:41 UTC, most to 5/5/5/5 with ">|"; tram stations 175 m to 201.2 m (× 1.15).
- **Every click booked once at the card's amount.** 114 buys and 6 removals on 28 stations; per station, the card's prices and refunds summed equal the charged and refunded amounts to the dollar.
- **The card at work** (screenshots 20261115_050115, 050801; 2026-11-14 20:24 to 20:26 UTC on the WR26D game, whose log was overwritten): footers equal the logged upkeep ($2,740,500 at 4/6/2/8 on a cargo rail station, $437,675 at 2/7/4/13 on a road station); at rank 1, all buttons greyed with the account at −$9,261, and the "<" tooltip "Remove level 1 for a refund of $16,128. Upkeep after removing it: $25,200/Year." (80% of 0.16 × $126,000; $21,000 × 1.2).
- **Base game and other mods' lines, not the mod's:** `Ignoring Set() on expired ReactRefWrap` stack traces from `gui/main/selector_react_util.tl`; the Depot Retrofits refusals earlier in the same session.

### 2026-11-21: the banner's third line cut off; a retry replaces the pending buy

The mod.io save "333" (a copy; May 2000, rank 13), logLevel `"full"`, Station Retrofits the only active mod, after PR #30 (one rebuild at a time per station, the reworded banner). Log: `local/logs/2026-11-21-banner-stdout.txt` (17:07 to 17:12 UTC). No `Error while loading game script`.

- **The third line did not fit.** Liskeard Station (passenger rail, 112652) was refused catchment 1 ($1,098,000; `ProposalData error: Collision`). Screenshot 20261121_121136 shows the banner 2 seconds after it appeared: "Not rebuilt: the game refused to rebuild the station." (53 characters) just fits beside the icon, but "Often a building, road or track is in the way: clear it and retry." (66) is cut off after "clear it and re". A line does not wrap, and about 55 characters fit at the default font, so the lines are now 42 characters at most.
- **A retry replaces the pending buy.** The banner showed 10 seconds after the click (`card notRebuilt waited=10`). Clicked again at once, the same level: the game script dropped the first buy (`buy notLanded ... reason=replaced charged=false`) and sent the retry, which the game refused again; the card showed the banner again 10 seconds later, and the game script gave the retry up 30 seconds after sending it (`buy notLanded seconds=30 stored=0/0/0/0 charged=false`). Nothing was charged.
- **Text Scaling, after the lines were cut to 42 characters** (log `local/logs/2026-11-21-fontsize-stdout.txt`, 17:16 to 17:18 UTC; Liskeard Station refused pollution 1, banner 10 seconds after the click, given up after 30 seconds, nothing charged). Screenshots 20261121_121738 to 121818: at "Small" (100% UI) the three lines fit with room. At "Large" (100% UI, 121753) the first line, "Not rebuilt: the game refused the rebuild." (42 characters), is cut off at its last letter, so about 40 fit; a smaller window at 121806 has it at the edge. So the lines are now 35 characters at most. In the same shots at "Large", the expanded card's catchment row ("150 -> 155 m", "$1,052,250/Year") pushes its ">|" button off the card, and the other rows nearly touch the edge.
- **Every click booked once.** 72 rebuilds sent on 8 rail and road stations: 66 buys charged, 4 removals refunded at 80% of the level's price (Fordwich Station, 96135, which then bought the same levels again at the same prices), 2 not landed (above). No buy refused by the game script, so the `pending` refusal was not seen.
