# Spec (draft)

## In short

Stations get levels, bought in the station's own window (one at a time, or all the rank and the money allow in one click) and removable one at a time for an 80% refund, the way [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) does it for depots. This is a draft: every number below is a starting point taken from Depot Retrofits, and the scope depends on the probes in [probe-plan.md](probe-plan.md). Levels are applied and shown (probes 1 and 2), and buying them has been tested in game on rail, road, tram, cargo and harbour stations (findings, test results). Removing a level is built but not yet tested in game. Not yet tested either: an era swap or catenary change on a levelled station, a vehicle at a platform during a rebuild, and loading a save with levelled stations.

The planned first version has three trees of 15 levels each (catchment radius, pollution, noise), plus an upkeep tree. Harbours get only the catchment and upkeep trees: a port emits no pollution or noise of its own (findings, 2026-11-05). Waiting capacity is not a tree: players already add it by building more station modules, and mods with larger stops or modules cover the rest. It covers the base modular stations (rail, road and tram terminals, harbours) and later stations from other mods that have the same shape. A tree's highest level is the company's claimed rank. A level is applied by rebuilding the station with new hidden params, as for depots.

## Scope

| Construction | First version | Why |
|---|---|---|
| Train station | yes | modular, values in `terminateConstructionHook` |
| Road and tram terminal | yes | same |
| Harbour | yes, catchment and upkeep only | same; its station emits no pollution or noise, so those trees would do nothing (findings, 2026-11-05) |
| Airport, airfield, heliport | later | also contain a depot (hangar); keep them apart from Depot Retrofits first |
| Underground station | maybe | not modular; upkeep set by the script, so the upkeep tree would work as for depots |
| Kerbside bus and tram stops | no | out of scope for this mod (decided 2026-11-05); they are edge objects and get no card |
| Warehouse | no | holds stocks, not a station pool |
| Stations from other mods | where their result has the same shape | detect by the result (a `station` table), not by folder |

## Trees

The two kinds of tree carry over from Depot Retrofits: three trees improve the station and raise its upkeep; the upkeep tree cuts the total.

| Tree | Game value changed | Per level (draft) | At level 15 |
|---|---|---|---|
| Catchment radius | every circle in `station.catchmentAreas` | +3%, or at least +5 m | +45%, or at least +75 m |
| Pollution | `metadata.emissions`, both states | −5% | −75% |
| Noise | `metadata.emissions`, both states | −5% | −75% |
| Upkeep | the station's total upkeep, modules included | −5% of the total | −75% |

Pollution and noise are not offered on harbours (note below); every other kind has all four trees.

Notes:

- **Harbours have two trees.** The card, the game script and the wrapper leave out pollution and noise for a harbour (`core.noTrees`). Every harbour's station emitter read 0 before its first level, and in the game's pollution and noise overlays a port and its wharves show no halo of their own, also after the port was expanded (findings, 2026-11-05). A level stored for either tree on a harbour is read as 0, so it has no effect and is not priced.
- **Catchment is the strongest tree.** It brings more town into reach of the station, so more passengers and cargo, which no depot tree does. So it has smaller steps than the depot radius tree (+3%, not +5%) and a higher price (share 0.20). Base circles are 50 to 250 m (a rail station has several 60 m ones), so the floor decides small circles: at 5 m a level, a 60 m circle grows +5 m a level (+75 m, +125%, at level 15) and a 175 m one +5.25 m.
- **Left out: waiting capacity.** Players add waiting places by building more station modules, and mods with larger stops or modules cover the rest; a bought level would only duplicate that.
- **Left out for now: comfort and load speed.** Both are set in the same hook, but their effect is decided in the engine and unmeasured. Add them only after a test shows what a level does in play.

## Price and upkeep

- **Build price.** 6 × the upkeep the game charges for the station now, divided by what its current levels do to the upkeep, rounded to $100. In 80 of 81 base station modules the price is exactly 6 × the upkeep, so this matches the modules' summed price.
- **Level price.** Level *n* costs the tree's first-level share × the build price × the tree's step^(*n*−1) (decided, after the pollution test):

