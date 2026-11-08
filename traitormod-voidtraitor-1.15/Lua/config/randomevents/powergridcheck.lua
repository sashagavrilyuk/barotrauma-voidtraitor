local event = {}

-- Station's take on the SS14 power grid check: after a warning the station's power controllers switch off one after
-- another, nobody may switch them back on, and after a while they all come back on at once.
event.Name = "PowerGridCheck"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local minWarningSeconds, maxWarningSeconds = 10, 20
local switchOffSeconds = 30 -- the controllers go out one by one over this time
local minOutageSeconds, maxOutageSeconds = 50, 100

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #Traitormod.PowerController.Find(true) > 0
end

event.Start = function ()
    event.Pending = Traitormod.PowerController.Find(true)
    event.Total = #event.Pending
    event.Off = {}
    event.OffAt = Traitormod.RoundTime + math.random(minWarningSeconds, maxWarningSeconds)
    event.OnAt = event.OffAt + math.random(minOutageSeconds, maxOutageSeconds)
    Traitormod.PowerController.Locked = true
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("PowerGridCheckStart"), "powerOff")
end

event.Think = function ()
    local now = Traitormod.RoundTime
    if now < event.OffAt then return end

    if now >= event.OnAt then
        for _, item in ipairs(event.Off) do
            if not item.Removed then Traitormod.PowerController.SetOn(item, true) end
        end
        Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("PowerGridCheckEnd"), "powerOn")
        event.End()
        return
    end

    local due = math.ceil(event.Total * math.min(1, (now - event.OffAt) / switchOffSeconds))
    while #event.Off < due do
        local item = table.remove(event.Pending, math.random(#event.Pending))
        if not item.Removed then Traitormod.PowerController.SetOn(item, false) end
        table.insert(event.Off, item)
    end
end

event.End = function ()
    Traitormod.PowerController.Locked = false
    event.Pending, event.Off = nil, nil
end

return event
