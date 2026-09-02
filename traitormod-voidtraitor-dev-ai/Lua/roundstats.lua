local roundStats = {}

roundStats.Data = {}
roundStats.CharacterAccounts = {}

local repairActions = LuaUserData.CreateEnumTable("Barotrauma.Items.Components.Repairable+FixActions")
local repairSnapshots = {}
local healingStates = {}
local pendingReductions = {}
local pendingAfflictions = {}
local healingUpdateTimer = 0

local recentTreatmentSeconds = 12
local duplicateHealingWindow = 0.05
local minimumReportedHealing = 0.5
local healingUpdateInterval = 0.25

local distinctionMinimums = {
    Healing = 25,
    SelfHealing = 25,
    HullRepair = 100,
    MechanicalRepair = 25,
    ElectricalRepair = 25,
    Damage = 100,
    TurretDamage = 100,
    Kills = 1,
}

local function isTrackedMode()
    if not Game.RoundStarted or Traitormod.SelectedGamemode == nil then return false end

    local name = Traitormod.SelectedGamemode.Name
    return name == "Secret" or name == "AttackDefendV2"
end

local function isGhostRole(character)
    return Traitormod.GhostRoles ~= nil and Traitormod.GhostRoles.IsGhostRole ~= nil
        and Traitormod.GhostRoles.IsGhostRole(character)
end

local function isEligiblePlayerCharacter(character)
    return character ~= nil
        and character.IsHuman
        and character.TeamID ~= CharacterTeamType.None
        and character.TeamID ~= CharacterTeamType.FriendlyNPC
        and not isGhostRole(character)
end

local function ensureEntry(accountKey, name)
    if accountKey == nil then return nil end

    local entry = roundStats.Data[accountKey]
    if entry == nil then
        entry = { Name = name }
        roundStats.Data[accountKey] = entry
    elseif name ~= nil then
        entry.Name = name
    end

    return entry
end

local function getCurrentPlayerAccount(character)
    if not isTrackedMode() or not isEligiblePlayerCharacter(character) then return nil end

    local client = Traitormod.FindClientCharacter(character)
    if client == nil or client.Character ~= character or client.SpectateOnly then return nil end

    local accountKey = Traitormod.GetClientAccountKey(client)
    if accountKey == nil then return nil end

    roundStats.CharacterAccounts[character] = accountKey
    ensureEntry(accountKey, tostring(character.Name))
    return accountKey
end

local function getCharacterAccount(character)
    if not isTrackedMode() or not isEligiblePlayerCharacter(character) then return nil end

    local client = Traitormod.FindClientCharacter(character)
    if client ~= nil and client.Character == character and not client.SpectateOnly then
        local accountKey = Traitormod.GetClientAccountKey(client)
        if accountKey ~= nil then
            roundStats.CharacterAccounts[character] = accountKey
            ensureEntry(accountKey, tostring(character.Name))
            return accountKey
        end
    end

    return roundStats.CharacterAccounts[character]
end

local function addAccount(accountKey, key, amount)
    amount = tonumber(amount) or 0
    if accountKey == nil or amount <= 0 then return end

    local entry = ensureEntry(accountKey)
    if entry == nil then return end
    entry[key] = (entry[key] or 0) + amount
end

local function reset()
    roundStats.Data = {}
    roundStats.CharacterAccounts = {}
    repairSnapshots = {}
    healingStates = {}
    pendingReductions = {}
    pendingAfflictions = {}
    healingUpdateTimer = 0

    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and isEligiblePlayerCharacter(character) and not client.SpectateOnly then
            local accountKey = Traitormod.GetClientAccountKey(client)
            if accountKey ~= nil then
                roundStats.CharacterAccounts[character] = accountKey
                ensureEntry(accountKey, tostring(character.Name))
            end
        end
    end
end

local function getRole(character)
    if Traitormod.RoleManager == nil then return nil end
    return Traitormod.RoleManager.GetRole(character)
end

