local event = {}

-- A crate of valuables hovers in open water on the main path ahead of the sub, marked by the active sonar
-- beacon inside it (which also draws creatures), and the strong creature guarding it is offered to a dead player.
event.Name = "GuardedCargo"
event.MinRoundTime = 6
event.MinIntensity = 0
event.MaxIntensity = 0.5
event.ChancePerMinute = 0.01
event.OnlyOncePerRound = true

local guardSpecies = { "Tigerthresher", "Mudraptor_veteran", "Hammerhead", "Bonethresher" }
local loot = { "physicorium", "incendium", "fulgurium", "dementonite", "combatstimulantsyringe", "fulguriumbatterycell" }
local lootCount = 3
local points = 1500
local minDistance, maxDistance = 10000, 25000
local wallClearance = 500

-- a main path point the sub has yet to reach: nearer the level's end than the sub, and some way off
local function findPositionAhead()
    local subPosition, endPosition = Submarine.MainSub.WorldPosition, Level.Loaded.EndPosition
    local subToEnd = Vector2.Distance(subPosition, endPosition)
    local candidates = {}
    for _, point in pairs(Level.Loaded.PositionsOfInterest) do
        if point.PositionType == Level.PositionType.MainPath then
            local position = Vector2(point.Position.X, point.Position.Y)
            local distance = Vector2.Distance(position, subPosition)
            if distance >= minDistance and distance <= maxDistance and Vector2.Distance(position, endPosition) < subToEnd
                and #Level.Loaded.GetTooCloseCells(position, wallClearance) == 0 then
                table.insert(candidates, position)
            end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

event.CanStart = function ()
    if Submarine.MainSub == nil or Level.Loaded == nil then return false end
    event.CargoPosition = findPositionAhead()
    return event.CargoPosition ~= nil
end

event.Start = function ()
    local position = event.CargoPosition

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("vt_guardedcargo"), position, nil, nil, function (crate)
        for i = 1, lootCount do
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(loot[math.random(#loot)]), crate.OwnInventory)
        end
        Traitormod.SpawnPointItem(crate.OwnInventory, points, Traitormod.Language.GuardedCargoPoints)
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("sonarbeacon"), crate.OwnInventory, nil, nil, function (beacon)
            -- the beacon draws creatures and removes itself when broken
            beacon.Indestructible = true
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("batterycell"), beacon.OwnInventory, nil, nil, function ()
                -- the beacon's interface re-applies its tickbox every update, so switch the tickbox, as BeaconPirate does
                local interface = beacon.GetComponentString("CustomInterface")
                interface.customInterfaceElementList[1].State = true
                interface.customInterfaceElementList[2].Signal = Traitormod.Language.GuardedCargoBeacon
                beacon.CreateServerEvent(interface, interface)
            end)
        end)
    end)

    Entity.Spawner.AddCharacterToSpawnQueue(guardSpecies[math.random(#guardSpecies)], position + Vector2(300, 0), function (guard)
        Traitormod.GhostRoles.Create("wild.cargoguard", guard)
    end)

    Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.GuardedCargo, "GameModeIcon.sandbox")

    event.End()
end

event.End = function ()

end

return event
