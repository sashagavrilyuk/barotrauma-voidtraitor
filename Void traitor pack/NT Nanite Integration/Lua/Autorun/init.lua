-- VoidTraitorPackBuilder bundled autorun guard
local __vtpackBundledAutorun = "NT Nanite Integration/Lua/Autorun/init.lua"
if rawget(_G, "__VTPACK_BUNDLED_AUTORUN") ~= __vtpackBundledAutorun then return end

NTNan = {} -- Neurotrauma Nanite Integration
NTNan.Name="Nanite Integration"
NTNan.Version = "1.2.8"
NTNan.VersionNum = 01200700
NTNan.MinNTVersion = "A1.14.7"
NTNan.MinNTVersionNum = 01140700
NTNan.Path = table.pack(...)[1]
Timer.Wait(function() if NTC ~= nil and NTC.RegisterExpansion ~= nil then NTC.RegisterExpansion(NTNan) end end,1)

if (Game.IsMultiplayer and SERVER) or not Game.IsMultiplayer then

    Timer.Wait(function()
        dofile(NTNan.Path.."/Lua/Scripts/hook.lua")
        dofile(NTNan.Path.."/Lua/Scripts/helperfunctions.lua")
        dofile(NTNan.Path.."/Lua/Scripts/afflictions.lua")
        dofile(NTNan.Path.."/Lua/Scripts/humanupdate.lua")

        NTC.AddHumanUpdateHook(NTNan.UpdateHuman)
    end, 2)
    
else
    -- client only
end