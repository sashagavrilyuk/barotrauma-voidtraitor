local suitMarkers = {
    { item = "divingsuit", affliction = AfflictionPrefab.Prefabs["huskregularsuit"] },
    { item = "combatdivingsuit", affliction = AfflictionPrefab.Prefabs["huskcombatsuit"] },
    { item = "abyssdivingsuit", affliction = AfflictionPrefab.Prefabs["huskabysssuit"] },
    { item = "pucs", affliction = AfflictionPrefab.Prefabs["huskpucssuit"] },
    { item = "slipsuit", affliction = AfflictionPrefab.Prefabs["huskslipsuit"] }
}

local function checkDiver(character)
    if character == nil or character.Removed then return end
    if string.lower(character.SpeciesName.Value) ~= "humanhuskdiver" then return end
    if not character.Enabled then
        Timer.Wait(function() checkDiver(character) end, 250)
        return
    end

    local health = character.CharacterHealth
    for i = 1, #suitMarkers do
        if health.GetAfflictionStrengthByIdentifier(suitMarkers[i].affliction.Identifier) > 0 then
            return
        end
    end

    if character.PressureProtection >= 100 and character.Inventory ~= nil then
        for i = 1, #suitMarkers do
            local marker = suitMarkers[i]
            for item in character.Inventory.AllItems do
                if item.Prefab.Identifier.Value == marker.item then
                    health.ApplyAffliction(character.AnimController.MainLimb, marker.affliction.Instantiate(100))
                    return
                end
            end
        end
    end

    Timer.Wait(function() checkDiver(character) end, 250)
end

local function registerDiver(character)
    if character ~= nil and string.lower(character.SpeciesName.Value) == "humanhuskdiver" then
        Timer.Wait(function() checkDiver(character) end, 250)
    end
end

Hook.Add("character.created", "VoidTraitorPack.EnhancedHusks.DiverSuit", registerDiver)

for character in Character.CharacterList do
    registerDiver(character)
end
