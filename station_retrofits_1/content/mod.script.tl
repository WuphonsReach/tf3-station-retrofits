-- runFn will register a loadConstruction modifier that wraps the update script of every construction that builds a station
-- (docs/design/spec.md). For now it only writes the start-up line, so the mod can be seen to load. Log lines start with
-- "STATION_RETROFITS".

local modVersion = "0.1-dev"

local record StationRetrofitsMod
	runFn : function(table, table, {string : {string : integer}})
end

local say = function(text : string)
	if log ~= nil then
		log.message("STATION_RETROFITS " .. text)
	else
		print("STATION_RETROFITS " .. text)
	end
end

-- settings.tl's logLevel. Guarded: without the file the log stays at "summary".
local settingsLoaded, settingsModule = pcall(ug_require, "station_retrofits_1::/settings.tl")
local logFull = settingsLoaded and type(settingsModule) == "table" and (settingsModule as {string:any}).logLevel == "full"

local mod : StationRetrofitsMod = {
	runFn = function(_captureParams : table, _settings : table, _allModParams : {string : {string : integer}})
		say("version " .. modVersion .. " logLevel=" .. (logFull and "full" or "summary")
			.. (settingsLoaded and "" or (" settingsError=" .. tostring(settingsModule))))
	end,
}

return mod
