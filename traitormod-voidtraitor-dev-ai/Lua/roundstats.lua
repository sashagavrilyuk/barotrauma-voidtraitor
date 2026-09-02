local roundStats = {}
local languages = dofile(Traitormod.Path .. "/Lua/language/roundstats.lua")
local language = languages[Traitormod.Config.Language] or languages.English

local function text(key)
    return language[key] or languages.English[key] or key
end

roundStats.Data = {}
roundStats.CharacterAccounts = {}

local repairActions = LuaUserData.CreateEnumTable("Barotrauma.Items.Components.Repairable+FixActions")
local repairSnapshots = {}

local function reset()
    roundStats.Data = {}
    roundStats.CharacterAccounts = {}
    repairSnapshots = {}

    for _, client in pairs(Client.ClientList) do
        local accountKey = Traitormod.GetClientAccountKey(client)
        if accountKey ~= nil then
            roundStats.Data[accountKey] = { Name = client.Character ~= nil and tostring(client.Character.Name) or client.Name }
            if client.Character ~= nil then
                roundStats.CharacterAccounts[client.Character] = accountKey
            end
        end
    end
end

local function getEntry(character)
    if character == nil then return nil end

    local client = Traitormod.FindClientCharacter(character)
    local accountKey
    if client ~= nil then
        accountKey = Traitormod.GetClientAccountKey(client)
        roundStats.CharacterAccounts[character] = accountKey
    else
        accountKey = roundStats.CharacterAccounts[character]
    end
    if accountKey == nil then return nil end

    local entry = roundStats.Data[accountKey]
    if entry == nil then
        entry = {}
        roundStats.Data[accountKey] = entry
    end
    entry.Name = tostring(character.Name)

    return entry, accountKey
end

