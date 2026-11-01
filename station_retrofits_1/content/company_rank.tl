-- The company rank for the rank gate, shared by the game script and the station window card (each loads it with ug_require
-- under pcall). Copied from Depot Retrofits. Read through the base company_progression_util.tl, as the company window reads
-- it. When that file cannot be loaded or read, the same values are read the way it reads them
-- (game_mechanics/company/company_progression_util.tl): the state of the base game script company_progression.gs, unless
-- company_growth_config.res sets an enforcedLevel. When neither works the rank is unknown, and no level can be bought.

local utilPath = "::/game_mechanics/company/company_progression_util.tl"
local gameScriptName = "::game_mechanics/company/company_progression.gs"
local growthConfigName = "::/game_mechanics/company/company_growth_config.res"

local utilLoaded, utilModule = pcall(ug_require, utilPath)
local progression = utilLoaded and (utilModule as CompanyProgressionUtil) or nil

local companyRank : StationRetrofitsRank = {}

-- The claimed and earned rank from the progression game script's state; 0 and 0 while the company has no entry, as the util
-- returns no company then.
local readState = function(player : Engine.Entity) : integer, integer
	local config = api.res.genericRep.get(api.res.genericRep.find(growthConfigName)).data as CompanyGrowthConfig
	if config ~= nil and config.enforcedLevel ~= nil then return config.enforcedLevel, config.enforcedLevel end
	local entity = api.engine.system.gameScriptSystem.getEntityForGameScript(gameScriptName)
	local component = api.engine.getComponent(entity, api.type.ComponentType.GAME_SCRIPT) as Engine.Component.GameScript<CompaniesGrowthState>
	local company = component.state.companyState and component.state.companyState[player] or nil
	if company == nil then return 0, 0 end
	return company.level, company.potentialLevel
end

function companyRank.read(player : Engine.Entity) : integer, integer, string
	local utilError = utilLoaded and "none" or ("unavailable " .. tostring(utilModule))
	if progression ~= nil then
		local ok, company = pcall(progression.getCompanyProgressionState, player)
		if ok and company ~= nil and type(company.level) == "number" then return company.level, company.potentialLevel, "util" end
		utilError = ok and "noEntry" or ("error " .. tostring(company))
	end
	local ok, level, potential = pcall(readState, player)
	if ok and type(level) == "number" then return level as integer, potential as integer, "state utilError=" .. utilError end
	return nil, nil, "unknown utilError=" .. utilError .. " stateError=" .. tostring(level)
end

return companyRank
