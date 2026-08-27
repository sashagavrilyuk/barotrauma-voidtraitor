local packPath = table.pack(...)[1]

assert(loadfile(packPath .. "/Lua/extensions/nt_surgery_access_fix.lua"))(packPath)

if SERVER then return end

assert(loadfile(packPath .. "/Lua/client/init.lua"))(packPath)
