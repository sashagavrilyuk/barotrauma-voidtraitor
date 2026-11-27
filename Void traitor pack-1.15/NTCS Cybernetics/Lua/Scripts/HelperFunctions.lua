-- This file contains a bunch of useful functions that see heavy use in the other scripts.
NTCS_Cybernetics.HF = {} -- Helperfunctions

function NTCS_Cybernetics.HF.LimbIsCyber(character, limbtype)
	return NTCS.HF.HasAfflictionLimb(character, "ntc_cyberlimb", NTCS.HF.NormalizeLimbType(limbtype), 0.1)
end

function NTCS_Cybernetics.UncyberifyLimb(character, limbtype)
	limbtype = NTCS.HF.NormalizeLimbType(limbtype)

	NTCS.HF.SetAfflictionLimb(character, "ntc_cyberlimb", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_cyberarm", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_cyberleg", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_legspeed", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_armspeed", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_waterproof", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_loosescrews", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_damagedelectronics", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_bentmetal", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "ntc_materialloss", limbtype, 0)

	if limbtype == LimbType.RightArm then
		NTCS.HF.SetAffliction(character, "ra_cyber", 0)
	elseif limbtype == LimbType.LeftArm then
		NTCS.HF.SetAffliction(character, "la_cyber", 0)
	elseif limbtype == LimbType.RightLeg then
		NTCS.HF.SetAffliction(character, "rl_cyber", 0)
	elseif limbtype == LimbType.LeftLeg then
		NTCS.HF.SetAffliction(character, "ll_cyber", 0)
	end
end

function NTCS_Cybernetics.CyberifyLimb(character, limbtype, iswaterproof)
	if limbtype == LimbType.RightArm then
		NTCS.HF.SetAffliction(character, "ra_cyber", 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_cyberarm", limbtype, 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_armspeed", limbtype, 100 * NTCS.Config.Get("NTCS_Cybernetics_cyberarmSpeed", 1))
		if iswaterproof == true then NTCS.HF.SetAfflictionLimb(character, "ntc_waterproof", limbtype, 100) end
	elseif limbtype == LimbType.LeftArm then
		NTCS.HF.SetAffliction(character, "la_cyber", 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_cyberarm", limbtype, 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_armspeed", limbtype, 100 * NTCS.Config.Get("NTCS_Cybernetics_cyberarmSpeed", 1))
		if iswaterproof == true then NTCS.HF.SetAfflictionLimb(character, "ntc_waterproof", limbtype, 100) end
	elseif limbtype == LimbType.RightLeg then
		NTCS.HF.SetAffliction(character, "rl_cyber", 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_cyberleg", limbtype, 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_legspeed", limbtype, 100 * NTCS.Config.Get("NTCS_Cybernetics_cyberlegSpeed", 1))
		if iswaterproof == true then NTCS.HF.SetAfflictionLimb(character, "ntc_waterproof", limbtype, 100) end
	elseif limbtype == LimbType.LeftLeg then
		NTCS.HF.SetAffliction(character, "ll_cyber", 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_cyberleg", limbtype, 100)
		NTCS.HF.SetAfflictionLimb(character, "ntc_legspeed", limbtype, 100 * NTCS.Config.Get("NTCS_Cybernetics_cyberlegSpeed", 1))
		if iswaterproof == true then NTCS.HF.SetAfflictionLimb(character, "ntc_waterproof", limbtype, 100) end
	end

	-- get rid of all the flesh-only stuff

	NTCS.HF.ArteryCutLimb(character, limbtype, -1000)
	NTCS.HF.BreakLimb(character, limbtype, -1000)
	NTCS.HF.DislocateLimb(character, limbtype, -1000)
	NTCS.HF.SetAfflictionLimb(character, "amputation_nt", limbtype, 0)

	NTCS.HF.SetAfflictionLimb(character, "tourniqueted", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "surgeryincision", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "clampedbleeding", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "drilledbones", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "retractedskin", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "suturedi", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "suturedw", limbtype, 0)

	NTCS.HF.SetAfflictionLimb(character, "internaldamage", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "burn", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "gunshotwound", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "bitewounds", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "explosiondamage", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "bleeding", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "lacerations", limbtype, 0)
	NTCS.HF.SetAfflictionLimb(character, "blunttrauma", limbtype, 0)

	NTCS.HF.SetAfflictionLimb(character, "sawedbones", limbtype, 0)

	-- do the thing

	NTCS.HF.SetAfflictionLimb(character, "ntc_cyberlimb", limbtype, 100)
	NTCS.HF.RegenerateLimb(character, limbtype, character)
end

NTCS_Cybernetics.HF.GetAllCyberDamages = function(targetCharacter, limbtype)
	return {
		ntc_bentmetal = NTCS.HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "ntc_bentmetal", 0),
		ntc_materialloss = NTCS.HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "ntc_materialloss", 0),
		ntc_damagedelectronics = NTCS.HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "ntc_damagedelectronics", 0),
		ntc_loosescrews = NTCS.HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "ntc_loosescrews", 0),
	}
end

NTCS_Cybernetics.HF.SetAllCyberDamages = function(targetCharacter, limbtype, oldCyberDamages)
	for damageType, damageAmount in pairs(oldCyberDamages) do
		NTCS.HF.SetAfflictionLimb(targetCharacter, damageType, limbtype, damageAmount)
	end
end

