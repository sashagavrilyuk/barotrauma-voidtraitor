NTCS_Cybernetics.ConfigData = {
	
	NTCS_Cybernetics_waterDamage = {
		name = "ntconfigname.waterDamage",
		description = "ntconfigdescription.waterDamage",
		default = 1,
		range = { 0, 5 },
		type = "float",
		difficultyCharacteristics = { multiplier = 0.5, max = 2 },
		group = true,
	},

	NTCS_Cybernetics_cyberpsychosisChance = {
		name = "ntconfigname.cyberpsychosisChance",
		description = "ntconfigdescription.cyberpsychosisChance",
		default = 1,
		range = { 0, 1 },
		type = "float",
		difficultyCharacteristics = { multiplier = 0.5, max = 2 },
		group = true,
	},

	NTCS_Cybernetics_cyberarmSpeed = {
		name = "ntconfigname.cyberarmSpeed",
		description = "ntconfigdescription.cyberarmSpeed",
		default = 1,
		range = { 0, 2 },
		type = "float",
		difficultyCharacteristics = { multiplier = 0.5, max = 2 },
		group = true,
	},
	
	NTCS_Cybernetics_cyberlegSpeed = {
		name = "ntconfigname.cyberlegSpeed",
		description = "ntconfigdescription.cyberlegSpeed",
		default = 1,
		range = { 0, 2 },
		type = "float",
		difficultyCharacteristics = { multiplier = 0.5, max = 2 },
		group = true,
	},
}

NTCS.Config.AddConfigOptions(NTCS_Cybernetics)
