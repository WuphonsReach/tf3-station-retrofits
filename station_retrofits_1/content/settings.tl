-- Test switches, not in-game settings. Read when the game loads the mod's scripts, so restart the game after changing them.
--
-- logLevel: how much the mod writes to the game log (every line starts with STATION_RETROFITS). Any other value counts as "summary".
--   "summary"  shipped: the start-up lines, every error and fallback, constructions skipped for a reason, and one line per buy
--              with its outcome (sent, then charged, not landed or refused)
--   "full"     for testing: plus the state before and after every action (entity ids, values)
-- tools/check_repo.py warns while logLevel is not "summary", and fails in CI.
return {
	logLevel = "summary",
}
