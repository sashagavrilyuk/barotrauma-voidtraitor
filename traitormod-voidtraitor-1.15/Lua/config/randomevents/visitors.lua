local event = {}

-- SS14's unknown shuttle: after a Coalition warning a ship with a few visitors of random trades comes in from the far end
-- of the level (Lua/gamemodes/station/boats.lua). The visitors are offered to dead players; their cards show only their
-- name and job, without access to any department, like those of the station's passengers.
event.Name = "Visitors"
event.MinRoundTime = 15
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local minVisitors, maxVisitors = 2, 4
local jobs = { "captain", "engineer", "mechanic", "medicaldoctor", "securityofficer", "scientist", "assistant" }

local function waitingPlayers()
    local count = 0
    for _, client in pairs(Client.ClientList) do
        if client.InGame and (client.Character == nil or client.Character.IsDead) then count = count + 1 end
    end
    return count
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and Traitormod.Config.GhostRoleConfig.Enabled
        and Traitormod.StationBoats.IsParked("Visitors") and waitingPlayers() > 0
end

event.Start = function ()
    local boats = Traitormod.StationBoats
    local boat = boats.Launch("Visitors")
    for _ = 1, math.min(math.random(minVisitors, maxVisitors), waitingPlayers()) do
        local character = boats.SpawnPerson(boat, jobs[math.random(#jobs)])
        character.GiveJobItems(false)
        -- a passenger's card, set up before the Station's own card hook would give it the access of the job
        Traitormod.IdConsole.InitializeCard(character, true)
        Traitormod.GhostRoles.Create("visitors.visitor", character, {
            Name = tostring(character.Info.Job.Name),
            OnAssigned = function (client)
                Traitormod.SendChatMessage(client, Traitormod.GetText("VisitorYou"))
            end
        })
    end
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("Visitors"), "attention")
    event.End()
end

event.End = function ()

end

return event
