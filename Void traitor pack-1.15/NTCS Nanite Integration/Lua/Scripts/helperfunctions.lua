

function NTCS_Nanite.addAfflictionAllLimbs(character, affliction, strength)
    for _,limb in pairs(NTCS.HF.LimbsToCheck) do
        character:AddAfflictionLimb(affliction, limb, strength)
    end
end

function NTCS_Nanite.downBattery(ntHuman, amount)

    local currentStrength = ntHuman:GetAfflictionStrength("nanitebattery")

    local multiplier = NTCS.Config.Get("NTCS_Nanite_batteryDecayMultiplier", 1)

    -- TODO: get config working
    ntHuman:SetAffliction("nanitebattery", math.max(currentStrength - amount * multiplier, 1))
end