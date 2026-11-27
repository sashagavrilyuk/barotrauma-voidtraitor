NTCS_SurgeryPlus.ConfigData = {
	NTCS_SurgeryPlus_enableSurgicalInfection = {
		name = "ntconfigname.enableSurgicalInfection",
		description = "ntconfigdescription.enableSurgicalInfection",
		default = true,
		type = "bool",
	},

	NTCS_SurgeryPlus_enableSurgerySkill = { 
		name = "ntconfigname.enableSurgerySkill",
		description = "ntconfigdescription.enableSurgerySkill",
		default = true, 
		type = "bool" },
	
	-- NT_beepboop = {
	-- 	name = "fractures remove casts!",
	-- 	default = true,
	-- 	type = "bool",
	-- 	difficultyCharacteristics = { multiplier = 0.5 },
	-- 	description = "when receiving damage that would cause a fracture, remove plaster casts on the limb",
	-- },
}

NTCS.Config.AddConfigOptions(NTCS_SurgeryPlus)