local function add(character, key, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local entry = getEntry(character)
    if entry == nil then return end
    entry[key] = (entry[key] or 0) + amount
end

local function isSecretAntagonistAgainstCrew(attacker, target)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Secret" then return false end
    if Traitormod.RoleManager == nil then return false end

    local attackerRole = Traitormod.RoleManager.GetRole(attacker)
    local targetRole = Traitormod.RoleManager.GetRole(target)
    return attackerRole ~= nil and attackerRole.IsAntagonist
        and (targetRole == nil or not targetRole.IsAntagonist)
end

local function isValidEnemy(attacker, target)
    if attacker.TeamID ~= target.TeamID then return true end
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Secret" then return false end
    if Traitormod.RoleManager == nil then return false end

    local attackerRole = Traitormod.RoleManager.GetRole(attacker)
    local targetRole = Traitormod.RoleManager.GetRole(target)
    return (attackerRole == nil or not attackerRole.IsAntagonist)
        and targetRole ~= nil and targetRole.IsAntagonist
end

local function isTurretDamageSource(source)
    if source == nil or not LuaUserData.IsTargetType(source, "Barotrauma.Item") then return false end

    local projectile = source.GetComponentString("Projectile")
    if projectile == nil or projectile.Launcher == nil then return false end

    return projectile.Launcher.GetComponentString("Turret") ~= nil
end

local function getParticipants(antagonists)
    local participants = {}
    if Traitormod.RoleManager == nil then return participants end

    local antagonistAccounts = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        if role.IsAntagonist then
            local _, accountKey = getEntry(character)
            if accountKey ~= nil then
                antagonistAccounts[accountKey] = true
            end
        end
    end

    local added = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        local entry, accountKey = getEntry(character)
        if entry ~= nil and accountKey ~= nil and not added[accountKey]
            and ((antagonists and role.IsAntagonist)
                or (not antagonists and not role.IsAntagonist and not antagonistAccounts[accountKey]))
        then
            added[accountKey] = true
            table.insert(participants, { Character = character, Role = role, Entry = entry })
        end
    end

    return participants
end

local function maxLeaders(participants, getValue)
    local best = 0
    local leaders = {}

    for _, participant in ipairs(participants) do
        local value = tonumber(getValue(participant)) or 0
        if value > best then
            best = value
            leaders = { participant }
        elseif value > 0 and value == best then
            table.insert(leaders, participant)
        end
    end

    return best, leaders
end

local function names(leaders)
    local result = {}
    for _, participant in ipairs(leaders) do
        table.insert(result, participant.Entry.Name or tostring(participant.Character.Name))
    end
    table.sort(result)
    return table.concat(result, ", ")
end

local function objectiveStats(participant)
    local completed = 0
    local points = 0
    for _, objective in ipairs(participant.Role.Objectives or {}) do
        if objective.Awarded then
            completed = completed + 1
            points = points + (tonumber(objective.AmountPoints) or 0)
        end
    end
    return completed, points
end

function roundStats.BuildSecretSummary()
    local lines = {}
    local crew = getParticipants(false)

    local distinctions = {
        { "RoundDistinctionHealing", "Healing" },
        { "RoundDistinctionSelfHealing", "SelfHealing" },
        { "RoundDistinctionHullRepair", "HullRepair" },
        { "RoundDistinctionMechanicalRepair", "MechanicalRepair" },
        { "RoundDistinctionElectricalRepair", "ElectricalRepair" },
        { "RoundDistinctionDamage", "Damage" },
        { "RoundDistinctionTurretDamage", "TurretDamage" },
        { "RoundDistinctionKills", "Kills" },
    }

    local crewLines = {}
    for _, distinction in ipairs(distinctions) do
        local value, leaders = maxLeaders(crew, function(participant)
            return participant.Entry[distinction[2]] or 0
        end)
        if math.floor(value) > 0 then
            table.insert(crewLines, string.format(text(distinction[1]), names(leaders), math.floor(value)))
        end
    end

    if #crewLines > 0 then
        table.insert(lines, text("RoundDistinctionsTitle"))
        for _, line in ipairs(crewLines) do table.insert(lines, line) end
    end

    local antagonists = getParticipants(true)
    local darkLines = {}

    local objectivePoints, greyLeaders = maxLeaders(antagonists, function(participant)
        local _, points = objectiveStats(participant)
        return points
    end)
    if objectivePoints > 0 then
        table.insert(darkLines, string.format(text("RoundDistinctionGreyCardinal"), names(greyLeaders), math.floor(objectivePoints)))
    end

    local crewKills, bloodyLeaders = maxLeaders(antagonists, function(participant)
        return participant.Entry.CrewKills or 0
    end)
    if crewKills > 0 then
        table.insert(darkLines, string.format(text("RoundDistinctionBloodyTrail"), names(bloodyLeaders), math.floor(crewKills)))
    end

    local cleanCompleted = 0
    local cleanDamage = math.huge
    local cleanLeaders = {}
    for _, participant in ipairs(antagonists) do
        local completed = objectiveStats(participant)
        local crewDamage = tonumber(participant.Entry.CrewDamage) or 0
        local kills = tonumber(participant.Entry.CrewKills) or 0
        if completed > 0 and kills == 0 then
            if completed > cleanCompleted or (completed == cleanCompleted and crewDamage < cleanDamage) then
                cleanCompleted = completed
                cleanDamage = crewDamage
                cleanLeaders = { participant }
            elseif completed == cleanCompleted and crewDamage == cleanDamage then
                table.insert(cleanLeaders, participant)
            end
        end
    end
    if cleanCompleted > 0 then
        table.insert(darkLines, string.format(text("RoundDistinctionCleanWork"), names(cleanLeaders), cleanCompleted, math.floor(cleanDamage)))
    end

    if #darkLines > 0 then
        if #lines > 0 then table.insert(lines, "") end
        table.insert(lines, text("RoundDarkMeritsTitle"))
        for _, line in ipairs(darkLines) do table.insert(lines, line) end
    end

    return table.concat(lines, "\n")
end

Hook.Add("roundStart", "Traitormod.RoundStats.RoundStart", reset)

Hook.Patch("Traitormod.RoundStats.CharacterHealed", "Barotrauma.Character", "TryAdjustHealerSkill", function(character, ptable)
    local healer = ptable["healer"]
    local healthChange = tonumber(ptable["healthChange"]) or 0
    if healer == nil or healthChange <= 0 or not character.IsHuman or not healer.IsHuman then return end
    if character.TeamID ~= healer.TeamID then return end

    if character == healer then
        add(healer, "SelfHealing", healthChange)
    else
        add(healer, "Healing", healthChange)
    end
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.HullRepaired", "Barotrauma.HumanAIController", "StructureDamaged", function(instance, ptable)
    local character = ptable["character"]
    local damage = tonumber(ptable["damageAmount"]) or 0
    if character ~= nil and damage < 0 then
        add(character, "HullRepair", -damage)
    end
end, Hook.HookMethodType.After)

local function addItemRepair(character, repairable, amount)
    if amount <= 0 then return end

    for skill in repairable.RequiredSkills do
        local identifier = tostring(skill.Identifier)
        if identifier == "mechanical" then
            add(character, "MechanicalRepair", amount)
        elseif identifier == "electrical" then
            add(character, "ElectricalRepair", amount)
        end
    end
end

local function recordRepairChange(repairable)
    local snapshot = repairSnapshots[repairable]
    if snapshot == nil then return end

    local condition = tonumber(repairable.Item.Condition) or 0
    addItemRepair(snapshot.Character, repairable, condition - snapshot.Condition)
    snapshot.Condition = condition
end

Hook.Patch("Traitormod.RoundStats.StartRepairing", "Barotrauma.Items.Components.Repairable", "StartRepairing", function(instance, ptable)
    if not ptable.ReturnValue then return end

    local snapshot = repairSnapshots[instance]
    if snapshot ~= nil and (snapshot.Character ~= instance.CurrentFixer or instance.CurrentFixerAction ~= repairActions.Repair) then
        recordRepairChange(instance)
        repairSnapshots[instance] = nil
    end

    if instance.CurrentFixerAction == repairActions.Repair and repairSnapshots[instance] == nil then
        repairSnapshots[instance] = { Character = instance.CurrentFixer, Condition = tonumber(instance.Item.Condition) or 0 }
    end
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.ItemRepaired", "Barotrauma.KarmaManager", "OnItemRepaired", function(instance, ptable)
    local repairable = ptable["repairable"]
    local character = ptable["character"]
    if repairable == nil or character == nil then return end

    local snapshot = repairSnapshots[repairable]
    if snapshot == nil or snapshot.Character ~= character then
        local amount = math.max(tonumber(ptable["repairAmount"]) or 0, 0)
        addItemRepair(character, repairable, amount)
        repairSnapshots[repairable] = { Character = character, Condition = tonumber(repairable.Item.Condition) or 0 }
        return
    end

    recordRepairChange(repairable)
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.StopRepairing", "Barotrauma.Items.Components.Repairable", "StopRepairing", function(instance, ptable)
    local snapshot = repairSnapshots[instance]
    if snapshot == nil or snapshot.Character ~= ptable["character"] then return end

    recordRepairChange(instance)
    repairSnapshots[instance] = nil
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.RoundStats.DamageLimb", "Barotrauma.Character", "DamageLimb", function(character, ptable)
    local attacker = ptable["attacker"]
    local result = ptable.ReturnValue
    if attacker == nil or attacker == character or result == nil then return end

    local damage = tonumber(result.Damage) or 0
    if damage <= 0 then return end

    if character.IsHuman and attacker.IsHuman and isSecretAntagonistAgainstCrew(attacker, character) then
        add(attacker, "CrewDamage", damage)
    elseif isValidEnemy(attacker, character) then
        add(attacker, "Damage", damage)
        if isTurretDamageSource(character.LastDamageSource) then
            add(attacker, "TurretDamage", damage)
        end
    end
end, Hook.HookMethodType.After)

Hook.Add("characterDeath", "Traitormod.RoundStats.CharacterDeath", function(character)
    if character == nil then return end

    local attacker = character.CauseOfDeath ~= nil and character.CauseOfDeath.Killer or nil
    if attacker == nil or attacker == character then return end

    if character.IsHuman and attacker.IsHuman and isSecretAntagonistAgainstCrew(attacker, character) then
        add(attacker, "CrewKills", 1)
    elseif isValidEnemy(attacker, character) then
        add(attacker, "Kills", 1)
    end
end)

local originalAddGamemode = Traitormod.AddGamemode
Traitormod.AddGamemode = function(gamemode)
    local result = originalAddGamemode(gamemode)

    if gamemode.Name == "Secret" and not gamemode.RoundStatsWrapped then
        local originalRoundSummary = gamemode.RoundSummary
        gamemode.RoundSummary = function(self)
            local summary = originalRoundSummary(self)
            if self.RoundDistinctionsIncluded then return summary end

            self.RoundDistinctionsIncluded = true
            local distinctions = roundStats.BuildSecretSummary()
            if distinctions == "" then return summary end
            return summary .. "\n\n" .. distinctions
        end
        gamemode.RoundStatsWrapped = true
    end

    return result
end

if Game.RoundStarted then
    reset()
end

return roundStats
