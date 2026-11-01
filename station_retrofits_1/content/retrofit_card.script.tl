-- The Retrofit card in the station window: a react plugin for the base StationGroupEowExtensionPoint
-- (gui/entity_window/station_group/station_group_eow.script.tl), registered by retrofit_card.res.lua. The station window
-- (gui/entity_window/station_group/station_group.tl) draws plugin cards after its notifications and before the waiting halls.
-- A plugin leaves the base window as it is; setting entityWindowScript on the construction would stop it opening
-- (docs/design/findings.md).
--
-- One card per station group, with each wrapped construction in the group. Collapsed, it is a summary: per tree the level
-- boxes and what the levels do now. Expanded (the station window keeps one card open at a time), it shows per tree what the
-- next level would change, the upkeep after it and a button that buys it: the button sends a buy event to the game script
-- (retrofits.script.tl), which checks it, rebuilds the station and charges the price once the rebuild lands. Prices follow
-- core.tl from the upkeep the game charges for the station now. Log lines start with "STATION_RETROFITS".
--
-- The game calls the condition for every station window it draws and calls a recipe that is nil without asking
-- (gui/main/gui_react_util.tl, usePlugins), so the condition never throws and is false whenever the recipe is missing.

local record Entry
	construction : Engine.Entity
	kind : string
	levels : {string : integer}
	stations : integer
	circles : integer
	terminals : integer
	radius : number -- the largest catchment circle now; nil when the station has none
	baseRadius : number -- that circle without the levels; nil when unknown
	upkeep : number -- the upkeep the game charges now (the window's footer); nil when unreadable
	buildPrice : number -- nil when the upkeep is unreadable
	affordable : {string : boolean} -- per tree, whether the balance covers the next level; nil when unreadable
	refused : boolean -- true when the game did not rebuild the station for its last buy (see readRefused)
end

local record CardState
	entries : {Entry}
	rank : integer -- nil when unknown: then every level not bought is drawn as locked and none can be bought
	key : string -- every shown value as text; the card redraws when it changes
end

local record NextParam
	state : CardState
end

local record RetrofitCard
	conditionRetrofitCard : function(params : StationGroupEow.StationGroupWidgetPluginParams) : boolean
	RetrofitCardPlugin : Recipe<StationGroupEow.StationGroupWidgetPluginParams>
end

local say = function(text : string)
	if log ~= nil then
		log.message("STATION_RETROFITS " .. text)
	else
		print("STATION_RETROFITS " .. text)
	end
end

-- settings.tl's logLevel: "full" adds a line for each station window the card is drawn in. Guarded: without the file the log
-- stays at "summary".
local settingsLoaded, settingsModule = pcall(ug_require, "station_retrofits_1::/settings.tl")
local logFull = settingsLoaded and type(settingsModule) == "table" and (settingsModule as {string:any}).logLevel == "full"

-- Every load guarded: without one of these the station window opens without the Retrofit card, and the log says why.
local loadModule = function(path : string) : any
	local ok, result = pcall(ug_require, path)
	if not ok or result == nil then
		say("card loadFailed path=" .. path .. " error=" .. tostring(result))
		return nil
	end
	return result
end

local react = loadModule("::/gui/main/react.lua") as React
local builtin = loadModule("::/gui/main/builtin.lua") as Builtin
local engineReact = loadModule("::/gui/main/engine_react_util.tl") as EngineReactUtil
local contentCard = loadModule("::/gui/main/content_card.tl") as ContentCard
local stationEow = loadModule("::/gui/entity_window/station_group/station_group_eow.script.tl") as StationGroupEow
local core = loadModule("station_retrofits_1::/core.tl") as StationRetrofitsCore
-- Without it the rank is unknown and every level not bought is drawn as locked.
local companyRank = loadModule("station_retrofits_1::/company_rank.tl") as StationRetrofitsRank
-- Optional: without it each tree shows its level as text instead of a row of boxes.
local styleutil = loadModule("::/gui/main/styleutil.tl") as StyleUtil
local ready = react ~= nil and builtin ~= nil and engineReact ~= nil and contentCard ~= nil and stationEow ~= nil
	and stationEow.StationGroupEowExtensionPoint ~= nil and core ~= nil
say("card loaded ready=" .. tostring(ready) .. " companyRank=" .. tostring(companyRank ~= nil)
	.. " styleutil=" .. tostring(styleutil ~= nil))

-- The station window keeps the open card in its own state, by this key (content_card.makeContentCardsCollapsibleFunctions).
local cardKey = "stationRetrofitsCard"

local buyEventId = "StationRetrofits"
-- Copied in retrofits.script.tl; keep the copies equal.
local buyEvent = "stationRetrofitsBuy"

-- Stock icons, as Depot Retrofits uses them: the line manager's standard-priority dot for the catchment circle, the vehicle
-- window's pollution and noise (gui/entity_window/vehicle/vehicle.tl), the upkeep footer's symbol
-- (gui/entity_window/entity_window_util.tl) and the shopping cart of the vehicle store's buy button
-- (gui/line_vehicle_mgmt/vehicle_store_window.tl).
local upkeepIcon = "::/gui/entity_window/icons/symbol_dollar_gear.tga"
local buyIcon = "::/gui/line_vehicle_mgmt/icons/symbol_shopping_cart.tga"
local buyTooltip = "Buy the next level. The station is rebuilt with it."
local treeIcons : {string : string} = {
	catchment = "::/gui/entity_window/icons/prio_standard.tga",
	pollution = "::/gui/entity_window/icons/symbol_pollution.tga",
	noise = "::/gui/entity_window/icons/symbol_noise.tga",
	upkeep = upkeepIcon,
}

local kindNames : {string : string} = {
	rail = "Train station",
	street = "Road station",
	harbour = "Harbour",
}

-- What each tree does, for the row's tooltip. A plain tooltip does not wrap (Depot Retrofits' findings), so the lines are
-- broken by hand, one sentence a line.
local treeTooltips : {string : string} = {
	catchment = "Each level widens every catchment circle by 3%, at least 5 m.\n"
		.. "Shown: the largest circle, without and with the levels.",
	pollution = "Each level cuts the station's own pollution by 5%.\n"
		.. "Vehicle pollution is not affected.",
	noise = "Each level cuts the station's own noise by 5%.\n"
		.. "Vehicle noise is not affected.",
	upkeep = "Each level cuts the station's upkeep by 5%,\n"
		.. "including what the other levels add.",
}