| Tree | First-level share | Step | Levels 1 to 9 (× build price) | All 15 (× build price) |
|---|---|---|---|---|
| Catchment | 0.20 | 1.15 | 3.36 | 9.52 |
| Pollution | 0.04 | 1.10 | 0.54 | 1.27 |
| Noise | 0.08 | 1.12 | 1.18 | 2.98 |
| Upkeep | 0.16 | 1.15 | 2.69 | 7.61 |
| Upkeep, harbours | 0.08 | 1.15 | 1.35 | 3.81 |

  Catchment is the dearest, as it brings in more town (passengers and cargo). Pollution and noise are cheap and rise slowly: stations are only part of a town's pollution, so pollution 9 on all 16 stations of a town cut its pollution by about 11% (findings, test results). The upkeep tree is priced to pay for itself: on a station with the other three trees full (5.5 × the base upkeep), the full tree costs 45.7 × the base upkeep and saves 4.1 × a year, about 11 years (level 1 in 3.5 years, level 15 in 25). On a station with no other levels it saves only 0.75 × a year. The harbour row is the upkeep row at half price (see "A harbour's upkeep tree costs half" below). Depot Retrofits keeps its own shares (0.15, 0.08, 0.12, 0.25) and one step of 1.15.
- **Upkeep.** Each improving level adds a share of the base upkeep: 15% catchment, 10% noise, 5% pollution. The upkeep tree multiplies the total by (1 − 0.05 × levels).
- **A harbour's upkeep tree costs half.** A harbour has no pollution or noise level to add upkeep, so at most its catchment (15% a level) raises the total, to 3.25 × the base upkeep at level 15, where a rail or road station with all three trees full is at 5.5 ×. At the other stations' price (45.7 × the base upkeep for all 15 levels) it would pay back far more slowly, since a level saves only 5% of the total a year, so every level of a harbour's upkeep tree costs 0.5 × the table's price (22.8 × the base upkeep for all 15; 0.48 × at level 1, 3.4 × at level 15). Payback with that price:

| Harbour's catchment | Upkeep level 1 | Upkeep level 15 | All 15 levels |
|---|---|---|---|
| 0 (no levels) | 9.6 years | 68 years | 30 years |
| 8 (about half) | 4.4 years | 31 years | 14 years |
| 15 (full) | 2.9 years | 21 years | 9.4 years |
| *Rail or road station, all three trees full (for comparison)* | *3.5 years* | *25 years* | *11 years* |

  What a harbour's levels buy is the range (catchment) and the upkeep cut, nothing else. With catchment full the half price pays back a little faster than on other stations (9.4 years against 11); with no catchment levels it takes 30 years. The catchment tree has no payback figure: what a larger circle earns depends on the town.
- **How upkeep is applied.** After the hook, the script's `maintenanceCost` already holds the modules' upkeep, and the game charges what the script leaves there; the wrapper multiplies it by the upkeep factor (probe 1).
- **Modules added later.** As in Depot Retrofits, levels are not repriced when the station grows; the upkeep the levels add follows the modules. Big stations pay big prices, since the build price grows with the modules.

## Buying a level

