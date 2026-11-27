local itemLoader = NTCS.ItemFunctionLoader(NTCS_Nanite.Name)

itemLoader:Register("nanitebatteryimplant", function (d)

    local item = d.item
    local usingCharacter = d.user
    local targetCharacter = d.target
    local targetLimb = d.targetLimb

    -- Not usable in stasis
    if targetCharacter:GetBoolStat("stasis", false) then return end

    -- Only usable on the Torso
    if targetLimb.type ~= LimbType.Torso then return end

    -- Not usable if already there
    if targetCharacter:HasAffliction("nanitebattery") then return end

    if not targetCharacter:HasAfflictionLimb("retractedskin", targetLimb.type, 99) then return end

    if NTCS.HF.GetSurgerySkillRequirementMet(usingCharacter.Human, 80) then

        targetCharacter:SetAffliction("nanitebattery", 200)

        Entity.Spawner.AddItemToRemoveQueue(item)
    else
        -- Failed
        targetCharacter:AddAffliction("heartdamage", 20)
        targetCharacter:AddAfflictionLimb("bleeding", LimbType.Torso, 10, usingCharacter)
    end

end)

itemLoader:Register("fulguriumbatterycell", function (d)

    local item = d.item
    local usingCharacter = d.user
    local targetCharacter = d.target
    local targetLimb = d.targetLimb

    -- Not usable in stasis
    if targetCharacter:GetBoolStat("stasis", false) then return end

    -- Only usable on the Torso
    if targetLimb.type ~= LimbType.Torso then return end

    -- Not usable if already there
    if not targetCharacter:HasAffliction("nanitebattery") then return end

    if not targetCharacter:HasAfflictionLimb("retractedskin", targetLimb.type, 99) then return end

    local condition = item.Condition

    local affCondition = targetCharacter:GetAfflictionStrength("nanitebattery")

    item.Condition = affCondition

    targetCharacter:SetAffliction("nanitebattery", condition)

end)

itemLoader:Register("emergencyenergyinjection", function (d)

    local item = d.item
    local usingCharacter = d.user
    local targetCharacter = d.target
    local targetLimb = d.targetLimb

    -- Not usable in stasis
    if targetCharacter:GetBoolStat("stasis", false) then return end

    -- TODO: make it customizable in the config
    if targetCharacter:HasAffliction("nanitebattery") then targetCharacter:AddAffliction("nanitebattery", NTCS.Config.Get("NTCS_Nanite_emergencyEnergyAmount", 20)) end

    local mult = 1
    if NTCS.HF.GetSkillRequirementMet(usingCharacter.Human, "Medical", 40) then mult = 1.5 end

    targetCharacter:AddAffliction("heartdamage", 20 * mult)
    targetCharacter:AddAffliction("electricshock", 100)

    targetCharacter:AddAfflictionLimb("burn", targetLimb.type, 15 * mult)

    Entity.Spawner.AddItemToRemoveQueue(item)

end)