local boats = {}
Traitormod.StationBoats = boats
local bodyTypes = LuaUserData.CreateEnumTable("FarseerPhysics.BodyType")

-- The boats of the events from outside (saboteur, operatives, visitors) belong to the station map like the evacuation
-- ship: they load with the station on every client, wait parked above the end of the level with their items switched
-- off, and come out at the far end of the level when their event starts.

local function park(sub, helm, spot)
    local active = {}
    for _, item in pairs(sub.GetItems(false)) do
        local port = item.GetComponentString("DockingPort")
        if port ~= nil and port.Docked then port.Undock(false) end
        active[item] = item.IsActive
        item.IsActive = false
    end
    -- side by side above the end of the level, clear of the evacuation ship parked over the end itself
    sub.SetPosition(Vector2(Level.Loaded.EndPosition.X - spot * (sub.Borders.Width + 500),
        Level.Loaded.Size.Y + sub.Borders.Height))
    sub.Velocity = Vector2.Zero
    sub.PhysicsBody.BodyType = bodyTypes.Static
    return { Submarine = sub, Helm = helm, Active = active }
end

function boats.Start(mode)
    boats.Parked = {}
    local spot = 0
    for item in Item.ItemList do
        for name, tag in pairs(mode.EventBoats) do
            if boats.Parked[name] == nil and item.Submarine ~= nil and item.HasTag(tag) then
                spot = spot + 1
                boats.Parked[name] = park(item.Submarine, item, spot)
            end
        end
    end
end

function boats.IsParked(name)
    return boats.Parked ~= nil and boats.Parked[name] ~= nil
end

-- brings the boat out at the far end of the level with its items on and charged, as the evacuation ship comes
function boats.Launch(name)
    local boat = boats.Parked[name]
    boats.Parked[name] = nil
    for item, wasActive in pairs(boat.Active) do
        if not item.Removed then
            local battery = item.GetComponentString("PowerContainer")
            if battery ~= nil then battery.Charge = battery.Capacity end
            local reactor = item.GetComponentString("Reactor")
            if reactor ~= nil then reactor.PowerOn, reactor.AutoTemp = true, true end
            item.IsActive = wasActive
        end
    end
    local sub = boat.Submarine
    sub.PhysicsBody.BodyType = bodyTypes.Dynamic
    sub.SetPosition(Game.Server.RespawnManager.FindSpawnPos(sub, Level.Loaded.EndOutpost))
    sub.Velocity = Vector2.Zero
    return boat
end

-- a person of the given job in the room of the boat's helm, hidden from the crew list like everyone on the station
function boats.SpawnPerson(boat, job)
    local info = CharacterInfo(Identifier("human"))
    info.Job = Job(JobPrefab.Get(job), false)
    local character = Character.Create(info, boat.Helm.WorldPosition, info.Name, 0, false, true)
    character.TeamID = CharacterTeamType.Team1
    Traitormod.SelectedGamemode:HidePlayerFromCrew(character)
    return character
end

-- puts the item into the given slot once it has spawned, and the contents into the item
function boats.Equip(character, identifier, slot, contents)
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(identifier), character.Inventory, nil, nil, function (item)
        if slot ~= nil then
            character.Inventory.TryPutItem(item, character.Inventory.FindLimbSlot(slot), true, false, character)
        end
        for _, inside in ipairs(contents or {}) do
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(inside), item.OwnInventory)
        end
    end)
end

return boats
