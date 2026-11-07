# Compatibility with other mods

## In short

- **No confirmed incompatibility yet.** One suspected: TRM: Industry Emissions, which wraps the base street station and harbour scripts itself. It should not stop stations from being placed, but it may make the levels on street stations and harbours do nothing. Read from its code; not tested in game.
- **Why it is suspected.** TRM loads the base station script with its own `ug_require` instead of the game's `util.useFn`. Station Retrofits applies its levels through a `loadScript` modifier, and only the `useFn` path is known to go through it.
- **Rail stations are not affected**: TRM leaves `modular_station` alone (its factor there is 1).
- **The other mods that change station values** were read from their code and are expected to stack ([docs/design/findings.md](design/findings.md), "Seen in other mods' code"). None is tested in game with the levels yet (TODO.md).
- **Related, in Depot Retrofits:** the same TRM mod blocks placing new depots when it loads after Depot Retrofits (`docs/compatibility.md` in `../tf3-depot-retrofits`). Station Retrofits leaves `updateScript` alone, so that failure does not apply here.

## Suspected incompatibilities

### TRM: Industry Emissions

- **The mod.** [TRM: Industry Emissions](https://mod.io/g/transportfever3/m/trm-industry-emissions) (EloudaLightstar, `trm_building_emissions_1`, part of the "Transport Rework Mod" series), read in the version updated 2026-10-27. With its "Transport Building Emissions" setting at "Rebalanced" (the default), its `loadConstruction` modifier points the `updateScript` of the base transport buildings at its own wrapper, picking them by `.con` file name. Among the stations Station Retrofits levels, it halves the emissions of `modular_terminal` (street stations) and `harbor_modular` (harbours), and skips `modular_station` (rail, factor 1). It also replaces the base emissions game script with its own copy.
- **How it loads the original.** Its wrapper turns the reference it found into a path with `.lua` added, loads it with `ug_require` and calls the global `data()` that the file defines (its `game_mechanics/building_emissions/building_build.script.lua`, `loadOriginal`). It then calls that table's `updateFn` with the capture params and scales the result's emission lists.
- **Why the levels may be lost.** Station Retrofits wraps the station script's `updateFn` in a `loadScript` modifier. The base game loads construction scripts with `util.useFn`, which goes through that modifier (tested in game, findings, probes 1 and 2). Whether TRM's direct `ug_require` and `data()` also go through it is not known. If they do not, TRM calls the unwrapped base `updateFn` on street stations and harbours. A level buy would then rebuild and charge, but change nothing, and nothing would raise an error. On harbours that would cost the catchment and upkeep levels; on street stations all four.
- **If the levels do apply.** Our wrapper is then inside TRM's, and the two reductions multiply. One possible gap is on TRM's side: our wrapper points the copies of `terminateConstructionHook` that harbours make in their station tables at our wrapped hook, while TRM wraps only `result.terminateConstructionHook`. If the game calls a copy, TRM's pass after the hook may not run.
- **Test** (TODO.md): TRM active and at "Rebalanced", in both load orders. Buy a level on a street station and on a harbour, and check the `wrapScript` and buy lines in the log and the values after the rebuild.
- **If it fails.** The wrapper also has to reach TRM's path. That could mean wrapping the base station script's `data()` result as well, or recognising TRM's `beOriginalScript` capture param. Station Retrofits takes no dependency on TRM.
