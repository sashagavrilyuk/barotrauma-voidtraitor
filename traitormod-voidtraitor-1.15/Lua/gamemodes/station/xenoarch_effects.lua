-- What an artifact's node does when its trigger happens, by the effect's id in config/station.lua (Xenoarch.Effects),
-- after SS14's old artifact effects (SS14 e9d13ea Resources/Prototypes/XenoArch/Effects). Each takes the artifact, its
-- entry in the config and the character who set it off, if any. Effects runs on the server; xenoarch.Fx shows the
-- clients what only they need to see.
local effects = {}

-- SS14's effect hints, which the analysis console shows for a node's effect
effects.Hints = {
    GoodFeeling = "mental", JunkSpawn = "creation", BananaSpawn = "creation", ChemicalPuddle = "biochemical",
    FloraSpawn = "creation", InstrumentSpawn = "creation", MonkeySpawn = "creation", Radiate = "release",
    Knock = "electricalinterference", ExplosionScary = "environment", RareMaterialSpawn = "creation",
    AngryCarpSpawn = "creation", FaunaSpawn = "creation", CashSpawn = "creation", Blink = "displacement",
    Emp = "electricalinterference", HealAll = "environment", RadiateStrong = "release", MaterialSpawn = "creation",
    Ignite = "release", Mitosis = "creation", Boom = "environment", Singulo = "destruction",
}

local function around(item, spread)
    return item.WorldPosition + Vector2(math.random(-spread, spread), math.random(0, spread))
end

local function charactersNear(item, range)
    local found = {}
    for character in Character.CharacterList do
        if not character.IsDead and Vector2.Distance(character.WorldPosition, item.WorldPosition) <= range then
            found[#found + 1] = character
        end
    end
    return found
end

local function spawnItems(item, entry)
    for _ = 1, math.random(1, entry.Max) do
        local id = entry.Items[math.random(#entry.Items)]
        if ItemPrefab.Prefabs.ContainsKey(id) then
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[id], around(item, 60))
        else
            Traitormod.Error("Xenoarch: no item " .. id)
        end
    end
end

local function spawnCreatures(item, entry)
    for _ = 1, math.random(1, entry.Max) do
        Entity.Spawner.AddCharacterToSpawnQueue(entry.Species[math.random(#entry.Species)], around(item, 60))
    end
end

local function afflict(item, entry)
    local prefab = AfflictionPrefab.Prefabs[entry.Affliction]
    for _, character in ipairs(charactersNear(item, entry.Range)) do
        character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, prefab.Instantiate(entry.Strength))
    end
end

-- the blast's damage on the server; the clients see it with no damage of their own
local function explode(item, entry, empStrength)
    Explosion(entry.Range, entry.Force or 0, entry.Damage or 0, entry.StructureDamage or 0, entry.Damage or 0, empStrength or 0).Explode(item.WorldPosition, item)
    Traitormod.Xenoarch.Fx(item, "explosion", entry.Range)
end

effects.GoodFeeling = function(item)
    local lines = Traitormod.Language.XenoarchFeelings
    for _, character in ipairs(charactersNear(item, 1000)) do
        local client = Traitormod.FindClientCharacter(character)
        if client ~= nil then Traitormod.SendMessage(client, lines[math.random(#lines)]) end
    end
end
effects.JunkSpawn = spawnItems
effects.BananaSpawn = spawnItems
effects.ChemicalPuddle = spawnItems
effects.FloraSpawn = spawnItems
effects.InstrumentSpawn = spawnItems
effects.RareMaterialSpawn = spawnItems
effects.MaterialSpawn = spawnItems
effects.MonkeySpawn = spawnCreatures
effects.AngryCarpSpawn = spawnCreatures
effects.FaunaSpawn = spawnCreatures
effects.Radiate = afflict
effects.RadiateStrong = afflict

effects.Knock = function(item, entry)
    for other in Item.ItemList do
        local door = other.GetComponentString("Door")
        if door ~= nil and not door.IsOpen and Vector2.Distance(other.WorldPosition, item.WorldPosition) <= entry.Range then
            door.TrySetState(true, false, true)
        end
    end
end

effects.ExplosionScary = function(item, entry) explode(item, entry) end
effects.Boom = function(item, entry) explode(item, entry) end
effects.Emp = function(item, entry) explode(item, entry, entry.Strength) end

effects.CashSpawn = function(item, entry, activator)
    if activator == nil then return end
    Traitormod.SpawnPointItem(activator.Inventory, math.random(entry.Points[1], entry.Points[2]), Traitormod.GetText("XenoarchCash"))
end

-- the artifact jumps to a free spot of its own room's station, as SS14's RandomTeleportArtifact
effects.Blink = function(item, entry)
    for _ = 1, 10 do
        local target = item.WorldPosition + Vector2(math.random(-entry.Range, entry.Range), math.random(-entry.Range, entry.Range))
        local hull = Hull.FindHull(target, nil, true)
        if hull ~= nil and hull.Submarine == item.Submarine then
            local position = item.Submarine ~= nil and target - item.Submarine.Position or target
            item.SetTransform(ConvertUnits.ToSimUnits(position), 0, true, true, item.Submarine)
            Traitormod.Xenoarch.Fx(item, "blink", 0)
            return
        end
    end
end

effects.HealAll = function(item, entry)
    for _, character in ipairs(charactersNear(item, entry.Range)) do
        for _, kind in ipairs({ "damage", "burn", "bleeding", "poison" }) do
            character.CharacterHealth.ReduceAfflictionOnAllLimbs(Identifier(kind), entry.Amount)
        end
    end
end

effects.Ignite = function(item, entry)
    for _, character in ipairs(charactersNear(item, entry.Range)) do
        if character.CurrentHull ~= nil then FireSource(character.WorldPosition, character.CurrentHull) end
    end
end

-- another artifact, as SS14's RandomArtifactSpawner
local artifactKinds
effects.Mitosis = function(item)
    if artifactKinds == nil then
        artifactKinds = {}
        for prefab in ItemPrefab.Prefabs do
            if string.sub(prefab.Identifier.Value, 1, 12) == "vt_artifact_" then artifactKinds[#artifactKinds + 1] = prefab end
        end
    end
    Entity.Spawner.AddItemToSpawnQueue(artifactKinds[math.random(#artifactKinds)], around(item, 80))
end

effects.Singulo = function(item, entry)
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[entry.Item], item.WorldPosition)
end

return effects
