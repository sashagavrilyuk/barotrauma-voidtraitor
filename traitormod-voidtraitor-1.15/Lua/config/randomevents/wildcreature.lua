local event = {}

-- A creature of the level near the sub that nobody controls is offered to a dead player.
event.Name = "WildCreature"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
event.ChancePerMinute = 0.02
event.OnlyOncePerRound = false

local maxDistance = 8000
-- bosses and alien ruin defences stay with the AI
local excludedSpecies = {
    endworm = true, charybdis = true, latcher = true, jove = true, leucocyte = true, terminalcell = true,
    guardianrepairbot = true, portalguardian = true, huskcontainer = true,
}

local function hasWaitingPlayers()
    for _, client in pairs(Client.ClientList) do
        if client.InGame and (client.Character == nil or client.Character.IsDead) then return true end
    end
    return false
end

local function findCreatures()
    local controlled = {}
    for _, client in pairs(Client.ClientList) do
        if client.Character ~= nil then controlled[client.Character] = true end
    end

    local creatures = {}
    for _, character in pairs(Character.CharacterList) do
        local ai = character.AIController
        if not character.IsDead and not character.IsIncapacitated and character.Enabled and not character.IsPet
            and not controlled[character] and not Traitormod.GhostRoles.IsGhostRole(character)
            and not excludedSpecies[string.lower(character.SpeciesName.Value)]
            and ai ~= nil and LuaUserData.IsTargetType(ai, "Barotrauma.EnemyAIController")
            and Vector2.Distance(character.WorldPosition, Submarine.MainSub.WorldPosition) <= maxDistance then
            table.insert(creatures, character)
        end
    end
    return creatures
end

event.CanStart = function ()
    return Traitormod.Config.GhostRoleConfig.Enabled and Submarine.MainSub ~= nil
        and hasWaitingPlayers() and #findCreatures() > 0
end

event.Start = function ()
    local creatures = findCreatures()
    local creature = creatures[math.random(#creatures)]
    Traitormod.GhostRoles.Create("wild.creature", creature, { Name = creature.Name })

    event.End()
end

event.End = function ()

end

return event