local function isSecretAntagonistAgainstCrew(attacker, target)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Secret" then return false end
    if target == nil or not target.IsHuman or target.TeamID ~= CharacterTeamType.Team1 then return false end

    local attackerRole = getRole(attacker)
    local targetRole = getRole(target)
    return attackerRole ~= nil and attackerRole.IsAntagonist
        and targetRole ~= nil and not targetRole.IsAntagonist
end

local function isValidEnemy(attacker, target)
    if attacker == nil or target == nil or attacker == target then return false end

    if Traitormod.SelectedGamemode ~= nil and Traitormod.SelectedGamemode.Name == "Secret" then
        local attackerRole = getRole(attacker)
        if attackerRole ~= nil and attackerRole.IsAntagonist then
            return false
        end

        local targetRole = getRole(target)
        if targetRole ~= nil and targetRole.IsAntagonist then
            return true
        end
    end

    return target.TeamID ~= attacker.TeamID and target.TeamID ~= CharacterTeamType.FriendlyNPC
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
            local accountKey = getCharacterAccount(character)
            if accountKey ~= nil then
                antagonistAccounts[accountKey] = true
            end
        end
    end

    local added = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        local accountKey = getCharacterAccount(character)
        local entry = accountKey ~= nil and roundStats.Data[accountKey] or nil
        if entry ~= nil and not added[accountKey]
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
        local value = math.floor(tonumber(getValue(participant)) or 0)
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

local function isOwnSubmarine(submarine, character)
    return submarine ~= nil and character ~= nil and submarine.TeamID == character.TeamID
end

local function addItemRepair(accountKey, repairable, amount)
    amount = tonumber(amount) or 0
    if accountKey == nil or repairable == nil or amount <= 0 then return end

    for skill in repairable.RequiredSkills do
        local identifier = tostring(skill.Identifier)
        if identifier == "mechanical" then
            addAccount(accountKey, "MechanicalRepair", amount)
        elseif identifier == "electrical" then
            addAccount(accountKey, "ElectricalRepair", amount)
        end
    end
end

local function recordRepairChange(repairable)
    local snapshot = repairSnapshots[repairable]
    if snapshot == nil then return end

    if repairable.Item == nil or repairable.Item.Removed then
        repairSnapshots[repairable] = nil
        return
    end

    local condition = tonumber(repairable.Item.Condition) or 0
    addItemRepair(snapshot.AccountKey, repairable, condition - snapshot.Condition)
    snapshot.Condition = condition
end

local function flushRepairs()
    for repairable in pairs(repairSnapshots) do
        recordRepairChange(repairable)
    end
end

local function getHealingState(target)
    local state = healingStates[target]
    if state == nil then
        state = {
            LastVitality = tonumber(target.Vitality) or 0,
            RecentHealer = nil,
            RecentSelf = false,
            RecentHealerExpiresAt = 0,
            LastDirectHealer = nil,
            LastDirectAmount = 0,
            LastDirectAt = 0,
        }
        healingStates[target] = state
    end
    return state
end

local function getTreatmentAccounts(target, healer)
    local healerAccount = getCurrentPlayerAccount(healer)
    if healerAccount == nil or healer.IsDead or target == nil or target.IsDead or not target.IsHuman or target.TeamID ~= healer.TeamID then return nil end

    local targetAccount = getCurrentPlayerAccount(target)
    if targetAccount == nil then return nil end

    return healerAccount, targetAccount
end

local function markRecentHealer(target, healerAccount, targetAccount)
    if target == nil or healerAccount == nil or targetAccount == nil then return end

    local state = getHealingState(target)
    state.RecentHealer = healerAccount
    state.RecentSelf = healerAccount == targetAccount
    state.RecentHealerExpiresAt = Timer.GetTime() + recentTreatmentSeconds
end

local function isDuplicateDirectHealing(target, healerAccount, amount)
    local state = healingStates[target]
    if state == nil or state.LastDirectHealer ~= healerAccount then return false end
    if math.abs(state.LastDirectAmount - amount) > minimumReportedHealing then return false end
    return Timer.GetTime() - state.LastDirectAt <= duplicateHealingWindow
end

