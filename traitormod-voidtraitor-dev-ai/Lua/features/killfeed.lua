local NET_KILLFEED = "VoidTraitor_KillFeed"
local DISPLAY_DELAY_MS = 100

local function isEnabledMode()
    if not Game.RoundStarted or Traitormod.SelectedGamemode == nil then return false end

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
    message.WriteString(character ~= nil and character.DisplayName or "")
    message.WriteString(character ~= nil and tostring(character.TeamID) or "")
    message.WriteString(getJobIdentifier(character))
end

local function resolveWeaponIdentifier(causeOfDeath)
    if causeOfDeath == nil or causeOfDeath.DamageSource == nil or causeOfDeath.Killer == nil then return "" end
    if not LuaUserData.IsTargetType(causeOfDeath.DamageSource, "Barotrauma.Item") then return "" end

    local item = causeOfDeath.DamageSource
    local projectile = item.GetComponentString("Projectile")
    if projectile ~= nil then
        local weapon = projectile.Launcher or item
        return weapon.Prefab ~= nil and tostring(weapon.Prefab.Identifier) or ""
    end

    if item.Equipper == causeOfDeath.Killer or (item.ParentInventory ~= nil and item.ParentInventory.Owner == causeOfDeath.Killer) then
        return item.Prefab ~= nil and tostring(item.Prefab.Identifier) or ""
    end

    return ""
end

local function sendKillFeed(victim, causeOfDeath)
    local message = Networking.Start(NET_KILLFEED)
    local killer = causeOfDeath.Killer

    message.WriteBoolean(killer ~= nil)
    if killer ~= nil then
        writeCharacter(message, killer)
    end

    writeCharacter(message, victim)
    message.WriteString(resolveWeaponIdentifier(causeOfDeath))
    message.WriteString(causeOfDeath.Affliction ~= nil and tostring(causeOfDeath.Affliction.Identifier) or "")

    for _, client in pairs(Client.ClientList) do
        if client.Connection ~= nil then
            Networking.Send(message, client.Connection)
        end
    end
end

Hook.Add("character.death", "Traitormod.KillFeed.CharacterDeath", function(character)
    if not isEnabledMode() or character == nil then return end

    Timer.Wait(function()
        if not isEnabledMode() or character == nil then return end
        local causeOfDeath = character.CauseOfDeath
        if causeOfDeath == nil then return end
        sendKillFeed(character, causeOfDeath)
    end, DISPLAY_DELAY_MS)
end)
