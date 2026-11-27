local itemLoader = NTCS.ItemFunctionLoader("NTCS_SurgeryPlus")

local endocrineTalents = {
	"aggressiveengineering", "crisismanagement", "cannedheat", "doubleduty", "firemanscarry",
	"fieldmedic", "multitasker", "aceofalltrades", "stillkicking", "drunkensailor",
	"trustedcaptain", "downwiththeship", "physicalconditioning", "beatcop", "commando",
	"justascratch", "intheflow", "collegeathletics",
}

local function applyEndocrineBoost(character)
	local info = character.Info
	if info == nil or info.Job == nil then return end

	local tree = TalentTree.JobTalentTrees[info.Job.Prefab.Identifier]
	if tree == nil then return end

	local unavailable = {}
	for talent in tree.AllTalentIdentifiers do
		unavailable[talent.Value] = true
	end
	for talent in info.UnlockedTalents do
		unavailable[talent.Value] = true
	end

	local candidates = {}
	for _, talent in ipairs(endocrineTalents) do
		if not unavailable[talent] then
			candidates[#candidates + 1] = talent
		end
	end
	if #candidates > 0 then
		character.GiveTalent(Identifier(candidates[math.random(#candidates)]), true)
	end
end

local experimentalEffects = {
	-- resistances and buffs
	vigor = {
		weight = 3,
		afflictions = { { identifier = "strengthen", minstrength = 200, maxstrength = 400, limbspecific = false } },
	},
	haste = {
		weight = 3,
		afflictions = { { identifier = "haste", minstrength = 200, maxstrength = 400, limbspecific = false } },
	},
	psychosisresistance = {
		weight = 2,
		afflictions = {
			{ identifier = "psychosisresistance", minstrength = 200, maxstrength = 400, limbspecific = false },
		},
	},
	huskinfectionresistance = {
		weight = 2,
		afflictions = {
			{ identifier = "huskinfectionresistance", minstrength = 200, maxstrength = 400, limbspecific = false },
		},
	},
	paralysisresistance = {
		weight = 2,
		afflictions = {
			{ identifier = "paralysisresistance", minstrength = 300, maxstrength = 600, limbspecific = false },
		},
	},
	analgesia = {
		weight = 1,
		afflictions = {
			{ identifier = "analgesia", minstrength = 20, maxstrength = 100, limbspecific = false },
		},
	},
	anesthesia = {
		weight = 0.5,
		afflictions = {
			{ identifier = "anesthesia", minstrength = 1, maxstrength = 100, limbspecific = false },
		},
	},
	ointmented = {
		weight = 1,
		afflictions = {
			{ identifier = "ointmented", minstrength = 20, maxstrength = 100, limbspecific = true },
		},
	},
	combatstimulant = {
		weight = 2,
		afflictions = { { identifier = "combatstimulant", minstrength = 30, maxstrength = 100, limbspecific = false } },
	},
	pressurestabilized = {
		weight = 1,
		afflictions = {
			{ identifier = "pressurestabilized", minstrength = 30, maxstrength = 100, limbspecific = false },
		},
	},
	-- other positive
	fullheal = {
		weight = 5,
		afflictions = {
			{ identifier = "bleeding", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "burn", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "explosiondamage", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "gunshotwound", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "bitewounds", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "lacerations", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "organdamage", minstrength = -20, maxstrength = -100, limbspecific = false },
			{ identifier = "neurotrauma", minstrength = -20, maxstrength = -100, limbspecific = false },
			{ identifier = "bloodloss", minstrength = -20, maxstrength = -100, limbspecific = false },
			{ identifier = "blunttrauma", minstrength = -20, maxstrength = -100, limbspecific = true },
			{ identifier = "sepsis", minstrength = -200, maxstrength = -200, limbspecific = false },
		},
	},
	-- damage
	bleeding = {
		weight = 1,
		afflictions = { { identifier = "bleeding", minstrength = 30, maxstrength = 80, limbspecific = true } },
	},
	burn = {
		weight = 1,
		afflictions = { { identifier = "burn", minstrength = 5, maxstrength = 20, limbspecific = true } },
	},
	explosiondamage = {
		weight = 1,
		afflictions = { { identifier = "explosiondamage", minstrength = 5, maxstrength = 20, limbspecific = true } },
	},
	gunshotwound = {
		weight = 1,
		afflictions = {
			{ identifier = "gunshotwound", minstrength = 5, maxstrength = 20, limbspecific = true },
		},
	},
	bitewounds = {
		weight = 1,
		afflictions = {
			{ identifier = "bitewounds", minstrength = 5, maxstrength = 20, limbspecific = true },
		},
	},
	lacerations = {
		weight = 1,
		afflictions = {
			{ identifier = "lacerations", minstrength = 5, maxstrength = 20, limbspecific = true },
		},
	},
	organdamage = {
		weight = 1,
		afflictions = {
			{ identifier = "organdamage", minstrength = 5, maxstrength = 20, limbspecific = false },
		},
	},
	blunttrauma = {
		weight = 1,
		afflictions = {
			{ identifier = "blunttrauma", minstrength = 5, maxstrength = 20, limbspecific = true },
		},
	},
	-- other negative
	stun = {
		weight = 1,
		afflictions = { { identifier = "stun", minstrength = 2, maxstrength = 15, limbspecific = false } },
	},
}

-- Artificial Brain
local ArtificialBrain = function(d)
	local item = d.item
    local usingCharacter = d.user.Human
    local targetCharacter = d.target.Human
    local targetLimb = d.targetLimb

	local limbtype = targetLimb.type

	if NTCS.HF.HasAffliction(targetCharacter, "brainremoved", 1) and limbtype == LimbType.Head then
		NTCS.HF.SetAffliction(targetCharacter, "neurotrauma", 0, usingCharacter)
		NTCS.HF.SetAffliction(targetCharacter, "brainremoved", 0, usingCharacter)
		NTCS.HF.SetAffliction(targetCharacter, "artificialbrain", 100, usingCharacter)

		NTCS.HF.RemoveItem(item)
	end
end

itemLoader:Register("artificialbrain", ArtificialBrain)

-- Experimental Treatment
local ExperimentalTreatment = function(d)
	local item = d.item
    local usingCharacter = d.user.Human
    local targetCharacter = d.target.Human
    local targetLimb = d.targetLimb

	local limbtype = targetLimb.type

	-- endocrine booster
	if NTCS.HF.Chance(1 / 25) then
		applyEndocrineBoost(targetCharacter)
	end

	local weightsum = 0
	for key, val in pairs(experimentalEffects) do
		weightsum = weightsum + val.weight
	end

	local triggerNewEffect = true
	while triggerNewEffect do
		triggerNewEffect = NTCS.HF.Chance(0.5)

		local weightpick = math.random() * weightsum
		local currentweightsum = 0

		for key, val in pairs(experimentalEffects) do
			currentweightsum = currentweightsum + val.weight
			if currentweightsum > weightpick then
				-- picked effect: val

				for _, aff in ipairs(val.afflictions) do
					if aff.limbspecific then
						NTCS.HF.AddAfflictionLimb(
							targetCharacter,
							aff.identifier,
							limbtype,
							NTCS.HF.Lerp(aff.minstrength, aff.maxstrength, math.random()),
							usingCharacter
						)
					else
						NTCS.HF.AddAffliction(
							targetCharacter,
							aff.identifier,
							NTCS.HF.Lerp(aff.minstrength, aff.maxstrength, math.random()),
							usingCharacter
						)
					end
				end

				break
			end
		end
	end

	NTCS.HF.RemoveItem(item)
	NTCS.HF.GiveItem(targetCharacter, "ntsfx_syringe")
end

itemLoader:Register("experimentaltreatment", ExperimentalTreatment)

-- ========================================== TRIAGE TAGS (MANUAL, AUTOMATIC) ==========================================
local function IsTriageTagged(character)
	return NTCS.HF.HasAffliction(character, "triagetag_green")
		or NTCS.HF.HasAffliction(character, "triagetag_yellow")
		or NTCS.HF.HasAffliction(character, "triagetag_red")
		or NTCS.HF.HasAffliction(character, "triagetag_black")
end

local function RemoveTriageTag(character)
	NTCS.HF.SetAffliction(character, "triagetag_green", 0)
	NTCS.HF.SetAffliction(character, "triagetag_yellow", 0)
	NTCS.HF.SetAffliction(character, "triagetag_red", 0)
	NTCS.HF.SetAffliction(character, "triagetag_black", 0)
end

-- CuttableAfflictions is a List. Register it so Lua can fuck with it.
LuaUserData.RegisterType("System.Collections.Generic.List`1[System.String]")

NTCS.Items.CuttableAfflictions:Add("triagetag_green")
NTCS.Items.CuttableAfflictions:Add("triagetag_yellow")
NTCS.Items.CuttableAfflictions:Add("triagetag_red")
NTCS.Items.CuttableAfflictions:Add("triagetag_black")

-- Triage Tag (Manual)
local TriageTagManual = function(d)
	local item = d.item
    local usingCharacter = d.user.Human
    local targetCharacter = d.target.Human
    local targetLimb = d.targetLimb

	local limbtype = NTCS.HF.NormalizeLimbType(targetLimb.type)

	local alreadyTagged = IsTriageTagged(targetCharacter)

	RemoveTriageTag(targetCharacter)

	if limbtype == LimbType.LeftLeg or limbtype == LimbType.RightLeg then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_green", 100)

	elseif limbtype == LimbType.LeftArm or limbtype == LimbType.RightArm then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_yellow", 100)

	elseif limbtype == LimbType.Torso then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_red", 100)

	else
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_black", 100)
	end

	if not alreadyTagged then
		NTCS.HF.RemoveItem(item)
	end
end

itemLoader:Register("manualtriagetag", TriageTagManual)

-- Triage Tag (Automatic)
local TriageTagAutomatic = function(d)
	local item = d.item
    local usingCharacter = d.user.Human
    local targetCharacter = d.target.Human
    local targetLimb = d.targetLimb

	local limbtype = NTCS.HF.NormalizeLimbType(targetLimb.type)

	local alreadyTagged = IsTriageTagged(targetCharacter)

	RemoveTriageTag(targetCharacter)

	local fuckedness = 0

	local charHealth = targetCharacter.CharacterHealth

	-- vitality
	local healthFraction = charHealth.Vitality / charHealth.MaxVitality
	fuckedness = math.max(fuckedness, (-healthFraction + 1) * 100)

	-- fractures
	if
		NTCS.HF.HasAffliction(targetCharacter, "fracturedextremity")
		or NTCS.HF.HasAffliction(targetCharacter, "fracturedskull")
		or NTCS.HF.HasAffliction(targetCharacter, "fracturedneck")
		or NTCS.HF.HasAffliction(targetCharacter, "fracturedribs")
	then
		fuckedness = math.max(fuckedness + 5, 20)
	end

	-- arterial cuts
	if
		NTCS.HF.HasAffliction(targetCharacter, "arterialcut")
		or NTCS.HF.HasAffliction(targetCharacter, "carotidarterialcut")
		-- or NTCS.HF.HasAffliction(targetCharacter, "n_arterialcut")
		or NTCS.HF.HasAffliction(targetCharacter, "aorticrupture")
	then
		if not NTCS.HF.HasAffliction(targetCharacter, "tourniqueted") then
			fuckedness = math.max(fuckedness + 10, 100)
		else
			fuckedness = math.max(fuckedness + 5, 50)
		end
	end

	-- rads
	local rads = NTCS.HF.GetAfflictionStrength(targetCharacter, "radiationsickness", 0)
	fuckedness = math.max(fuckedness + math.max(0, rads - 25) * 0.2, math.min(rads, 25, 0) * 1.5)

	-- hypoxemia
	local hypoxemia = NTCS.HF.GetAfflictionStrength(targetCharacter, "hypoxemia", 0)
	fuckedness = math.max(fuckedness + hypoxemia * 0.2, NTCS.HF.Clamp(hypoxemia * 2, 0, 100))

	-- bloodloss
	local bloodloss = NTCS.HF.GetAfflictionStrength(targetCharacter, "bloodloss", 0)
	fuckedness = math.max(fuckedness + bloodloss * 0.1, NTCS.HF.Clamp(bloodloss, 0, 100))

	if fuckedness < 5 then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_green", 100)
	elseif fuckedness < 60 then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_yellow", 100)
	elseif fuckedness < 200 then
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_red", 100)
	else
		NTCS.HF.SetAffliction(targetCharacter, "triagetag_black", 100)
	end

	if not alreadyTagged then
		NTCS.HF.RemoveItem(item)
	end
end

itemLoader:Register("triagetag", TriageTagAutomatic)