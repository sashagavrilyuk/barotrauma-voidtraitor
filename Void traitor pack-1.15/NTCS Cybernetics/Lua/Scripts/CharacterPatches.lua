local genericJobs = {
	"medicaldoctor",
	"engineer",
	"mechanic",
	"captain",
	"assistant",
	"securityofficer",
}

local function cyberiRoulette(createdCharacter, rollAmount)
	local tier2Flag = true
	local waterproofFlag = false
	local organName = nil
	local limbtype = LimbType.Torso
	if NTCS.HF.Chance(0.05) then -- tier 3 if hit 5%
		tier2Flag = false
		waterproofFlag = true
	end
	for i = 0, rollAmount - 1, 1 do -- apply one random organ every roll
		organName = nil
		if NTCS.HF.Chance(0.33) then -- organs
			if NTCS.HF.Chance(0.2) then -- heart
				organName = "heart"
			elseif NTCS.HF.Chance(0.2) then -- liver
				organName = "liver"
			elseif NTCS.HF.Chance(0.2) then -- kidney
				organName = "kidney"
			elseif NTCS.HF.Chance(0.2) then -- brain
				organName = "brain"
				limbtype = LimbType.Head
			else -- lungs
				organName = "lung"
			end
		elseif NTCS.HF.Chance(0.33) then -- arms
			if NTCS.HF.Chance(0.5) then
				NTCS_Cybernetics.CyberifyLimb(createdCharacter, LimbType.LeftArm, waterproofFlag)
			else
				NTCS_Cybernetics.CyberifyLimb(createdCharacter, LimbType.RightArm, waterproofFlag)
			end
		else -- legs
			if NTCS.HF.Chance(0.5) then
				NTCS_Cybernetics.CyberifyLimb(createdCharacter, LimbType.LeftLeg, waterproofFlag)
			else
				NTCS_Cybernetics.CyberifyLimb(createdCharacter, LimbType.RightLeg, waterproofFlag)
			end
		end
		if organName ~= nil then
			NTCS.HF.SetAfflictionLimb(createdCharacter, "ntc_cyber" .. organName, limbtype, tier2Flag and 50 or 100) -- add "ntc_cyberliver", at 50% strength if its Augmented (tier 2), 100% if Cyber (tier 3)
		end
	end
end

Hook.Add("characterCreated", "NTCS_Cybernetics.CyberNPC", function(createdCharacter)
	Timer.Wait(function()
		if createdCharacter.IsHuman and CharacterTeamType.None then
			if
				(createdCharacter.HasJob("commoner") or genericJobs[createdCharacter.JobIdentifier] ~= nil)
				and NTCS.HF.Chance(0.02)
			then -- 2% cyber chance
				cyberiRoulette(createdCharacter, 1)
			elseif createdCharacter.HasJob("prisoner") and NTCS.HF.Chance(0.04) then -- 4% cyber chance
				cyberiRoulette(createdCharacter, 1)
			elseif createdCharacter.HasJob("structuredefender") and NTCS.HF.Chance(0.08) then -- 8% cyber chance
				cyberiRoulette(createdCharacter, 1)
			elseif
				(createdCharacter.HasJob("vipsecurityofficer") or createdCharacter.HasJob("outpostsecurityofficer"))
				and NTCS.HF.Chance(0.2)
			then -- 20% cyber chance
				cyberiRoulette(createdCharacter, 1)
			elseif createdCharacter.HasJob("vip") and NTCS.HF.Chance(0.3) then -- 30% cyber chance
				cyberiRoulette(createdCharacter, 3)
			elseif createdCharacter.HasJob("killer") and NTCS.HF.Chance(0.5) then -- 50% cyber chance (pretty rare job)
				cyberiRoulette(createdCharacter, 1)
			end
		end
	end, 10000) -- hopefully enough to not trigger obj reference error
end)