if SERVER then return end

local packPath = table.pack(...)[1]

assert(loadfile(packPath .. "/Lua/client/spectator/camera_teleport.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/spectator/ghostroles.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/pointshop.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/menu.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath)
