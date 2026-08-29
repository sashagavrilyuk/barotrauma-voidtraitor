if SERVER then return end

local packPath = table.pack(...)[1]
local clientCommon = assert(loadfile(packPath .. "/Lua/client/common.lua"))(packPath)

assert(loadfile(packPath .. "/Lua/client/spectator/camera_teleport.lua"))(packPath, clientCommon)
assert(loadfile(packPath .. "/Lua/client/spectator/ghostroles.lua"))(packPath, clientCommon)
assert(loadfile(packPath .. "/Lua/client/pointshop/gui.lua"))(packPath, clientCommon)
assert(loadfile(packPath .. "/Lua/client/pointshop/input.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/lobby/menu.lua"))(packPath, clientCommon)
assert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath, clientCommon)
assert(loadfile(packPath .. "/Lua/client/runtime.lua"))(packPath)
