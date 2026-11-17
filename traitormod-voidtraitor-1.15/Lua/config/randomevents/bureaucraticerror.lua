local event = {}

-- Station's take on the SS14 bureaucratic error: the role seats for newcomers change. Mostly a few roles get more or
-- fewer seats; sometimes every role closes but one, which takes everyone.
event.Name = "BureaucraticError"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

-- SS14 values
local closeAllButOneChance = 0.25
local minShare, maxShare = 0.2, 0.3
local minChange, maxChange = -3, 5

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station"
end

event.Start = function ()
    local mode = Traitormod.SelectedGamemode
    -- heads stay one each, and passengers take anyone anyway
    local slots, roles = mode.Seats, {}
    for id, role in pairs(mode.Roles) do
        if role.Head == nil and not role.Passenger then roles[#roles + 1] = id end
    end
    -- SS14 changes the seats left, so the crew's seats stay and a cut can't leave a debt that eats a later rise
    local taken = mode:CountCrewSeats(mode:GetCrew())

    if math.random() < closeAllButOneChance then
        local open = table.remove(roles, math.random(#roles))
        slots[open] = math.huge
        for _, id in ipairs(roles) do slots[id] = taken[id] or 0 end
    else
        for _ = 1, math.floor(#roles * (minShare + math.random() * (maxShare - minShare))) do
            local id = table.remove(roles, math.random(#roles))
            local crew = taken[id] or 0
            slots[id] = math.max(crew, math.max(slots[id], crew) + math.random(minChange, maxChange))
        end
    end

    -- the crew list shows the seats each role has left
    mode.CrewChanged = true
    mode:SendCoalitionAnnouncement(Traitormod.GetText("BureaucraticError"), "green")
    event.End()
end

event.End = function ()

end

return event
