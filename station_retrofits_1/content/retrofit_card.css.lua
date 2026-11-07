-- Styles for the Retrofit card (retrofit_card.script.tl). The game loads a mod's .css.lua files with its own
-- (gui/main/*.css.lua, built with gui/main/stylesheetutil.lua). Inline style sheets only take a fixed size; a class rule
-- can set a minimum.
local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- Every buy button at least as wide as an eight-digit price ("$99,999,999"), so the buttons and the upkeep figures beside
	-- them line up from row to row. A minimum, not a fixed width: a longer label (a larger font setting, a dearer level)
	-- widens its button instead of being cut off. Measured in game: "$5,380,247" took about 105 of the window's 450 units.
	a("Button!station-retrofits-buy", { minSize = { 120, -1 } })
	-- The ">|" button beside it (buy every level the rank and the money allow), as small as its label.
	a("Button!station-retrofits-max", { minSize = { 32, -1 } })

	return result
end