local function registerDirectHealing(target, healerAccount, targetAccount, amount)
    amount = tonumber(amount) or 0
    if amount < minimumReportedHealing then return end

    local state = getHealingState(target)
    addAccount(healerAccount, healerAccount == targetAccount and "SelfHealing" or "Healing", amount)

    state.LastVitality = tonumber(target.Vitality) or state.LastVitality
    state.LastDirectHealer = healerAccount
    state.LastDirectAmount = amount
    state.LastDirectAt = Timer.GetTime()
end

local function captureReduction(instance, ptable)
    if instance == nil or instance.Character == nil then return end

    local target = instance.Character
    local healer = ptable["attacker"]
    local healerAccount, targetAccount = getTreatmentAccounts(target, healer)
    if healerAccount == nil then return end

    markRecentHealer(target, healerAccount, targetAccount)
    table.insert(pendingReductions, {
        Health = instance,
        Target = target,
        PrevVitality = tonumber(target.Vitality) or 0,
        HealerAccount = healerAccount,
        TargetAccount = targetAccount,
    })
end

local function finishReduction(instance)
    local index
    for i = #pendingReductions, 1, -1 do
        if pendingReductions[i].Health == instance then
            index = i
            break
        end
    end
    if index == nil then return end

    local context = table.remove(pendingReductions, index)
    if context.Target == nil or context.Target.Removed then return end

    local healthChange = (tonumber(context.Target.Vitality) or context.PrevVitality) - context.PrevVitality
    if healthChange >= minimumReportedHealing and not isDuplicateDirectHealing(context.Target, context.HealerAccount, healthChange) then
        registerDirectHealing(context.Target, context.HealerAccount, context.TargetAccount, healthChange)
    end
end

local function captureAppliedAffliction(instance, ptable)
    if instance == nil or instance.Character == nil or ptable["allowStacking"] ~= false then return end

    local affliction = ptable["affliction"]
    local healer = affliction ~= nil and affliction.Source or nil
    local target = instance.Character
    local healerAccount, targetAccount = getTreatmentAccounts(target, healer)
    if healerAccount == nil or affliction.Prefab == nil then return end

    table.insert(pendingAfflictions, {
        Health = instance,
        Target = target,
        Identifier = affliction.Prefab.Identifier,
        PrevStrength = tonumber(instance.GetAfflictionStrengthByIdentifier(affliction.Prefab.Identifier, true)) or 0,
        PrevVitality = tonumber(target.Vitality) or 0,
        HealerAccount = healerAccount,
        TargetAccount = targetAccount,
    })
end

local function finishAppliedAffliction(instance)
    local index
    for i = #pendingAfflictions, 1, -1 do
        if pendingAfflictions[i].Health == instance then
            index = i
            break
        end
    end
    if index == nil then return end

    local context = table.remove(pendingAfflictions, index)
    if context.Target == nil or context.Target.Removed then return end

    local currentStrength = tonumber(instance.GetAfflictionStrengthByIdentifier(context.Identifier, true)) or context.PrevStrength
    local healthChange = (tonumber(context.Target.Vitality) or context.PrevVitality) - context.PrevVitality

    if currentStrength < context.PrevStrength then
        markRecentHealer(context.Target, context.HealerAccount, context.TargetAccount)
    end

    if healthChange >= minimumReportedHealing and not isDuplicateDirectHealing(context.Target, context.HealerAccount, healthChange) then
        registerDirectHealing(context.Target, context.HealerAccount, context.TargetAccount, healthChange)
    end
end

local function updateDelayedHealing()
    local currentTime = Timer.GetTime()

    for target, state in pairs(healingStates) do
        if target == nil or target.Removed or target.IsDead then
            healingStates[target] = nil
        else
            local vitality = tonumber(target.Vitality) or state.LastVitality
            local gain = vitality - state.LastVitality

            if gain >= minimumReportedHealing
                and state.RecentHealer ~= nil
                and currentTime <= state.RecentHealerExpiresAt
            then
                addAccount(state.RecentHealer, state.RecentSelf and "SelfHealing" or "Healing", gain)
            end

            state.LastVitality = vitality

            if state.RecentHealer ~= nil and currentTime > state.RecentHealerExpiresAt then
                state.RecentHealer = nil
                state.RecentSelf = false
            end
        end
    end
