# TODO

## In short

- **Where it stands.** Levels, the Retrofit card and buying all work in game: 130-odd buys on rail, road, tram, cargo and harbour stations, charged to the dollar, prices as the formulas say (results in [docs/design/findings.md](docs/design/findings.md)). Configure (the station's module editor) keeps the levels on road, tram and cargo rail stations. Harbours get only the catchment and upkeep trees (a port emits no pollution or noise), and their upkeep tree costs half. Kerbside stops are out of scope. Decisions are in [docs/design/spec.md](docs/design/spec.md), "Decisions".
- **Next.** One in-game session for what is untested: removing a level ("<"), an era swap and catenary on a levelled station, a vehicle at a platform during a rebuild, loading a levelled save, and the levels with the most used competing mods active. Then the code-review fixes below, then the user guide, listing and release.

## Done

- Name check, scaffolding, tools and CI, `tlconfig.lua`, staging symlink, GitHub repo and rulesets (2026-11-01).
- Probes 1 and 2 (levels applied by a rebuild; the card in the station window through the plugin extension point). Probe 4 dropped, kerbside stops are out of scope.
- Buying from the card: prices in `core.tl`, the game script `retrofits.script.tl`, buy buttons, the "Not bought" note (money) and the "Not rebuilt" banner.
- Prices lowered after the pollution test; harbours without pollution and noise trees and with a half-price upkeep tree, seen in game on seven ports with prices matching the formula on five (findings, 2026-11-05).
- The emitter refills after a rebuild; how fast does not matter.
- Desk checks: `STATION` as the journal construction; no base station `.con` sets `constructionType`; the rail and street `upgradeFn` keep the other params; how the station window shows catchment and capacity; 13 competing mods read (notes in `local/competitors.md`).
- Waiting passengers survive rebuilds (findings, 2026-11-05).

## TRM: Industry Emissions

Levels did nothing on road and tram stations and harbours while it was active (seen 2026-11-07; [docs/compatibility.md](docs/compatibility.md)). Fixed in the dev version (`postRunFn` in `mod.script.tl`, `station_original.script.lua`); tested outside the game with stand-ins for TRM's loader and `util.useFn`, both paths, and in game in both load orders (below), with no TRM "has no function" error in either. Not planned, as the mod is unreleased: a save written while the fix was missing, Configure on a levelled station with TRM, TRM at "Base Game".

- [x] TRM before us (2026-11-08, 1974 test save, TRM: Infrastructure Upkeep and Industry Emissions at their defaults, then Station Retrofits, then Depot Retrofits; `local/logs/stdout-2026-11-07-trmfirst.txt`): `postRun trmRedirected=2` (`modular_terminal.con`, `harbor_modular.con`), `trmShim loaded … via=useFn` in each Lua state that built one, no TRM or load errors. 83 buys on two road stations, a harbour and a rail station, 41 charged and 42 refunded, each equal to the card's amount; 82 `applied` lines. Catchment 1 on a road station 175 -> 180.2 m and +15% upkeep; harbour upkeep -5% a level; catchment 11 232.8 m (175 + 33%). Pollution 11 and noise 11 on a road station: emitter 45 -> 20.25 and 4.5 -> 2.025 (× 0.45), so TRM's emissions script keeps our share and the two multiply.
- [x] TRM after us with the fix (2026-11-08, the original 1974 test save, Station Retrofits, Depot Retrofits, then both TRM mods at their defaults; `local/logs/stdout-2026-11-08-next.txt`): `postRun trmRedirected=2`, the shim loaded `via=useFn`, no errors. 79 buys on three road stations, two harbours and three rail stations, 75 charged and 4 refunded, each equal to the card's amount, 79 `applied` lines. A harbour's catchment 11 150 -> 205 m and its upkeep TRM's half × 2.65 × 0.9; a road station's pollution 11 cut its emitter 12.67 -> 5.70 (× 0.45). A road station and a harbour (463985, 464177) were placed in that session (next item).
- [x] Placing a new road station and a new harbour with TRM active (2026-11-08, TRM after us): Peterlee Port (harbour, $600,745) and Ashenvale Station Annex (Universal Cargo Station, $989,108) placed without errors, their cards shown at once, then levelled (constructions 464177 and 463985 in the test above). With TRM before us an airfield, a heliport, an airport, a train depot and a Roundhouse placed without errors too.

## To test in game

- [ ] Probe 3 rest: an era swap and catenary keep the levels. Done: Configure on road and tram stations, cargo rail module add, remove and move.
- [ ] Probe 1 rest: a vehicle at a platform during a rebuild; waiting cargo; save and load of a levelled station (save `WR26A Giga-Tv3 1915 1101-1303-test`).
- [ ] Probe 2 rest: a station placed in session, a group of two constructions, next to another mod's card.
- [ ] The levels with the most used competing mods active.
- [ ] The ">|" button: one rebuild for several levels on rail, road and harbour; the charge equals the sum of the single prices and the tooltip's price; a refused one shows the banner and charges nothing; the one-line expanded layout ("<", ">", ">|", prices in the tooltips) fits the card on a harbour and at a larger font setting, and the row tooltip gives the price or the reason on a greyed button. Seen working on road, tram, rail and harbour, one-line layout included (2026-11-07, `local/logs/stdout-2026-11-07-maxbutton.txt` and `stdout-2026-11-07-oneline.txt`: 21 buys, each charged once, charges equal the tooltip prices). The narrower buttons and money through `api.util.formatMoney` (full setting) seen working, no errors (`stdout-2026-11-07-narrow.txt`, 6 more buys). Switching the game's money setting changes the card's figures at once (2026-11-07). Left: a larger font setting, a refused rebuild.
- [ ] Removing a level ("<", 80% refund at today's build price; spec, "Removing a level"): the refund equals the tooltip's and books once, when the level has gone down; how the Finances tab shows the positive station construction entry; a refused removal shows the "Not rebuilt" banner with the removal wording and refunds nothing; the refund on a harbour's upkeep tree (half); a removal then ">" on the same tree; "<" greyed at level 0 and working above the rank; the upkeep after it as the tooltip says. Logs: `direction=down`, `refund=`, `buy refunded`. Seen working on a cargo rail station (2026-11-07, `local/logs/stdout-2026-11-07-remove.txt`, crop `local/screenshots/2026-11-07-170221-remove-tooltip.png`): 18 removals and 4 buys, each booked once when the level had moved, every refund and price equal to the card's; a 14-level ">|" catchment buy for $7,806,875 removed level by level refunded $6,245,716 (80%, per-level rounding); a removal then ">" on the same tree; the tooltip's upkeep after removal matched. Left: the Finances tab entry, a refused removal, a harbour's upkeep tree, a road or tram station.
- [ ] A mod that changes station upkeep (TRM: Infrastructure Upkeep, active in that session) changes every price and refund, as they come from the upkeep the game charges. A station keeps the upkeep it was built with until its next rebuild: the first removal on a station built before the mod was switched on refunded $159,982, priced from the old upkeep (twice the new), and the rebuild then halved the station's upkeep. Decide whether that matters (the levels would have to price from the modules' own upkeep instead, which the card cannot read without the hook).
- [ ] Buying: a harbour that lands slower than a game day at 4x (the game script waits 30 real seconds); a refused rebuild shows the banner and charges nothing; buying while the game runs.

## Still to do

- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Read-only for anything not MIT/BSD/Apache/CC0.
- [ ] Spec: scope for airports and the underground station; whether to look for what a port does emit.
- [ ] `types/station_retrofits.d.tl` and the require in `all_def.tl`.
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings).
- [ ] User guide, listing text, cover and gallery (collected screenshots in `local/screenshots/`), release process (`docs/publishing.md` from Depot Retrofits).

