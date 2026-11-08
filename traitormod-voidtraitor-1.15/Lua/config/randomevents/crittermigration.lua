local event = {}

-- Station's take on the SS14 mouse and cockroach migrations: a few harmless pets crawl out of the station vents, and
-- dead players can take them over. Unannounced, as in SS14.
event.Name = "CritterMigration"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local petPool = { "orangeboy", "balloon", "psilotoad" }
local minCritters, maxCritters = 2, 5

local function findVents()
    local vents = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("vent") then vents[#vents + 1] = item end
    end
    return vents
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #findVents() > 0
end

event.Start = function ()
    local vents = findVents()
    for _ = 1, math.random(minCritters, maxCritters) do
        local vent = vents[math.random(#vents)]
        Entity.Spawner.AddCharacterToSpawnQueue(petPool[math.random(#petPool)], vent.WorldPosition, function (character)
            local roleConfig = Traitormod.GhostRoles.GetConfigBySpecies("ventcreatures", character.SpeciesName.Value)
            if roleConfig ~= nil then Traitormod.GhostRoles.Create(roleConfig.FullIdentifier, character) end
        end)
    end
    event.End()
end

event.End = function ()

end

return event
