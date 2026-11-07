local event = {}

-- Station's take on the SS14 sleeper agents: Coalition internal security intercepts a transmission of the Jovian
-- Separatists, and one or two of the crew wake up as traitors.
event.Name = "SleeperAgents"
event.MinRoundTime = 30
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = true

local playersPerAgent = 15
local maxAgents = 2

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    if mode == nil or mode.Name ~= "Station" then return false end
    local _, count = mode:MidRoundAntagonistCandidates()
    return count > 0
end

event.Start = function ()
    local mode = Traitormod.SelectedGamemode
    mode:AssignMidRoundAntagonists("Traitor", math.max(1, math.min(maxAgents, math.floor(#Client.ClientList / playersPerAgent))))
    mode:SendCoalitionAnnouncement(Traitormod.GetText("SleeperAgents"), "green")
    event.End()
end

event.End = function ()

end

return event
