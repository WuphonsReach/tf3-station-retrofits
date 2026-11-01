-- The four level trees, the formulas of docs/design/spec.md and the wrapper of a base station script's updateFn, shared by
-- the mod script and the game script (each loads it with ug_require under pcall). No game API calls, so it loads the same in
-- every Lua state.
--
-- The wrapper runs the original updateFn. On a modular station (params.modules and result.slots set) the game calls
-- result.terminateConstructionHook after every module's own script; the wrapper replaces that hook, and every copy of it in
-- the result's tables (harbours copy it into their station tables), with one that runs the original once, keeps its
-- returns for any later call, and then scales the station once. Without modules or slots the game calls no hook, so it scales
-- at once. Scaling multiplies the values it finds, on copies of their tables, so the levels stack with other mods that scale
-- the same values and nothing scaled is written back into params (docs/design/findings.md, "Seen in other mods' code").
-- A station with every level at 0 is left as the original made it.

local core : StationRetrofitsCore = {
	maxLevel = 15,
	trees = { "catchment", "pollution", "noise", "upkeep" },
	paramKeys = {
		catchment = "stationRetrofitsCatchment",
		pollution = "stationRetrofitsPollution",
		noise = "stationRetrofitsNoise",
		upkeep = "stationRetrofitsUpkeep",
	},
	scriptKinds = {
		["stations/rail/modular_station/modular_station.script"] = "rail",
		["stations/street/modular_street_station/modular_terminal.script"] = "street",
		["stations/water/harbor_modular.script"] = "harbour",
	},
	constructionKinds = {
		["stations/rail/modular_station/modular_station.con"] = "rail",
		["stations/street/modular_street_station/modular_terminal.con"] = "street",
		["stations/water/harbor_modular.con"] = "harbour",
	},
	names = {
		catchment = "Catchment radius",
		pollution = "Pollution",
		noise = "Noise",
		upkeep = "Upkeep",
	},
}

local catchmentStep = 0.03
local minCatchmentStep = 5
local emissionStep = 0.05
-- Each level adds this share of the base upkeep; the upkeep tree cuts the total.
local upkeepPerLevel : {string : number} = { catchment = 0.15, pollution = 0.05, noise = 0.10 }
local upkeepStep = 0.05
core.upkeepShares = upkeepPerLevel
core.upkeepStep = upkeepStep

function core.kindOf(fileName : string, kinds : {string : string}) : string
	local path = (fileName or ""):gsub("^.-::", ""):gsub("%.lua$", ""):gsub("^/", "")
	return kinds[path]
end

local round = function(x : number) : integer
	return math.floor(x + 0.5)
end

-- Construction params are 1-based indexes into the declared values, so the stored 1 is level 0 and 16 is level 15.
function core.read(params : {string : any}) : {string : integer}
	local result : {string : integer} = {}
	for _, tree in ipairs(core.trees) do
		local raw = params and tonumber(params[core.paramKeys[tree]])
		local level = raw and (math.floor(raw) - 1) or 0
		result[tree] = math.max(0, math.min(core.maxLevel, level))
	end
	return result
end

function core.store(params : {string : any}, values : {string : integer})
	for _, tree in ipairs(core.trees) do
		params[core.paramKeys[tree]] = (values[tree] or 0) + 1
	end
end

