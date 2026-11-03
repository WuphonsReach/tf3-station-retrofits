-- The game script: buying a level. The Retrofit card in the station window (retrofit_card.script.tl) sends a buy event;
-- this script checks it (the construction is a base station with the level params, the level the card saw is still the
-- stored one, below 15, within the company rank, enough money; a rank that cannot be read refuses the buy) and rebuilds the
-- station with the new level. The game decides whether the rebuild is built: one it refuses (something built around the
-- station since is in its way) never lands. Once the rebuild has landed (the stored level is at least the one bought) it
-- books the price as station construction under the station's carrier; a rebuild that never lands costs nothing. It logs
-- each buy and its outcome; at logLevel "full" (settings.tl) also the station before the buy and when it lands. Log lines
-- start with "STATION_RETROFITS". A buy it refuses is kept in its state for the card to read, so the card can tell a buy
-- refused here (short of money) from a rebuild the game refused.
--
-- Copied from Depot Retrofits' retrofits.script.tl (MIT, same author). The probe that levelled stations by itself (probe 1)
-- is in git history; its results are in docs/design/findings.md.

local stateVersion = 1

-- Copied in retrofit_card.script.tl; keep the copies equal.
local buyEvent = "stationRetrofitsBuy"

-- Clock units: a game day at calendar speed 1x is 4,000.
local dayClock = 4000
-- A buy is charged when its rebuild lands: the stored level in its tree is at least the one bought, so a later buy landing
-- first also counts. A new buy for the same station before then replaces it, uncharged: the card sends one buy at a time per
-- station and says after a few seconds that the game refused it, so a buy sent again after clearing the way must go
-- through. Both rebuild to the same level from the same stored levels, so at most one is charged. A rebuild that has not
-- landed after a game day, or after 30 real seconds, is given up, uncharged: the game refused it. The real seconds count
-- while the game is paused, when game time stands still. Rail and road stations land within a second, harbours in 2 to 3
-- (docs/design/findings.md); Depot Retrofits' 3 seconds would have let a harbour keep a level uncharged, and waiting longer
-- is safe, as only our own rebuild raises a stored level. The pending buy keeps only its tree and level, as in Depot
-- Retrofits: pending buys that kept all the levels were found holding the levels from before the buy in a run of quick buys.
local buyPendingClock = dayClock
local buyPendingSeconds = 30

local record Buy
	construction : Engine.Entity
	tree : string
	from : integer
	click : integer -- the card's number for the click that sent it; nil from a card without one
end

-- A buy refused here, kept for the card (retrofit_card.script.tl), which reads it from this script's state: the card only
-- sees that the level did not go up, and the balance can fall between its last read and the check here (Depot Retrofits'
-- 2026-11-02 session: hundreds of thousands at once, back within seconds).
local record Refusal
	construction : Engine.Entity
	click : integer
	reason : string -- the reason's first word: "noMoney", "rank", "stale" and so on
end
-- One per station, the newest last; the card looks only for the click it is waiting on.
local maxRefusals = 16

local record Pending
	construction : Engine.Entity
	tree : string
	level : integer
	untilT : number
	sentAt : number -- os.time() when the rebuild was sent; nil where os.time is not available
	price : integer -- charged when the rebuild lands
	carrier : string -- the finance row's carrier, "ROAD", "TRAM", "RAIL" or "WATER"
	label : string
end

local record RetrofitState
	version : integer
	buys : {Buy}
	pending : {Pending}
	refusals : {Refusal}
end

local say = function(text : string)
	if log ~= nil then
		log.message("STATION_RETROFITS " .. text)
	else
		print("STATION_RETROFITS " .. text)
	end
end

local coreLoaded, coreModule = pcall(ug_require, "station_retrofits_1::/core.tl")
local core = coreLoaded and (coreModule as StationRetrofitsCore) or nil
-- Without it update does nothing (no buy is taken), so the reason goes to the log.
if not coreLoaded then say("gameScript core unavailable error=" .. tostring(coreModule)) end

