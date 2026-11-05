local event = {}

event.Enabled = true
event.Name = "AmmoDelivery"
event.MinRoundTime = 5
event.MinIntensity = 0.5
event.MaxIntensity = 1
event.ChancePerMinute = 0.05
event.OnlyOncePerRound = false

-- turret types: the loader that shows the sub has one, the tag of its ammo, the usual box (railgun shells
-- come one by one, so six make up its box) and the stronger ones
local turretAmmo = {
    { Loader = "coilgunloader", Tag = "coilgunammo", Regular = "coilgunammobox",
        Strong = { "coilgunammoboxexplosive", "coilgunammoboxpiercing" } },
    { Loader = "chaingunloader", Tag = "chaingunammo", Regular = "chaingunammobox",
        Strong = { "chaingunammoboxshredder", "chaingunammoboxphysicorium" } },
    { Loader = "flakcannonloader", Tag = "flakcannonammo", Regular = "flakcannonammobox",
        Strong = { "flakcannonammoboxexplosive", "flakcannondirectionalammobox", "flakcannonammoboxgravity", "flakcannonammoboxphysicorium" } },
    { Loader = "pulselaserloader", Tag = "pulselaserammo", Regular = "pulselaserammobox",
        Strong = { "pulselaserammobox_overcharge", "pulselaserammoboxtrilaser", "pulselaserammobox_emp" } },
    { Loader = "railgunloader", Tag = "railgunammo", Regular = "railgunshell", RegularCount = 6,
        Strong = { "railguncanistershell", "gravityshell" } },
}
local boxesPerType = 2 -- one to use and one to spare for every turret type on the sub
-- for a sub without any of the loaders above
local fallbackItems = {"coilgunammoboxexplosive", "coilgunammoboxexplosive", "coilgunammoboxexplosive", "railgunshell", "railgunshell", "railgunshell", "railgunshell", "railgunshell"}

-- Two regular boxes per turret type on the sub, each going to a type the likelier the less of it is aboard
-- (loaded boxes count), so they can all be one type; the worse it is around the sub, the likelier stronger ammo on top.
local function pickItems()
    local present, stock = {}, {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        local identifier = item.Prefab.Identifier.Value
        for _, ammo in ipairs(turretAmmo) do
            if string.find(identifier, ammo.Loader, 1, true) == 1 then present[ammo] = true end
            if item.HasTag(ammo.Tag) then stock[ammo] = (stock[ammo] or 0) + 1 end
        end
    end

    local types, totalWeight = {}, 0
    for _, ammo in ipairs(turretAmmo) do
        if present[ammo] then
            local weight = 1 / ((stock[ammo] or 0) + 1)
            table.insert(types, { Ammo = ammo, Weight = weight })
            totalWeight = totalWeight + weight
        end
    end
    if #types == 0 then return fallbackItems end

    local items = {}
    for _ = 1, boxesPerType * #types do
        local roll = math.random() * totalWeight
        local chosen = types[#types].Ammo
        for _, entry in ipairs(types) do
            roll = roll - entry.Weight
            if roll <= 0 then chosen = entry.Ammo break end
        end
        for _ = 1, chosen.RegularCount or 1 do table.insert(items, chosen.Regular) end
    end

    local intensity = Game.GameSession.EventManager.CurrentIntensity
    for _, entry in ipairs(types) do
        if math.random() < intensity then
            table.insert(items, entry.Ammo.Strong[math.random(#entry.Ammo.Strong)])
        end
    end
    return items
end

event.Start = function ()
    local position = nil

    for key, value in pairs(Submarine.MainSub.GetWaypoints(true)) do
        if value.AssignedJob and value.AssignedJob.Identifier == "securityofficer" then
            position = value.WorldPosition
            break
        end
    end

    if position == nil then
        position = Submarine.MainSub.WorldPosition
    end

    for key, value in pairs(pickItems()) do
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(value), position)
    end

    local text = Traitormod.Language.AmmoDelivery
    Traitormod.RoundEvents.SendEventMessage(text, "GameModeIcon.sandbox")

    event.End()
end


event.End = function ()

end

return event