function core.describe(values : {string : integer}) : string
	if values == nil then return "nil" end
	local parts : {string} = {}
	for _, tree in ipairs(core.trees) do parts[#parts + 1] = tostring(values[tree]) end
	return table.concat(parts, "/")
end

function core.isZero(values : {string : integer}) : boolean
	for _, tree in ipairs(core.trees) do
		if (values[tree] or 0) ~= 0 then return false end
	end
	return true
end

function core.radius(baseRadius : number, level : integer) : number
	return baseRadius + math.max(baseRadius * catchmentStep * level, minCatchmentStep * level)
end

-- The value before the levels, from a value the wrapper scaled: whichever branch of the formula gives back the value. nil when
-- neither does (another mod scaled it too, or the value is not ours).
function core.baseRadius(radius : number, level : integer) : number
	if level <= 0 then return radius end
	for _, base in ipairs({ radius / (1 + catchmentStep * level), radius - minCatchmentStep * level }) do
		if base > 0 and math.abs(core.radius(base, level) - radius) < 0.01 then return base end
	end
	return nil
end

function core.withLevel(values : {string : integer}, tree : string, level : integer) : {string : integer}
	local copy : {string : integer} = {}
	for _, t in ipairs(core.trees) do copy[t] = values[t] end
	copy[tree] = level
	return copy
end

function core.emissionFactor(level : integer) : number
	return 1 - emissionStep * level
end

function core.upkeepFactor(values : {string : integer}) : number
	local added = 0.0
	for tree, share in pairs(upkeepPerLevel) do added = added + share * (values[tree] or 0) end
	return (1 + added) * (1 - upkeepStep * (values.upkeep or 0))
end

local copyTable = function(source : {any : any}) : {any : any}
	local copy : {any : any} = {}
	for key, value in pairs(source) do copy[key] = value end
	return copy
end

-- The tables of a result that hold a station: the result, its cargo and passenger stations and its subconstructions, each
-- once.
local stationNodes = function(result : {string : any}) : {{string : any}}
	local nodes : {{string : any}} = {}
	local seen : {any : boolean} = {}
	local add = function(node : any)
		if type(node) ~= "table" or seen[node] then return end
		seen[node] = true
		if type((node as {string : any}).station) == "table" then nodes[#nodes + 1] = node as {string : any} end
	end
	add(result)
	add(result.cargoStation)
	add(result.passengerStation)
	if type(result.subconstructions) == "table" then
		for _, sub in ipairs(result.subconstructions as {any}) do add(sub) end
	end
	return nodes
end

-- "r1,r2,r3 pool=n terminals=n emissions=noise/pollution,noise/pollution" for a log line.
local describeNode = function(node : {string : any}) : string
	local station = node.station as {string : any}
	local radii : {string} = {}
	for _, area in ipairs((station.catchmentAreas or {}) as {{string : any}}) do
		radii[#radii + 1] = string.format("%.1f", tonumber(area.radius) or -1)
	end
	local terminals = 0.0
	for _, terminal in ipairs((station.terminals or {}) as {{string : any}}) do
		terminals = terminals + (tonumber(terminal.capacity) or 0)
	end
	local pool = type(station.pool) == "table" and (station.pool as {string : any}).capacity or nil
	local emissions : {string} = {}
	local metadata = node.metadata as {string : any}
	if type(metadata) == "table" and type(metadata.emissions) == "table" then
		for _, e in ipairs(metadata.emissions as {{string : any}}) do
			emissions[#emissions + 1] = tostring(e.noise) .. "/" .. tostring(e.pollution)
		end
	end
	return "radii=" .. table.concat(radii, ",") .. " pool=" .. tostring(pool) .. " terminals=" .. tostring(terminals)
		.. " emissions=" .. table.concat(emissions, ",")
end

local scaleNode = function(node : {string : any}, values : {string : integer})
	local station = copyTable(node.station as {any : any}) as {string : any}
	node.station = station
	if values.catchment > 0 and type(station.catchmentAreas) == "table" then
		local areas : {any} = {}
		for i, area in ipairs(station.catchmentAreas as {any}) do
			if type(area) == "table" then
				local copy = copyTable(area as {any : any}) as {string : any}
				local radius = tonumber(copy.radius)
				if radius ~= nil then copy.radius = core.radius(radius, values.catchment) end
				areas[i] = copy
			else
				areas[i] = area
			end
		end
		station.catchmentAreas = areas
	end
	local metadata = node.metadata as {string : any}
	if (values.noise > 0 or values.pollution > 0) and type(metadata) == "table" and type(metadata.emissions) == "table" then
		metadata = copyTable(metadata as {any : any}) as {string : any}
		local emissions : {any} = {}
		for i, e in ipairs(metadata.emissions as {any}) do
			if type(e) == "table" then
				local copy = copyTable(e as {any : any}) as {string : any}
				local noise, pollution = tonumber(copy.noise), tonumber(copy.pollution)
				if noise ~= nil then copy.noise = noise * core.emissionFactor(values.noise) end
				if pollution ~= nil then copy.pollution = pollution * core.emissionFactor(values.pollution) end
				emissions[i] = copy
			else
				emissions[i] = e
			end
		end
		metadata.emissions = emissions
		node.metadata = metadata
	end
end

-- The upkeep the modules add, which the game adds to the script's own maintenanceCost.
local modulesUpkeep = function(params : {string : any}) : number
	local total = 0.0
	if type(params.modules) ~= "table" then return total end
	for _, m in pairs(params.modules as {any : any}) do
		if type(m) == "table" and type((m as {string : any}).metadata) == "table" then
			total = total + (tonumber(((m as {string : any}).metadata as {string : any}).maintenanceCost) or 0)
		end
	end
	return total
end

local apply = function(result : {string : any}, params : {string : any}, values : {string : integer}, kind : string,
	say : function(string), logFull : boolean)
	local nodes = stationNodes(result)
	for i, node in ipairs(nodes) do
		local before = logFull and describeNode(node) or nil
		scaleNode(node, values)
		if logFull then
			say("scale kind=" .. kind .. " node=" .. tostring(i) .. " levels=" .. core.describe(values) .. " before " .. before
				.. " after " .. describeNode(node))
		end
	end
	-- By the time the hook has run, the result's maintenanceCost already holds the modules' upkeep (probe 1: it equalled
	-- their sum, and the game charged 1.25 times whatever was set), so the levels scale it directly.
	local base = tonumber(result.maintenanceCost) or 0
	result.maintenanceCost = round(base * core.upkeepFactor(values))
	say("applied kind=" .. kind .. " levels=" .. core.describe(values) .. " stations=" .. tostring(#nodes)
		.. " upkeepBase=" .. tostring(base) .. " upkeepModules=" .. tostring(modulesUpkeep(params))
		.. " maintenanceCost=" .. tostring(result.maintenanceCost))
end

function core.wrapUpdate(original : function(any, any) : any, kind : string, say : function(string), logFull : boolean)
	: function(any, any) : any
	return function(captureParams : any, params : any) : any
		local result = original(captureParams, params)
		if type(result) ~= "table" then return result end
		local p = (type(params) == "table" and params or {}) as {string : any}
		local values = core.read(p)
		if core.isZero(values) then return result end
		local r = result as {string : any}
		local hook = r.terminateConstructionHook
		if p.modules ~= nil and r.slots ~= nil and type(hook) == "function" then
			local inner = hook as function(...: any) : (any...)
			local ran = false
			local returns : {any} = {}
			local count = 0
			local calls = 0
			local wrapped = function(...: any) : (any...)
				calls = calls + 1
				if ran then
					if logFull then say("hookAgain kind=" .. kind .. " calls=" .. tostring(calls)) end
					return table.unpack(returns, 1, count)
				end
				ran = true
				local packed = table.pack(inner(...))
				count = packed.n
				for i = 1, count do returns[i] = packed[i] end
				apply(r, p, values, kind, say, logFull)
				return table.unpack(returns, 1, count)
			end
			r.terminateConstructionHook = wrapped
			local relinked = 0
			local relink = function(value : any)
				if type(value) == "table" and (value as {string : any}).terminateConstructionHook == hook then
					(value as {string : any}).terminateConstructionHook = wrapped
					relinked = relinked + 1
				end
			end
			for _, value in pairs(r) do relink(value) end
			if type(r.subconstructions) == "table" then
				for _, sub in ipairs(r.subconstructions as {any}) do relink(sub) end
			end
			if logFull then say("hookWrapped kind=" .. kind .. " relinked=" .. tostring(relinked)) end
		else
			apply(r, p, values, kind, say, logFull)
		end
		return result
	end
end

return core
