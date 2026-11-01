# TODO

## In short

- **Where it stands.** Design, plus a mod scaffold that only logs its start-up line: findings read from the base game's station scripts, a draft spec and a probe plan. Nothing tested in game.
- **Next.** Check in game that the scaffold loads (`STATION_RETROFITS version 0.1-dev` in the log), then build probe 1 ([docs/design/probe-plan.md](docs/design/probe-plan.md)). Decisions so far are in [docs/design/spec.md](docs/design/spec.md), "Decisions".

## Set-up

- [ ] Check mod.io for a mod already called "Station Retrofits" or close to it: the user, in a browser (the site's search needs JavaScript). A web search and the 630 cached listings in the local mod.io `state.json` found none; the closest names are "Industry Upgrades" and plain station assets.
- [x] Mod scaffolding, copied from Depot Retrofits and renamed: `mod.json`, `_metadata/modinfo.json` (draft text), `_content.json`, `content/settings.tl`, and a `content/mod.script.tl` that only logs its start-up line.
- [ ] `types/station_retrofits.d.tl` and the require in `all_def.tl`: with `levels.tl`, when there is something to type.
- [x] Tools and CI, copied and adapted: `tools/check_content_list.py`, `tools/check_repo.py`, `.github/workflows/checks.yml` (checkout v7.0.1 and setup-python v7.1.0, still the latest releases on 2026-11-01).
- [x] `tlconfig.lua` filled in on this machine; `tl check` passes.
- [x] Symlink `station_retrofits_1/` into the game's `staging_area/`.
- [x] GitHub repo, public, MIT, settings and rulesets as Depot Retrofits: `main`, `pr-checks`, `trunks`, `version-tags`.

## Probes ([docs/design/probe-plan.md](docs/design/probe-plan.md))

- [ ] Probe 1: rebuild up to 3 stations with fixed levels; hook wrapper, ids, waiting passengers and cargo, vehicles at platforms, cost of a rebuild, negative upkeep, catchment, emissions, save and load, refusals.
- [ ] Probe 2: Retrofit tab in the station window, base tabs unchanged.
- [ ] Probe 3: module edits, era swaps and catenary keep the levels.
- [ ] Probe 4: kerbside stops (edge objects) can be replaced.
- [ ] Record each probe's results in [docs/design/findings.md](docs/design/findings.md) (In short first, test results at the bottom).

## Desk checks (no game needed)

- [ ] Which `JournalEntry.Construction` value suits a station charge (`api/tealdef/api/type.d.tl`; Depot Retrofits uses `DEPOT`).
- [ ] Whether base station `.con` files set `constructionType`.
- [ ] Whether the rail and street `upgradeFn` return the other params unchanged (`rail/modular_station/modular_station.script.lua` around line 351).
- [ ] How the station window shows catchment and capacity (`gui/entity_window/station_group/`), to know what the Summary card should repeat.
- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Note licences: read-only for anything not MIT/BSD/Apache/CC0.

## After the probes

- [ ] Fix the spec: trees, shares, scope (airports, underground station, kerbside stops), the upkeep tree.
- [ ] Build 1.0 from Depot Retrofits' 1.2 code: `levels.tl`, `company_rank.tl` (unchanged), the game script (buy queue, charge on landing, "Not rebuilt"), the window.
- [ ] User guide, listing text, cover and gallery, release process (`docs/publishing.md` from Depot Retrofits).