-- settings.tl's logLevel: "full" adds the snapshots and the queued lines. Guarded: without the file the log stays at
-- "summary".
local settingsLoaded, settingsModule = pcall(ug_require, "station_retrofits_1::/settings.tl")
local logFull = settingsLoaded and type(settingsModule) == "table" and (settingsModule as {string:any}).logLevel == "full"

-- Without it the rank is unknown and every buy is refused.
local rankLoaded, rankModule = pcall(ug_require, "station_retrofits_1::/company_rank.tl")
local companyRank = rankLoaded and (rankModule as StationRetrofitsRank) or nil

-- Module variables do not persist across saves; this only keeps the load line to one per session.
local loadLogged = false

local exists = function(entity : Engine.Entity) : boolean
	if entity == nil then return false end
	local ok, result = pcall(api.engine.entityExists, entity)
	return ok and result == true
end

local now = function() : number
	local gameTime : Engine.Component.GameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	return gameTime.gameTime
end

-- Real time in whole seconds, or nil where os.time is not available.
local clockNow = function() : number
	local ok, seconds = pcall(os.time)
	return ok and type(seconds) == "number" and seconds or nil
end

local balanceOf = function() : number
	local ok, value = pcall(api.engine.util.finance.getPlayersBalance, api.engine.util.getPlayer())
	return ok and tonumber(value) or nil
end

-- The claimed rank (what the company window shows as reached) and the earned rank; nil when unknown.
local readRank = function() : integer, integer, string
	if companyRank == nil then return nil, nil, "unknown moduleError=" .. tostring(rankModule) end
	return companyRank.read(api.engine.util.getPlayer())
end

local describeRank = function() : string
	local level, potential, source = readRank()
	return "rank=" .. tostring(level) .. " earnedRank=" .. tostring(potential) .. " rankSource=" .. source
end

-- The construction's params as a plain table (the replace proposal takes a full set).
local constructionParams = function(construction : Engine.Component.Construction) : {string:any}
	local source : {string:any} = nil
	if construction.params_native ~= nil then
		local ok, asTable = pcall(construction.params_native.asTable, construction.params_native)
		if ok and asTable ~= nil then source = asTable as {string:any} end
	end
	if source == nil then source = (construction.params as table) as {string:any} end
	local params : {string:any} = {}
	for key, value in pairs(source or {}) do params[key] = value end
	return params
end

local getConstruction = function(construction : Engine.Entity) : Engine.Component.Construction
	if not exists(construction) then return nil end
	return api.engine.getComponent(construction, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
end

local storedLevels = function(construction : Engine.Entity) : {string : integer}
	local con = getConstruction(construction)
	return con and core.read(constructionParams(con)) or nil
end

-- true when the construction's definition carries the level params (mod.script.tl's loadConstruction modifier); nil when the
-- definition cannot be read. A rebuild without them would drop the levels.
local hasLevelParams = function(con : Engine.Component.Construction) : boolean
	local ok, found = pcall(function() : boolean
		local key = core.paramKeys[core.trees[1]]
		for _, p in ipairs(api.res.constructionRep.findAndGet(con.fileName).params) do
			if p.key == key then return true end
		end
		return false
	end)
	if not ok then return nil end
	return found
end

-- What the game charges for the station each year, as the window's upkeep footer shows it: the first station's
-- subconstruction holds the whole construction's upkeep (probe 2: it matched the footer).
local chargedUpkeepOf = function(con : Engine.Component.Construction) : number
	local first = con.stations and con.stations[1]
	if first == nil then return nil end
	local ok, value = pcall(api.engine.util.maintenance.calcMaintenanceForSubconstruction, first)
	return ok and tonumber(value) or nil
end

