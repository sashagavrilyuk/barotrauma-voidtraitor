local statLoader = NTCS.StatLoader(NTCS_Nanite.Name)

statLoader:Register(NTCS.StatBool("naniteEnoughBattery", false, function (C, dT)
    return C:GetAfflictionStrength("nanitebattery") > 1
end))