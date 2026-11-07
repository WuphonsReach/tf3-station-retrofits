# TODO

## In short

- **Where it stands.** Levels, the Retrofit card and buying all work in game: 130-odd buys on rail, road, tram, cargo and harbour stations, charged to the dollar, prices as the formulas say (results in [docs/design/findings.md](docs/design/findings.md)). Configure (the station's module editor) keeps the levels on road, tram and cargo rail stations. Harbours get only the catchment and upkeep trees (a port emits no pollution or noise), and their upkeep tree costs half. Kerbside stops are out of scope. Decisions are in [docs/design/spec.md](docs/design/spec.md), "Decisions".
- **Next.** One in-game session for what is untested: an era swap and catenary on a levelled station, a vehicle at a platform during a rebuild, loading a levelled save, and the levels with the most used competing mods active. Then the code-review fixes below, then the user guide, listing and release.

## Done

- Name check, scaffolding, tools and CI, `tlconfig.lua`, staging symlink, GitHub repo and rulesets (2026-11-01).
- Probes 1 and 2 (levels applied by a rebuild; the card in the station window through the plugin extension point). Probe 4 dropped, kerbside stops are out of scope.
- Buying from the card: prices in `core.tl`, the game script `retrofits.script.tl`, buy buttons, the "Not bought" note (money) and the "Not rebuilt" banner.
- Prices lowered after the pollution test; harbours without pollution and noise trees and with a half-price upkeep tree, seen in game on seven ports with prices matching the formula on five (findings, 2026-11-05).
- The emitter refills after a rebuild; how fast does not matter.
- Desk checks: `STATION` as the journal construction; no base station `.con` sets `constructionType`; the rail and street `upgradeFn` keep the other params; how the station window shows catchment and capacity; 13 competing mods read (notes in `local/competitors.md`).
- Waiting passengers survive rebuilds (findings, 2026-11-05).

## To test in game

- [ ] Probe 3 rest: an era swap and catenary keep the levels. Done: Configure on road and tram stations, cargo rail module add, remove and move.
- [ ] Probe 1 rest: a vehicle at a platform during a rebuild; waiting cargo; save and load of a levelled station (save `WR26A Giga-Tv3 1915 1101-1303-test`).
- [ ] Probe 2 rest: a station placed in session, a group of two constructions, next to another mod's card.
- [ ] The levels with the most used competing mods active.
- [ ] The ">|" button: one rebuild for several levels on rail, road and harbour; the charge equals the sum of the single prices and the tooltip's price; a refused one shows the banner and charges nothing; the one-line expanded layout ("<", ">", ">|", prices in the tooltips) fits the card on a harbour and at a larger font setting, and the row tooltip gives the price or the reason on a greyed button. Seen working on road, tram, rail and harbour, one-line layout included (2026-11-07, `local/logs/stdout-2026-11-07-maxbutton.txt` and `stdout-2026-11-07-oneline.txt`: 21 buys, each charged once, charges equal the tooltip prices). The narrower buttons and money through `api.util.formatMoney` (full setting) seen working, no errors (`stdout-2026-11-07-narrow.txt`, 6 more buys). Left: the short money setting, a larger font setting, a refused rebuild.
- [ ] Buying: a harbour that lands slower than a game day at 4x (the game script waits 30 real seconds); a refused rebuild shows the banner and charges nothing; buying while the game runs.

## Still to do

- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Read-only for anything not MIT/BSD/Apache/CC0.
- [ ] Spec: scope for airports and the underground station; whether to look for what a port does emit.
- [ ] `types/station_retrofits.d.tl` and the require in `all_def.tl`.
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings).
- [ ] User guide, listing text, cover and gallery (collected screenshots in `local/screenshots/`), release process (`docs/publishing.md` from Depot Retrofits).

- [ ] Removing a level: the "<" button, design in [docs/design/spec.md](docs/design/spec.md), "Removing a level" (80% refund at today's build price, no record of what a level cost; the year-step and long-hold profits are accepted). To build:
  - The game script's `landed` counts a rebuild as landed when the stored level is at least the target, which a removal's old level already is: the refund would be booked at once, even for a rebuild the game refuses. Pending buys need a direction, and a removal lands when the stored level is at most the target.
  - The card's `readRefused` waits for the tree to go up, so every removal would show "Not rebuilt" after 10 seconds. `Try` needs the same direction.
  - The buy event gets a direction (or a `to` below `from`); the game script checks the stored level and that it is above 0, and skips the rank and money checks.
  - The refund is booked through `bookPrice` with a negative amount (a positive journal entry).
  - Tooltips: the refund and the upkeep after it, on "<" and in the row tooltip.
  - Log `direction=down` and `refund=` on the queued, sent and charged lines.
  - Test in game: how the Finances tab shows a refund, that a refused removal refunds nothing, the refund on a harbour's upkeep tree, a removal then ">" on the same tree.

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
