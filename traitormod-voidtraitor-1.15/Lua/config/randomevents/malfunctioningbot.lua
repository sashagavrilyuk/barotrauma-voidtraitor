local event = {}

-- A defense bot in a dry room of the sub goes rogue, as in the game's own malfunctioningdefensebot event,
-- and is offered to a dead player.
event.Name = "MalfunctioningBot"
event.MinRoundTime = 8
event.MinIntensity = 0
event.MaxIntensity = 0.5
event.ChancePerMinute = 0.01
event.OnlyOncePerRound = true

event.CanStart = function ()
    return Submarine.MainSub ~= nil
end

event.Start = function ()
    local hulls = {}
    for _, hull in pairs(Submarine.MainSub.GetHulls(false)) do
        if not hull.IsWetRoom then table.insert(hulls, hull) end
    end
    local hull = hulls[math.random(#hulls)]

    Entity.Spawner.AddCharacterToSpawnQueue("defensebot", hull.WorldPosition, function (bot)
        -- the game turns its bot hostile the same way (NPCChangeTeamAction teamid="Team2")
        bot.TeamID = CharacterTeamType.Team2
        Traitormod.GhostRoles.Create("defensebot.malfunctioning", bot)
    end)

    Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.MalfunctioningBot, "GameModeIcon.PVP", Color.Red)

    event.End()
end

event.End = function ()

end

return event