-- The level boxes, as Depot Retrofits draws them (gui/layers/layer_terrain.tl's legend swatches): white for a level bought and
-- grey for one the company rank allows (the game's NeutralLightest and NeutralMedium, gui/main/default_colors.gres.lua);
-- above the rank a grey just lighter than the card, so those boxes recede.
local boxColors : {string : {number}} = {
	bought = { 1, 1, 1, 1 },
	open = { 0.502, 0.502, 0.502, 1 },
	locked = { 0.251, 0.251, 0.251, 1 },
}
local drawnStyles : {string : StyleSheet} = nil

local maxShownLines = 60
local shownLines = 0
local shownKeys : {string : boolean} = {}

local round = function(x : number) : integer
	return math.floor(x + 0.5)
end

local grouped = function(amount : number) : string
	local digits = tostring(round(amount))
	local sign = ""
	if digits:sub(1, 1) == "-" then sign, digits = "-", digits:sub(2) end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local money = function(amount : number) : string
	local digits = grouped(amount)
	if digits:sub(1, 1) == "-" then return "-$" .. digits:sub(2) end
	return "$" .. digits
end

local perYear = function(amount : number) : string
	return money(amount) .. "/" .. _("Year")
end

-- A buy is tried, not checked first, as in Depot Retrofits: the click sends it, and the game builds the rebuild or refuses
-- it (when something built around the station since is in its way). The card remembers the levels it showed at the click;
-- when they have not changed about a second later, the game refused it (nothing is charged then), and the card says so
-- until a level lands. A click while it shows keeps the warning up, so a retry the game refuses again does not make it
-- blink; a buy sent again replaces the refused one in the game script. Kept per construction for the session, so the warning
-- is still there when the window is opened again. Depot Retrofits also shows what is in the way, with the game's proposal
-- viewer in the window's action area; the station window gives its cards no action area (setActionFn), so the card only
-- says it.
local record Try
	levels : string -- core.describe of the levels the card showed at the click
	at : number -- clockNow() at the click
	step : integer -- stepCount at the click
end
local tries : {Engine.Entity : Try} = {}
local refused : {Engine.Entity : string} = {} -- the levels when the buy was found refused; cleared by a new level
-- One to two seconds: two ticks of os.time, as the game API has no finer clock. One tick could come just after the click,
-- and the card's steps are no measure of time (Depot Retrofits' findings: at the fastest speed 45 steps passed before a
-- rebuild that landed in the same second). The step count is only for where os.time is not available.
local refusedAfterSeconds = 2
local refusedAfterSteps = 120
local stepCount = 0
-- Real time in whole seconds. Not os.clock: that is the process's processor time, summed over the game's threads.
local clockNow = function() : number, boolean
	local ok, seconds = pcall(os.time)
	if ok and type(seconds) == "number" then return seconds, true end
	return stepCount, false
end

-- Whether the construction's last buy was refused by the game: the levels did not change within the wait after the click.
-- Called once per construction on each of the card's steps.
local readRefused = function(construction : Engine.Entity, current : string) : boolean
	stepCount = stepCount + 1
	local try = tries[construction]
	if try ~= nil then
		local now, isClock = clockNow()
		if try.levels ~= current then
			tries[construction] = nil
		elseif (isClock and now - try.at >= refusedAfterSeconds) or (not isClock and stepCount - try.step >= refusedAfterSteps) then
			tries[construction] = nil
			refused[construction] = current
			say("card notRebuilt construction=" .. tostring(construction) .. " levels=" .. current
				.. " waited=" .. tostring(now - try.at) .. " steps=" .. tostring(stepCount - try.step) .. " clock=" .. tostring(isClock))
		end
	end
	if refused[construction] ~= nil and refused[construction] ~= current then refused[construction] = nil end
	return refused[construction] ~= nil
end

local constructionParams = function(construction : Engine.Component.Construction) : {string:any}
	if construction.params_native ~= nil then
		local ok, asTable = pcall(construction.params_native.asTable, construction.params_native)
		if ok and asTable ~= nil then return asTable as {string:any} end
	end
	return construction.params as {string:any}
end

-- The wrapped constructions of a station group's stations, each once, in the group's order, with their levels. A kerbside
-- stop has no construction (-1), and a station of another kind or mod is not wrapped; both are left out. Cheap enough for the
-- condition, which runs on every station window.
local findEntries = function(group : Engine.Entity) : {Entry}
	local entries : {Entry} = {}
	local component = api.engine.getComponent(group, api.type.ComponentType.STATION_GROUP) as Engine.Component.StationGroup
	if component == nil or component.stations == nil then return entries end
	local seen : {Engine.Entity : boolean} = {}
	for _, station in ipairs(component.stations) do
		local ok, construction = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, station)
		if ok and construction ~= nil and construction >= 0 and not seen[construction] then
			seen[construction] = true
			local c = api.engine.getComponent(construction, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
			local kind = c ~= nil and core.kindOf(c.fileName, core.constructionKinds) or nil
			if kind ~= nil then
				entries[#entries + 1] = { construction = construction, kind = kind, levels = core.read(constructionParams(c)) }
			end
		end
	end
	return entries
end

-- The values the game keeps for the construction's stations (STATION components), and what they were without the levels.
local readValues = function(entry : Entry)
	local c = api.engine.getComponent(entry.construction, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
	local stations = c and c.stations or {}
	entry.stations, entry.circles, entry.terminals = #stations, 0, 0
	local radiusLevel = entry.levels.catchment
	local unknownBase = false
	for _, station in ipairs(stations) do
		local s = api.engine.getComponent(station, api.type.ComponentType.STATION) as Station
		if s ~= nil then
			for _, area in ipairs(s.catchmentAreas or {}) do
				entry.circles = entry.circles + 1
				if entry.radius == nil or area.radius > entry.radius then
					entry.radius = area.radius
					entry.baseRadius = core.baseRadius(area.radius, radiusLevel)
				end
				if core.baseRadius(area.radius, radiusLevel) == nil then unknownBase = true end
			end
			entry.terminals = entry.terminals + #(s.terminals or {})
		end
	end
	if unknownBase then entry.baseRadius = nil end
	if #stations > 0 then
		local ok, charged = pcall(api.engine.util.maintenance.calcMaintenanceForSubconstruction, stations[1])
		entry.upkeep = ok and tonumber(charged) or nil
	end
	entry.buildPrice = entry.upkeep and core.buildPrice(entry.upkeep, entry.levels) or nil
end

-- Per tree whether the balance covers the next level, as "yynn" for the card's key; kept as yes or no, not the balance itself,
-- so the card redraws only when one of them changes.
local readAffordable = function(entry : Entry, balance : number) : string
	if balance == nil or entry.buildPrice == nil then return "?" end
	entry.affordable = {}
	local marks : {string} = {}
	for _, tree in ipairs(core.trees) do
		local level = entry.levels[tree]
		entry.affordable[tree] = level >= core.maxLevel or balance >= core.levelPrice(entry.buildPrice, tree, level + 1)
		marks[#marks + 1] = entry.affordable[tree] and "y" or "n"
	end
	return table.concat(marks)
end

local readCard = function(group : Engine.Entity) : CardState
	local s : CardState = { entries = findEntries(group) }
	if companyRank ~= nil then s.rank = companyRank.read(api.engine.util.getPlayer()) end
	local okBalance, balance = pcall(api.engine.util.finance.getPlayersBalance, api.engine.util.getPlayer())
	local parts : {string} = { "rank=" .. tostring(s.rank) }
	for _, entry in ipairs(s.entries) do
		readValues(entry)
		local okRefused, wasRefused = pcall(readRefused, entry.construction, core.describe(entry.levels))
		entry.refused = okRefused and wasRefused or nil
		local afford = readAffordable(entry, okBalance and tonumber(balance) or nil)
		parts[#parts + 1] = tostring(entry.construction) .. ":" .. entry.kind .. ":" .. core.describe(entry.levels)
			.. ":stations=" .. tostring(entry.stations) .. ",circles=" .. tostring(entry.circles)
			.. ",terminals=" .. tostring(entry.terminals) .. ",radius=" .. string.format("%.1f", entry.radius or -1)
			.. "/" .. string.format("%.1f", entry.baseRadius or -1) .. ",upkeep=" .. tostring(entry.upkeep)
			.. ",buildPrice=" .. tostring(entry.buildPrice) .. ",affordable=" .. afford .. ",refused=" .. tostring(entry.refused)
	end
	s.key = table.concat(parts, " ")
	return s
end

local card : RetrofitCard = {}

card.conditionRetrofitCard = function(params : StationGroupEow.StationGroupWidgetPluginParams) : boolean
	if not ready or params == nil or params.ownershipState ~= "Player" then return false end
	local ok, entries = pcall(findEntries, params.entityId)
	if not ok then
		say("card conditionError group=" .. tostring(params.entityId) .. " error=" .. tostring(entries))
		return false
	end
	return #entries > 0
end

-- One text size everywhere in the card, for now.
local text = function(value : string) : TreeNodeId
	return builtin.TextView{ meta = { class = "font-scale-body" }, text = value }
end

-- 20 x 20, the size of the footer's upkeep icon ("text-icon-size-hack" in gui/main/default.css.lua).
local icon = function(path : string) : TreeNodeId
	return builtin.ImageView{
		meta = { class = "text-icon-size-hack" },
		path = path,
		scaling = builtin.type.ImageViewScaling.AutoFit,
	}
end

-- The sized pieces the card draws (the level boxes, the gaps between them, the height of a row), built once on the first
-- draw. An empty table after a failure, so a failure is logged once and the card falls back to text and default spacing.
local getDrawnStyles = function() : {string : StyleSheet}
	if drawnStyles == nil and styleutil ~= nil then
		local ok, styles = pcall(function() : {string : StyleSheet}
			local result : {string : StyleSheet} = {
				gap = styleutil.makeStyle{ size = { 3, 16 } },
				rowHeight = styleutil.makeStyle{ size = { 0, 24 } },
				buttonGap = styleutil.makeStyle{ size = { 8, 0 } },
			}
			for state, color in pairs(boxColors) do
				result[state] = styleutil.makeStyle{ backgroundColor = color, size = { 9, 16 } }
			end
			return result
		end)
		if not ok then say("card drawnStylesFailed error=" .. tostring(styles)) end
		drawnStyles = ok and styles or {}
	end
	return drawnStyles ~= nil and drawnStyles.gap ~= nil and drawnStyles or nil
end

-- The "Not rebuilt" banner, drawn as Depot Retrofits draws it, after the yellow caution cards at the top of the town and line
-- windows (entity_window_util.NotificationWidget in gui/entity_window/entity_window_util.tl): the card surface tinted with
-- the caution colour at the game's high transparency, the icon on a solid caution tile (the colours and sizes are in
-- game_mechanics/notifications/gui/notifications.css.lua; Caution is #FFC40C, gui/main/color_internal.lua). That CSS matches
-- the base recipe's name, so the banner sets the same values inline; the outline class is not tied to a recipe. Built once
-- on the first draw, apart from the drawn styles, so a failure here leaves the level boxes alone; an empty table after a
-- failure, and the banner falls back to plain lines.
local bannerStyles : {string : StyleSheet} = nil
local caution = { 1, 0.769, 0.047 }
local bannerIcon = "::/game_mechanics/notifications/gui/icons/building_industry_bulldozer.tga"
local refusedLines = {
	"Not rebuilt: a building, road or track is in the way.",
	"Nothing was charged. Clear it and buy again.",
}

local getBannerStyles = function() : {string : StyleSheet}
	if bannerStyles == nil and styleutil ~= nil then
		local ok, styles = pcall(function() : {string : StyleSheet}
			local ninePatch = function(fileName : string) : NinePatch
				local patch = api.gui.NinePatch.new()
				patch.fileName = fileName
				patch.horizontal = { 0, 6, 26, 32 }
				patch.vertical = { 0, 6, 26, 32 }
				return patch
			end
			local surface = styleutil.makeStyle{
				backgroundImage1 = ninePatch("::/gui/entity_window/design/card_surface.tga"),
				backgroundColor1 = { caution[1], caution[2], caution[3], 0.25 },
			}
			surface.padding = api.type.Vec4f.new(8, 10, 8, 10)
			local tile = styleutil.makeStyle{
				backgroundImage1 = ninePatch("::/game_mechanics/notifications/gui/design/notification_surface.tga"),
				backgroundColor1 = { caution[1], caution[2], caution[3], 1 },
				color = { 1, 1, 1, 1 },
				size = { 32, 32 },
			}
			tile.padding = api.type.Vec4f.new(4, 4, 4, 4)
			return {
				surface = surface,
				tile = tile,
				iconGap = styleutil.makeStyle{ size = { 10, 0 } },
				below = styleutil.makeStyle{ size = { 0, 8 } },
			}
		end)
		if not ok then say("card bannerStylesFailed error=" .. tostring(styles)) end
		bannerStyles = ok and styles or {}
	end
	return bannerStyles ~= nil and bannerStyles.surface ~= nil and bannerStyles or nil
end

local banner = function(bannerLines : {string}) : TreeNodeId
	local lines : {TreeNodeId} = {}
	for _, line in ipairs(bannerLines) do
		lines[#lines + 1] = builtin.TextView{ meta = { class = "font-scale-body" }, text = line, tooltipWhenClipped = line }
	end
	local styles = getBannerStyles()
	if styles == nil then
		return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = lines }
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			builtin.Component{
				meta = { class = "notification-entity-window-card-outline" },
				layout = builtin.BoxLayout{ children = {
					builtin.Component{
						meta = { styleSheet = styles.surface },
						layout = builtin.BoxLayout{
							orientation = builtin.type.Orientation.Horizontal,
							children = {
								builtin.ImageView{
									meta = { styleSheet = styles.tile },
									path = bannerIcon,
									scaling = builtin.type.ImageViewScaling.AutoFit,
								},
								builtin.Component{ meta = { styleSheet = styles.iconGap } },
								builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = lines },
							},
						},
					},
				} },
			},
			builtin.Component{ meta = { styleSheet = styles.below } },
		},
	}
end

-- A row 24 pixels high with its pieces at the left edge and one at the right; the base windows push items apart with the
-- "horizontal-spacer" class (gui_react_util.makeHorizontalSpacer in gui/main/gui_react_util.tl). The tooltip covers the row.
-- With a middle piece, a spacer on each side of it centres it between the other two.
local row = function(left : {TreeNodeId}, right : TreeNodeId, tooltip : string, middle? : TreeNodeId) : TreeNodeId
	local styles = getDrawnStyles()
	local children : {TreeNodeId} = {}
	if styles ~= nil then children[1] = builtin.Component{ meta = { styleSheet = styles.rowHeight } } end
	for _, node in ipairs(left) do children[#children + 1] = node end
	children[#children + 1] = builtin.Component{ meta = { class = "horizontal-spacer" } }
	if middle ~= nil then
		children[#children + 1] = middle
		children[#children + 1] = builtin.Component{ meta = { class = "horizontal-spacer" } }
	end
	children[#children + 1] = right
	return builtin.Component{
		meta = { tooltip = tooltip },
		layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = children },
	}
end

-- "Level 4/7 (max 15)": the level over the highest the company rank allows now; "(max 15)" only while the rank is lower.
-- With the rank unknown, "Level 4/? (max 15)".
local levelLabel = function(s : CardState, level : integer) : string
	local limit = s.rank ~= nil and math.min(s.rank, core.maxLevel) or nil
	return "Level " .. tostring(level) .. "/" .. (limit and tostring(limit) or "?")
		.. ((limit == nil or limit < core.maxLevel) and (" (max " .. tostring(core.maxLevel) .. ")") or "")
end

-- The tree's name and level, what it does and what else it costs, one sentence a line.
local rowTooltip = function(s : CardState, tree : string, level : integer) : string
	local share = core.upkeepShares[tree]
	local costLine = share ~= nil and ("\nEach level also adds " .. tostring(round(share * 100)) .. "% of the station's own upkeep.") or ""
	return core.names[tree] .. ": " .. levelLabel(s, level) .. "\n" .. treeTooltips[tree] .. costLine
end

local boxes = function(s : CardState, level : integer) : {TreeNodeId}
	local styles = getDrawnStyles()
	if styles == nil then return { text(" " .. levelLabel(s, level)) } end
	local nodes : {TreeNodeId} = {}
	for n = 1, core.maxLevel do
		local style = n <= level and styles.bought or (s.rank == nil or n > s.rank) and styles.locked or styles.open
		nodes[#nodes + 1] = builtin.Component{ meta = { styleSheet = styles.gap } }
		nodes[#nodes + 1] = builtin.Component{ meta = { styleSheet = style } }
	end
	return nodes
end

local meters = function(radius : number) : string
	return grouped(radius) .. " m"
end

local percentAt = function(level : integer) : string
	return level == 0 and "0%" or ("-" .. tostring(round(level * core.upkeepStep * 100)) .. "%")
end

-- What a tree's levels do now: "200 -> 230 m" (without and with the levels), "-25%"; just the value at level 0 or when the
-- value without the levels is unknown.
local effectNow = function(entry : Entry, tree : string) : string
	local level = entry.levels[tree]
	if tree == "catchment" then
		if entry.radius == nil then return "-" end
		if level == 0 or entry.baseRadius == nil then return meters(entry.radius) end
		return grouped(entry.baseRadius) .. " -> " .. meters(entry.radius)
	elseif tree == "upkeep" then
		return percentAt(level) .. " of total"
	end
	return percentAt(level)
end

-- What the next level changes: "230 -> 236 m", "-25% -> -30%"; "?" when the value without the levels is unknown. Short, so
-- the row has room for the upkeep and the buy button: the upkeep row leaves out the summary's "of total", which its tooltip
-- gives.
local effectNext = function(entry : Entry, tree : string, level : integer) : string
	if tree == "catchment" then
		if entry.radius == nil then return "no circle" end
		if entry.baseRadius == nil then return "?" end
		return grouped(core.radius(entry.baseRadius, level - 1)) .. " -> " .. meters(core.radius(entry.baseRadius, level))
	end
	return percentAt(level - 1) .. " -> " .. percentAt(level)
end

local heading = function(s : CardState, entry : Entry, rows : {TreeNodeId})
	-- A group can hold several constructions (a train station and a bus terminal joined): each gets its own heading.
	if #s.entries > 1 then rows[#rows + 1] = text(kindNames[entry.kind] or entry.kind) end
end

-- The stock shopping cart and the price; a rank too low (or unknown) replaces the price. Short of money the price stays and the
-- button is greyed out, as the game script refuses the buy. The game shows no tooltip on a disabled button (Depot Retrofits'
-- findings), so the label says why. No "buying" state: the rebuild lands within a second, paused or not, and the card redraws
-- with the new level. A second click before that is ignored (tries), and the game script refuses a stale level, so nothing
-- is charged twice. A rebuild the game refuses shows as the yellow banner a few seconds later (readRefused); the buttons
-- stay, so the buy can be sent again.
local buyButton = function(s : CardState, entry : Entry, tree : string) : TreeNodeId
	local level = entry.levels[tree]
	local nextLevel = level + 1
	local label, tooltip : string, string
	local enabled = false
	local price = entry.buildPrice and core.levelPrice(entry.buildPrice, tree, nextLevel) or nil
	if price == nil then
		label, tooltip = "?", "Price unknown"
	elseif tree == "catchment" and entry.radius == nil then
		label, tooltip = money(price), "The station has no catchment circle"
	elseif s.rank == nil then
		label, tooltip = "Rank ?", "The company rank could not be read, so no level can be bought (see the game log)"
	elseif nextLevel > s.rank then
		label, tooltip = "Rank " .. tostring(nextLevel), "Needs company rank " .. tostring(nextLevel)
	elseif entry.affordable ~= nil and not entry.affordable[tree] then
		label, tooltip = money(price), "Not enough money"
	else
		label, tooltip = money(price), buyTooltip
		enabled = true
	end
	local construction = entry.construction
	return builtin.Button{
		-- "primary" is the class the base game's dialog buttons use (gui/line_vehicle_mgmt/feedback_list_util.tl); its disabled
		-- style greys the icon and the text (gui/main/default.css.lua).
		meta = { class = "primary", enabled = enabled, tooltip = tooltip,
			localKey = "station_retrofits_buy_" .. tostring(construction) .. "_" .. tree },
		content = builtin.Component{ layout = builtin.BoxLayout{
			orientation = builtin.type.Orientation.Horizontal,
			children = { icon(buyIcon), text(label) },
		} },
		onClick = function()
			if not enabled then return end
			-- One buy at a time per station: a second click before the first lands or is refused is ignored.
			if tries[construction] ~= nil then return end
			tries[construction] = { levels = core.describe(entry.levels), at = clockNow(), step = stepCount }
			if logFull then
				say("card buy construction=" .. tostring(construction) .. " tree=" .. tree .. " from=" .. tostring(level)
					.. " shownPrice=" .. tostring(price))
			end
			api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", buyEventId, buyEvent,
				{ construction = construction, tree = tree, from = level }))
		end,
	}
end

-- Collapsed: per tree the symbol, the boxes and what the levels do now; above them the banner after a refused buy, so it
-- shows whether the card is open or not.
local summaryRows = function(s : CardState) : {TreeNodeId}
	local rows : {TreeNodeId} = {}
	for _, entry in ipairs(s.entries) do
		heading(s, entry, rows)
		if entry.refused then rows[#rows + 1] = banner(refusedLines) end
		for _, tree in ipairs(core.trees) do
			local level = entry.levels[tree]
			local left : {TreeNodeId} = { icon(treeIcons[tree]) }
			for _, node in ipairs(boxes(s, level)) do left[#left + 1] = node end
			rows[#rows + 1] = row(left, text(effectNow(entry, tree)), rowTooltip(s, tree, level))
		end
	end
	return rows
end

-- Expanded: per tree what the next level changes at the left, the upkeep the footer would show after it in the middle, and
-- the buy button at the right. The level number is left out for room (in game the row ran past the card's edge with it); the
-- tooltip gives the level.
local nextRows = function(s : CardState) : {TreeNodeId}
	local rows : {TreeNodeId} = {}
	for _, entry in ipairs(s.entries) do
		heading(s, entry, rows)
		for _, tree in ipairs(core.trees) do
			local level = entry.levels[tree]
			local tooltip = rowTooltip(s, tree, level)
			if level >= core.maxLevel then
				rows[#rows + 1] = row({ icon(treeIcons[tree]), text(" Highest level") }, builtin.Component{}, tooltip)
			else
				local nextLevel = level + 1
				local upkeep : TreeNodeId
				if entry.upkeep ~= nil then
					local after = entry.upkeep / core.upkeepFactor(entry.levels) * core.upkeepFactor(core.withLevel(entry.levels, tree, nextLevel))
					upkeep = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = { icon(upkeepIcon), text(perYear(after)) } }
				else
					upkeep = text("?")
				end
				-- A gap before the button, so the upkeep never touches it when the row is full.
				local styles = getDrawnStyles()
				local buy = buyButton(s, entry, tree)
				local right = styles ~= nil and builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal,
					children = { builtin.Component{ meta = { styleSheet = styles.buttonGap } }, buy } } or buy
				rows[#rows + 1] = row({ icon(treeIcons[tree]), text(" " .. effectNext(entry, tree, nextLevel)) }, right,
					tooltip .. "\nThe next level, level " .. tostring(nextLevel) .. ": what it changes, the upkeep after it and its price.", upkeep)
			end
		end
	end
	return rows
end

local logShown = function(group : Engine.Entity, s : CardState)
	if not logFull or shownLines >= maxShownLines then return end
	local shownKey = tostring(group) .. " " .. s.key
	if shownKeys[shownKey] then return end
	shownKeys[shownKey] = true
	shownLines = shownLines + 1
	local prices : {string} = {}
	for _, entry in ipairs(s.entries) do
		local list : {string} = {}
		for _, tree in ipairs(core.trees) do
			local level = entry.levels[tree]
			list[#list + 1] = level < core.maxLevel and entry.buildPrice and tostring(core.levelPrice(entry.buildPrice, tree, level + 1)) or "-"
		end
		prices[#prices + 1] = tostring(entry.construction) .. ":" .. table.concat(list, "/")
	end
	say("card shown group=" .. tostring(group) .. " constructions=" .. tostring(#s.entries) .. " " .. s.key
		.. " nextPrices=" .. table.concat(prices, " "))
end

local errorState = function() : CardState
	return { entries = {}, key = "error" }
end

local vertical = function(rows : {TreeNodeId}) : TreeNodeId
	return builtin.Component{ layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = rows } }
end

if ready then
	-- The expanded part, as its own recipe: the card builds it only while it is open. A recipe's root must be a layout
	-- ("Recipe child must be a layout"), so it returns the BoxLayout itself, not a Component around it.
	local NextLevels = react.RegisterRecipe("StationRetrofitsNextLevels", function(param : NextParam) : TreeNodeId
		local ok, rows = pcall(nextRows, param.state)
		if not ok then
			say("card nextError error=" .. tostring(rows))
			rows = { text("The next levels could not be shown (see the game log).") }
		end
		return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = rows }
	end)

	card.RetrofitCardPlugin = react.RegisterPluginRecipe(stationEow.StationGroupEowExtensionPoint, "StationRetrofitsCard",
		function(params : StationGroupEow.StationGroupWidgetPluginParams) : TreeNodeId
			local group = params.entityId
			local state = engineReact.useStepState(function() : CardState
				local ok, s = pcall(readCard, group)
				if ok then return s end
				say("card readError group=" .. tostring(group) .. " error=" .. tostring(s))
				return errorState()
			end, nil, function(a : CardState, b : CardState) : boolean
				return a ~= nil and b ~= nil and a.key == b.key
			end)
			local s = state:old()
			local ok, rows = pcall(function() : {TreeNodeId}
				logShown(group, s)
				return summaryRows(s)
			end)
			if not ok then
				say("card error group=" .. tostring(group) .. " error=" .. tostring(rows))
				rows = { text("Station Retrofits: the levels could not be shown (see the game log).") }
			end
			local collapsible = params.setCollapsibleExpanded ~= nil and params.getCollapsibleExpanded ~= nil
			return builtin.BoxLayout{
				child = contentCard.ContentCard{
					title = "Retrofit",
					initialCalloutTextPermanent = "",
					extraChildrenPermanent = { vertical(rows) },
					initialCalloutTextCollapsible = collapsible and "" or nil,
					recipeAndParamCollapsible = collapsible and contentCard.makeRecipeAndParam(NextLevels, { state = s }) or nil,
					setCollapsibleExpanded = collapsible and function(v : boolean) params.setCollapsibleExpanded(cardKey, v) end or nil,
					collapsibleExpanded = collapsible and params.getCollapsibleExpanded(cardKey) or nil,
					gameCtx = params.gameCtx,
					showOnRightSide = params.showCalloutOnRightSide,
				},
			}
		end)
end

return card
