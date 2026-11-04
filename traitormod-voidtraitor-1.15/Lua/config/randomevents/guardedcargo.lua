local event = {}

-- A crate of valuables lies in open water near the sub, marked by an active sonar beacon (which also draws
-- creatures), and the strong creature guarding it is offered to a dead player.
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
local minDistance, maxDistance = 3000, 6000
local wallClearance = 500

local function findOpenWater()
    local sub = Submarine.MainSub
    for attempt = 1, 10 do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(minDistance, maxDistance)
        local position = sub.WorldPosition + Vector2(math.cos(angle) * distance, math.sin(angle) * distance)
        if #Level.Loaded.GetTooCloseCells(position, wallClearance) == 0 then return position end
    end
    return nil
end

event.CanStart = function ()
    if Submarine.MainSub == nil or Level.Loaded == nil then return false end
    event.CargoPosition = findOpenWater()
    return event.CargoPosition ~= nil
end

event.Start = function ()
    local position = event.CargoPosition

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("metalcrate"), position, nil, nil, function (crate)
        for i = 1, lootCount do
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(loot[math.random(#loot)]), crate.OwnInventory)
        end
        Traitormod.SpawnPointItem(crate.OwnInventory, points, Traitormod.Language.GuardedCargoPoints)
    end)

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("sonarbeacon"), position + Vector2(0, 100), nil, nil, function (beacon)
        -- the beacon draws creatures and removes itself when broken, and the guard is right next to it
        beacon.Indestructible = true
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("batterycell"), beacon.OwnInventory, nil, nil, function ()
            -- the beacon's interface re-applies its tickbox every update, so switch the tickbox, as BeaconPirate does
            local interface = beacon.GetComponentString("CustomInterface")
            interface.customInterfaceElementList[1].State = true
            interface.customInterfaceElementList[2].Signal = Traitormod.Language.GuardedCargoBeacon
            beacon.CreateServerEvent(interface, interface)
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
