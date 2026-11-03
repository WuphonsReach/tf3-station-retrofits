# TODO

## In short

- **Where it stands.** Probes 1 and 2 work in game: levels applied by a rebuild, all values as the formulas say for 30 days, and a Retrofit card in the station window showing them. Buying a level from the card is built (game script, buy buttons, "Not rebuilt" banner) and not yet tested. Configure (the station's module editor) keeps the bought levels on road stations; the other rebuilds the game starts and kerbside stops are not tested yet.
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
- [ ] Probe 3: module edits, era swaps and catenary keep the levels. Done: Configure on two road stations, platforms and a module added (findings, test results). Left: a rail station (add a platform, remove a module), an era swap, catenary.
- [ ] Probe 4: kerbside stops (edge objects) can be replaced.
- [ ] Record each probe's results in [docs/design/findings.md](docs/design/findings.md) (In short first, test results at the bottom).

## Desk checks (no game needed)

- [x] Which `JournalEntry.Construction` value suits a station charge: `STATION` (`scripts/journal.d.tl`); still to see in the Finances tab.
- [ ] Whether base station `.con` files set `constructionType`.
- [ ] Whether the rail and street `upgradeFn` return the other params unchanged (`rail/modular_station/modular_station.script.lua` around line 351). Street: Configure kept them in game (probe 3).
- [x] How the station window shows catchment and capacity: a Waiting Hall row and terminal rows with waiting / capacity (passenger terminals only), the upkeep footer; no catchment figure (findings, test results). The card need not repeat them.
- [x] Survey the mods that change the same values or the station window: 13 mods read (notes in `local/competitors.md`, lessons in [docs/design/findings.md](docs/design/findings.md), "Seen in other mods' code").
- [ ] Test the levels with the most used of them active (after probe 1).
- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Note licences: read-only for anything not MIT/BSD/Apache/CC0.

## After the probes

- [ ] Fix the spec: trees, shares, scope (airports, underground station, kerbside stops), the upkeep tree.
- [x] Buying, from Depot Retrofits' 1.2 code: prices in `core.tl`, the game script `retrofits.script.tl` (buy queue, checks, rebuild, charge on landing), buy buttons and the "Not rebuilt" banner in the card. The probe 1 game script is retired (git history).
- [ ] Test buying in game. Done on a rail station (11 buys, all four trees): prices, charges, upkeep and catchment as the card showed (findings, test results). Then 70 buys on six stations (rail, road with tram, cargo rail, cargo road, harbour): charges under Investments, Infrastructure, to the dollar; the three-part rows fit; "Rank 14" greyed at rank 13. 132 buys at 1.5x to 4x on 13 stations, harbours included, all charged once (findings, 2026-11-03). Left: a harbour that lands slower than a game day at 4x (the game script now waits 30 real seconds); harbour buys with the longer waits (no flash); greyed for money; a refused rebuild shows the banner and charges nothing; buying while the game runs.
- [x] Prices lowered after the pollution test (spec, "Price and upkeep"). Not yet seen in game.
- [ ] Find where a harbour's pollution and noise are emitted (findings, unknown 13): its station emitter read 0.
- [x] "Not bought" note for buys refused for money (spec), from Depot Retrofits' fix for the same case. Seen in game on a harbour (findings, test results); before it, two such buys on a tram station showed "Not rebuilt".
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings).
- [ ] User guide, listing text, cover and gallery, release process (`docs/publishing.md` from Depot Retrofits).

## From the code review (2026-11-03)

Not yet checked in game. The first two share a cause (the card guesses the outcome of a buy) and are best fixed together.

- [ ] The card's "Not rebuilt… Nothing was charged" comes from its own 10-second wait, while the game script waits 30 seconds and charges a rebuild that lands in that time (`retrofit_card.script.tl`, `readRefused`). Have `processPending` record landed or not landed for each click in state, as `recordRefusal` does, and have the card read that.
- [ ] `replacePending` drops the station's pending buy uncharged even when the new buy is for another tree (`retrofits.script.tl`). If the earlier rebuild then lands and the game refuses the new one, the station keeps a level it never paid for. Replace only a pending buy for the same tree and level.
- [ ] `core.wrapUpdate`: a modular result (`params.modules` and `slots`) without a `terminateConstructionHook` is scaled at once, before the game adds the modules' upkeep and catchment. Log and skip it instead.
- [ ] `core.wrapUpdate`: after its first call the wrapped hook returns the cached results to every later call, including the copies relinked in harbour tables, without running the original. Check in a probe whether the game calls those copies with other arguments (`hookAgain` at logLevel "full"; none seen in probe 1).
- [ ] `update` and `handleEvent` each read the whole state and write it back; if they ever interleave, a queued buy or a refusal is lost. Probably they run one after the other (Depot Retrofits lost none in 144 quick buys); confirm or merge the writes.
- [ ] The card's `stepCount` goes up once per construction per step across all open windows, so the step fallbacks (`refusedAfterSteps`, `shortForSteps`, used only without `os.time`) run several times too fast. Count per construction or once per card step.
- [ ] `say`, the `logLevel` load, `clockNow`, `constructionParams`, `round` and `buyEvent` are copied in up to three scripts; move them to `core.tl`. Check whether the card's `constructionParams` (returns the native table) should copy as the game script's does.
- [ ] `tools/check_repo.py` reads `settings.tl` with a loose pattern: a trailing comment or single quotes fail CI on a correct value. Match only the quoted string.
