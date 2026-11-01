# TODO

## In short

- **Where it stands.** Design only: findings read from the base game's station scripts, a draft spec and a probe plan. No mod code, no GitHub repo, nothing tested in game.
- **Next.** Ask the user the open decisions in [docs/design/spec.md](docs/design/spec.md) that block the probe (separate mod, name), set up the scaffolding, then build probe 1 ([docs/design/probe-plan.md](docs/design/probe-plan.md)).

## Set-up

- [ ] Confirm with the user: separate mod (not part of Depot Retrofits), name "Station Retrofits", folder `station_retrofits_1`, log prefix `STATION_RETROFITS`.
- [ ] Check mod.io for a mod already called "Station Retrofits" (or close to it, as "Upgrades" was too close to Industry Upgrades for the depot mod).
- [ ] Mod scaffolding, copied from Depot Retrofits (MIT, same author) and renamed: `mod.json` (`runScript` `mod.script@runFn`), `_metadata/modinfo.json`, `_content.json`, `content/settings.tl` (`logLevel`), `types/station_retrofits.d.tl`; uncomment the require in `all_def.tl`.
- [ ] Tools and CI, copied and adapted: `tools/check_content_list.py`, `tools/check_repo.py`, `.github/workflows/checks.yml` (actions pinned to full SHAs; look them up again, do not copy stale ones without checking).
- [ ] Copy `tlconfig.example.lua` to the gitignored `tlconfig.lua` and fill in the install folder (see `local/machine.md`), then `tl check` works.
- [ ] Symlink `station_retrofits_1/` into the game's `staging_area/`.
- [ ] GitHub repo (public, MIT, rulesets as Depot Retrofits: `main`, `pr-checks`, `trunks`, `version-tags`): only when the user says so. Until then, commits stay local.

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
