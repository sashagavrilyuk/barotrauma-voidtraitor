NTCS_Nanite.ConfigData = {

	NTCS_Nanite_emergencyEnergyAmount = {
		name = "ntconfigname.emergencyEnergyAmount",
		description = "ntconfigdescription.emergencyEnergyAmount",
		default = 20,
		range = { 0, 200 },
		type = "float",
		group = true,
	},

	NTCS_Nanite_batteryDecayMultiplier = {
		name = "ntconfigname.batteryDecayMultiplier",
		description = "ntconfigdescription.batteryDecayMultiplier",
		default = 1,
		range = { 0, 5 },
		type = "float",
		group = true,
	}
}

NTCS.Config.AddConfigOptions(NTCS_Nanite)
