
NTCS_Nanite = {} -- Neurotrauma Nanite Integration
NTCS_Nanite.Name="Nanite Integration"
NTCS_Nanite.Version = "2.1.5"
NTCS_Nanite.VersionNum = 02001005
NTCS_Nanite.MinNTVersion = "2.0.0"
NTCS_Nanite.MinNTVersionNum = 02000000
NTCS_Nanite.Path = table.pack(...)[1] .. "/NTCS Nanite Integration"

dofile(NTCS_Nanite.Path.."/Lua/Library/NeurotraumaLib.lua")
NTCS.Info.RegisterAddon(NTCS_Nanite)

local NTLuaEnabledMsg = "Error loading NT Nanite Integration: Lua Neurotrauma is enabled!"
local NTCSNotEnabledMsg = "Error loading NT Nanite Integration: It appears Neurotrauma CS isn't loaded!"

-- Serverside + Singleplayer code
if (Game.IsMultiplayer and SERVER) or not Game.IsMultiplayer then
	Timer.Wait(function()

		-- NT is the table initialised in Lua Neurotrauma and not present in NTCS. If this returns true, NT Lua is active.
		if NT ~= nil then
			print(NTLuaEnabledMsg)
			Game.SendMessage(NTLuaEnabledMsg, ChatMessageType.Server)
			return
		end

		-- If Info cannot be found it's because the initialization line above did not trigger since NTCS isn't active.
		if NTCS.Info == nil then
			print(NTCSNotEnabledMsg)
			Game.SendMessage(NTCSNotEnabledMsg, ChatMessageType.Server)
			return
		end

		-- Lua Content Scripts SP/MP:
		dofile(NTCS_Nanite.Path .. "/Lua/Scripts/helperfunctions.lua")
		dofile(NTCS_Nanite.Path .. "/Lua/Scripts/hook.lua")
        dofile(NTCS_Nanite.Path .. "/Lua/Scripts/stats.lua")
        dofile(NTCS_Nanite.Path .. "/Lua/Scripts/afflictions.lua")
        dofile(NTCS_Nanite.Path .. "/Lua/Scripts/items.lua")
	end, 1)
else
	Timer.Wait(function()

		if NT ~= nil then
			print(NTLuaEnabledMsg)
			Game.SendMessage(NTLuaEnabledMsg, ChatMessageType.Server)
			return
		end

		if NTCS.Info == nil then
			print(NTCSNotEnabledMsg)
			Game.SendMessage(NTCSNotEnabledMsg, ChatMessageType.Server)
			return
		end

	end, 1)
end

Timer.Wait(function()
	dofile(NTCS_Nanite.Path .. "/Lua/Scripts/config.lua")
end, 1)