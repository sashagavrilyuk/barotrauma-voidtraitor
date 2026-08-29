if SERVER then return end

local packPath, Common = ...
local base = packPath .. "/Lua/client/lobby/"
local P = assert(loadfile(base .. "menu_core.lua"))(packPath, Common)
assert(loadfile(base .. "menu_widgets.lua"))(P)
assert(loadfile(base .. "menu_window.lua"))(P)
assert(loadfile(base .. "voting.lua"))(P)
assert(loadfile(base .. "menu_controls.lua"))(P)
assert(loadfile(base .. "menu_runtime.lua"))(P)