function NTCS_Cybernetics.ConvertDamageTypes(character, limbtype, IncomingDamage)
	-- Instead of OnDamaged letting afflictions stick for a single tick, intercept them INSTANTLY!! so it doesnt flash the health bar constantly
	IncomingDamage = IncomingDamage or {}

	if NTCS_Cybernetics.HF.LimbIsCyber(character, limbtype) then
		-- /// fetch stats ///

		local AfflictionsAlreadyOnLimb = {}

		-- Lets say this function is ran by OnDamaged while HumanUpdate hasn't ticked yet to convert already present damage
		-- We may as well do that right now since we're already converting!
		-- Combine Incoming + Present damage and convert!
		local function GetTotalDamageOfType(id)
			AfflictionsAlreadyOnLimb[id] = NTCS.HF.GetAfflictionStrengthLimb(character, limbtype, id, 0)
			return AfflictionsAlreadyOnLimb[id] + (IncomingDamage[id] or 0)
		end

		-- physical damage types
		local bleeding = GetTotalDamageOfType("bleeding")
		local burn = GetTotalDamageOfType("burn")
		local lacerations = GetTotalDamageOfType("lacerations")
		local gunshotwound = GetTotalDamageOfType("gunshotwound")
		local bitewounds = GetTotalDamageOfType("bitewounds")
		local explosiondamage = GetTotalDamageOfType("explosiondamage")
		local blunttrauma = GetTotalDamageOfType("blunttrauma")
		local internaldamage = GetTotalDamageOfType("internaldamage")
		local foreignbody = GetTotalDamageOfType("foreignbody")

		-- cyber stats
		local loosescrews = NTCS.HF.GetAfflictionStrengthLimb(character, limbtype, "ntc_loosescrews", 0)
		local prevloosescrews = loosescrews
		local damagedelectronics = NTCS.HF.GetAfflictionStrengthLimb(character, limbtype, "ntc_damagedelectronics", 0)
		local prevdamagedelectronics = damagedelectronics
		local bentmetal = NTCS.HF.GetAfflictionStrengthLimb(character, limbtype, "ntc_bentmetal", 0)
		local prevbentmetal = bentmetal
		local materialloss = NTCS.HF.GetAfflictionStrengthLimb(character, limbtype, "ntc_materialloss", 0)
		local prevmaterialloss = materialloss

		-- calculate damage conversion

		local function damageChance(val, chance)
			if val > 0.01 and NTCS.HF.Chance(chance) then return val end
			return 0
		end

		loosescrews = loosescrews
			+ 1
				* (0.25 * damageChance(lacerations, 0.75) + 1 * damageChance(explosiondamage, 0.8) + 0.5 * damageChance(
					blunttrauma,
					0.5
				) + 1 * damageChance(internaldamage, 0.75) + 0.5 * damageChance(bitewounds, 0.5) + 0.75 * damageChance(
					foreignbody,
					0.75
				))

		damagedelectronics = damagedelectronics
			+ 0.5
				* (1 + prevmaterialloss / 50)
				* (2 * damageChance(burn, 0.75) + 0.75 * damageChance(gunshotwound, 0.85) + 0.25 * damageChance(
					bitewounds,
					0.5
				) + 0.5 * damageChance(explosiondamage, 0.5) + 1 * damageChance(blunttrauma, 0.5) + 1 * damageChance(
					internaldamage,
					0.75
				) + 0.75 * damageChance(foreignbody, 0.75))

		bentmetal = bentmetal
			+ 1
				* (0.25 * damageChance(burn, 0.85) + 0.25 * damageChance(lacerations, 0.5) + 0.5 * damageChance(
					bitewounds,
					0.5
				) + 1 * damageChance(explosiondamage, 0.85) + 2 * damageChance(blunttrauma, 0.75))

		materialloss = materialloss
			+ (1 + prevloosescrews / 50)
				* (0.5 * damageChance(lacerations, 0.75) + 0.8 * damageChance(gunshotwound, 0.8) + 0.6 * damageChance(
					bitewounds,
					0.7
				) + 1 * explosiondamage + 0.5 * damageChance(foreignbody, 0.8))

		-- /// apply changes ///

		-- remove only what is really on the limb (incoming damage was already zeroed in the hook)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "burn", 0, AfflictionsAlreadyOnLimb.burn, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "bleeding", 0, AfflictionsAlreadyOnLimb.bleeding, 0, 100)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "lacerations", 0, AfflictionsAlreadyOnLimb.lacerations, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "gunshotwound", 0, AfflictionsAlreadyOnLimb.gunshotwound, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "bitewounds", 0, AfflictionsAlreadyOnLimb.bitewounds, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "explosiondamage", 0, AfflictionsAlreadyOnLimb.explosiondamage, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "blunttrauma", 0, AfflictionsAlreadyOnLimb.blunttrauma, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "internaldamage", 0, AfflictionsAlreadyOnLimb.internaldamage, 0, 200)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "foreignbody", 0, AfflictionsAlreadyOnLimb.foreignbody, 0, 100)

		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "ntc_loosescrews", loosescrews, prevloosescrews, 0, 100)
		NTCS.HF.ApplyAfflictionChangeLimb(
			character,
			limbtype,
			"ntc_damagedelectronics",
			damagedelectronics,
			prevdamagedelectronics,
			0,
			100
		)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "ntc_bentmetal", bentmetal, prevbentmetal, 0, 100)
		NTCS.HF.ApplyAfflictionChangeLimb(character, limbtype, "ntc_materialloss", materialloss, prevmaterialloss, 0, 100)

		NTCS.HF.DislocateLimb(character, limbtype, -1000)
		NTCS.HF.BreakLimb(character, limbtype, -1000)
		NTCS.HF.ArteryCutLimb(character, limbtype, -1000)

		NTCS.HF.SetAfflictionLimb(character, "tourniqueted", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "surgeryincision", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "clampedbleeding", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "drilledbones", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "retractedskin", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "suturedi", limbtype, 0)
		NTCS.HF.SetAfflictionLimb(character, "suturedw", limbtype, 0)

		NTCS.HF.SetAfflictionLimb(character, "amputation_nt", limbtype, 0)
	end
end
