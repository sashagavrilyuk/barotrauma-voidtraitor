local updateTimer = 0
local updateInterval = 0.25
local watcherRage = AfflictionPrefab.Prefabs["watcher'srage"]

local suitMarkers = {
    { item = "divingsuit", affliction = AfflictionPrefab.Prefabs["huskregularsuit"] },
    { item = "combatdivingsuit", affliction = AfflictionPrefab.Prefabs["huskcombatsuit"] },
    { item = "abyssdivingsuit", affliction = AfflictionPrefab.Prefabs["huskabysssuit"] },
    { item = "pucs", affliction = AfflictionPrefab.Prefabs["huskpucssuit"] },
    { item = "slipsuit", affliction = AfflictionPrefab.Prefabs["huskslipsuit"] }
}

local resolvedDivers = {}

Hook.Add("think", "VoidTraitorPack.EnhancedHusks.Update", function(deltaTime)
    updateTimer = updateTimer + (tonumber(deltaTime) or 0)
    if updateTimer < updateInterval then return end

    local elapsed = updateTimer
    updateTimer = 0
    local characters = {}
    local watchers = {}

    for character in Character.CharacterList do
        if character.Enabled and not character.Removed then
            characters[#characters + 1] = character

            local species = string.lower(character.SpeciesName.Value)
            if species == "watcherhusk" and not character.IsDead then
                watchers[#watchers + 1] = character
            elseif species == "humanhuskdiver" and not resolvedDivers[character] then
                local health = character.CharacterHealth
                local resolved = false
                for i = 1, #suitMarkers do
                    if health.GetAfflictionStrengthByIdentifier(suitMarkers[i].affliction.Identifier) > 0 then
                        resolved = true
                        break
                    end
                end

                if not resolved and character.PressureProtection >= 100 and character.Inventory ~= nil then
                    local present = {}
                    for item in character.Inventory.AllItems do
                        present[item.Prefab.Identifier.Value] = true
                    end
                    for i = 1, #suitMarkers do
                        local marker = suitMarkers[i]
                        if present[marker.item] then
                            health.ApplyAffliction(character.AnimController.MainLimb, marker.affliction.Instantiate(100))
                            resolved = true
                            break
                        end
                    end
                end

                if resolved then
                    resolvedDivers[character] = true
                end
            end
        end
    end

    for i = 1, #watchers do
        local watcher = watchers[i]
        local wx = watcher.WorldPosition.X
        local wy = watcher.WorldPosition.Y

        for j = 1, #characters do
            local target = characters[j]
            local dx = target.WorldPosition.X - wx
            local dy = target.WorldPosition.Y - wy
            local distanceSquared = dx * dx + dy * dy

            if distanceSquared < 25000000 then
                local amount = 5 * elapsed
                if distanceSquared < 2250000 and target.CurrentHull == nil then
                    amount = amount + 20 * elapsed
                end
                target.LastDamageSource = watcher
                target.CharacterHealth.ApplyAffliction(target.AnimController.MainLimb, watcherRage.Instantiate(amount))
            end
        end
    end
end)
