# Spec (draft)

## In short

Stations get levels, bought one at a time in the station's own window, the way [Depot Retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits) does it for depots. This is a draft: every number below is a starting point taken from Depot Retrofits, and the trees marked "if the probe allows" depend on the probes in [probe-plan.md](probe-plan.md). Nothing is built yet.

The planned first version has four trees of 15 levels each (catchment radius, waiting capacity, pollution, noise), plus an upkeep tree. It covers the base modular stations (rail, road and tram terminals, harbours) and later stations from other mods that have the same shape. A tree's highest level is the company's claimed rank. A level is applied by rebuilding the station with new hidden params, as for depots.

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

The two kinds of tree carry over from Depot Retrofits: four trees improve the station and raise its upkeep; the upkeep tree cuts the total.

| Tree | Game value changed | Per level (draft) | At level 15 |
|---|---|---|---|
| Catchment radius | every circle in `station.catchmentAreas` | +3%, or at least +5 m | +45%, or at least +75 m |
| Waiting capacity | `station.pool.capacity` and each terminal's capacity | +10%, or at least +1 | +150% |
| Pollution | `metadata.emissions`, both states | −5% | −75% |
| Noise | `metadata.emissions`, both states | −5% | −75% |
| Upkeep | the station's total upkeep, modules included | −5% of the total | −75% |

Notes:

- **Catchment is the strongest tree.** It brings more town into reach of the station, so more passengers and cargo, which no depot tree does. So it has smaller steps than the depot radius tree (+3%, not +5%) and a higher price (share 0.20). Base circles are 50 to 250 m (a rail station has several 60 m ones), so the floor decides small circles: at 5 m a level, a 60 m circle grows +5 m a level (+75 m, +125%, at level 15) and a 175 m one +5.25 m.
- **Capacity lowers emissions too.** Station emissions slide toward the crowded state (2 × base) as waiting passengers and cargo fill the capacity, so on a busy station a capacity level also cuts pollution and noise.
- **Left out for now: comfort and load speed.** Both are set in the same hook, but their effect is decided in the engine and unmeasured. Add them only after a test shows what a level does in play.

## Price and upkeep (draft, from Depot Retrofits)

- **Build price.** 6 × the upkeep the game charges for the station now, divided by what its current levels do to the upkeep, rounded to $100. In 80 of 81 base station modules the price is exactly 6 × the upkeep, so this matches the modules' summed price.
- **Level price.** Level *n* costs the tree's first-level share × the build price × 1.15^(*n*−1). Depot shares: 0.15 radius and vehicles, 0.12 noise, 0.08 pollution, 0.25 upkeep. Here: 0.20 catchment (decided: above the other trees), and as starting points 0.15 capacity, 0.12 noise, 0.08 pollution, 0.25 upkeep.
- **Upkeep.** Each improving level adds a share of the base upkeep: 15% catchment and capacity, 10% noise, 5% pollution. The upkeep tree multiplies the total by (1 − 0.05 × levels). Waiting capacity levels add nothing while the station has no waiting places (decided: they do nothing there); they are charged again once it has some.
- **How upkeep is applied.** After the hook, the script's `maintenanceCost` already holds the modules' upkeep, and the game charges what the script leaves there; the wrapper multiplies it by the upkeep factor (probe 1).
- **Modules added later.** As in Depot Retrofits, levels are not repriced when the station grows; the upkeep the levels add follows the modules. Big stations pay big prices, since the build price grows with the modules.

## Buying a level

- In a collapsible Retrofit card in the station's window (a tab would need `entityWindowScript`, which stops the station window from opening; see findings). The station window keeps one collapsible card open at a time, and the card starts collapsed.
  - **Collapsed (summary):** one row per tree: the stock icon, 15 level boxes (bought, allowed by the rank, locked) and, at the right edge, what the levels do now ("200 -> 230 m" for the largest catchment circle, "310 -> 465" for all waiting places, "-25%" for pollution and noise, "-25% of total" for upkeep). A station with no waiting places (a cargo-only station) has no waiting capacity row, collapsed or expanded, even with levels bought before its waiting places were removed: it takes no passengers, so the row would only confuse. Those levels stay on the station and show again when it gets waiting places.
  - **Expanded:** one row per tree: what the next level changes, the upkeep after it, and a buy button with the shopping cart and the price. Greyed when the rank is too low or unknown, or the balance is short. The game's own upkeep footer stays where it is in the window.
  - **Tooltip, on the whole row:** the tree's name and "Level 4/7 (max 15)" as in Depot Retrofits (the level over what the rank allows, "(max 15)" only while the rank is lower), then what a level does and what upkeep it adds, one sentence a line.
- A click sends the buy; the game script rebuilds the station and books the price once the rebuild has landed; "Not rebuilt" with the proposal viewer when the game refuses it.
- What a rebuild does to waiting passengers and cargo and to vehicles at the platforms is unknown (probe 1). If it loses the waiting passengers or cargo, say so on the card.

## Rank gate

As in Depot Retrofits: a tree's maximum level is the claimed company rank; no level can be bought while the rank cannot be read.

## Decisions

- A separate mod, not part of Depot Retrofits: own listing, own balance, a failure in one does not break the other.
- Name "Station Retrofits", folder `station_retrofits_1`, log prefix `STATION_RETROFITS` (mod.io still to be checked for a clash).
- Catchment is in: +3% per level, at least +5 m, first-level share 0.20.

## Open decisions (for the user)

1. Whether kerbside stops are in scope (after probe 4).
