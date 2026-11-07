-- The base station script, as TRM: Industry Emissions loads it (docs/compatibility.md). TRM's wrapper for road and tram
-- stations and harbours loads the script it wraps itself (ug_require of a .lua file, then the global data()), so it got a
-- copy our loadScript wrapper (mod.script.tl) never saw, and the levels were lost. mod.script.tl's postRunFn points TRM at
-- this file instead and keeps the original's reference in the capture param stationRetrofitsOriginal. This file defines
-- data() as base scripts do; its updateFn loads that original through the game's util.useFn, which goes through the
-- loadScript modifier, so the original comes back wrapped, as it does without TRM. TRM's wrapper then sits outside ours
-- and both apply. Plain Lua, not Teal: TRM loads it by this exact path.
--
-- If util.useFn cannot give the original, it is loaded TRM's way and wrapped here with core.wrapUpdate, so the station
-- still builds with its levels; the failure is logged once per reference.

local say = function(text)
	if log ~= nil then
		log.message("STATION_RETROFITS " .. text)
	else
		print("STATION_RETROFITS " .. text)
	end
end

local settingsLoaded, settingsModule = pcall(ug_require, "station_retrofits_1::/settings.tl")
local logFull = settingsLoaded and type(settingsModule) == "table" and settingsModule.logLevel == "full"
local utilLoaded, util = pcall(ug_require, "::/scripts/util.tl")
local coreLoaded, core = pcall(ug_require, "station_retrofits_1::/core.tl")

local originalKey = "stationRetrofitsOriginal"
local originals = {}
local logged = {}

-- The original's updateFn without useFn: its file run with ug_require, then the global data() it defines, then wrapped
-- here, as the loadScript modifier would have. The result is kept in originals: a second ug_require of the same file in a
-- Lua state does not run it again, so data() would then be whichever file defined it last.
local loadDirect = function(ref)
	local path, fnName = ref:match("^(.-)@(.*)$")
	if path == nil then error("bad reference " .. tostring(ref)) end
	ug_require(path .. ".lua")
	if type(data) ~= "function" then error("no data() in " .. path) end
	local fn = data()[fnName]
	if type(fn) ~= "function" then error("no " .. fnName .. " in " .. path) end
	if not coreLoaded or type(core) ~= "table" then error("core unavailable: " .. tostring(core)) end
	local kind = core.kindOf(path, core.scriptKinds)
	if kind == nil then error("not a base station script: " .. path) end
	return core.wrapUpdate(fn, kind, say, logFull)
end

local original = function(ref)
	local cached = originals[ref]
	if cached ~= nil then return cached end
	local ok, fn = false, nil
	if utilLoaded and type(util) == "table" then ok, fn = pcall(util.useFn, ref) end
	local via = "useFn"
	if not ok or type(fn) ~= "function" then
		local useFnError = tostring(fn)
		via = "direct"
		local okDirect, direct = pcall(loadDirect, ref)
		if not okDirect then
			error("STATION_RETROFITS trmShim originalMissing ref=" .. tostring(ref) .. " useFnError=" .. useFnError
				.. " directError=" .. tostring(direct))
		end
		fn = direct
		if not logged[ref] then say("trmShim useFnFailed ref=" .. tostring(ref) .. " error=" .. useFnError .. " via=direct") end
	elseif logFull and not logged[ref] then
		say("trmShim loaded ref=" .. tostring(ref) .. " via=" .. via)
	end
	logged[ref] = true
	originals[ref] = fn
	return fn
end

function data()
	return {
		updateFn = function(captureParams, params)
			local ref = type(captureParams) == "table" and captureParams[originalKey] or nil
			if type(ref) ~= "string" then
				error("STATION_RETROFITS trmShim noOriginal: the capture params have no " .. originalKey)
			end
			return original(ref)(captureParams, params)
		end,
	}
end
