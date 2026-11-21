# User guide

## In short

- **What it does.** Stations get levels. A level widens the station's catchment area, or cuts its pollution, noise or upkeep.
- **Where to buy.** Open the station's window and expand its Retrofit card. Buy the next level, or every level you can in one click. A level can be removed again for 80% of its price.
- **What it costs.** Levels are priced from what the station would cost to build today, and each level costs more than the one before. Every level except the upkeep levels also raises the station's upkeep.
- **Limit.** A retrofit's highest level is your company rank, up to 15.
- **One catch.** Buying or removing a level rebuilds the station. Waiting passengers stay. When the game cannot rebuild the station, usually because something built after it is in the way, nothing is charged.
- **Status.** Version 1.0, the first release: train stations, road and tram stations and harbours.

## Which stations

The game's train stations, road and tram stations and harbours, for passengers and cargo, including ones built before the mod was added. A newly placed station starts at level 0 in every retrofit; the build menu has no level options.

Harbours get only the catchment and upkeep retrofits: a harbour gives off no pollution or noise of its own (its ships do, and the mod does not change vehicles), so those levels would do nothing.

Not covered: airports, airfields, heliports and helipads (planned for a later version), the underground station, kerbside bus and tram stops, and stations from other mods that bring their own construction file. Depot Retrofits, the sibling mod, levels depots and maintenance buildings; the two mods never touch the same building.

## The Retrofit card

The card sits in the station's window, above the terminals. It starts collapsed; the station window keeps one card open at a time.

- **Collapsed:** one row per retrofit, with the retrofit's icon, 15 level boxes and, at the right, what the levels do now: "200 -> 230 m" for the largest catchment circle, "-25%" for pollution and noise, "-25% of total" for upkeep. White boxes are levels bought, grey ones levels you can buy at your rank, dark ones levels that need a higher rank.
- **Expanded:** one line per retrofit: what the next level changes ("200 -> 206 m", "0% -> -5%"), the upkeep after it, and three buttons:
  - **<** removes the top level and gives back 80% of what that level costs today.
  - **>** buys the next level.
  - **>|** buys every level your rank and your money allow, in one go. It costs the same as buying those levels one by one.
- **Tooltip:** hover over a row for the retrofit's level, for example "Level 4/7 (max 15)" (the level over what your rank allows), what a level does and what upkeep it adds, and, in the expanded card, the price of the next level, the total for ">|", and the refund and upkeep after "<". The game shows no tooltip on a greyed button, so the row's tooltip also says why a button is greyed.

The station's own upkeep footer, at the bottom of the window, shows the upkeep now.

## Buying and removing levels

- **When the buttons are greyed.** ">" and ">|" are greyed when the next level needs a higher company rank ("Level 8 needs company rank 8." in the tooltip) or you do not have enough money for it. "<" is greyed at level 0. A level above your rank can still be removed.
- **The price is charged once the rebuild is done**, as station construction: the Finances tab shows it under Investments, Infrastructure. A removal's refund is paid the same way.
- **Not enough money at the click.** If your money drops below the price just as you click (for example while vehicles are being bought), the level is not bought, nothing is charged, and a yellow note on the card says "Not bought: not enough money". It stays for at least 10 seconds, until you have the money for that level again.
- **Not rebuilt.** Sometimes the game cannot rebuild the station, usually because something built after it is in the way: a town building on the lot next door, or a road or track rebuilt next to it. Then the level is not bought (or not removed), nothing is charged or given back, and about 10 seconds after the click a yellow "Not rebuilt" banner shows on the card. Clear what is in the way and click again; pausing the game first keeps the town from building there again. While the card waits for a station's rebuild, more clicks on that station are ignored.
- **The refund follows today's price.** A removed level gives back 80% of what it would cost to buy now, not of what you paid. Build prices step up over the decades, so a level bought long ago can give back more than it cost.

## The four retrofits

| Retrofit | Per level | At level 15 |
|---|---|---|
| Catchment radius | every catchment circle +3%, or at least +5 m | +45%, or at least +75 m |
| Pollution | -5% | -75% |
| Noise | -5% | -75% |
| Upkeep | -5% of the total upkeep | -75% of the total |

The catchment levels grow every circle of the station, so a rail station's small 60 m circles grow by the 5 m floor (+75 m at level 15) and a 250 m circle by 3% a level.

Pollution and noise levels lower only what the station itself gives off. Vehicles and tracks keep their own pollution and noise.

## What levels cost

Level prices follow the station's build price: what it would cost to build today, modules included. A large station's levels cost more, and modules added later raise the price of the next levels.

| Retrofit | Level 1 | Each level after that | Level 15 | All 15 levels |
|---|---|---|---|---|
| Catchment radius | 20% of the build price | 15% more than the one before | 1.4 × the build price | 9.5 × the build price |
| Pollution | 4% | 10% more | 0.15 × | 1.3 × |
| Noise | 8% | 12% more | 0.39 × | 3.0 × |
| Upkeep | 16% | 15% more | 1.1 × | 7.6 × |
| Upkeep, harbours | 8% | 15% more | 0.57 × | 3.8 × |

Catchment costs the most, as it brings more of the town into reach of the station: more passengers and more cargo. Pollution and noise cost little, as stations are only part of a town's pollution. The order you buy in does not change any price, and neither does buying several levels with ">|".

## Upkeep

Each catchment level adds 15% of the station's normal upkeep, each noise level 10% and each pollution level 5%. With those three retrofits at 15, the upkeep is 5.5 times the normal upkeep (a harbour with full catchment: 3.25 times). The upkeep the levels add follows the station: modules added later raise it too.

The upkeep retrofit cuts the total by 5% per level, so level 15 leaves a quarter of it. On a station with the other three retrofits at 15, a full upkeep retrofit pays for itself in about 11 game years; on a harbour with full catchment, in about 9. On a station with no other levels it pays back far more slowly. The first upkeep levels pay back fastest.

## Good to know

- **The town window shows the effect best:** the list of pollution sources and the Pollution Rating graph on a town's pollution card. Expect a real but small change: industries, company vehicles and tracks give off much of a town's pollution, and the mod does not change them. In a test, pollution level 9 on all 16 stations of a town cut the town's pollution by about 11%, and its rating stayed Poor.
- **Levels are saved with the game.**
- **The game's own rebuilds keep the levels**, for example adding, moving or removing modules with Configure.
- **Waiting passengers stay** through a rebuild.
- **Other mods.** Works with TRM: Industry Emissions in either load order, and both mods' cuts to pollution and noise apply. With TRM: Infrastructure Upkeep, prices and refunds are lower by the share of upkeep it cuts, as they are worked out from the upkeep the game charges. More in [compatibility.md](compatibility.md).
- **Not checked yet.**
  - Whether changing a station's era or adding catenary keeps the levels.
  - What a rebuild does to vehicles standing at the platforms and to waiting cargo.
  - What happens to levelled stations when the mod is removed from a save. Keep a backup of any save you play with the mod.
