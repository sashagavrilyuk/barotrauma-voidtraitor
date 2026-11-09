local event = {}

-- A defense bot in a dry room of the sub goes rogue, as in the game's own malfunctioningdefensebot event,
-- and is offered to a dead player.
event.Name = "MalfunctioningBot"
event.MinRoundTime = 8
event.MinIntensity = 0
event.MaxIntensity = 0.5
event.ChancePerMinute = 0.01
event.OnlyOncePerRound = true

local playersPerBot, maxBots = 10, 3

event.CanStart = function ()
    return Submarine.MainSub ~= nil
end

event.Start = function ()
    local hulls = {}
    for _, hull in pairs(Submarine.MainSub.GetHulls(false)) do
        if not hull.IsWetRoom then table.insert(hulls, hull) end
    end

    local amount = math.max(1, math.min(maxBots, math.floor(#Client.ClientList / playersPerBot)))
    for _ = 1, math.min(#hulls, amount) do
        local hull = table.remove(hulls, math.random(#hulls))
        Entity.Spawner.AddCharacterToSpawnQueue("defensebot", hull.WorldPosition, function (bot)
            -- the game turns its bot hostile the same way (NPCChangeTeamAction teamid="Team2")
            bot.TeamID = CharacterTeamType.Team2
            Traitormod.GhostRoles.Create("defensebot.malfunctioning", bot)
        end)
    end

    -- the station is not warned, like the hidden threats of SS14
    local mode = Traitormod.SelectedGamemode
    if mode == nil or mode.Name ~= "Station" then
        Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.MalfunctioningBot, "GameModeIcon.PVP", Color.Red)
    end

    event.End()
end

event.End = function ()

end

return event
