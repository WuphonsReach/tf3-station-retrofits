# TODO

## In short

- **Where it stands.** Probes 1 and 2 work in game: levels applied by a rebuild, all values as the formulas say for 30 days, and a Retrofit card in the station window showing them. Buying a level from the card is built (game script, buy buttons, "Not rebuilt" banner) and not yet tested. Rebuilds the game starts and kerbside stops are not tested yet.
- **Next.** Test buying in game (below), then probe 3 (rebuilds the game starts) with bought levels, in one session with the probe 1 and 2 leftovers (results so far in [docs/design/findings.md](docs/design/findings.md)). Decisions so far are in [docs/design/spec.md](docs/design/spec.md), "Decisions".

## Set-up

- [x] mod.io name check: no Station Retrofits or close name (in-game Mod Hub and mod.io, 2026-11-01).
- [x] Mod scaffolding, copied from Depot Retrofits and renamed: `mod.json`, `_metadata/modinfo.json` (draft text), `_content.json`, `content/settings.tl`, and a `content/mod.script.tl` that only logs its start-up line.
- [ ] `types/station_retrofits.d.tl` and the require in `all_def.tl`: with `levels.tl`, when there is something to type.
- [x] Tools and CI, copied and adapted: `tools/check_content_list.py`, `tools/check_repo.py`, `.github/workflows/checks.yml` (checkout v7.0.1 and setup-python v7.1.0, still the latest releases on 2026-11-01).
- [x] `tlconfig.lua` filled in on this machine; `tl check` passes.
- [x] Symlink `station_retrofits_1/` into the game's `staging_area/`.
- [x] GitHub repo, public, MIT, settings and rulesets as Depot Retrofits: `main`, `pr-checks`, `trunks`, `version-tags`.

## Probes ([docs/design/probe-plan.md](docs/design/probe-plan.md))

- [x] Probe 1: rebuild 3 stations with fixed levels (findings, test results): wrapper, ids, cost, upkeep, catchment, capacity, emissions all as the formulas say.
- [ ] Probe 1 leftovers: a crowded station and a vehicle at a platform during a rebuild; save and load of a levelled station (load `WR26A Giga-Tv3 1915 1101-1303-test`). Done: 30 days, the beam beside the circle centres.
- [x] Probe 2: Retrofit card in the station window (plugin extension point, not `entityWindowScript`), base window unchanged. Left: a station placed in session, a group of two constructions, next to another mod's card.
- [ ] Probe 3: module edits, era swaps and catenary keep the levels.
- [ ] Probe 4: kerbside stops (edge objects) can be replaced.
- [ ] Record each probe's results in [docs/design/findings.md](docs/design/findings.md) (In short first, test results at the bottom).

## Desk checks (no game needed)

- [x] Which `JournalEntry.Construction` value suits a station charge: `STATION` (`scripts/journal.d.tl`); still to see in the Finances tab.
- [ ] Whether base station `.con` files set `constructionType`.
- [ ] Whether the rail and street `upgradeFn` return the other params unchanged (`rail/modular_station/modular_station.script.lua` around line 351).
- [x] How the station window shows catchment and capacity: a Waiting Hall row and terminal rows with waiting / capacity (passenger terminals only), the upkeep footer; no catchment figure (findings, test results). The card need not repeat them.
- [x] Survey the mods that change the same values or the station window: 13 mods read (notes in `local/competitors.md`, lessons in [docs/design/findings.md](docs/design/findings.md), "Seen in other mods' code").
- [ ] Test the levels with the most used of them active (after probe 1).
- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Note licences: read-only for anything not MIT/BSD/Apache/CC0.

## After the probes

- [ ] Fix the spec: trees, shares, scope (airports, underground station, kerbside stops), the upkeep tree.
- [x] Buying, from Depot Retrofits' 1.2 code: prices in `core.tl`, the game script `retrofits.script.tl` (buy queue, checks, rebuild, charge on landing), buy buttons and the "Not rebuilt" banner in the card. The probe 1 game script is retired (git history).
- [ ] Test buying in game. Done on a rail station (11 buys, all four trees): prices, charges, upkeep and catchment as the card showed (findings, test results). Left: the new row layout; which Finances row the charge lands in; a road station with tram tracks and a harbour; greyed buttons (rank, money); a quick double click charges once; a refused rebuild shows the banner and charges nothing; buying while the game runs.
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings).
- [ ] User guide, listing text, cover and gallery, release process (`docs/publishing.md` from Depot Retrofits).
