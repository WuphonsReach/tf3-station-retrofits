# Changelog

Newest first. The number in the title is `modVersion` at the top of [mod.script.tl](station_retrofits_1/content/mod.script.tl), which the game log prints at every load as `STATION_RETROFITS version <number>` (between releases it reads the next number with "-dev", for example `1.1-dev`). Each entry's last line is the one-liner for the Changelog field of the in-game uploader ([how to release](docs/publishing.md#releasing-a-version)). mod.io labels every uploaded file "1.0", whatever the number here is, so the number in this file and in the log is the one that tells builds apart.

## 1.1 (not released)

Nothing yet.

## 1.0 (2026-11-21)

The first version meant for players.

- **Levels for stations.** Four retrofits of 15 levels each: catchment radius (every catchment circle +3% a level, at least +5 m), pollution (-5%), noise (-5%) and upkeep (-5% of the total). Harbours get the catchment and upkeep retrofits only, as a harbour gives off no pollution or noise of its own, and their upkeep retrofit costs half. The highest level a retrofit can reach is the company rank you have claimed.
- **A Retrofit card in the station window**, above the terminals. Collapsed, it shows one row per retrofit: 15 level boxes and what the levels do now. Expanded, each row shows what the next level changes and the upkeep after it, with three buttons: **<** removes the top level for 80% of what it costs today, **>** buys the next level, **>|** buys every level your rank and money allow in one rebuild, for the same total as buying them one by one. Prices are in the row's tooltip. At the game's Medium and Large text sizes the expanded rows write the upkeep more briefly, so the buttons stay on the card.
- **Buying or removing a level rebuilds the station** and charges the price (or pays the refund) once the rebuild has landed. Waiting passengers stay. When the game refuses the rebuild, usually because something built after the station is in the way, nothing is charged and the card shows "Not rebuilt" about 10 seconds after the click. When the money drops below the price just as you click, the card shows "Not bought: not enough money" and nothing is charged.
- **Which stations.** The game's train stations, road and tram stations and harbours, for passengers and cargo, including ones built before the mod was added. Configure keeps the levels, and levels are saved with the game.
- **Works with TRM: Industry Emissions** in either load order; both mods' cuts to pollution and noise apply.

Release note: `First release: stations get levels for catchment radius, pollution, noise and upkeep, bought in the station's Retrofit card.`
