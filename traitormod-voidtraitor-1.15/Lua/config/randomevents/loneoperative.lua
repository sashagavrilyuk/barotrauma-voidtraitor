local event = {}

-- SS14's lone operative: a separatist operative comes on his own shuttle from the far end of the level
-- (Lua/gamemodes/station/boats.lua) to blow up the station with its own nuclear bomb. He is offered to a dead player,
-- unannounced; the operative role gives him the codes of the bombs and his objective.
event.Name = "LoneOperative"
event.MinRoundTime = 35
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = true

local function hasWaitingPlayers()
    for _, client in pairs(Client.ClientList) do
        if client.InGame and (client.Character == nil or client.Character.IsDead) then return true end
    end
    return false
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and Traitormod.Config.GhostRoleConfig.Enabled
        and Traitormod.StationBoats.IsParked("LoneOperative") and hasWaitingPlayers()
end

event.Start = function ()
    local boats = Traitormod.StationBoats
    local character = boats.SpawnPerson(boats.Launch("LoneOperative"), "securityofficer")
    boats.Equip(character, "combatdivingsuit", InvSlotType.OuterClothes, { "oxygentank" })
    boats.Equip(character, "smg", nil, { "smgmagazine" })
    boats.Equip(character, "smgmagazine")
    boats.Equip(character, "smgmagazine")

    Traitormod.GhostRoles.Create("separatists.operative", character, {
        OnAssigned = function ()
            local roles = Traitormod.RoleManager
            roles.AssignRole(character, roles.Roles.Operative:new())
        end
    })
    event.End()
end

event.End = function ()

end

return event
