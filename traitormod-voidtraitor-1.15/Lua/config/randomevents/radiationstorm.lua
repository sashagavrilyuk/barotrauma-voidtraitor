local event = {}

-- Station's take on the SS14 solar flare: the Coalition warns the station, then charged particles from Jupiter jam
-- the common channel and two random department channels for a few minutes. The communications console still
-- reaches everyone.
event.Name = "RadiationStorm"
event.MinRoundTime = 10
event.MinIntensity = 0
event.MaxIntensity = 1
event.ChancePerMinute = 0.02
event.OnlyOncePerRound = true

local warningSeconds = 20
local minJamSeconds, maxJamSeconds = 120, 240
local jammedDepartments = 2

local function pickChannels()
    local config = Traitormod.Config.Radio
    local channels = { [config.CommonChannel] = true }
    local departments = {}
    for _, department in ipairs(config.Departments) do departments[#departments + 1] = department.Channel end
    for _ = 1, math.min(jammedDepartments, #departments) do
        channels[table.remove(departments, math.random(#departments))] = true
    end
    return channels
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station"
end

event.Start = function ()
    local jamSeconds = math.random(minJamSeconds, maxJamSeconds)
    event.JamAt = Traitormod.RoundTime + warningSeconds
    event.EndAt = event.JamAt + jamSeconds
    event.Jammed = false
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("RadiationStormStart"), "commsBlackout")
end

event.Think = function ()
    local now = Traitormod.RoundTime
    if not event.Jammed then
        if now < event.JamAt then return end
        event.Jammed = true
        Traitormod.StationRadio.Jam(pickChannels())
    elseif now >= event.EndAt then
        Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("RadiationStormEnd"), "green")
        event.End()
    end
end

event.End = function ()
    Traitormod.StationRadio.Jam({})
end

return event