-- "levels=… radius=… noisePower=… pollutionPower=… upkeepCharged=… upkeepScript=…" for a log line: the largest catchment
-- circle and the emitters summed over the construction's stations.
local describeStation = function(construction : Engine.Entity) : string
	local con = getConstruction(construction)
	if con == nil then return "construction=nil" end
	local radius : number = nil
	local noise, pollution = 0.0, 0.0
	for _, station in ipairs(con.stations or {}) do
		local s = api.engine.getComponent(station, api.type.ComponentType.STATION) as Station
		for _, area in ipairs(s and s.catchmentAreas or {}) do
			if radius == nil or area.radius > radius then radius = area.radius end
		end
		local emitter = api.engine.getComponent(station, api.type.ComponentType.EMISSION_EMITTER) as Engine.Component.EmissionEmitter
		if emitter ~= nil then
			noise = noise + (emitter.noisePower or 0)
			pollution = pollution + (emitter.pollutionPower or 0)
		end
	end
	local okCost, script = pcall(function() : number
		local m = api.engine.getComponent(construction, api.type.ComponentType.MAINTENANCE_COST) as Engine.Component.MaintenanceCost
		return m and m.maintenanceCost or nil
	end)
	return "levels=" .. core.describe(core.read(constructionParams(con))) .. " radius=" .. string.format("%.1f", radius or -1)
		.. " noisePower=" .. tostring(noise) .. " pollutionPower=" .. tostring(pollution)
		.. " upkeepCharged=" .. tostring(chargedUpkeepOf(con)) .. " upkeepScript=" .. tostring(okCost and script or nil)
end

-- Sends the rebuild; the game builds it or refuses it. The second result is the reason it was not sent.
local sendRebuild = function(construction : Engine.Entity, values : {string : integer}) : boolean, string
	local con = getConstruction(construction)
	if con == nil then return false, "noConstruction" end
	local params = constructionParams(con)
	core.store(params, values)
	local ok, proposal = pcall(api.engine.util.proposal.createProposalReplaceConstruction, construction, params)
	if not ok or proposal == nil then return false, "noProposal error=" .. tostring(proposal) end
	local sent, err = pcall(function() : string
		api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, nil, false, false, false))
		return nil
	end)
	if not sent then return false, "sendError error=" .. tostring(err) end
	return true, nil
end

-- The finance row's carrier and where it came from: rail stations RAIL, harbours WATER, road stations ROAD, or TRAM when
-- they have tram tracks (the tramTrack param above 1 adds the tram modes, street/modular_street_station/modules.script.lua).
local carrierFor = function(kind : string, params : {string : any}) : string, string
	if kind == "rail" then return "RAIL", "kind" end
	if kind == "harbour" then return "WATER", "kind" end
	local tramTrack = tonumber(params.tramTrack)
	if tramTrack ~= nil and tramTrack > 1 then return "TRAM", "tramTrack=" .. tostring(tramTrack) end
	return "ROAD", "tramTrack=" .. tostring(params.tramTrack)
end

local journalCarrier = function(name : string) : JournalEntry.Carrier
	local c = api.type.JournalEntry.Carrier
	local byName : {string : JournalEntry.Carrier} = { ROAD = c.ROAD, RAIL = c.RAIL, TRAM = c.TRAM, WATER = c.WATER }
	return byName[name] or c.ROAD
end

-- Books a level's price as station construction (JournalEntry.Construction.STATION, scripts/journal.d.tl).
local bookPrice = function(amount : integer, carrier : string) : string
	local entry = api.type.JournalEntry.new()
	entry.amount = -amount
	entry.time = -1 -- the engine fills in the time
	entry.category.type = api.type.JournalEntry.Type.CONSTRUCTION
	entry.category.construction = api.type.JournalEntry.Construction.STATION
	entry.category.carrier = journalCarrier(carrier)
	api.cmd.sendCommand(api.cmd.makeJournalBookAssetCmd(api.engine.util.getPlayer(), entry, api.type.Vec3f.new(0, 0, 0)))
	return nil
end

local landed = function(p : Pending, stored : {string : integer}) : boolean
	return stored ~= nil and (stored[p.tree] or 0) >= p.level
end

local expired = function(p : Pending, t : number, clock : number) : boolean
	return t >= p.untilT or (clock ~= nil and p.sentAt ~= nil and clock >= p.sentAt + buyPendingSeconds)
end

local stillPending = function(p : Pending, t : number) : boolean
	return not expired(p, t, clockNow()) and not landed(p, storedLevels(p.construction))
end

