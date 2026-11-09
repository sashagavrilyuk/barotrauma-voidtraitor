local event = {}

-- SS14's space ninja for the Station: a separatist saboteur comes on his own small boat from the far end of the level
-- (Lua/gamemodes/station/boats.lua). He is offered to a dead player, unannounced, and gets the saboteur role with its
-- objectives once taken.
event.Name = "SaboteurBoat"
event.MinRoundTime = 30
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

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and Traitormod.Config.GhostRoleConfig.Enabled
        and Traitormod.StationBoats.IsParked("Saboteur") and hasWaitingPlayers()
end

event.Start = function ()
    local boats = Traitormod.StationBoats
    local character = boats.SpawnPerson(boats.Launch("Saboteur"), "assistant")
    boats.Equip(character, "assistantclothes", InvSlotType.InnerClothes)
    boats.Equip(character, "divingsuit", InvSlotType.OuterClothes, { "oxygentank" })
    boats.Equip(character, "screwdriver")
    boats.Equip(character, "wrench")

    Traitormod.GhostRoles.Create("separatists.saboteur", character, {
        OnAssigned = function ()
            local roles = Traitormod.RoleManager
            roles.AssignRole(character, roles.Roles.Saboteur:new())
        end
    })
    event.End()
end

event.End = function ()

end

return event
