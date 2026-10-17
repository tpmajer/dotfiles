-- Toggles the background between black and the configured color, which
-- the palette quickshell applies may have changed.
local configured = mp.get_property("background-color")
local black = false

mp.add_key_binding(nil, "toggle-black", function()
    black = not black
    mp.set_property("background-color", black and "#000000" or configured)
end)
