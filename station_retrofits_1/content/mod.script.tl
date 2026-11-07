-- runFn registers two modifiers for the base modular stations (rail station, street terminal, harbour):
-- - loadConstruction adds one hidden param per level tree (keys in core.tl), with an availability year past the end of the
--   calendar, which keeps them out of the build menu. It leaves updateScript alone: other mods recognise stations by it.
-- - loadScript wraps the station script's updateFn (core.wrapUpdate). The game loads a construction's update script through
--   this modifier, so the wrapper runs whichever way the construction is reached and sits inside any mod that wraps the
--   construction (docs/design/findings.md, "Seen in other mods' code").
-- postRunFn (after every mod's modifiers have run, so in either load order) points TRM: Industry Emissions at
-- station_original.script.lua: TRM's wrapper for road and tram stations and harbours loads the base script itself, which
-- skips the loadScript wrapper and lost every level (docs/compatibility.md). It changes only TRM's own param naming the
-- script to load, never updateScript.fileName.
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
	postRunFn : function(any, any, any, any)
end

-- TRM: Industry Emissions' wrapper (its building_build.script.lua) reads the script it wraps from these capture params: a
-- .lua path ("::/stations/street/modular_street_station/modular_terminal.script.lua") and the function's name.
local trmScriptKey = "beOriginalScript"
local trmFnKey = "beOriginalFn"
-- Where station_original.script.lua finds the original, as a util.useFn reference ("…/modular_terminal.script@updateFn").
local originalKey = "stationRetrofitsOriginal"
local shimPath = "station_retrofits_1::/station_original.script.lua"

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

-- For each base station construction whose update script is a wrapper that names the base script in trmScriptKey, points
-- that param at the shim and keeps the original in originalKey. The update script is replaced by a fresh ScriptRef with the
-- same fileName, as TRM: Infrastructure Upkeep edits station constructions in its own postRunFn. Returns how many were
-- pointed at the shim.
local redirectTrm = function() : integer
	local count = 0
	for id, name in pairs(api.res.constructionRep.getAll(true)) do
		local kind = core.kindOf(name, core.constructionKinds)
		if kind ~= nil then
			local con = api.res.constructionRep.get(id)
			local script = con and con.updateScript
			local params = script and (script.params as {string : any}) or nil
			local named = params and params[trmScriptKey] or nil
			if type(named) == "string" then
				local scriptName = named as string
				if scriptName == shimPath then
					say("trmRedirect already construction=" .. tostring(name))
				elseif core.kindOf(scriptName, core.scriptKinds) == kind then
					local copy : {string : any} = {}
					for key, value in pairs(params) do copy[key] = value end
					local fnName = type(params[trmFnKey]) == "string" and params[trmFnKey] as string or "updateFn"
					copy[originalKey] = scriptName:gsub("%.lua$", "") .. "@" .. fnName
					copy[trmScriptKey] = shimPath
					local ref = api.type.ScriptRef.new()
					ref.fileName = script.fileName
					ref.params = copy as table
					con.updateScript = ref
					count = count + 1
					say("trmRedirect construction=" .. tostring(name) .. " kind=" .. kind .. " wrapper=" .. tostring(script.fileName)
						.. " original=" .. tostring(copy[originalKey]))
				else
					say("trmRedirect skipped construction=" .. tostring(name) .. " kind=" .. kind .. " names=" .. scriptName)
				end
			end
		end
	end
	return count
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
	postRunFn = function(_captureParams : any, _configDict : any, _allModParams : any, _baseConfig : any)
		if core == nil then return end
		local ok, result = pcall(redirectTrm)
		if ok then
			say("postRun trmRedirected=" .. tostring(result))
		else
			say("postRun trmRedirectError error=" .. tostring(result))
		end
	end,
}

return mod
