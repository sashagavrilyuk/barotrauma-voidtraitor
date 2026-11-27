local convertedDamageTypes = {
    bleeding = true,
    blunttrauma = true,
    lacerations = true,
    burn = true,
    gunshotwound = true,
    bitewounds = true,
    explosiondamage = true,
    internaldamage = true,
    foreignbody = true,
}

local damageTypeSFXDict = {}
damageTypeSFXDict["blunttrauma"] = "ntcsfx_cyberblunt"
damageTypeSFXDict["lacerations"] = "ntcsfx_cyberblunt"
damageTypeSFXDict["burn"] = "ntcsfx_welding"
damageTypeSFXDict["gunshotwound"] = "ntcsfx_cyberblunt"
damageTypeSFXDict["bitewounds"] = "ntcsfx_cyberbite"
damageTypeSFXDict["explosiondamage"] = "ntcsfx_cyberblunt"
damageTypeSFXDict["internaldamage"] = "ntcsfx_cyberblunt"
damageTypeSFXDict["foreignbody"] = "ntcsfx_cyberblunt"

NTCS.NTC.AddOnDamagedHook(function(characterHealth, attackResult, hitLimb)
    local targetChar = characterHealth.Character
    if not NTCS_Cybernetics.HF.LimbIsCyber(targetChar, hitLimb.type) then return end

    local sfxidentifier = nil
    local IncomingDamage = {}
    local ShouldConvertToCyberAffliction = false

    -- Originally, you'd wait a tick before running ConvertDamageTypes. That meant for roughly 0.16 seconds you'd see the health bar of a character pop up;
    -- Since most Damage types afflicted have direct Vitality damage while Cybernetic damage types don't. After conversion, the health bar would flicker.
    -- This sucks! Instead, catch the damage and convert immediately instead of waiting.
    for _, value in pairs(attackResult.Afflictions) do
        local identifier = value.Prefab.Identifier.Value

        if value.Strength > 1 and convertedDamageTypes[identifier] then
            ShouldConvertToCyberAffliction = true
            sfxidentifier = damageTypeSFXDict[identifier] or sfxidentifier
            IncomingDamage[identifier] = (IncomingDamage[identifier] or 0) + value.Strength
            value.Strength = 0
        end
    end

    if ShouldConvertToCyberAffliction then
        if sfxidentifier ~= nil then NTCS.HF.GiveItem(targetChar, sfxidentifier) end
        NTCS_Cybernetics.ConvertDamageTypes(targetChar, hitLimb.type, IncomingDamage)
    end
end)
