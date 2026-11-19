local event = {}

-- SS14's anomaly spawn: the Coalition warns the station of an anomaly aboard, and a little later one appears in a random
-- room (gamemodes/station/anomalies.lua).
event.Name = "AnomalySpawn"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

-- SS14 starts the rule 10-20 seconds after the announcement
local minDelaySeconds, maxDelaySeconds = 10, 20

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and Traitormod.Anomalies.CanSpawn()
end

event.Start = function ()
    local sightings = Traitormod.Language.AnomalySightings
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(
        Traitormod.FormatText("AnomalySpawnAnnouncement", sightings[math.random(#sightings)]), "announcement")
    event.SpawnAt = Traitormod.RoundTime + math.random(minDelaySeconds, maxDelaySeconds)
end

event.Think = function ()
    if Traitormod.RoundTime < event.SpawnAt then return end
    Traitormod.Anomalies.Spawn()
    event.End()
end

event.End = function ()

end

return event
