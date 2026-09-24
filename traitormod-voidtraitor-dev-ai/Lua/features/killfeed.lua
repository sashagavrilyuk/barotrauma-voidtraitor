local NET_KILLFEED = "VoidTraitor_KillFeed"

local function isEnabledMode()
    if Traitormod.SelectedGamemode == nil then return false end

    local name = Traitormod.SelectedGamemode.Name
    return name == "PvP" or name == "AttackDefendV2"
end

local function getJobIdentifier(character)
    if character == nil or character.Info == nil or character.Info.Job == nil or character.Info.Job.Prefab == nil then
        return ""
    end

    return tostring(character.Info.Job.Prefab.Identifier)
end

local function writeCharacter(message, character)
    message.WriteString(character ~= nil and character.Name or "")
    message.WriteString(character ~= nil and tostring(character.TeamID) or "")
    message.WriteString(getJobIdentifier(character))
end

local function getWeaponIdentifier(causeOfDeath)
    if causeOfDeath == nil then return "" end

    local source = causeOfDeath.DamageSource
    if source == nil or not LuaUserData.IsTargetType(source, "Barotrauma.Item") then
        return ""
    end

    local projectile = source.GetComponentString("Projectile")
    if projectile ~= nil and projectile.Launcher ~= nil then
        source = projectile.Launcher
    end

    if source.Prefab == nil then return "" end
    return tostring(source.Prefab.Identifier)
end

Hook.Add("characterDeath", "Traitormod.KillFeed.CharacterDeath", function(character)
    if not Game.RoundStarted or not isEnabledMode() or character == nil or not character.IsHuman then
        return
    end

    local causeOfDeath = character.CauseOfDeath
    if causeOfDeath == nil then return end

    local killer = causeOfDeath.Killer
    local message = Networking.Start(NET_KILLFEED)

    message.WriteBoolean(killer ~= nil)
    if killer ~= nil then
        writeCharacter(message, killer)
    end

    writeCharacter(message, character)
    message.WriteString(getWeaponIdentifier(causeOfDeath))

    for _, client in pairs(Client.ClientList) do
        if client.Connection ~= nil then
            Networking.Send(message, client.Connection)
        end
    end
end)