end

function roundStats.BuildSecretSummary()
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Secret" then return "" end

    flushRepairs()
    updateDelayedHealing()

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
        if value >= distinctionMinimums[distinction[2]] then
            table.insert(crewLines, string.format(Traitormod.GetText(distinction[1]), names(leaders), value))
        end
    end

    if #crewLines > 0 then
        table.insert(lines, Traitormod.GetText("RoundDistinctionsTitle"))
        for _, line in ipairs(crewLines) do table.insert(lines, line) end
    end

    local antagonists = getParticipants(true)
    local darkLines = {}

    local objectivePoints, greyLeaders = maxLeaders(antagonists, function(participant)
        local _, points = objectiveStats(participant)
        return points
    end)
    if objectivePoints > 0 then
        table.insert(darkLines, string.format(Traitormod.GetText("RoundDistinctionGreyCardinal"), names(greyLeaders), objectivePoints))
    end

    local crewKills, bloodyLeaders = maxLeaders(antagonists, function(participant)
        return participant.Entry.CrewKills or 0
    end)
    if crewKills > 0 then
        table.insert(darkLines, string.format(Traitormod.GetText("RoundDistinctionBloodyTrail"), names(bloodyLeaders), crewKills))
    end

    local cleanCompleted = 0
    local cleanDamage = math.huge
    local cleanLeaders = {}
    for _, participant in ipairs(antagonists) do
        local completed = objectiveStats(participant)
        local crewDamage = math.floor(tonumber(participant.Entry.CrewDamage) or 0)
        local kills = math.floor(tonumber(participant.Entry.CrewKills) or 0)
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
        table.insert(darkLines, string.format(Traitormod.GetText("RoundDistinctionCleanWork"), names(cleanLeaders), cleanCompleted, cleanDamage))
    end

    if #darkLines > 0 then
        if #lines > 0 then table.insert(lines, "") end
        table.insert(lines, Traitormod.GetText("RoundDarkMeritsTitle"))
        for _, line in ipairs(darkLines) do table.insert(lines, line) end
    end

    return table.concat(lines, "\n")
end

Hook.Add("roundStart", "Traitormod.RoundStats.RoundStart", reset)