-- Drops the station's buy that has not landed yet, uncharged, as a new buy for it replaces it.
local replacePending = function(retrofit : RetrofitState, construction : Engine.Entity, t : number)
	local kept : {Pending} = {}
	for _, p in ipairs(retrofit.pending or {}) do
		if p.construction == construction and stillPending(p, t) then
			say("buy notLanded construction=" .. tostring(p.construction) .. " bought=" .. tostring(p.label) .. " price=" .. tostring(p.price)
				.. " reason=replaced charged=false")
		else
			kept[#kept + 1] = p
		end
	end
	retrofit.pending = kept
end

local recordRefusal = function(retrofit : RetrofitState, buy : Buy, reason : string)
	local kept : {Refusal} = {}
	for _, r in ipairs(retrofit.refusals or {}) do
		if r.construction ~= buy.construction then kept[#kept + 1] = r end
	end
	kept[#kept + 1] = { construction = buy.construction, click = buy.click, reason = reason:match("^%S+") or reason }
	while #kept > maxRefusals do table.remove(kept, 1) end
	retrofit.refusals = kept
end

-- Returns the reason a buy was refused, or nil when it was carried out.
local processBuy = function(retrofit : RetrofitState, buy : Buy, t : number) : string
	if core.paramKeys[buy.tree] == nil then return "unknownTree" end
	local con = getConstruction(buy.construction)
	if con == nil then return "noConstruction" end
	local kind = core.kindOf(con.fileName, core.constructionKinds)
	if kind == nil then return "notStation fileName=" .. tostring(con.fileName) end
	if hasLevelParams(con) == false then return "noLevelParams fileName=" .. tostring(con.fileName) end
	local params = constructionParams(con)
	local from = core.read(params)
	if from[buy.tree] ~= buy.from then return "stale stored=" .. tostring(from[buy.tree]) end
	if buy.from >= core.maxLevel then return "maxLevel" end
	local rank, _, rankSource = readRank()
	if rank == nil then return "rankUnknown rankSource=" .. rankSource end
	if buy.from + 1 > rank then return "rank rank=" .. tostring(rank) end
	local charged = chargedUpkeepOf(con)
	if charged == nil then return "noUpkeep" end
	local price = core.levelPrice(core.buildPrice(charged, from), buy.tree, buy.from + 1)
	local balance = balanceOf()
	if balance ~= nil and balance < price then return "noMoney balance=" .. tostring(balance) .. " price=" .. tostring(price) end

	local to = core.withLevel(from, buy.tree, buy.from + 1)
	local before = logFull and describeStation(buy.construction) or nil
	local ran, result = sendRebuild(buy.construction, to)
	if not ran then return "rebuild " .. result end
	local label = buy.tree .. tostring(buy.from + 1)
	local carrier, carrierSource = carrierFor(kind, params)
	say("buy sent construction=" .. tostring(buy.construction) .. " kind=" .. kind .. " tree=" .. buy.tree
		.. " level=" .. tostring(buy.from + 1) .. " price=" .. tostring(price) .. " balanceBefore=" .. tostring(balance)
		.. " rank=" .. tostring(rank) .. " rankSource=" .. rankSource .. " carrier=" .. carrier .. " carrierSource=" .. carrierSource
		.. " from=" .. core.describe(from) .. " to=" .. core.describe(to) .. (before ~= nil and (" before " .. before) or ""))
	replacePending(retrofit, buy.construction, t)
	table.insert(retrofit.pending, { construction = buy.construction, tree = buy.tree, level = buy.from + 1,
		untilT = t + buyPendingClock, sentAt = clockNow(), price = price, carrier = carrier, label = label })
	return nil
end

-- Charges each buy whose rebuild has landed and gives up the ones that did not land in time; true when the list changed.
local processPending = function(retrofit : RetrofitState, t : number) : boolean
	local changed = false
	local pending : {Pending} = {}
	local clock = clockNow()
	for _, p in ipairs(retrofit.pending or {}) do
		local stored = storedLevels(p.construction)
		if landed(p, stored) then
			changed = true
			local balance = balanceOf()
			local okCharge, chargeErr = pcall(bookPrice, p.price, p.carrier)
			say("buy charged construction=" .. tostring(p.construction) .. " bought=" .. tostring(p.label) .. " price=" .. tostring(p.price)
				.. " carrier=" .. tostring(p.carrier) .. " charged=" .. tostring(okCharge) .. " chargeError=" .. tostring(chargeErr)
				.. " balanceBefore=" .. tostring(balance) .. (logFull and (" after " .. describeStation(p.construction)) or ""))
		elseif expired(p, t, clock) then
			changed = true
			say("buy notLanded construction=" .. tostring(p.construction) .. " bought=" .. tostring(p.label) .. " price=" .. tostring(p.price)
				.. " seconds=" .. (clock ~= nil and p.sentAt ~= nil and tostring(clock - p.sentAt) or "?") .. " stored=" .. core.describe(stored)
				.. " expected=" .. tostring(p.tree) .. ">=" .. tostring(p.level) .. " charged=false")
		else
			pending[#pending + 1] = p
		end
	end
	retrofit.pending = pending
	return changed
end

local loadState = function(state : GameScriptState<RetrofitState>) : RetrofitState
	local retrofit = state:get() or {}
	if retrofit.version ~= stateVersion then
		if next(retrofit as table) ~= nil then
			say("oldStateReset version=" .. tostring(retrofit.version))
		end
		retrofit = { version = stateVersion }
		state:set(retrofit)
	end
	return retrofit
end

local retrofitScript : GameScript<RetrofitState> = {
	update = function(_userParams : table, state : GameScriptState<RetrofitState>, _dt : number) : any
		if core == nil then return end
		if not state:hasEventSubscriptions() then
			state:subscribeToEvent(buyEvent)
		end
		local retrofit = loadState(state)
		local t = now()
		if not loadLogged then
			loadLogged = true
			say("gameScript loaded t=" .. tostring(t) .. " " .. describeRank())
		end

		-- One buy per update; the queue is saved first, so a buy that fails is not retried.
		if retrofit.buys ~= nil and #retrofit.buys > 0 then
			local buy = table.remove(retrofit.buys, 1)
			state:set(retrofit)
			local ok, refused = pcall(processBuy, retrofit, buy, t)
			if not ok or refused ~= nil then
				local reason = ok and refused or ("error " .. tostring(refused))
				say("buy refused construction=" .. tostring(buy.construction) .. " tree=" .. tostring(buy.tree) .. " from=" .. tostring(buy.from)
					.. " reason=" .. reason .. " click=" .. tostring(buy.click))
				if buy.click ~= nil then recordRefusal(retrofit, buy, reason) end
			end
			state:set(retrofit)
		end
		local okPending, charged = pcall(processPending, retrofit, t)
		if not okPending then
			-- Dropped, so a failing charge is not retried (and possibly booked) on every update.
			say("buy pendingError error=" .. tostring(charged) .. " dropped=" .. tostring(retrofit.pending and #retrofit.pending))
			retrofit.pending = {}
			state:set(retrofit)
		elseif charged then
			state:set(retrofit)
		end
	end,
	-- Queued here and carried out in update: sendCommand cannot be called from handleEvent.
	handleEvent = function(_userParams : table, state : GameScriptState<RetrofitState>, src : string, id : string, name : string, param : any) : any
		if name ~= buyEvent then return end
		local p = (type(param) == "table" and param or {}) as {string : any}
		local buy : Buy = {
			construction = math.floor(tonumber(p.construction) or -1) as Engine.Entity,
			tree = tostring(p.tree),
			from = math.floor(tonumber(p.from) or -1),
			click = tonumber(p.click) and math.floor(tonumber(p.click)) or nil,
		}
		local retrofit = loadState(state)
		retrofit.buys = retrofit.buys or {}
		table.insert(retrofit.buys, buy)
		state:set(retrofit)
		if logFull then
			say("buy queued src=" .. tostring(src) .. " id=" .. tostring(id) .. " construction=" .. tostring(buy.construction)
				.. " tree=" .. buy.tree .. " from=" .. tostring(buy.from) .. " click=" .. tostring(buy.click) .. " queued=" .. tostring(#retrofit.buys))
		end
	end,
}

return retrofitScript
