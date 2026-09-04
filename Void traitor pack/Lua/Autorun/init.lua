local packPath = table.pack(...)[1]

assert(loadfile(packPath .. "/Lua/extensions/nt_surgery_access_fix.lua"))(packPath)

if SERVER then
    assert(loadfile(packPath .. "/Lua/extensions/headset_stun.lua"))(packPath)
    return
end

assert(loadfile(packPath .. "/Lua/client/init.lua"))(packPath)
