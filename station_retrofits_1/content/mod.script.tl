-- runFn registers two modifiers for the base modular stations (rail station, street terminal, harbour):
-- - loadConstruction adds one hidden param per level tree (keys in core.tl), with an availability year past the end of the
--   calendar, which keeps them out of the build menu. It leaves updateScript alone: other mods recognise stations by it.
-- - loadScript wraps the station script's updateFn (core.wrapUpdate). The game loads a construction's update script through
--   this modifier, so the wrapper runs whichever way the construction is reached and sits inside any mod that wraps the
--   construction (docs/design/findings.md, "Seen in other mods' code").
-- Base stations only for now. Log lines start with "STATION_RETROFITS".

local modVersion = "0.1-dev"

-- The game's date card goes up to the year 5000; a level param available from 9999 never shows in the build menu.
local hiddenYear = 9999

local record ParamDef
	key : string
	name : string
	tooltip : string
	values : {string}
	yearFrom : integer
	yearTo : integer
	defaultIndex : integer
	uiType : string
	postConstructionModifiable : boolean
end

local record Definition
	params : {ParamDef}
end

local record StationScript
	updateFn : function(any, any) : any
end

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

-- Guarded: without the core module nothing is wrapped, and the log says why.
local coreLoaded, coreModule = pcall(ug_require, "station_retrofits_1::/core.tl")
local core = coreLoaded and (coreModule as StationRetrofitsCore) or nil

local levelValues = function() : {string}
	local values : {string} = {}
	for level = 0, core.maxLevel do values[#values + 1] = tostring(level) end
	return values
end

local levelParam = function(tree : string) : ParamDef
	return {
		key = core.paramKeys[tree],
		name = "Retrofit level: " .. core.names[tree],
		tooltip = "Bought in the station's window; not offered when placing a station.",
		values = levelValues(),
		defaultIndex = 1,
		yearFrom = hiddenYear,
		yearTo = 0,
		uiType = "ComboBox",
		postConstructionModifiable = false,
	}
end

local addParams = function(fileName : string, definition : Definition) : Definition
	local kind = core.kindOf(fileName, core.constructionKinds)
	if kind == nil or type(definition) ~= "table" then return definition end
	definition.params = definition.params or {}
	local present : {string : boolean} = {}
	for _, p in ipairs(definition.params) do present[p.key] = true end
	for _, tree in ipairs(core.trees) do
		if not present[core.paramKeys[tree]] then table.insert(definition.params, levelParam(tree)) end
	end
	if logFull then say("params fileName=" .. tostring(fileName) .. " kind=" .. kind .. " count=" .. tostring(#definition.params)) end
	return definition
end

-- Scripts already wrapped, so a script table handed to the modifier twice is wrapped once.
local wrapped : {any : boolean} = setmetatable({}, { __mode = "k" })

local wrapScript = function(fileName : string, script : StationScript) : StationScript
	local kind = core.kindOf(fileName, core.scriptKinds)
	if logFull and kind == nil and (fileName or ""):find("stations/", 1, true) then
		say("loadScript seen fileName=" .. tostring(fileName))
	end
	if kind == nil or type(script) ~= "table" or type(script.updateFn) ~= "function" or wrapped[script] then return script end
	script.updateFn = core.wrapUpdate(script.updateFn, kind, say, logFull)
	wrapped[script] = true
	say("wrapScript fileName=" .. tostring(fileName) .. " kind=" .. kind)
	return script
end

local mod : StationRetrofitsMod = {
	runFn = function(_captureParams : table, _settings : table, _allModParams : {string : {string : integer}})
		say("version " .. modVersion .. " logLevel=" .. (logFull and "full" or "summary") .. " core=" .. tostring(coreLoaded)
			.. (coreLoaded and "" or (" error=" .. tostring(coreModule)))
			.. (settingsLoaded and "" or (" settingsError=" .. tostring(settingsModule))))
		if core == nil then return end
		addModifier("loadConstruction", function(fileName : string, definition : Definition) : Definition
			local ok, result = pcall(addParams, fileName, definition)
			if ok then return result as Definition end
			say("paramsError fileName=" .. tostring(fileName) .. " error=" .. tostring(result))
			return definition
		end)
		-- Guarded: "loadScript" is not in the game's own scripts; several mods on mod.io use it.
		local registered, registerError = pcall(addModifier, "loadScript", function(fileName : string, script : StationScript) : StationScript
			local ok, result = pcall(wrapScript, fileName, script)
			if ok then return result as StationScript end
			say("wrapError fileName=" .. tostring(fileName) .. " error=" .. tostring(result))
			return script
		end)
		if not registered then say("loadScript unavailable error=" .. tostring(registerError)) end
	end,
}

return mod