- In a collapsible Retrofit card in the station's window (a tab would need `entityWindowScript`, which stops the station window from opening; see findings). The station window keeps one collapsible card open at a time, and the card starts collapsed.
  - **Collapsed (summary):** one row per tree: the stock icon, 15 level boxes (bought, allowed by the rank, locked) and, at the right edge, what the levels do now ("200 -> 230 m" for the largest catchment circle, "-25%" for pollution and noise, "-25% of total" for upkeep).
  - **Expanded:** one line per tree: what the next level changes at the left ("200 -> 206 m", "0% -> -5%"); at the right the upkeep after it, then three small buttons: "<" removes the top level for a refund (below), ">" buys the next level, ">|" buys every level it can (below). The prices are in the tooltips, not on the buttons: with the price on the buy button and a ">|" beside it, the text ran into the upkeep figure on a harbour. The three buttons share a minimum width (a mod CSS rule; a longer label widens its button rather than being cut off), so the upkeep figures end in one column. A buy button is greyed when the rank is too low or unknown, or the balance is short; "<" is greyed at level 0. No "Level 1:" label; the tooltip gives the level. Money is written by the game's formatter (`api.util.formatMoney`), in the player's currency and full or short as set in the game, as in the rest of the window. The game's own upkeep footer stays where it is in the window.
  - **Tooltip, on the whole row:** the tree's name and "Level 4/7 (max 15)" as in Depot Retrofits (the level over what the rank allows, "(max 15)" only while the rank is lower), then what a level does and what upkeep it adds, one sentence a line. In the expanded card the row's tooltip adds what ">" buys and for how much, or why it cannot ("Level 14 needs company rank 14.", "Level 9 costs $6,600: not enough money."), what ">|" buys ("Levels 9 to 13: $340,314.") and, above level 0, what "<" refunds and the upkeep after it. The game shows no tooltip on a greyed button, so the reason is there.
