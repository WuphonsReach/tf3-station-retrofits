# Station Retrofits

A Transport Fever 3 script mod, in development: stations get levels that widen their catchment, cut their pollution and noise, and cut their upkeep, bought in the station's window. It is the sibling of [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits), which does the same for depots and maintenance buildings.

## In short

- **Status.** In development, not released; version 1.0 is being prepared for rail, road, tram and harbour stations ([TODO.md](TODO.md), "Release 1.0"). Levels are bought and removed from a Retrofit card in the station window, and work in game on rail, road, tram, cargo and harbour stations. Airports, airfields and heliports come after 1.0.
- **How it works.** As in Depot Retrofits: the mod wraps each base station script's update function, reads hidden level parameters, and rebuilds the station to apply a level. A modular station sets its catchment and emissions in one hook that runs after all its modules, so the wrapper sees the final values. Harbours get only the catchment and upkeep levels: a port emits no pollution or noise of its own.
- **How sure.** The station facts are read from the game's own scripts; buying, removing and the levels' effects are tested in game, one fix for TRM: Industry Emissions included ([docs/compatibility.md](docs/compatibility.md)).
- **Unknown.** What a rebuild does to vehicles at the platforms, and whether era and catenary swaps keep the levels ([TODO.md](TODO.md)).

## Notes

- [docs/user-guide.md](docs/user-guide.md): how to use the mod, for players.
- [CHANGELOG.md](CHANGELOG.md): what each version changed.
- [docs/publishing.md](docs/publishing.md): how a version is released on mod.io and GitHub.
- [docs/design/findings.md](docs/design/findings.md): what is known about stations in the base game, with source files, and what is still unknown.
- [docs/design/spec.md](docs/design/spec.md): the levels, prices, card and scope, with the open decisions.
- [docs/design/probe-plan.md](docs/design/probe-plan.md): the in-game probes that tested the method, and what is left of them.
- [docs/compatibility.md](docs/compatibility.md): known and suspected incompatibilities with other mods.
- [TODO.md](TODO.md): what is left to do.

## Licence

MIT, see [LICENSE](LICENSE).
