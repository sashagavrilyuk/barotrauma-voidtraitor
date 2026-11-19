-- What each kind of anomaly does at its pulses, once a second and when it goes supercritical, after SS14's anomaly
-- effects (SS14 f00a972 Content.Server/Anomaly/Effects, Content.Shared/Anomaly/Effects). Each gets the anomaly, its kind's
-- entry in config/station.lua (Anomalies.Types) and the anomaly's stability, severity and pulse power;
-- Traitormod.Anomalies.Fx shows the clients near it what only they need to see.
local effects = {}

local function charactersNear(position, range)
    local found = {}
    for character in Character.CharacterList do
        if not character.IsDead and Vector2.Distance(character.WorldPosition, position) <= range then found[#found + 1] = character end
    end
    return found
end

local function afflict(character, id, strength)
    character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, AfflictionPrefab.Prefabs[id].Instantiate(strength))
end

-- pushes people and loose items near the anomaly away from it, or towards it when the force is negative
local function push(item, range, force)
    for character in Character.CharacterList do
        local offset = character.WorldPosition - item.WorldPosition
        local distance = offset.Length()
        if not character.IsDead and character.AnimController.MainLimb ~= nil and distance > 1 and distance <= range then
            character.AnimController.MainLimb.body.ApplyLinearImpulse(offset / distance * force * character.Mass / 10)
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

-- the server deals the damage; the clients only see the blast
local function explode(item, range, force, damage, structureDamage, empStrength)
    Explosion(range, force, damage, structureDamage, damage, empStrength or 0).Explode(item.WorldPosition, item)
    Traitormod.Anomalies.Fx(item, "explosion", range)
end

-- SS14 PyroclasticAnomaly: everyone within reach catches fire, the more of it the more severe (SS14's fire stacks)
local function ignite(item, kind, range, severity)
    for _, character in ipairs(charactersNear(item.WorldPosition, range)) do
        if character.CurrentHull ~= nil then FireSource(character.WorldPosition, character.CurrentHull) end
        afflict(character, "burn", kind.Burn * (1 + math.floor(severity / 0.15)))
    end
end
effects.pyro = {
    Pulse = function(item, kind, stability, severity, power) ignite(item, kind, kind.IgnitionRange * stability * power, severity) end,
    Supercritical = function(item, kind, power)
        ignite(item, kind, kind.IgnitionRange * 2 * power, 1)
        local hull = Hull.FindHull(item.WorldPosition, nil, true)
        if hull ~= nil then FireSource(item.WorldPosition, hull) end
    end,
}

-- SS14 ElectricityAnomaly: bolts at random people and machines around, a shock that ignores insulation
local function shock(character, kind, severity)
    afflict(character, "burn", kind.Burn * severity)
    afflict(character, "stun", kind.Stun * severity)
end
local function bolts(item, kind, range, count, severity)
    local targets = charactersNear(item.WorldPosition, range)
    for other in Item.ItemList do
        if other.GetComponentString("Powered") ~= nil and other.ParentInventory == nil
            and Vector2.Distance(other.WorldPosition, item.WorldPosition) <= range then targets[#targets + 1] = other end
    end
    for _ = 1, math.min(count, #targets) do
        local target = table.remove(targets, math.random(#targets))
        Traitormod.Anomalies.Fx(item, "bolt", 0, target.WorldPosition)
        if LuaUserData.IsTargetType(target, "Barotrauma.Character") then shock(target, kind, severity) end
    end
end
effects.electric = {
    Pulse = function(item, kind, stability, severity, power)
        bolts(item, kind, kind.Range * stability * power, math.floor(kind.Bolts[1] + (kind.Bolts[2] - kind.Bolts[1]) * severity), severity)
    end,
    -- now and then a shock to everyone close, the likelier the more unstable
    Tick = function(item, kind, stability, severity)
        if math.random() >= kind.ShockChance * stability then return end
        for _, character in ipairs(charactersNear(item.WorldPosition, kind.Range * stability)) do
            Traitormod.Anomalies.Fx(item, "bolt", 0, character.WorldPosition)
            shock(character, kind, severity)
        end
    end,
    Supercritical = function(item, kind, power)
        local range = kind.Range * 3 * power
        explode(item, range, 0, 0, 0, 1)
        bolts(item, kind, range, kind.Bolts[2] * 3, 1)
    end,
}

-- SS14 GravityAnomaly: a pulse throws everything away; between pulses it pulls things in and radiates, both growing with
-- severity; at the end it tears the station open (SS14 makes the floor around it space)
effects.gravity = {
    Pulse = function(item, kind, stability, severity, power) push(item, kind.ThrowRange * severity * power, kind.ThrowForce * severity * power) end,
    Tick = function(item, kind, stability, severity)
        push(item, kind.PullRange * stability, -kind.PullForce * severity)
        for _, character in ipairs(charactersNear(item.WorldPosition, kind.PullRange * stability / 2)) do
            afflict(character, "radiationsickness", kind.Radiation * severity)
        end
    end,
    Supercritical = function(item, kind, power)
        explode(item, kind.TearRange, 0, 0, kind.TearDamage)
        push(item, kind.ThrowRange * 2 * power, kind.ThrowForce * 2 * power)
    end,
}

-- water into the anomaly's room, a share of its volume
local function flood(item, share)
    local hull = Hull.FindHull(item.WorldPosition, nil, true)
    if hull ~= nil then hull.WaterVolume = hull.WaterVolume + hull.Volume * share end
end
effects.liquid = {
    Pulse = function(item, kind, stability, severity, power) flood(item, kind.Flood * severity * power) end,
    Supercritical = function(item, kind, power) flood(item, power) end,
}

-- SS14 BluespaceAnomaly: a pulse swaps the places of the anomaly and everyone near it, the further the more severe;
-- whoever touches it ends up elsewhere in the station (its portal), and at the end everyone near it is scattered
local function teleport(item, character, position)
    Traitormod.Anomalies.Fx(item, "teleport", 0, character.WorldPosition)
    character.TeleportTo(position)
    Traitormod.Anomalies.Fx(item, "teleport", 0, position)
end
effects.bluespace = {
    Pulse = function(item, kind, stability, severity, power)
        local people = charactersNear(item.WorldPosition, kind.ShuffleRange * severity * power)
        local places = { item.WorldPosition }
        for _, character in ipairs(people) do places[#places + 1] = character.WorldPosition end
        for index = #places, 2, -1 do
            local other = math.random(index)
            places[index], places[other] = places[other], places[index]
        end
        for index, character in ipairs(people) do teleport(item, character, places[index + 1]) end
        if Vector2.Distance(places[1], item.WorldPosition) > 1 then Traitormod.Anomalies.MoveTo(item, places[1]) end
    end,
    Tick = function(item, kind, stability, severity)
        local range = kind.PortalRange
        for _, character in ipairs(charactersNear(item.WorldPosition, kind.TouchRange)) do
            local spot = Traitormod.Anomalies.RandomSpot(item.WorldPosition, range[1], range[1] + (range[2] - range[1]) * severity)
            if spot ~= nil then teleport(item, character, spot) end
        end
    end,
    Supercritical = function(item, kind, power)
        for _, character in ipairs(charactersNear(item.WorldPosition, kind.ShuffleRange)) do
            local spot = Traitormod.Anomalies.RandomSpot(item.WorldPosition, 0, kind.ScatterRange * power)
            if spot ~= nil then teleport(item, character, spot) end
        end
    end,
}

return effects
