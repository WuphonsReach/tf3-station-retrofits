# Probe plan

## In short

- **Why probes first.** The method is proven on depots, but a station rebuild touches far more of the game: waiting passengers and cargo, vehicles at the platforms, lines, and many track and road connections. Four probes answer the unknowns in [findings.md](findings.md) before the spec is fixed. Each probe is a small test build of the mod, run by the user in game on a copy of a manual save. Results go into findings.md, and the probe code stays in git history.
- **Order.** Probe 1 (rebuild a few stations with fixed levels) decides whether the mod is worth building and whether the upkeep tree exists. Probe 2 (the window tab) and probe 3 (rebuilds the game starts) come next. Probe 4 (kerbside stops) decides their scope. Probes 2 and 3 can share one session with probe 1's build.
- **How a probe acts.** As in Depot Retrofits: a probe acts by itself once the save loads, with a small cap (a handful of stations), and logs before and after. No buttons, no confirmations; the user tests on a copy of a save.

## Shared setup

- The mod folder (planned name `station_retrofits_1`) is symlinked into the game's `staging_area/`; scripts and `mod.json` need a game restart to reload.
- Every log line starts with `STATION_RETROFITS` and carries `key=value` fields. Copy `crash_dump/stdout.txt` to `local/logs/` before reading it (it is overwritten at each launch; times are UTC).
- After a load, check the first lines for `Error while loading game script` before the user plays at speed.
- Put every unverified API call under `pcall` with a log line as the fallback.
- A good save has a rail station with a few platforms and lines, a road or tram terminal, and a harbour, all busy, near a town.

## Probe 1: rebuild with fixed levels

**Build.**

- `mod.script.tl` `runFn`: a `loadConstruction` modifier that only declares five params on the base modular rail station, street terminal and harbour (`stationRetrofitsCatchment`, `…Capacity`, `…Pollution`, `…Noise`, `…Upkeep`; values 0 to 15; `yearFrom` 9999) and leaves `updateScript` alone; and a `loadScript` modifier that wraps the `updateFn` of their three base scripts (findings, "Seen in other mods' code"). Skip anything Depot Retrofits wraps.
- Wrapper: run the original `updateFn`; if `params.modules` and `result.slots` are set, replace `result.terminateConstructionHook` (and every copy of it in the result's tables, for harbours) with one that runs the original once, caches its returns, and then scales, once per result, the station subconstruction (`cargoStation` or `passengerStation`, whichever has a `station` table): every `catchmentAreas[i].radius`, `station.pool.capacity`, each terminal's capacity, both `metadata.emissions` states. Set `result.maintenanceCost` to the levelled total minus the modules' upkeep (`params.modules[*].metadata.maintenanceCost`), and let it go below 0. Scale copies of the tables, multiplying the values found. Log before and after for each value.
- Game script: once per save (flag in `state`), pick up to 3 stations (one of each kind if present) and rebuild each with all five levels at 5, from `update`, with a full copy of the construction's params. Log a snapshot before the rebuild and after 1 game hour, 1 day, 7 days and 30 days.

**Snapshot fields.** Construction id; station entity ids and terminal count (`CONSTRUCTION` component, `STATION` components); `api.engine.util.station.calculateStationUsage` (pool capacity, terminal capacity, total used); waiting passengers and cargo per station; lines stopping there (line system) and vehicles at its terminals; catchment radii; emitter noise and pollution (live); the `MAINTENANCE_COST` component and `calcMaintenanceForSubconstruction`; the company balance just before and just after the rebuild lands.

**Answers it gives (pass = yes).**

1. The hook wrapper runs after the modules: the logged values before scaling equal the sums from the modules, and after scaling equal the formula.
2. Station and terminal entity ids, lines and stops survive the rebuild.
3. Waiting passengers and cargo survive (if not: how many are lost).
4. Vehicles loading or arriving carry on (watch a train in the platform at the moment of the rebuild).
5. A rebuild that changes nothing costs nothing (rebuild one station with all levels 0 too).
6. A negative `maintenanceCost` lowers the charged upkeep: the footer, `calcMaintenanceForSubconstruction` and the Finances tab show the lower figure. If the game clamps, errors or ignores it, record exactly what it does.
7. Catchment: the station window's catchment display and the map overlay show the larger circles; more houses are in reach.
8. Emissions: the emitter's power follows the scaled states.
9. The levels and values survive save and load (load the autosave; the wrapper should not be called on load).
10. Refusals: note every rebuild the game refuses (`ProposalData error` lines) and what was in the way.
11. The `loadScript` wrapper is reached: the wrapper's log line shows on each rebuild and on placing a new station, with the hidden params in `params`.
12. The hook guard: count calls of the wrapped hook per result; a second call must not scale twice or crash.

## Probe 2: Retrofit card in the station window

**Build.** `retrofit_card.res.lua` and `retrofit_card.script.tl`: a react plugin for `::StationGroupEowExtensionPoint` that shows one collapsible Retrofit card per station group: collapsed, a row per tree with the level boxes and what the levels do now; expanded, what the next level changes and the upkeep after it (no buy button yet). Each wrapped construction in the group gets its rows (found with `getConstructionEntityForStation`; a heading per construction when the group holds more than one). Its condition shows the card only for the player's stations with at least one wrapped construction. The game calls a plugin's recipe without checking it exists and calls its condition unguarded (`gui/main/gui_react_util.tl`, `usePlugins`), so the condition never throws and is false when a load failed. Do not set `entityWindowScript`: it would stop the station window from opening. At `"full"` the card logs `card shown group=…` with, per construction, the levels, the number of stations, circles and terminals, the largest circle and the waiting places, once per change; on a big station these show what the card reads on every step.

**Pass.** The station window is unchanged and the Retrofit card shows on all three kinds with the levels probe 1 stored (5/5/5/5/5 on the rail and street stations, 0/0/0/0/10 on the harbour, 0/0/0/0/0 elsewhere), on a station placed during the session too, on a group of a station and a terminal joined, not on a kerbside stop or a competitor's station, and next to other mods' cards when they are active. The log has no `Recipe not found` or `card … Error` lines.

## Probe 3: rebuilds the game starts

By hand, on a levelled station from probe 1: add a platform, remove a module, swap a module's era, switch catenary on a rail station, and on a street terminal swap a module.

**Pass.** Each edit goes through the wrapper (log line) and keeps the five levels; the scaled values match the formula for the new module set; the upkeep is (base + modules) × the level factor.

## Probe 4: kerbside stops

**Build.** Wrap the kerbside stop script (`street/small_stops/small_stops.script`; scale straight away, as stops have no hook), scale the `streetTerminal` capacity and catchment radius, and have the game script rebuild one stop with `replaceSegment` and a new `SimpleStreetProposal.EdgeObject` carrying the copied params (the method other mods use). Note: one mod replaces the stop script outright (last wins), so a stop tree may not reach every player.

**Pass.** The proposal is accepted and the stop keeps its street, lines and waiting passengers. If the API refuses an edge object, or the stop is removed and placed again with new ids, leave stops out of scope.

## Later (not planned)

- **Comfort and load speed.** Two like stations on one line, one with a comfort or load-speed level: compare passenger choice and loading times. Only if a tree for them is wanted.
- **Other mods' stations.** Survey the stations of the user's subscribed mods (a desk check of their scripts, see TODO.md) before widening detection.