- **">|" button (all levels).** One click buys every level the rank allows and the balance pays for, in one rebuild, for the sum of the single prices (the same as clicking them one by one). Short of the rank's limit for want of money, it buys as far as the money goes. The button's tooltip gives the levels and the price ("Buy levels 8 to 12 for $X."). Greyed unless it would buy at least two levels. The buy event carries the target level (`to`); the game script checks the target against the rank and the money and charges the sum when the rebuild lands. It saves the 50 or so single clicks a new station takes at a high rank; ">" stays for buying part of the way.
- A click sends the buy; the game script checks it again (level not stale, within the rank, enough money), rebuilds the station and books the price once the rebuild has landed, as station construction under the station's carrier (rail RAIL, harbour WATER, road station ROAD, or TRAM with tram tracks). A rebuild that never lands costs nothing. The price shows in the Finances tab under Investments, Infrastructure.
- When the game refuses the rebuild (the clicked tree has not gone up about 10 seconds after the click: harbours take up to 3 seconds to build, and a busy game can take 3 more to take up the buy), the card shows the yellow "Not rebuilt" banner above its rows until a level lands: "Not rebuilt: a building, road or track is in the way. Nothing was charged. Clear it and buy again." Depot Retrofits also shows what is in the way with the game's proposal viewer; the station window gives its cards no place for it (findings), so that is left for later.
- A buy the game script refuses never reaches the game, so the card would take it for a refused rebuild. The card sends a click number with each buy; the game script keeps each refusal (station, click, reason) in its state, one per station, and the card reads that state while a click waits (`getEntityForGameScript`, as `company_rank.tl`'s fallback does). A buy refused for money (the balance can fall by hundreds of thousands between the card's last read and the check, and come back within seconds) shows a yellow note with the base dollar notification icon instead, until the next click, a new level, or once it has shown for about 10 seconds and the balance covers the clicked level again (checked on each of the card's steps; still short of money, it stays): "Not bought: not enough money at the time of the buy. Nothing was charged." Other script refusals (rank, stale level) show nothing. Seen in game on a harbour (findings, test results); a card that cannot read the state logs `card scriptStateError` once and falls back to "Not rebuilt".
- A rebuild keeps the waiting passengers (102 of 144 at a terminal stayed through six rebuilds; findings, 2026-11-05). What it does to waiting cargo and to vehicles at the platforms is unknown (probe 1). If it loses waiting cargo, say so on the card.

## Removing a level

- **What.** The "<" button removes the tree's top level, one per click, in one rebuild. The buy event carries `to` one below `from`; the game script checks that the stored level is still the one the card saw and above 0, with no rank or money check (a level above a lower rank can be removed too). Built, not yet tested in game; how the Finances tab shows the positive entry is unknown.
- **Refund: 80% of that level's price at today's build price**, as ">" would charge to buy it back now (`core.levelPrice`, so a harbour's half-price upkeep tree refunds half as much). Booked as a station construction entry with a positive amount, once the rebuild has landed; a rebuild that never lands refunds nothing. The game itself refunds 75% of the placement price when a building is demolished (seen once, on a mod depot: `../tf3-save-format/docs/depots.md`); 80% is a little kinder, so a misclick costs only a fifth of a level.
- **No record of what a level cost.** The refund is priced from today's upkeep, not from what was paid. Keeping what was paid, or when, would mean a record for every level of every tree of every station. Without it, the refund can pay more than the level cost:
  - **Year steps.** Building upkeep, and with it the build price, steps up every 20 years (×1.5 at 1920, ×2.2 at 1940, ×3.2 at 1960, ×4.0 at 1980, ×5.0 at 2000, ×6.0 at 2020; `../tf3-save-format/docs/inflation.md`, "The year cost table"; the 1940, 1980 and 2020 steps are untested). A level bought before a step and removed after it pays back 20% more at 1920, 17% at 1940, 16% at 1960, nothing at 1980 and 2000, and 4% less at 2020.
  - **A long hold.** Bought before 1920 and removed after 2020, a level refunds 0.8 × 6 = 4.8 times its price: for a fully levelled large station (a $30M to $50M outlay at 1919 prices in the test saves), about $115M to $190M profit. Accepted: it takes a click and a rebuild per level, gives up the levels for a century, and a company with that money (several billion in the test saves by 1919) barely notices. Only a refund of about 1/6 (17%) would make a 100-year hold break even, which defeats the point of a kind refund; cheaper levels shrink the profit in dollars but not as a multiple of the price.
  - **Modules added later** raise the build price, and with it the refund, the same way.
- **Landing.** A pending removal has landed once the stored level is at most the one left (a buy: at least the one bought); the old level already passes the buy's test, which would book the refund at once, even for a rebuild the game refuses. The card's wait likewise ends when the tree goes down. A refused removal shows the "Not rebuilt" banner with "The level was kept and nothing was refunded. Clear it and try again."
- **Card.** "<" sits before ">". Its tooltip and the row's give the refund and the upkeep after it ("Remove level 6 for a refund of $X." / "Upkeep after removing it: $Y/Year."). Log lines carry `direction=down` and `refund=`; the landed line is `buy refunded`.

## Rank gate

As in Depot Retrofits: a tree's maximum level is the claimed company rank; no level can be bought while the rank cannot be read.

## Decisions

- A separate mod, not part of Depot Retrofits: own listing, own balance, a failure in one does not break the other.
- Name "Station Retrofits", folder `station_retrofits_1`, log prefix `STATION_RETROFITS` (mod.io checked 2026-11-01: no clash).
- Catchment is in: +3% per level, at least +5 m, first-level share 0.20.
- Waiting capacity is out: more station modules, or mods with larger stops or modules, already add it.
- Harbours get the catchment and upkeep trees only (their emitter reads 0 and the overlays show no pollution or noise at a port); their upkeep tree costs half (`core.levelPrice`, a per-kind factor), which pays back in about 9.4 years with full catchment and 30 with none, against 11 on other stations.
- The Retrofit card stays compact: one line per tree, with "<", ">" and ">|" as small buttons and the prices in the tooltips. Depot Retrofits draws two lines per tree with a header for each, which fits because it has its own tab; this card shares the station window with the terminals and statistics.
- Removing a level refunds 80% of its price at today's build price, with no record of what it cost or when it was bought; the profit across the 20-year upkeep steps is accepted ("Removing a level").
- Kerbside bus and tram stops are out of scope for this mod (decided 2026-11-05).
- Prices (after the pollution test): pollution 0.04 with a step of 1.10, noise 0.08 with 1.12, upkeep 0.16 so that a fully levelled station's upkeep tree pays back in about 11 years; catchment unchanged. Pollution and noise levels still add 5% and 10% of the base upkeep.

## Open decisions (for the user)

1. Whether to look for what a port does emit (its ships' own pollution and noise are vehicle emissions, which no tree touches) and give harbours those levels.
