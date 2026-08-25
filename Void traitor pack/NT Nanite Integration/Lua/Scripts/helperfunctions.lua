NTNan.Limbs = {LimbType.Head, LimbType.Torso, LimbType.LeftArm, LimbType.LeftLeg, LimbType.RightArm, LimbType.RightLeg}

NTNan.Afflictions = {}
NTNan.AfflictionsCustom = {}
NTNan.AfflictionsHealing = {}

-- If the Nanite has custom properties
function NTNan.RegisterCustomAffliction(afflictionID, tickingFunction, decayFunction)

    local notPresent = true
    for e in NTNan.Afflictions do
        if e == afflictionID then
            notPresent = false
            break
        end
    end

    if notPresent then
        table.insert(NTNan.Afflictions, afflictionID)
    end
    
    NTNan.AfflictionsCustom[afflictionID] = {tickingFunction, decayFunction}
end

-- If the Nanite only heals
function NTNan.RegisterHealingAffliction(afflictionID, levels, decayFunction)

    local notPresent = true
    for e in NTNan.Afflictions do
        if e == afflictionID then
            notPresent = false
            break
        end
    end

    if notPresent then
        table.insert(NTNan.Afflictions, afflictionID)
    end
    
    NTNan.AfflictionsHealing[afflictionID] = {levels, decayFunction}
end

-- If the Nanite properties are only defined in the XML and doesn't need lua code
function NTNan.RegisterXMLAffliction(afflictionID)
    local notPresent = true
    for e in NTNan.Afflictions do
        if e == afflictionID then
            notPresent = false
            break
        end
    end

    if notPresent then
        table.insert(NTNan.Afflictions, afflictionID)
    end
end

function NTNan.applyHeals(character, healStats)


    for _,hl in pairs(healStats)do

        local affName = hl[1]
        local str = hl[2]
        local isLocal = hl[3]

        if isLocal == nil then
            HF.AddAffliction(character, affName, -1*str*NT.Deltatime)
        else
            for _,limb in pairs(NTNan.Limbs) do
                HF.AddAfflictionLimb(character, affName, limb, -1*str*NT.Deltatime)
            end
            
        end
    end

end

function NTNan.hasEnoughPrecursors(character, afflictions)

    local nanitesCount = 0
    
    for aff in afflictions do
        if aff == "naniteremover" or aff == "precursor" or aff == "nanitedecay" then
            goto continue
        end

        if aff == "oxybloodnanite" then
            nanitesCount = nanitesCount + 2*HF.GetAfflictionStrength(character, aff)
            goto continue
        end

        nanitesCount = nanitesCount + HF.GetAfflictionStrength(character, aff)

        ::continue::
    end

    if nanitesCount == 0 then return true end

    if not HF.HasAffliction(character, "precursor") then
        return false
    end

    local precursorCount = HF.GetAfflictionStrength(character, "precursor")
    if nanitesCount > precursorCount then
        return false
    end

    return true

end

function NTNan.GetAfflictionHeals(healsStats, tier)

    local heals = {}

    for key, i in ipairs(healsStats) do

        for _,value in pairs(i) do
            table.insert(heals, value)
        end

        if key == math.floor(tier) then return heals end

    end

    return {}
end

function NTNan.GetAllNanAfflictions(character)

    local l = {}

    for e in NTNan.Afflictions do
        if HF.HasAffliction(character, e) then table.insert(l, e) end
    end

    return l
end

