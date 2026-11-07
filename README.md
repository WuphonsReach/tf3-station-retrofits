# Station Retrofits

A planned Transport Fever 3 script mod: stations get levels that widen their catchment, cut their pollution and noise, and cut their upkeep, bought in the station's window. It is the sibling of [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits), which does the same for depots and maintenance buildings.

## In short

- **Status.** In development, not released. Levels are applied by a rebuild and shown in the station window (tested in game); buying them is built and not yet tested.
- **How it would work.** As in Depot Retrofits: the mod wraps each station construction's update script, reads hidden level parameters, and rebuilds the station to apply a level. A modular station sets its catchment and emissions in one hook that runs after all its modules, so the wrapper sees the final values.
- **How sure.** The station facts are read from the game's own scripts. The rebuild method is tested on depots, not yet on stations.
- **Unknown.** What a rebuild does to waiting passengers and cargo and to vehicles at the platforms, and whether the upkeep can be cut at all on a modular station. The probes in [docs/design/probe-plan.md](docs/design/probe-plan.md) answer these first.

## Notes

- [docs/design/findings.md](docs/design/findings.md): what is known about stations in the base game, with source files, and what is still unknown.
- [docs/design/spec.md](docs/design/spec.md): the draft retrofits, prices and scope.
- [docs/design/probe-plan.md](docs/design/probe-plan.md): the in-game probes to run first.
- [docs/compatibility.md](docs/compatibility.md): known and suspected incompatibilities with other mods.
- [TODO.md](TODO.md): what is left to do.

## Licence

MIT, see [LICENSE](LICENSE).
