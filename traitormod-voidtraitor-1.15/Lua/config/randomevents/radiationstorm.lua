local event = {}

-- Station's take on the SS14 solar flare: the Coalition warns the station, then charged particles from Jupiter jam
-- every chat radio for a few minutes. The game's own jam timer runs out by itself; the communications console still
-- reaches everyone.
event.Name = "RadiationStorm"
event.MinRoundTime = 10
event.MinIntensity = 0
event.MaxIntensity = 1
event.ChancePerMinute = 0.02
event.OnlyOncePerRound = true

local warningSeconds = 20
local minJamSeconds, maxJamSeconds = 120, 240
local announcementColor = Color(255, 215, 0, 255) -- shown like the alert codes: a lighter header over the coloured text

local function jam(item, seconds)
    -- the tag check first keeps the pass over every item of the station cheap
    if not item.HasTag("mobileradio") then return end
    local radio = item.GetComponentString("WifiComponent")
    if radio ~= nil and radio.LinkToChat then radio.JamTimer = seconds end
end

local function announce(text, sound)
    local mode = Traitormod.SelectedGamemode
    mode:SendAlertMessage(text, announcementColor, nil, Traitormod.GetText("CoalitionAnnouncementHeader"))
    mode:PlayAlertSound(sound)
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
    announce(Traitormod.GetText("RadiationStormStart"), "commsBlackout")
end

event.Think = function ()
    local now = Traitormod.RoundTime
    if not event.Jammed then
        if now < event.JamAt then return end
        event.Jammed = true
        for item in Item.ItemList do jam(item, event.EndAt - now) end
        -- radios made or bought during the storm are jammed too
        Hook.Add("item.created", "Traitormod.RadiationStorm", function (item)
            jam(item, event.EndAt - Traitormod.RoundTime)
        end)
    elseif now >= event.EndAt then
        announce(Traitormod.GetText("RadiationStormEnd"), "green")
        event.End()
    end
end

event.End = function ()
    Hook.Remove("item.created", "Traitormod.RadiationStorm")
end

return event
