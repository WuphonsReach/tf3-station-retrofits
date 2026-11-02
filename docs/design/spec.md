# Spec (draft)

## In short

Stations get levels, bought one at a time in the station's own window, the way [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) does it for depots. This is a draft: every number below is a starting point taken from Depot Retrofits, and the scope depends on the probes in [probe-plan.md](probe-plan.md). Levels are applied and shown (probes 1 and 2); buying them is built and not yet tested in game.

The planned first version has three trees of 15 levels each (catchment radius, pollution, noise), plus an upkeep tree. Waiting capacity is not a tree: players already add it by building more station modules, and mods with larger stops or modules cover the rest. It covers the base modular stations (rail, road and tram terminals, harbours) and later stations from other mods that have the same shape. A tree's highest level is the company's claimed rank. A level is applied by rebuilding the station with new hidden params, as for depots.

## Scope

| Construction | First version | Why |
|---|---|---|
| Train station | yes | modular, values in `terminateConstructionHook` |
| Road and tram terminal | yes | same |
| Harbour | yes | same |
| Airport, airfield, heliport | later | also contain a depot (hangar); keep them apart from Depot Retrofits first |
| Underground station | maybe | not modular; upkeep set by the script, so the upkeep tree would work as for depots |
| Kerbside bus and tram stops | only if probe 4 works | edge objects; replacing one in place is untested |
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

Notes:

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

  Catchment is the dearest, as it brings in more town (passengers and cargo). Pollution and noise are cheap and rise slowly: stations are only part of a town's pollution, so pollution 9 on all 16 stations of a town cut its pollution by about 11% (findings, test results). The upkeep tree is priced to pay for itself: on a station with the other three trees full (5.5 × the base upkeep), the full tree costs 45.7 × the base upkeep and saves 4.1 × a year, about 11 years (level 1 in 3.5 years, level 15 in 25). On a station with no other levels it saves only 0.75 × a year. Depot Retrofits keeps its own shares (0.15, 0.08, 0.12, 0.25) and one step of 1.15.
- **Upkeep.** Each improving level adds a share of the base upkeep: 15% catchment, 10% noise, 5% pollution. The upkeep tree multiplies the total by (1 − 0.05 × levels).
- **How upkeep is applied.** After the hook, the script's `maintenanceCost` already holds the modules' upkeep, and the game charges what the script leaves there; the wrapper multiplies it by the upkeep factor (probe 1).
- **Modules added later.** As in Depot Retrofits, levels are not repriced when the station grows; the upkeep the levels add follows the modules. Big stations pay big prices, since the build price grows with the modules.

## Buying a level

- In a collapsible Retrofit card in the station's window (a tab would need `entityWindowScript`, which stops the station window from opening; see findings). The station window keeps one collapsible card open at a time, and the card starts collapsed.
  - **Collapsed (summary):** one row per tree: the stock icon, 15 level boxes (bought, allowed by the rank, locked) and, at the right edge, what the levels do now ("200 -> 230 m" for the largest catchment circle, "-25%" for pollution and noise, "-25% of total" for upkeep).
  - **Expanded:** one row per tree: what the next level changes at the left ("200 -> 206 m", "0% -> -5%"), and at the right the upkeep after it, then a buy button with the shopping cart and the price. The buy buttons share a minimum width (a mod CSS rule; a longer label widens its button rather than being cut off), so the upkeep figures end in one column. No "Level 1:" label: with it the row ran past the card's edge; the tooltip gives the level. Greyed when the rank is too low or unknown, or the balance is short. The game's own upkeep footer stays where it is in the window.
  - **Tooltip, on the whole row:** the tree's name and "Level 4/7 (max 15)" as in Depot Retrofits (the level over what the rank allows, "(max 15)" only while the rank is lower), then what a level does and what upkeep it adds, one sentence a line.
- A click sends the buy; the game script checks it again (level not stale, within the rank, enough money), rebuilds the station and books the price once the rebuild has landed, as station construction under the station's carrier (rail RAIL, harbour WATER, road station ROAD, or TRAM with tram tracks). A rebuild that never lands costs nothing. The price shows in the Finances tab under Investments, Infrastructure.
- When the game refuses the rebuild (the clicked tree has not gone up about 10 seconds after the click: harbours take up to 3 seconds to build, and a busy game can take 3 more to take up the buy), the card shows the yellow "Not rebuilt" banner above its rows until a level lands: "Not rebuilt: a building, road or track is in the way. Nothing was charged. Clear it and buy again." Depot Retrofits also shows what is in the way with the game's proposal viewer; the station window gives its cards no place for it (findings), so that is left for later.
- What a rebuild does to waiting passengers and cargo and to vehicles at the platforms is unknown (probe 1). If it loses the waiting passengers or cargo, say so on the card.

## Rank gate

As in Depot Retrofits: a tree's maximum level is the claimed company rank; no level can be bought while the rank cannot be read.

## Decisions

- A separate mod, not part of Depot Retrofits: own listing, own balance, a failure in one does not break the other.
- Name "Station Retrofits", folder `station_retrofits_1`, log prefix `STATION_RETROFITS` (mod.io still to be checked for a clash).
- Catchment is in: +3% per level, at least +5 m, first-level share 0.20.
- Waiting capacity is out: more station modules, or mods with larger stops or modules, already add it.
- Prices (after the pollution test): pollution 0.04 with a step of 1.10, noise 0.08 with 1.12, upkeep 0.16 so that a fully levelled station's upkeep tree pays back in about 11 years; catchment unchanged. Pollution and noise levels still add 5% and 10% of the base upkeep.

## Open decisions (for the user)

1. Whether kerbside stops are in scope (after probe 4).
