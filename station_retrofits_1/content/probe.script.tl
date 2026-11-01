-- Probe 1 (docs/design/probe-plan.md): acts by itself once per save. It picks up to 3 base stations, one of each kind (the
-- ids in preferred first, then the first of each kind found), logs a snapshot of each, and rebuilds each with every level at
-- 5, except as below. It logs when each rebuild lands (the stored levels are the ones sent) with the balance before and after, and a snapshot
-- after 1 game hour, 1 day, 7 days and 30 days. The last station (of two or more) gets only an upkeep level of 10 instead,
-- which halves its upkeep. One game day after the first rebuild it rebuilds the first station again with
-- the same levels, to see what a rebuild that changes nothing costs. Test on a copy of a save. Log lines start with
-- "STATION_RETROFITS probe".

local stateVersion = 1

-- Entities selected in the test save "WR26A Giga-Tv3 1915 1101-1134 more mods" (docs/design/findings.md, test results):
-- Upper Peterlee Station (rail), Lower Peterlee Station (tram), Peterlee Refinery N Port (harbour). Each may be a
-- construction, a station or a station group; ids that resolve to no base station are skipped.
local preferred : {integer} = { 175556, 44612, 78577 }
local maxTargets = 3
local probeLevel = 5
local upkeepOnlyLevel = 10

-- Clock units: a game day at calendar speed 1x is 4,000 (from Depot Retrofits).
local dayClock = 4000
local watchOffsets : {number} = { 200, dayClock, 7 * dayClock, 30 * dayClock }
local watchTags : {string} = { "1h", "1d", "7d", "30d" }

local record Target
	kind : string
	construction : integer
	stations : {integer}
end

local record Send
	target : integer
	tag : string
	at : number
	levels : {string : integer}
end

local record Pending
	target : integer
	tag : string
	levels : {string : integer}
	sentAt : number
	balanceBefore : number
end

local record Watch
	target : integer
	tag : string
	at : number
end

local record ProbeState
	version : integer
	picked : boolean
	targets : {Target}
	sends : {Send}
	pending : {Pending}
	watches : {Watch}
end

local say = function(text : string)
	if log ~= nil then
		log.message("STATION_RETROFITS probe " .. text)
	else
		print("STATION_RETROFITS probe " .. text)
	end
end

local coreLoaded, coreModule = pcall(ug_require, "station_retrofits_1::/core.tl")
local core = coreLoaded and (coreModule as StationRetrofitsCore) or nil

local exists = function(entity : integer) : boolean
	if entity == nil or entity < 0 then return false end
	local ok, result = pcall(api.engine.entityExists, entity as Engine.Entity)
	return ok and result == true
end

local now = function() : number
	local gameTime : Engine.Component.GameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	return gameTime.gameTime
end

local balance = function() : number
	local ok, value = pcall(api.engine.util.finance.getPlayersBalance, api.engine.util.getPlayer())
	return ok and tonumber(value) or nil
end

