local packPath = table.pack(...)[1]

assert(loadfile(packPath .. "/Lua/extensions/nt_surgery_access_fix.lua"))(packPath)
assert(loadfile(packPath .. "/Lua/extensions/station_ragdoll_platforms.lua"))()
assert(loadfile(packPath .. "/Lua/extensions/station_boats.lua"))()
assert(loadfile(packPath .. "/Lua/extensions/detachable_devices.lua"))()
assert(loadfile(packPath .. "/Lua/extensions/device_assembly.lua"))()
assert(loadfile(packPath .. "/Lua/extensions/artifacts.lua"))()

if SERVER then
    assert(loadfile(packPath .. "/Lua/extensions/skin_ointment.lua"))()
    assert(loadfile(packPath .. "/Lua/extensions/surgery_buttons.lua"))()
    assert(loadfile(packPath .. "/Lua/extensions/headset_stun.lua"))(packPath)
    assert(loadfile(packPath .. "/Lua/extensions/enhanced_husks_optimization.lua"))(packPath)
    return
end

assert(loadfile(packPath .. "/Lua/client/init.lua"))(packPath)
