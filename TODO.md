# TODO

## In short

- **Where it stands.** Levels, the Retrofit card, buying (">" and ">|") and removing a level ("<") all work in game on rail, road, tram, cargo and harbour stations, charged and refunded to the dollar at the prices the formulas give (results in [docs/design/findings.md](docs/design/findings.md)). Configure (the station's module editor) keeps the levels on road, tram and cargo rail stations. Harbours get only the catchment and upkeep trees, and their upkeep tree costs half. TRM: Industry Emissions is fixed in the dev version ([docs/compatibility.md](docs/compatibility.md)). Kerbside stops are out of scope. Decisions are in [docs/design/spec.md](docs/design/spec.md), "Decisions".
- **Next.** One in-game session for what is untested (below): an era swap and catenary on a levelled station, a vehicle at a platform during a rebuild, loading a levelled save, a refused rebuild, and the levels with the most used competing mods active. Then the code-review fixes, then the user guide, listing and release.

## Done

- Name check, scaffolding, tools and CI, `tlconfig.lua`, staging symlink, GitHub repo and rulesets (2026-11-01).
- Probes 1 and 2 (levels applied by a rebuild; the card in the station window through the plugin extension point). Probe 4 dropped, kerbside stops are out of scope.
- Buying from the card: prices in `core.tl`, the game script `retrofits.script.tl`, buy buttons, the "Not bought" note (money) and the "Not rebuilt" banner.
- Prices lowered after the pollution test; harbours without pollution and noise trees and with a half-price upkeep tree (findings, 2026-11-05).
- The ">|" button (every level in one rebuild) and the one-line card with prices in the tooltips and money in the game's format (findings, 2026-11-07).
- Removing a level for an 80% refund, seen on rail, road and harbour stations, a harbour's upkeep tree included (findings, 2026-11-07 and 2026-11-08).
- TRM: Industry Emissions: levels lost on road and tram stations and harbours, fixed with a `postRunFn` and `station_original.script.lua`, tested in game in both load orders, new stations placed with it active ([docs/compatibility.md](docs/compatibility.md)). Not planned while the mod is unreleased: a save written while the fix was missing, Configure on a levelled station with TRM, TRM at "Base Game".
- `types/station_retrofits.d.tl` and its require in `all_def.tl`.
- Desk checks: `STATION` as the journal construction; no base station `.con` sets `constructionType`; the rail and street `upgradeFn` keep the other params; how the station window shows catchment and capacity; 13 competing mods read (notes in `local/competitors.md`).
- Waiting passengers survive rebuilds; the emitter refills after a rebuild, how fast does not matter (findings, 2026-11-05).

## To test in game

- [ ] Probe 3 rest: an era swap and catenary keep the levels. Done: Configure on road and tram stations, cargo rail module add, remove and move.
- [ ] Probe 1 rest: a vehicle at a platform during a rebuild; waiting cargo; save and load of a levelled station (save `WR26A Giga-Tv3 1915 1101-1303-test`, or the 1919 autosave in findings, 2026-11-07).
- [ ] Probe 2 rest: a group of two constructions, next to another mod's card. Done: stations placed in session (2026-11-08).
- [ ] The levels with the most used competing mods active.
- [ ] A refused rebuild: the "Not rebuilt" banner shows, for a buy, a ">|" buy and a removal (removal wording), and nothing is charged or refunded.
- [ ] The card at a larger font setting, on a harbour (the one-line layout still fits).
- [ ] Removing a level, the rest: how the Finances tab shows the positive station construction entry; "<" greyed at level 0 and working above the rank; a tram station.
- [ ] Buying: a harbour that lands slower than a game day at 4x (the game script waits 30 real seconds); buying while the game runs.

## Still to do

- [ ] Decide how levels are priced with a mod that scales station upkeep (TRM: Infrastructure Upkeep; spec, "Open decisions").
- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Read-only for anything not MIT/BSD/Apache/CC0.
- [ ] Spec: scope for airports and the underground station; whether to look for what a port does emit (spec, "Open decisions").
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings).
- [ ] User guide, listing text, cover and gallery (collected screenshots in `local/screenshots/`), release process (`docs/publishing.md` from Depot Retrofits).

## From the code review (2026-11-03)

Not yet fixed. The first two share a cause (the card guesses the outcome of a buy) and are best fixed together.

- [ ] The card's "Not rebuilt… Nothing was charged" comes from its own 10-second wait, while the game script waits 30 seconds and charges a rebuild that lands in that time (`retrofit_card.script.tl`, `readRefused`). Have `processPending` record landed or not landed for each click in state, as `recordRefusal` does, and have the card read that.
- [ ] `replacePending` drops the station's pending buy uncharged even when the new buy is for another tree (`retrofits.script.tl`). If the earlier rebuild then lands and the game refuses the new one, the station keeps a level it never paid for; a replaced removal that lands later loses its level without the refund. Replace only a pending buy for the same tree and level.
- [ ] `core.wrapUpdate`: a modular result (`params.modules` and `slots`) without a `terminateConstructionHook` is scaled at once, before the game adds the modules' upkeep and catchment. Log and skip it instead.
- [ ] `core.wrapUpdate`: after its first call the wrapped hook returns the cached results to every later call, including the copies relinked in harbour tables, without running the original. Check in a probe whether the game calls those copies with other arguments (`hookAgain` at logLevel "full"; none seen so far).
- [ ] `update` and `handleEvent` each read the whole state and write it back; if they ever interleave, a queued buy or a refusal is lost. Probably they run one after the other (Depot Retrofits lost none in 144 quick buys); confirm or merge the writes.
- [ ] The card's `stepCount` goes up once per construction per step across all open windows, so the step fallbacks (`refusedAfterSteps`, `shortForSteps`, used only without `os.time`) run several times too fast. Count per construction or once per card step.
- [ ] `say`, the `logLevel` load, `clockNow`, `constructionParams`, `round` and `buyEvent` are copied in up to three scripts; move them to `core.tl`. Check whether the card's `constructionParams` (returns the native table) should copy as the game script's does.
- [ ] `tools/check_repo.py` reads `settings.tl` with a loose pattern: a trailing comment or single quotes fail CI on a correct value. Match only the quoted string.
