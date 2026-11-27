local limbtypes = {
	LimbType.LeftArm,
	LimbType.RightArm,
	LimbType.LeftLeg,
	LimbType.RightLeg,
	LimbType.Torso,
	LimbType.Head,
}

-- multipliers that are used in humanupdate are set here
function NTCS_SurgeryPlus.PreUpdateHuman(character)
	-- under pressure talent
	if NTCS.HF.HasAffliction(character, "underpressure") and NTCS.HF.HasAffliction(character, "unconsciousness") then
		NTCS.NTC.SetMultiplier(character, "anyorgandamage", 0.5)
		NTCS.NTC.SetMultiplier(character, "neurotraumagain", 0.5)
	end

	-- fine bedisde manner talent
	if NTCS.HF.HasTalent(character, "ntsp_bedsidemanner") then
		for _, targetcharacter in pairs(Character.CharacterList) do
			if
				character ~= targetcharacter
				and targetcharacter.IsHuman
				and not targetcharacter.IsDead
				and NTCS.HF.CharacterDistance(character, targetcharacter) < 600
			then
				-- near surgeon, no bed: 200%
				-- near surgeon, on bed: 300%
				if NTCS.HF.HasAffliction(targetcharacter, "safesurgery", 0.1) then
					NTCS.NTC.SetMultiplier(targetcharacter, "healingrate", 3)
				else
					NTCS.NTC.SetMultiplier(targetcharacter, "healingrate", 2)
				end
			end
		end
	end

	-- sterility during surgery
	if NTCS.Config.Get("NTSP_enableSurgicalInfection", false) and NTCS.HF.HasAffliction(character, "surgeryincision") then
		local sterility = 50

		local wearsdrape = NTCS.HF.GetOuterWearIdentifier(character) == "surgicaldrapes"
		if wearsdrape then
			-- wearing surgical drapes? 100 base sterility
			sterility = 100
		else
			-- if no drape, check for ointments
			for i, val in ipairs(limbtypes) do
				if NTCS.HF.HasAfflictionLimb(character, "surgeryincision", val) then
					if NTCS.HF.HasAfflictionLimb(character, "ointmented", val) then
						sterility = sterility + 50
					else
						sterility = -9001
					end
				end
			end
		end

		sterility = NTCS.HF.Clamp(sterility, 0, 100)

		-- determine overall sterility based on present humans and their sterility
		for _, targetcharacter in pairs(Character.CharacterList) do
			if
				character ~= targetcharacter
				and targetcharacter.IsHuman
				and NTCS.HF.CharacterDistance(character, targetcharacter) < 150
			then
				local charSterility = 10 + NTCS.HF.GetSkillLevel(targetcharacter, "surgery") / 5

				-- inner wear sterile? +40
				charSterility = charSterility
					+ 40 * NTCS.HF.BoolToNum(HF.ItemHasTag(HF.GetItemInInnerWear(targetcharacter), "sterile"))
				-- headwear sterile? +40
				charSterility = charSterility
					+ 40 * NTCS.HF.BoolToNum(HF.ItemHasTag(HF.GetItemInHeadWear(targetcharacter), "sterile"))
				-- add sterility from Ultrasonic Cleaner perk
				if NTCS.HF.HasTalent(character, "ntsp_ultrasoniccleaner") then
					charSterility = charSterility + 30
				end

				-- adjust overall sterility based on character sterility and distance to patient
				charSterility = NTCS.HF.Clamp(charSterility, 0, 100)
				sterility = NTCS.HF.Lerp(
					sterility,
					sterility * (charSterility / 100),
					(150 - NTCS.HF.CharacterDistance(character, targetcharacter)) / 150
				)
			end
		end

		-- at max dirtyness, theres a 10% chance every update (two seconds) to cause sepsis
		local sepsischance = NTCS.HF.Clamp(1 - (sterility / 100), 0, 1) * 0.1

		if NTCS.HF.Chance(sepsischance) then
			-- oops...
			NTCS_SurgeryPlus.TriggerUnsterilityEvent(character)
		end
	end

	-- artificial brain
	local NTHuman = NTCS.Human.getNTHumanFromCharacter(character)
	if NTCS.HF.HasAffliction(character, "artificialbrain") then
		NTHuman.SetSymptomTrue(character, "unconsciousness", 2)
	end
end

-- multipliers that are used outside of humanupdate are set here
function NTCS_SurgeryPlus.PostUpdateHuman(character)
	-- Compat.SetTag requires a NTHuman instance. Convert the current Character to NTHuman beforehand.
    local NTHuman = NTCS.Human.getNTHumanFromCharacter(character)

	-- preventative permit talent
	if NTCS.HF.HasAffliction(character, "preventativepermit") then
		NTCS.NTC.SetMultiplier(character, "anyfracturechance", 0.5)
		NTCS.NTC.SetMultiplier(character, "pneumothoraxchance", 0.5)
		NTCS.NTC.SetMultiplier(character, "tamponadechance", 0.5)
		NTCS.NTC.SetMultiplier(character, "traumamputatechance", 0.5)
	end

	-- rinse and repeat talent
	if NTCS.HF.HasTalent(character, "ntsp_ultrasoniccleaner") then
		NTCS.NTC.SetMultiplier(character, "drainageconsumechance", 0)
		NTCS.NTC.SetMultiplier(character, "balloonconsumechance", 0)
		NTCS.NTC.SetMultiplier(character, "needleconsumechance", 0)
	end

	-- medical licence talent
	if NTCS.HF.HasTalent(character, "ntsp_brucereitzperk") then
		NTHuman.Tags:SetTag(character, "organssellforfull")
		NTCS.NTC.SetMultiplier(character, "organrejectionchance", 0)
	end
end

-- this function can be overriden by other mods
-- nudge nudge, wink wink
function NTCS_SurgeryPlus.TriggerUnsterilityEvent(character)
	NTCS.HF.AddAffliction(character, "sepsis", 1)
end