Hook.Patch("Traitormod.RoundStats.ReduceAfflictionAll.Before", "Barotrauma.CharacterHealth", "ReduceAfflictionOnAllLimbs", function(instance, ptable)
    captureReduction(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.RoundStats.ReduceAfflictionAll.After", "Barotrauma.CharacterHealth", "ReduceAfflictionOnAllLimbs", function(instance)
    finishReduction(instance)
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.ReduceAfflictionLimb.Before", "Barotrauma.CharacterHealth", "ReduceAfflictionOnLimb", function(instance, ptable)
    captureReduction(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.RoundStats.ReduceAfflictionLimb.After", "Barotrauma.CharacterHealth", "ReduceAfflictionOnLimb", function(instance)
    finishReduction(instance)
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.ApplyAffliction.Before", "Barotrauma.CharacterHealth", "ApplyAffliction", function(instance, ptable)
    captureAppliedAffliction(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.RoundStats.ApplyAffliction.After", "Barotrauma.CharacterHealth", "ApplyAffliction", function(instance)
    finishAppliedAffliction(instance)
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.CharacterHealed", "Barotrauma.Character", "TryAdjustHealerSkill", function(character, ptable)
    local healer = ptable["healer"]
    local healerAccount, targetAccount = getTreatmentAccounts(character, healer)
    if healerAccount == nil then return end

    markRecentHealer(character, healerAccount, targetAccount)

    local healthChange = tonumber(ptable["healthChange"]) or 0
    if healthChange >= minimumReportedHealing and not isDuplicateDirectHealing(character, healerAccount, healthChange) then
        registerDirectHealing(character, healerAccount, targetAccount, healthChange)
    end
end, Hook.HookMethodType.After)

Hook.Add("think", "Traitormod.RoundStats.DelayedHealing", function(deltaTime)
    if not isTrackedMode() then
        healingUpdateTimer = 0
        return
    end

    healingUpdateTimer = healingUpdateTimer + deltaTime
    if healingUpdateTimer < healingUpdateInterval then return end
    healingUpdateTimer = 0
    updateDelayedHealing()
end)

Hook.Patch("Traitormod.RoundStats.HullRepaired", "Barotrauma.HumanAIController", "StructureDamaged", function(instance, ptable)
    local character = ptable["character"]
    local structure = ptable["structure"]
    local damage = tonumber(ptable["damageAmount"]) or 0
    if damage >= 0 or not isOwnSubmarine(structure ~= nil and structure.Submarine or nil, character) then return end

    local accountKey = getCurrentPlayerAccount(character)
    if accountKey ~= nil then
        addAccount(accountKey, "HullRepair", -damage)
    end
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.StartRepairing", "Barotrauma.Items.Components.Repairable", "StartRepairing", function(instance, ptable)
    if not ptable.ReturnValue then return end

    local snapshot = repairSnapshots[instance]
    if snapshot ~= nil and (snapshot.Character ~= instance.CurrentFixer or instance.CurrentFixerAction ~= repairActions.Repair) then
        recordRepairChange(instance)
        repairSnapshots[instance] = nil
    end

    if instance.CurrentFixerAction ~= repairActions.Repair or repairSnapshots[instance] ~= nil then return end

    local character = instance.CurrentFixer
    if character == nil or not isOwnSubmarine(instance.Item ~= nil and instance.Item.Submarine or nil, character) then return end

    local accountKey = getCurrentPlayerAccount(character)
    if accountKey ~= nil then
        repairSnapshots[instance] = {
            AccountKey = accountKey,
            Character = character,
            Condition = tonumber(instance.Item.Condition) or 0,
        }
    end
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.RoundStats.StopRepairing", "Barotrauma.Items.Components.Repairable", "StopRepairing", function(instance, ptable)
    local snapshot = repairSnapshots[instance]
    if snapshot == nil or snapshot.Character ~= ptable["character"] or instance.CurrentFixer ~= ptable["character"] then return end

    recordRepairChange(instance)
    repairSnapshots[instance] = nil
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.RoundStats.DamageLimb", "Barotrauma.Character", "DamageLimb", function(character, ptable)
    local attacker = ptable["attacker"]
    local result = ptable.ReturnValue
    if attacker == nil or attacker == character or result == nil then return end

    local accountKey = getCharacterAccount(attacker)
    if accountKey == nil then return end

    local damage = tonumber(result.Damage) or 0
    if damage <= 0 then return end

    if isSecretAntagonistAgainstCrew(attacker, character) then
        addAccount(accountKey, "CrewDamage", damage)
    elseif isValidEnemy(attacker, character) then
        addAccount(accountKey, "Damage", damage)
        if isTurretDamageSource(character.LastDamageSource) then
            addAccount(accountKey, "TurretDamage", damage)
        end
    end
end, Hook.HookMethodType.After)

Hook.Add("characterDeath", "Traitormod.RoundStats.CharacterDeath", function(character)
    if not isTrackedMode() or character == nil then return end

    local attacker = character.CauseOfDeath ~= nil and character.CauseOfDeath.Killer or nil
    if attacker == nil or attacker == character then return end

    local accountKey = getCharacterAccount(attacker)
    if accountKey == nil then return end

    if isSecretAntagonistAgainstCrew(attacker, character) then
        addAccount(accountKey, "CrewKills", 1)
    elseif isValidEnemy(attacker, character) then
        addAccount(accountKey, "Kills", 1)
    end
end)

Hook.Add("roundEnd", "Traitormod.RoundStats.RoundEnd", function()
    flushRepairs()
    updateDelayedHealing()
    repairSnapshots = {}
    healingStates = {}
    pendingReductions = {}
    pendingAfflictions = {}
    healingUpdateTimer = 0
end)

if Game.RoundStarted then
    reset()
end

return roundStats
