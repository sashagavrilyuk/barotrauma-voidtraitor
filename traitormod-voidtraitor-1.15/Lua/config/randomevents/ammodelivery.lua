local event = {}

event.Enabled = true
event.Name = "AmmoDelivery"
event.MinRoundTime = 5
event.MinIntensity = 0.5
event.MaxIntensity = 1
event.ChancePerMinute = 0.05
event.OnlyOncePerRound = false

-- turret types: the loader that shows the sub has one, the tag of its ammo, the usual box and the stronger ones
local turretAmmo = {
    { Loader = "coilgunloader", Tag = "coilgunammo", Regular = "coilgunammobox",
        Strong = { "coilgunammoboxexplosive", "coilgunammoboxpiercing" } },
    { Loader = "chaingunloader", Tag = "chaingunammo", Regular = "chaingunammobox",
        Strong = { "chaingunammoboxshredder", "chaingunammoboxphysicorium" } },
    { Loader = "flakcannonloader", Tag = "flakcannonammo", Regular = "flakcannonammobox",
        Strong = { "flakcannonammoboxexplosive", "flakcannondirectionalammobox", "flakcannonammoboxgravity", "flakcannonammoboxphysicorium" } },
    { Loader = "pulselaserloader", Tag = "pulselaserammo", Regular = "pulselaserammobox",
        Strong = { "pulselaserammobox_overcharge", "pulselaserammoboxtrilaser", "pulselaserammobox_emp" } },
    { Loader = "railgunloader", Tag = "railgunammo", Regular = "railgunshell",
        Strong = { "railguncanistershell", "gravityshell" } },
}
local lowStock = 2 -- boxes of a type on the sub, loaded ones included, below which it gets regular ones
local regularAmount = 2
-- for a sub without any of the loaders above
local fallbackItems = {"coilgunammoboxexplosive", "coilgunammoboxexplosive", "coilgunammoboxexplosive", "railgunshell", "railgunshell", "railgunshell", "railgunshell", "railgunshell"}

-- Regular ammo for the turret types that run low; the worse it is around the sub, the likelier stronger ammo on top.
local function pickItems()
    local present, stock = {}, {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        local identifier = item.Prefab.Identifier.Value
        for _, ammo in ipairs(turretAmmo) do
            if string.find(identifier, ammo.Loader, 1, true) == 1 then present[ammo] = true end
            if item.HasTag(ammo.Tag) then stock[ammo] = (stock[ammo] or 0) + 1 end
        end
    end

    local intensity = Game.GameSession.EventManager.CurrentIntensity
    local items, scarcest = {}, nil
    for _, ammo in ipairs(turretAmmo) do
        if present[ammo] then
            local count = stock[ammo] or 0
            if count < lowStock then
                for i = 1, regularAmount do table.insert(items, ammo.Regular) end
            end
            if math.random() < intensity then
                table.insert(items, ammo.Strong[math.random(#ammo.Strong)])
            end
            if scarcest == nil or count < (stock[scarcest] or 0) then scarcest = ammo end
        end
    end

    if scarcest == nil then return fallbackItems end
    if #items == 0 then table.insert(items, scarcest.Regular) end
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