if SERVER then return end

local packPath = table.pack(...)[1]
local spectatorCommon = assert(loadfile(packPath .. "/Lua/client/spectator/common.lua"))(packPath)

assert(loadfile(packPath .. "/Lua/client/spectator/camera_teleport.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/spectator/ghostroles.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/pointshop/gui.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/lobby/menu.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath, spectatorCommon)
