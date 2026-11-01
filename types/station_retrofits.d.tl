-- The type of the shared core module (station_retrofits_1/content/core.tl), for type checking only; the mod does not ship
-- this file. Each script loads the module with ug_require and casts it to this record.

global record StationRetrofitsCore
	maxLevel : integer
	trees : {string} -- the four trees in display order
	paramKeys : {string : string} -- tree -> construction param key
	names : {string : string} -- tree -> display name

	-- The base station scripts and constructions, by the end of their path (".lua" stripped), and the kind each log line names.
	scriptKinds : {string : string}
	constructionKinds : {string : string}
	-- The kind of a file in kinds, from its path with or without a namespace and ".lua"; nil for any other file.
	kindOf : function(fileName : string, kinds : {string : string}) : string

	-- The levels stored in a construction's params, 0 for a tree with no param (a station placed before the mod, or new).
	read : function(params : {string : any}) : {string : integer}
	-- Writes the levels into a params table, in the stored form (1-based index into "0".."15").
	store : function(params : {string : any}, levels : {string : integer})
	-- "catchment/pollution/noise/upkeep", as the log lines write levels; "nil" for nil.
	describe : function(levels : {string : integer}) : string
	-- true when every tree is at level 0.
	isZero : function(levels : {string : integer}) : boolean

	radius : function(baseRadius : number, level : integer) : number
	-- The value before the levels, from one the wrapper scaled; nil when the formula does not give it back (another mod also
	-- scaled it).
	baseRadius : function(radius : number, level : integer) : number
	-- A copy of levels with one tree set to level.
	withLevel : function(levels : {string : integer}, tree : string, level : integer) : {string : integer}
	emissionFactor : function(level : integer) : number
	upkeepFactor : function(levels : {string : integer}) : number
	-- 6 times the upkeep charged now without the levels, rounded to $100; the price of a tree's level from it.
	buildPrice : function(chargedUpkeep : number, levels : {string : integer}) : number
	levelPrice : function(buildPrice : number, tree : string, level : integer) : integer
	-- The share of the base upkeep each level of a tree adds (no entry for the upkeep tree), and the share of the total each
	-- upkeep level cuts.
	upkeepShares : {string : number}
	upkeepStep : number

	-- Wraps a base station script's updateFn (the loadScript modifier in mod.script.tl). kind names the script in log lines;
	-- say writes a log line; logFull adds the before and after values.
	wrapUpdate : function(original : function(any, any) : any, kind : string, say : function(string), logFull : boolean)
		: function(any, any) : any
end

-- The company rank module (station_retrofits_1/content/company_rank.tl, copied from Depot Retrofits).
global record StationRetrofitsRank
	-- The claimed rank, the earned rank and where they were read ("util", "state ..."); nil, nil and "unknown ..." when neither
	-- read works.
	read : function(player : Engine.Entity) : integer, integer, string
end
