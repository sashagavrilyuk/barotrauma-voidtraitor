-- What an artifact's node does when its trigger happens, by the effect's id in config/station.lua (Xenoarch.Effects),
-- after SS14's old artifact effects (SS14 e9d13ea Resources/Prototypes/XenoArch/Effects). Each takes the artifact, its
-- entry in the config and the character who set it off, if any. Effects runs on the server; xenoarch.Fx shows the
-- clients what only they need to see. effects.Passive are those SS14 gives the artifact as components while it sits
-- on their node: Enter and Exit as it comes and goes, Tick once a second in between.
local effects = { Passive = {} }

-- SS14's effect hints, which the analysis console shows for a node's effect
effects.Hints = {
    GoodFeeling = "mental", PointLight = "visual", Throw = "environment", Heat = "release", Magnet = "magnet",
    AntiMagnet = "magnet", Invisibility = "visual", FoamGood = "biochemical", Shuffle = "displacement", JunkSpawn = "creation", BananaSpawn = "creation", ChemicalPuddle = "biochemical",
    FloraSpawn = "creation", InstrumentSpawn = "creation", MonkeySpawn = "creation", Radiate = "release",
    Knock = "electricalinterference", ExplosionScary = "environment", RareMaterialSpawn = "creation",
    AngryCarpSpawn = "creation", FaunaSpawn = "creation", CashSpawn = "creation", Blink = "displacement",
    Emp = "electricalinterference", HealAll = "environment", RadiateStrong = "release", MaterialSpawn = "creation",
    Ignite = "release", Mitosis = "creation", Boom = "environment", Singulo = "destruction", Own = "own",
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
        if client ~= nil then Traitormod.SendChatMessage(client, lines[math.random(#lines)], Color(200, 170, 255, 255)) end
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
-- a property the game syncs to every client, as pointitems.lua does
local function setProperty(item, owner, name, value)
    owner[name] = value
    Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(owner.SerializableProperties[Identifier(name)], owner))
end

-- pushes physics bodies near the artifact away from it, or towards it when the force is negative
local function push(item, range, force, characters)
    for character in Character.CharacterList do
        if characters and not character.IsDead and character.AnimController.MainLimb ~= nil then
            local offset = character.WorldPosition - item.WorldPosition
            local distance = offset.Length()
            if distance > 1 and distance <= range then
                character.AnimController.MainLimb.body.ApplyLinearImpulse(offset / distance * force * character.Mass / 10)
            end
        end
    end
    for other in Item.ItemList do
        if other ~= item and other.body ~= nil and other.body.Enabled and other.ParentInventory == nil then
            local offset = other.WorldPosition - item.WorldPosition
            local distance = offset.Length()
            if distance > 1 and distance <= range then other.body.ApplyLinearImpulse(offset / distance * force * other.body.Mass) end
        end
    end
end

-- nothing on the trigger itself: the radiation comes off the artifact while it sits on the node
effects.Radiate = function() end
effects.RadiateStrong = effects.Radiate
effects.Passive.Radiate = { Tick = afflict }
effects.Passive.RadiateStrong = { Tick = afflict }

-- the light the pack adds after the artifact's own ones (pack Lua/extensions/artifacts.lua)
local function glowOf(item)
    local glow
    for component in item.Components do
        if component.Name == "LightComponent" then glow = component end
    end
    return glow
end

-- glows while on the node and flashes when triggered, as SS14's PointLight with FlashOnTrigger
effects.PointLight = function(item) Traitormod.Xenoarch.Fx(item, "flash", 0) end
effects.Passive.PointLight = {
    Enter = function(item) setProperty(item, glowOf(item), "IsOn", true) end,
    Exit = function(item) setProperty(item, glowOf(item), "IsOn", false) end,
}

effects.Magnet = function() end
effects.AntiMagnet = effects.Magnet
effects.Passive.Magnet = { Tick = function(item, entry) push(item, entry.Range, -entry.Force, false) end }
effects.Passive.AntiMagnet = { Tick = function(item, entry) push(item, entry.Range, -entry.Force, false) end }

-- all but invisible while on the node, as SS14's Stealth
effects.Invisibility = function() end
effects.Passive.Invisibility = {
    Enter = function(item) setProperty(item, item, "SpriteColor", Color(255, 255, 255, 12)) end,
    Exit = function(item) setProperty(item, item, "SpriteColor", item.Prefab.SpriteColor) end,
}

-- a big artifact's own node keeps its family's tier for the node's depth awake (pack Lua/extensions/artifacts.lua);
-- going off adds nothing to it
effects.Own = function() end
effects.Passive.Own = {
    Enter = function(item, _, node) Hook.Call("VoidTraitor.ArtifactTier", item, node.Tier) end,
    Exit = function(item) Hook.Call("VoidTraitor.ArtifactTier", item, 0) end,
}

effects.Throw = function(item, entry) push(item, entry.Range, entry.Force, true) end
effects.Heat = afflict

-- SS14's healing foam, milder than HealAll
effects.FoamGood = function(item, entry) effects.HealAll(item, entry) end

-- the people nearby swap places, as SS14's ShuffleArtifact
effects.Shuffle = function(item, entry)
    local people, places = {}, {}
    for _, character in ipairs(charactersNear(item, entry.Range)) do
        if character.IsHuman then
            people[#people + 1] = character
            places[#places + 1] = character.WorldPosition
        end
    end
    for index = #places, 2, -1 do
        local other = math.random(index)
        places[index], places[other] = places[other], places[index]
    end
    for index, character in ipairs(people) do character.TeleportTo(places[index]) end
end

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
            if prefab.ConfigElement.GetAttributeString("vtartifact", "") == "big" then artifactKinds[#artifactKinds + 1] = prefab end
        end
    end
    Entity.Spawner.AddItemToSpawnQueue(artifactKinds[math.random(#artifactKinds)], around(item, 80))
end

effects.Singulo = function(item, entry)
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[entry.Item], item.WorldPosition)
end

return effects
