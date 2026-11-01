-- The Retrofit card in the station window (retrofit_card.script.tl). The game draws a plugin when its condition is true, in
-- the order of "order" (gui/main/react.lua, getPlugins); the base window adds none of its own cards through this point.
function data()
	return {
		type = "react-plugin ::StationGroupEowExtensionPoint",
		data = {
			filePath = "station_retrofits_1::/retrofit_card.script@RetrofitCardPlugin",
			condition = "station_retrofits_1::/retrofit_card.script@conditionRetrofitCard",
			order = 100,
		},
	}
end
