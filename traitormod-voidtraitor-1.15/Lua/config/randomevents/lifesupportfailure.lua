local event = {}

-- Station's take on the SS14 gas leak: one of the station's oxygen generators breaks down, and the air in the rooms it
-- feeds slowly runs out until mechanics or engineers repair it.
event.Name = "LifeSupportFailure"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local function workingGenerators()
    local generators = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("oxygengenerator") and item.Condition > 0 then
            table.insert(generators, item)
        end
    end
    return generators
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #workingGenerators() > 0
end

event.Start = function ()
    local generators = workingGenerators()
    -- the server sends a broken item to the clients at once
    generators[math.random(#generators)].Condition = 0
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("LifeSupportFailure"), "green")
    event.End()
end

event.End = function ()

end

return event
