# TODO

## In short

- **Where it stands.** Levels, the Retrofit card, buying (">" and ">|") and removing a level ("<") all work in game on rail, road, tram, cargo and harbour stations, charged and refunded to the dollar at the prices the formulas give (results in [docs/design/findings.md](docs/design/findings.md)). Configure (the station's module editor) keeps the levels on road, tram, passenger and cargo rail stations, and levelled stations come back as they were when a save is loaded. When the game refuses a rebuild, the card shows "Not rebuilt" and nothing is charged (seen for ">|" buys). Harbours get only the catchment and upkeep trees, and their upkeep tree costs half. TRM: Industry Emissions is fixed in the dev version ([docs/compatibility.md](docs/compatibility.md)). Kerbside stops are out of scope. Airports, airfields, heliports and helipads are next: this mod owns them, hangar depots included (decided 2026-11-16; spec, "Air buildings"). Decisions are in [docs/design/spec.md](docs/design/spec.md), "Decisions".
- **1.0 released** on mod.io (2026-11-21, mod id 6544442; docs/publishing.md, "First upload"). **Next: air buildings**: probe 5, the hangar trees' prices and what happens with several hangars, then the card rows and the buy path.

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
- Save and load of levelled stations: three saves loaded with their levels, circles and upkeep as left, and the station script not run on load; Configure on a levelled passenger rail station (findings, 2026-11-10 to 2026-11-13).
- Refused rebuilds: two ">|" buys refused by the game (a passenger rail station, a harbour), the "Not rebuilt" banner shown, nothing charged; removals on a tram station; 13 levels in one rebuild on rail, road, tram and harbour stations (findings, 2026-11-15).

## Release 1.0

Scope: train stations, road and tram stations and harbours, as the listing and the user guide say. Air buildings come in a later version; the untested items under "To test in game" ship as the listing's "Not checked yet" lines, as in Depot Retrofits 1.0. Steps in [docs/publishing.md](docs/publishing.md), "Releasing a version".

Before the release branch:

- [x] Code-review fix 2 in code (2026-11-21), not tested in game: a buy for a station with a pending rebuild replaces it only for the same tree, level and direction, any other is refused as `pending` (spec, "Removing a level", "One rebuild at a time per station"). Fix 1 won't be done (below).
- [x] "Not rebuilt" worded for any cause (2026-11-21): "Not rebuilt: the game refused it.", then "Nothing was charged." or "The level was kept, no refund.", then "Clear anything in the way, retry."; 35 characters a line at most, as about 40 fit at Text Scaling "Large" (findings, 2026-11-21). The "Not bought" note's first line is cut to "Not bought: not enough money." for the same reason. Neither is seen in game yet.
- [ ] Optional, not for 1.0: in game, the rest (2026-11-21 done: a refused ">" buy on a rail station with the banner after 10 seconds, its retry replacing the pending buy, given up after 30 seconds uncharged; 72 buys and removals on 8 rail and road stations, each charged or refunded once): the 35-character banner fits at Text Scaling "Large", also on a harbour; a refused ">|" buy and a refused removal; a click on another tree while the banner shows, refused as `pending`; a buy at 4x.
- [x] Gallery (2026-11-21): `2-retrofit-cards.jpg` (a pile of four windows from `tools/gallery/`), `3-not-rebuilt.jpg`, `4-road-station.jpg`, `5-tooltip.jpg` (publishing.md, "Gallery"). From shots of 2026-11-13 and 15, with "->" and the older banner wording.
- [ ] Gallery, later: a new "Not rebuilt" shot with the current banner lines, at Text Scaling "Small", for the pile's top card (`tools/gallery/rail_not_rebuilt.png`) and `3-not-rebuilt.jpg`, both under new names. Candidate: screenshot 20261121_171021 (Liskeard Station, published 1.0, Text Scaling "Small", current lines, catchment circle on the map) (publishing.md, "Gallery"). Best sent with a release.

On the release branch (`<YYYY-MM-DD>-release-1.0`):

- [x] `modVersion = "1.0"`, CHANGELOG entry dated, cover redrawn with `--version 1.0`, `settings.tl` at `"summary"`, all checks and `tl check` passing; `modinfo.json` and the user guide checked against each other and the last findings (2026-11-21: the listing's "Not covered" line now names helipads and the later version, as the guide does).
- [x] Merged, uploaded from `main` (2f6be05), `mod.io_fileid.txt` committed, published copy tested, upload recorded in publishing.md, `modVersion = "1.1-dev"` and a 1.1 CHANGELOG entry (2026-11-21). Tag `v1.0` on 2f6be05 and the GitHub release published.
- [x] README: status "released", with the mod.io link.

## To test in game

- [ ] Probe 3 rest: an era swap and catenary keep the levels. Done: Configure on road and tram stations and a passenger rail station, cargo rail module add, remove and move.
- [ ] Probe 1 rest: a vehicle at a platform during a rebuild; waiting cargo. Done: save and load of levelled stations (2026-11-10 to 2026-11-13).
- [ ] Probe 2 rest: a group of two constructions, next to another mod's card. Done: stations placed in session (2026-11-08).
- [ ] The levels with the most used competing mods active.
- [ ] A refused rebuild, the rest: a ">" buy and a removal (removal wording), nothing charged or refunded. Done: two ">|" buys (2026-11-15).
- [x] The expanded card at every Text Scaling (2026-11-21): the upkeep icon left out at "Medium" and "Large", "/Yr" and an unspaced arrow at "Large"; Hannover Station Ost at catchment, pollution and noise 13 ($11.6 million upkeep) fits at all three sizes with about a character to spare (findings, 2026-11-21). Still to see: a harbour at "Large".
- [ ] Removing a level, the rest: how the Finances tab shows the positive station construction entry; "<" working above the rank. Done: "<" greyed at level 0 (2026-11-10), a tram station (2026-11-15).
- [ ] Buying: a harbour that lands slower than a game day at 4x (the game script waits 30 real seconds); buying while the game runs.

## Still to do

- [ ] Decide how levels are priced with a mod that scales station upkeep (TRM: Infrastructure Upkeep; spec, "Open decisions").
- [ ] Survey the stations of the user's subscribed mods (mod.io folder in `local/machine.md`): does each return a `station` table, use `terminateConstructionHook`, set `constructionType`? Read-only for anything not MIT/BSD/Apache/CC0.
- [ ] Spec: scope for the underground station; whether to look for what a port does emit (spec, "Open decisions").
- [ ] "Not rebuilt": show what is in the way (the proposal viewer needs an action area the station window does not give its cards; findings). Not for 1.0.

## Air buildings

Airports, airfields, heliports and helipads, hangar depots included (decided 2026-11-16). Spec, "Air buildings"; findings, "Air buildings"; probe plan, probe 5.

- [ ] Probe 5: wrap the four air scripts, level the hangar depots in the wrapped hook, see which tabs the window shows and where the card lands.
- [ ] Decide what the hangar trees' prices are based on, and one set of hangar levels for the whole airport or levels per hangar (spec, open decisions 4 and 5), with what probe 5 shows.
- [ ] The hangar rows on the card (only where there is a hangar depot), the buy and removal path for the two hangar trees, the carrier for the journal entry (AIR).
- [ ] The listing's "Not covered" line, the user guide's "Which stations" and the CHANGELOG, once air buildings ship.
- [ ] In-game session: buys and removals on each air building, Configure, era templates, save and load.

## From the code review (2026-11-03)

Fix 2 is in code ("Release 1.0" above), to be tested in game; fix 1 won't be done; the rest are not fixed and do not block 1.0.

- [x] Won't fix: the card's "Not rebuilt… Nothing was charged" comes from its own 10-second wait, while the game script waits 30 seconds. A rebuild landing in between would be charged after the banner, but the level then shows and the banner clears, so the card ends up right; none has landed that late (rail and road within a second, harbours 2 to 3 seconds, an autosave delays the game script before it sends, findings 2026-11-07), and fix 2 keeps a second click in that window from costing money. Waiting the 30 seconds would make every real refusal wait three times as long (spec, "Buying a level").
- [x] `replacePending` dropped the station's pending buy uncharged even for another tree. Fixed: only a buy for the same tree, level and direction replaces it; any other is refused as `pending`.
- [ ] `core.wrapUpdate`: a modular result (`params.modules` and `slots`) without a `terminateConstructionHook` is scaled at once, before the game adds the modules' upkeep and catchment. Log and skip it instead.
- [ ] `core.wrapUpdate`: after its first call the wrapped hook returns the cached results to every later call, including the copies relinked in harbour tables, without running the original. Check in a probe whether the game calls those copies with other arguments (`hookAgain` at logLevel "full"; none seen so far).
- [ ] `update` and `handleEvent` each read the whole state and write it back; if they ever interleave, a queued buy or a refusal is lost. Probably they run one after the other (Depot Retrofits lost none in 144 quick buys); confirm or merge the writes.
- [ ] The card's `stepCount` goes up once per construction per step across all open windows, so the step fallbacks (`refusedAfterSteps`, `shortForSteps`, used only without `os.time`) run several times too fast. Count per construction or once per card step.
- [ ] `say`, the `logLevel` load, `clockNow`, `constructionParams`, `round` and `buyEvent` are copied in up to three scripts; move them to `core.tl`. Check whether the card's `constructionParams` (returns the native table) should copy as the game script's does.
- [ ] `tools/check_repo.py` reads `settings.tl` with a loose pattern: a trailing comment or single quotes fail CI on a correct value. Match only the quoted string.
