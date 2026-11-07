-- Styles for the Retrofit card (retrofit_card.script.tl). The game loads a mod's .css.lua files with its own
-- (gui/main/*.css.lua, built with gui/main/stylesheetutil.lua). Inline style sheets only take a fixed size; a class rule
-- can set a minimum.
local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- The "<", ">" and ">|" buttons all one width, so the upkeep figures beside them end in one column from row to row. A
	-- minimum, not a fixed width: at a larger font setting a label widens its button instead of being cut off. The minimum is
	-- the content's: the station window adds its buttons' padding, 3 above and below and 4 at the sides ("R::EntityWindowContent
	-- Button", gui/entity_window/entity_window.css.lua). A minimum of 40 came out 48 wide in game; 28 gives about 36. The
	-- padding is the game's, so the buttons keep its height (8 above and below made the rows taller).
	a("Button!station-retrofits-step", { minSize = { 28, -1 } })

	return result
end
