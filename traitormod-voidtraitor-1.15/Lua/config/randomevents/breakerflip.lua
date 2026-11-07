local event = {}

-- Station's take on the SS14 breaker flip: to protect the equipment the Coalition switches off a few of the station's
-- power controllers, and engineers switch them back on.
event.Name = "BreakerFlip"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local minControllers, maxControllers = 3, 6

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #Traitormod.PowerController.Find(true) > 0
end

event.Start = function ()
    local controllers = Traitormod.PowerController.Find(true)
    for _ = 1, math.min(#controllers, math.random(minControllers, maxControllers)) do
        Traitormod.PowerController.SetOn(table.remove(controllers, math.random(#controllers)), false)
    end

    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("BreakerFlip"), "green")
    event.End()
end

event.End = function ()

end

return event
