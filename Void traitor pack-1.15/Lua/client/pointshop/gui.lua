if SERVER then return end

local packPath, Common = ...
local base = packPath .. "/Lua/client/pointshop/"
local P = assert(loadfile(base .. "gui_core.lua"))(packPath, Common)
assert(loadfile(base .. "network.lua"))(P)
