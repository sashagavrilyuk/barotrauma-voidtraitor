-- VoidTraitorPackBuilder bundled autorun guard
local __vtpackBundledAutorun = "NTCS Surgery Plus/Lua/Autorun/init.lua"
if rawget(_G, "__VTPACK_BUNDLED_AUTORUN") ~= __vtpackBundledAutorun then return end
NTCS_SurgeryPlus = {}
NTCS_SurgeryPlus.Name = "Surgery Plus"
NTCS_SurgeryPlus.Version = "A1.0.0"
NTCS_SurgeryPlus.VersionNum = 01000000
NTCS_SurgeryPlus.Path = table.pack(...)[1]

-- Initialise C# Classes needed
dofile(NTCS_SurgeryPlus.Path.."/Lua/Library/NeurotraumaLib.lua")
NTCS.Info.RegisterAddon(NTCS_SurgeryPlus)

local NTLuaEnabledMsg = "Error loading NTCS Cybernetics: Lua Neurotrauma is enabled!"
local NTCSNotEnabledMsg = "Error loading NTCS Cybernetics: It appears Neurotrauma CS isn't loaded!"

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

		dofile(NTCS_SurgeryPlus.Path .. "/Lua/Scripts/HumanUpdate.lua")
		dofile(NTCS_SurgeryPlus.Path .. "/Lua/Scripts/Items.lua")
		dofile(NTCS_SurgeryPlus.Path .. "/Lua/Scripts/AddIDTags.lua")
		dofile(NTCS_SurgeryPlus.Path .. "/Lua/Scripts/DoctorSkill.lua")

		-- Hook a function to NTCS Pre-HumanUpdate
		Hook.Add("Neurotrauma.HumanUpdate.PreHook", "NTCS_Cybernetics.UpdateHuman", function(character, deltaTime)
			if character == nil or character.Human == nil or character.Human.Removed then return end
			NTCS_SurgeryPlus.PreUpdateHuman(character.Human, deltaTime)
		end)

		-- Hook a function to NTCS Post-HumanUpdate
		Hook.Add("Neurotrauma.HumanUpdate.PostHook", "NTCS_Cybernetics.UpdateHuman", function(character, deltaTime)
			if character == nil or character.Human == nil or character.Human.Removed then return end
			NTCS_SurgeryPlus.PostUpdateHuman(character.Human, deltaTime)
		end)
	end, 1)
end

Timer.Wait(function()
	dofile(NTCS_SurgeryPlus.Path .. "/Lua/Scripts/ConfigData.lua")
end, 1)