local getConstruction = function(entity : integer) : Engine.Component.Construction
	if not exists(entity) then return nil end
	return api.engine.getComponent(entity as Engine.Entity, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
end

-- The construction's params as a plain table (the replace proposal takes a full set).
local constructionParams = function(con : Engine.Component.Construction) : {string : any}
	local source : {string : any} = nil
	if con.params_native ~= nil then
		local ok, asTable = pcall(con.params_native.asTable, con.params_native)
		if ok and asTable ~= nil then source = asTable as {string : any} end
	end
	if source == nil then source = (con.params as table) as {string : any} end
	local params : {string : any} = {}
	for key, value in pairs(source or {}) do params[key] = value end
	return params
end

local stationsOf = function(con : Engine.Component.Construction) : {integer}
	local list : {integer} = {}
	for _, s in ipairs(con.stations or {}) do list[#list + 1] = s as integer end
	return list
end

local constructionForStation = function(station : integer) : integer
	if not exists(station) then return nil end
	local ok, c = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, station as Engine.Entity)
	if ok and c ~= nil and (c as integer) >= 0 then return c as integer end
	return nil
end

-- A construction, station or station group id to the construction that builds it.
local resolveEntity = function(entity : integer) : integer
	if getConstruction(entity) ~= nil then return entity end
	if not exists(entity) then return nil end
	if api.engine.getComponent(entity as Engine.Entity, api.type.ComponentType.STATION) ~= nil then
		return constructionForStation(entity)
	end
	local group = api.engine.getComponent(entity as Engine.Entity, api.type.ComponentType.STATION_GROUP) as Engine.Component.StationGroup
	if group ~= nil and group.stations ~= nil and group.stations[1] ~= nil then
		return constructionForStation(group.stations[1] as integer)
	end
	return nil
end

-- The target's construction now: its id, else the construction of one of its stations (a rebuild may give new ids).
local currentConstruction = function(target : Target) : integer, string
	if getConstruction(target.construction) ~= nil then return target.construction, "id" end
	for _, s in ipairs(target.stations or {}) do
		local c = constructionForStation(s)
		if c ~= nil then return c, "station" end
	end
	return nil, "lost"
end

local nameOf = function(entity : integer) : string
	local ok, name = pcall(function() : string
		local n = api.engine.getComponent(entity as Engine.Entity, api.type.ComponentType.NAME) as Engine.Component.Name
		return n and n.name or nil
	end)
	return ok and name or nil
end

local snapshot = function(target : Target, tag : string) : string
	local c, how = currentConstruction(target)
	local con = getConstruction(c)
	if con == nil then return "tag=" .. tag .. " kind=" .. target.kind .. " construction=nil resolvedBy=" .. how end
	local parts : {string} = {
		"tag=" .. tag, "kind=" .. target.kind, "construction=" .. tostring(c), "resolvedBy=" .. how,
		"levels=" .. core.describe(core.read(constructionParams(con))), "fileName=" .. tostring(con.fileName),
	}
	-- The construction's own position (where the map shows its marker), to set beside the catchment circles' centres.
	local okOrigin, origin = pcall(function() : string
		local p = con.transf:getTransl()
		return string.format("%.1f/%.1f", p.x, p.y)
	end)
	parts[#parts + 1] = "origin=" .. tostring(okOrigin and origin or ("error " .. tostring(origin)))
	local stations = stationsOf(con)
	parts[#parts + 1] = "stations=" .. table.concat((function() : {string}
		local s : {string} = {}
		for _, e in ipairs(stations) do s[#s + 1] = tostring(e) end
		return s
	end)(), ",")
	local subs : {string} = {}
	for _, sub in ipairs(con.subconstructions or {}) do subs[#subs + 1] = tostring(sub) end
	parts[#parts + 1] = "subconstructions=" .. table.concat(subs, ",")
	for i, s in ipairs(stations) do
		local entity = s as Engine.Entity
		local prefix = "s" .. tostring(i) .. "."
		local okUsage, usage = pcall(api.engine.util.station.calculateStationUsage, entity)
		if okUsage and usage ~= nil then
			parts[#parts + 1] = prefix .. "used=" .. tostring(usage.totalUsed) .. " " .. prefix .. "pool=" .. tostring(usage.poolCapacity)
				.. " " .. prefix .. "terminals=" .. tostring(usage.terminalCapacity) .. " " .. prefix .. "overflow=" .. tostring(usage.overflow)
		else
			parts[#parts + 1] = prefix .. "usageError=" .. tostring(usage)
		end
		-- The circles the game keeps for the station, and the buildings in its reach (the catchment cache may update a little
		-- after a rebuild).
		local okRadii, radii = pcall(function() : string
			local comp = api.engine.getComponent(entity, api.type.ComponentType.STATION) as Station
			if comp == nil or comp.catchmentAreas == nil then return "nil" end
			local list : {string} = {}
			-- "x/y:radius" per circle, in map metres, so a map of the save can draw them.
			for _, area in ipairs(comp.catchmentAreas) do
				local p = area.position
				list[#list + 1] = p and string.format("%.1f/%.1f:%.1f", p.x, p.y, area.radius) or string.format("?:%.1f", area.radius)
			end
			return table.concat(list, ",")
		end)
		parts[#parts + 1] = prefix .. "radii=" .. tostring(okRadii and radii or ("error " .. tostring(radii)))
		local okPassengers, passengers = pcall(api.engine.system.catchmentAreaSystem.getStationCatchables, entity, false)
		local okCargo, cargo = pcall(api.engine.system.catchmentAreaSystem.getStationCatchables, entity, true)
		parts[#parts + 1] = prefix .. "catchablesPassenger=" .. tostring(okPassengers and passengers and #passengers or ("error " .. tostring(passengers)))
			.. " " .. prefix .. "catchablesCargo=" .. tostring(okCargo and cargo and #cargo or ("error " .. tostring(cargo)))
		local okStops, stops = pcall(api.engine.system.lineSystem.getLineStopsForStation, entity)
		parts[#parts + 1] = prefix .. "lineStops=" .. tostring(okStops and stops and #stops or ("error " .. tostring(stops)))
		local okGroup, group = pcall(api.engine.system.stationGroupSystem.getStationGroup, entity)
		if okGroup and group ~= nil then
			parts[#parts + 1] = prefix .. "group=" .. tostring(group) .. " " .. prefix .. "name=\"" .. tostring(nameOf(group as integer)) .. "\""
		end
		local emitter = api.engine.getComponent(entity, api.type.ComponentType.EMISSION_EMITTER) as Engine.Component.EmissionEmitter
		if emitter ~= nil then
			parts[#parts + 1] = prefix .. "noisePower=" .. tostring(emitter.noisePower) .. " " .. prefix .. "pollutionPower=" .. tostring(emitter.pollutionPower)
		end
		local okCharged, charged = pcall(api.engine.util.maintenance.calcMaintenanceForSubconstruction, entity)
		parts[#parts + 1] = prefix .. "upkeepCharged=" .. tostring(okCharged and charged or ("error " .. tostring(charged)))
	end
	local okCost, cost = pcall(function() : number
		local m = api.engine.getComponent(c as Engine.Entity, api.type.ComponentType.MAINTENANCE_COST) as Engine.Component.MaintenanceCost
		return m and m.maintenanceCost or nil
	end)
	parts[#parts + 1] = "upkeepScript=" .. tostring(okCost and cost or ("error " .. tostring(cost)))
	parts[#parts + 1] = "balance=" .. tostring(balance())
	return table.concat(parts, " ")
end

local addTarget = function(retrofit : ProbeState, c : integer, source : string) : boolean
	local con = getConstruction(c)
	if con == nil then return false end
	local kind = core.kindOf(con.fileName as string, core.constructionKinds)
	if kind == nil then return false end
	for _, t in ipairs(retrofit.targets) do
		if t.kind == kind or t.construction == c then return false end
	end
	local target : Target = { kind = kind, construction = c, stations = stationsOf(con) }
	retrofit.targets[#retrofit.targets + 1] = target
	say("picked source=" .. source .. " " .. snapshot(target, "before"))
	return true
end

local levelsAll = function(level : integer) : {string : integer}
	local values : {string : integer} = {}
	for _, tree in ipairs(core.trees) do values[tree] = level end
	return values
end

local pick = function(retrofit : ProbeState, t : number)
	for _, entity in ipairs(preferred) do
		if #retrofit.targets >= maxTargets then break end
		local c = resolveEntity(entity)
		if c == nil or not addTarget(retrofit, c, "preferred entity=" .. tostring(entity)) then
			say("preferredSkipped entity=" .. tostring(entity) .. " construction=" .. tostring(c))
		end
	end
	if #retrofit.targets < maxTargets then
		local found : {integer} = {}
		api.engine.forEachEntityWithComponent(function(entity : Engine.Entity)
			found[#found + 1] = entity as integer
		end, api.type.ComponentType.CONSTRUCTION)
		for _, c in ipairs(found) do
			if #retrofit.targets >= maxTargets then break end
			addTarget(retrofit, c, "scan")
		end
	end
	for i = 1, #retrofit.targets do
		if i == #retrofit.targets and i > 1 then
			local values = levelsAll(0)
			values.upkeep = upkeepOnlyLevel
			retrofit.sends[#retrofit.sends + 1] = { target = i, tag = "upkeepOnly", at = t, levels = values }
		else
			retrofit.sends[#retrofit.sends + 1] = { target = i, tag = "level" .. tostring(probeLevel), at = t, levels = levelsAll(probeLevel) }
		end
	end
	if #retrofit.targets > 0 then
		retrofit.sends[#retrofit.sends + 1] = { target = 1, tag = "noChange", at = t + dayClock, levels = retrofit.sends[1].levels }
	end
	say("pickDone targets=" .. tostring(#retrofit.targets) .. " sends=" .. tostring(#retrofit.sends))
end

-- Sends the rebuild; the game builds it or refuses it.
local sendRebuild = function(retrofit : ProbeState, send : Send, t : number)
	local target = retrofit.targets[send.target]
	local c, how = currentConstruction(target)
	local con = getConstruction(c)
	if con == nil then
		say("send tag=" .. send.tag .. " kind=" .. target.kind .. " refused=noConstruction resolvedBy=" .. how)
		return
	end
	target.construction = c
	local params = constructionParams(con)
	core.store(params, send.levels)
	local before = balance()
	local ok, proposal = pcall(api.engine.util.proposal.createProposalReplaceConstruction, c as Engine.Entity, params)
	if not ok or proposal == nil then
		say("send tag=" .. send.tag .. " kind=" .. target.kind .. " refused=noProposal error=" .. tostring(proposal))
		return
	end
	local sent, err = pcall(function() : string
		api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, nil, false, false, false))
		return nil
	end)
	if not sent then
		say("send tag=" .. send.tag .. " kind=" .. target.kind .. " refused=sendError error=" .. tostring(err))
		return
	end
	say("sent tag=" .. send.tag .. " kind=" .. target.kind .. " construction=" .. tostring(c) .. " levels=" .. core.describe(send.levels)
		.. " balance=" .. tostring(before))
	retrofit.pending[#retrofit.pending + 1] = { target = send.target, tag = send.tag, levels = send.levels, sentAt = t, balanceBefore = before }
end

-- A rebuild has landed when the stored levels are the ones sent; a noChange rebuild cannot be told apart that way, so it
-- counts as landed on the next update. Gives up after a game day.
local checkPending = function(retrofit : ProbeState, t : number) : boolean
	local changed = false
	local left : {Pending} = {}
	for _, p in ipairs(retrofit.pending) do
		local target = retrofit.targets[p.target]
		local c, how = currentConstruction(target)
		local con = getConstruction(c)
		local stored = con and core.read(constructionParams(con)) or nil
		local landed = stored ~= nil and core.describe(stored) == core.describe(p.levels) and (p.tag ~= "noChange" or t > p.sentAt)
		if landed then
			local after = balance()
			say("landed tag=" .. p.tag .. " kind=" .. target.kind .. " construction=" .. tostring(c) .. " was=" .. tostring(target.construction)
				.. " resolvedBy=" .. how .. " balanceBefore=" .. tostring(p.balanceBefore) .. " balanceAfter=" .. tostring(after)
				.. " delta=" .. tostring(after and p.balanceBefore and (after - p.balanceBefore)) .. " clock=" .. tostring(t - p.sentAt))
			say("after tag=" .. p.tag .. " " .. snapshot(target, p.tag .. ".landed"))
			target.construction = c
			target.stations = stationsOf(con)
			for i, offset in ipairs(watchOffsets) do
				retrofit.watches[#retrofit.watches + 1] = { target = p.target, tag = p.tag .. "." .. watchTags[i], at = t + offset }
			end
			changed = true
		elseif t - p.sentAt > dayClock then
			say("notLanded tag=" .. p.tag .. " kind=" .. target.kind .. " construction=" .. tostring(c) .. " resolvedBy=" .. how
				.. " stored=" .. (stored and core.describe(stored) or "nil"))
			changed = true
		else
			left[#left + 1] = p
		end
	end
	retrofit.pending = left
	return changed
end

local checkWatches = function(retrofit : ProbeState, t : number) : boolean
	local changed = false
	local left : {Watch} = {}
	for _, w in ipairs(retrofit.watches) do
		if t >= w.at then
			say("watch " .. snapshot(retrofit.targets[w.target], w.tag))
			changed = true
		else
			left[#left + 1] = w
		end
	end
	retrofit.watches = left
	return changed
end

local loadState = function(state : GameScriptState<ProbeState>) : ProbeState
	local retrofit = state:get() or {}
	if retrofit.version ~= stateVersion then
		retrofit = { version = stateVersion, picked = false, targets = {}, sends = {}, pending = {}, watches = {} }
		state:set(retrofit)
	end
	return retrofit
end

-- Module variables do not persist across saves; this only keeps the load line to one per session.
local loadLogged = false

local probeScript : GameScript<ProbeState> = {
	update = function(_userParams : table, state : GameScriptState<ProbeState>, _dt : number) : any
		if core == nil then
			if not loadLogged then
				loadLogged = true
				say("disabled coreError=" .. tostring(coreModule))
			end
			return
		end
		local retrofit = loadState(state)
		local t = now()
		if not loadLogged then
			loadLogged = true
			say("loaded t=" .. tostring(t) .. " picked=" .. tostring(retrofit.picked) .. " targets=" .. tostring(#retrofit.targets)
				.. " sends=" .. tostring(#retrofit.sends) .. " pending=" .. tostring(#retrofit.pending) .. " watches=" .. tostring(#retrofit.watches))
		end
		if not retrofit.picked then
			retrofit.picked = true
			state:set(retrofit)
			local ok, err = pcall(function() : string pick(retrofit, t) return nil end)
			if not ok then say("pickError error=" .. tostring(err)) end
			state:set(retrofit)
			return
		end
		-- One rebuild per update; the queue is saved first, so a send that fails is not retried.
		for i, send in ipairs(retrofit.sends) do
			if t >= send.at then
				table.remove(retrofit.sends, i)
				state:set(retrofit)
				local ok, err = pcall(function() : string sendRebuild(retrofit, send, t) return nil end)
				if not ok then say("sendError tag=" .. send.tag .. " error=" .. tostring(err)) end
				state:set(retrofit)
				break
			end
		end
		local okPending, pendingChanged = pcall(checkPending, retrofit, t)
		if not okPending then
			say("pendingError error=" .. tostring(pendingChanged))
			retrofit.pending = {}
			state:set(retrofit)
		elseif pendingChanged then
			state:set(retrofit)
		end
		local okWatch, watchChanged = pcall(checkWatches, retrofit, t)
		if not okWatch then
			say("watchError error=" .. tostring(watchChanged))
			retrofit.watches = {}
			state:set(retrofit)
		elseif watchChanged then
			state:set(retrofit)
		end
	end,
}

return probeScript