## From the code review (2026-11-03)

Not yet checked in game. The first two share a cause (the card guesses the outcome of a buy) and are best fixed together.

- [ ] The card's "Not rebuilt… Nothing was charged" comes from its own 10-second wait, while the game script waits 30 seconds and charges a rebuild that lands in that time (`retrofit_card.script.tl`, `readRefused`). Have `processPending` record landed or not landed for each click in state, as `recordRefusal` does, and have the card read that.
- [ ] `replacePending` drops the station's pending buy uncharged even when the new buy is for another tree (`retrofits.script.tl`). If the earlier rebuild then lands and the game refuses the new one, the station keeps a level it never paid for; a replaced removal that lands later loses its level without the refund. Replace only a pending buy for the same tree and level.
- [ ] `core.wrapUpdate`: a modular result (`params.modules` and `slots`) without a `terminateConstructionHook` is scaled at once, before the game adds the modules' upkeep and catchment. Log and skip it instead.
- [ ] `core.wrapUpdate`: after its first call the wrapped hook returns the cached results to every later call, including the copies relinked in harbour tables, without running the original. Check in a probe whether the game calls those copies with other arguments (`hookAgain` at logLevel "full"; none seen in probe 1).
- [ ] `update` and `handleEvent` each read the whole state and write it back; if they ever interleave, a queued buy or a refusal is lost. Probably they run one after the other (Depot Retrofits lost none in 144 quick buys); confirm or merge the writes.
- [ ] The card's `stepCount` goes up once per construction per step across all open windows, so the step fallbacks (`refusedAfterSteps`, `shortForSteps`, used only without `os.time`) run several times too fast. Count per construction or once per card step.
- [ ] `say`, the `logLevel` load, `clockNow`, `constructionParams`, `round` and `buyEvent` are copied in up to three scripts; move them to `core.tl`. Check whether the card's `constructionParams` (returns the native table) should copy as the game script's does.
- [ ] `tools/check_repo.py` reads `settings.tl` with a loose pattern: a trailing comment or single quotes fail CI on a correct value. Match only the quoted string.
