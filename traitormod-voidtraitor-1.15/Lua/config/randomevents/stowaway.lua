local event = {}

-- Station's take on the SS14 closet skeleton: a stowaway who hid in a station locker, without an ID card or a place in
-- the crew, is offered to a dead player. Unannounced, as in SS14.
event.Name = "Stowaway"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local function hasWaitingPlayers()
    for _, client in pairs(Client.ClientList) do
        if client.InGame and (client.Character == nil or client.Character.IsDead) then return true end
    end
    return false
end

local function findLockers()
    local lockers = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("locker") and item.CurrentHull ~= nil then lockers[#lockers + 1] = item end
    end
    return lockers
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and Traitormod.Config.GhostRoleConfig.Enabled
        and hasWaitingPlayers() and #findLockers() > 0
end

event.Start = function ()
    local lockers = findLockers()
    local locker = lockers[math.random(#lockers)]

    local info = CharacterInfo(Identifier("human"))
    info.Job = Job(JobPrefab.Get("assistant"), false)
    local character = Character.Create(info, locker.WorldPosition, info.Name, 0, false, true)
    character.TeamID = CharacterTeamType.Team1
    Traitormod.SelectedGamemode:HidePlayerFromCrew(character)
    -- no job items: they bring an ID card and a headset
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("assistantclothes"), character.Inventory, nil, nil, function (item)
        character.Inventory.TryPutItem(item, character.Inventory.FindLimbSlot(InvSlotType.InnerClothes), true, false, character)
    end)

    Traitormod.GhostRoles.Create("stowaway.stowaway", character, {
        OnAssigned = function (client)
            Traitormod.SendChatMessage(client, Traitormod.GetText("StowawayYou"))
        end
    })
    event.End()
end

event.End = function ()

end

return event
