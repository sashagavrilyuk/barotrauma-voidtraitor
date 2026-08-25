local objective = Traitormod.RoleManager.Objectives.Objective:new()

objective.Name = "HealCharacters"
objective.AmountPoints = 400
objective.Amount = 500
objective.RecentTreatmentAttributionSeconds = 12
objective.DedupWindowSeconds = 0.05
objective.MinimumReportedHeal = 0.5

objective.PendingReductionCalls = {}
objective.CharacterStates = {}
objective.ActiveObjectives = setmetatable({}, { __mode = "k" })

local function now()
    if Timer ~= nil and Timer.GetTime ~= nil then
        return Timer.GetTime()
    end

    return 0
end

local function getCharacterState(character)
    local state = objective.CharacterStates[character]
    if state ~= nil then return state end

    state = {
        LastVitality = character ~= nil and character.Vitality or 0,
        RecentHealer = nil,
        RecentHealerExpiresAt = 0,
        IgnoreHealing = 0,
        LastDirectHealer = nil,
        LastDirectAmount = 0,
        LastDirectAt = 0,
    }

    objective.CharacterStates[character] = state
    return state
end

local function updateObjectiveText(obj)
    obj.Text = string.format(Traitormod.Language.ObjectiveHealCharacters, math.floor(obj.Progress), obj.Amount)
end

local function isActiveHealObjective(activeObjective)
    return activeObjective ~= nil
        and not activeObjective.Awarded
        and not activeObjective.Failed
        and activeObjective.Character ~= nil
        and not activeObjective.Character.IsDead
end

local function getActiveHealObjective(healer)
    if healer == nil then return nil end

    for activeObjective in pairs(objective.ActiveObjectives) do
        if not isActiveHealObjective(activeObjective) then
            objective.ActiveObjectives[activeObjective] = nil
        elseif activeObjective.Character == healer then
            return activeObjective
        end
    end

    return nil
end

local function hasActiveHealObjectives()
    for activeObjective in pairs(objective.ActiveObjectives) do
        if isActiveHealObjective(activeObjective) then
            return true
        end
        objective.ActiveObjectives[activeObjective] = nil
    end
    return false
end

local function awardHealing(targetCharacter, healer, amount)
    if amount == nil or amount < objective.MinimumReportedHeal then return end
    if targetCharacter == nil or targetCharacter.Removed then return end

    local activeObjective = getActiveHealObjective(healer)
    if activeObjective == nil then return end

    activeObjective.Progress = activeObjective.Progress + amount
    updateObjectiveText(activeObjective)
end

local function markRecentHealer(targetCharacter, healer)
    if targetCharacter == nil or healer == nil then return end

    local state = getCharacterState(targetCharacter)
    state.RecentHealer = healer
    state.RecentHealerExpiresAt = now() + objective.RecentTreatmentAttributionSeconds
end

local function registerDirectHealing(targetCharacter, healer, amount)
    if targetCharacter == nil or healer == nil then return end

    markRecentHealer(targetCharacter, healer)

    if amount == nil or amount < objective.MinimumReportedHeal then return end

    local state = getCharacterState(targetCharacter)
    state.IgnoreHealing = state.IgnoreHealing + amount
    state.LastVitality = targetCharacter.Vitality
    state.LastDirectHealer = healer
    state.LastDirectAmount = amount
    state.LastDirectAt = now()

    awardHealing(targetCharacter, healer, amount)
end

local function isDuplicateDirectHealing(targetCharacter, healer, amount)
    if targetCharacter == nil or healer == nil or amount == nil then return false end

    local state = getCharacterState(targetCharacter)
    if state.LastDirectHealer ~= healer then return false end
    if math.abs(state.LastDirectAmount - amount) > objective.MinimumReportedHeal then return false end

    return (now() - state.LastDirectAt) <= objective.DedupWindowSeconds
end

local function captureReductionState(instance, ptable)
    if instance == nil or instance.Character == nil then return end

    local healer = ptable["attacker"]
    if getActiveHealObjective(healer) == nil then return end

    table.insert(objective.PendingReductionCalls, {
        Health = instance,
        Target = instance.Character,
        PrevVitality = instance.Character.Vitality,
        Healer = healer,
    })
end

local function finishReductionState(instance)
    local index = nil
    for i = #objective.PendingReductionCalls, 1, -1 do
        if objective.PendingReductionCalls[i].Health == instance then
            index = i
            break
        end
    end

    if index == nil then return end

    local context = table.remove(objective.PendingReductionCalls, index)
    local targetCharacter = context.Target
    local healer = context.Healer

    if targetCharacter == nil or targetCharacter.Removed or healer == nil then return end

    local healthChange = targetCharacter.Vitality - context.PrevVitality
    registerDirectHealing(targetCharacter, healer, healthChange)
end

objective.Static = function()
    Hook.Patch(
        "Traitormod.Objective.HealCharacters.ReduceAfflictionAll.Before",
        "Barotrauma.CharacterHealth",
        "ReduceAfflictionOnAllLimbs",
        function(instance, ptable)
            captureReductionState(instance, ptable)
        end,
        Hook.HookMethodType.Before
    )

    Hook.Patch(
        "Traitormod.Objective.HealCharacters.ReduceAfflictionAll.After",
        "Barotrauma.CharacterHealth",
        "ReduceAfflictionOnAllLimbs",
        function(instance, _)
            finishReductionState(instance)
        end,
        Hook.HookMethodType.After
    )

    Hook.Patch(
        "Traitormod.Objective.HealCharacters.ReduceAfflictionLimb.Before",
        "Barotrauma.CharacterHealth",
        "ReduceAfflictionOnLimb",
        function(instance, ptable)
            captureReductionState(instance, ptable)
        end,
        Hook.HookMethodType.Before
    )

    Hook.Patch(
        "Traitormod.Objective.HealCharacters.ReduceAfflictionLimb.After",
        "Barotrauma.CharacterHealth",
        "ReduceAfflictionOnLimb",
        function(instance, _)
            finishReductionState(instance)
        end,
        Hook.HookMethodType.After
    )

    Hook.Add("think", "Traitormod.Objective.HealCharacters.TrackDelayedHealing", function()
        if not Game.RoundStarted or not hasActiveHealObjectives() then return end

        local currentTime = now()
        for character, state in pairs(objective.CharacterStates) do
            if character == nil or character.Removed then
                objective.CharacterStates[character] = nil
            else
                local currentVitality = character.Vitality
                local vitalityGain = currentVitality - state.LastVitality

                if vitalityGain > 0 then
                    if state.IgnoreHealing > 0 then
                        local ignored = math.min(vitalityGain, state.IgnoreHealing)
                        state.IgnoreHealing = state.IgnoreHealing - ignored
                        vitalityGain = vitalityGain - ignored
                    end

                    if vitalityGain >= objective.MinimumReportedHeal and state.RecentHealer ~= nil and currentTime <= state.RecentHealerExpiresAt then
                        awardHealing(character, state.RecentHealer, vitalityGain)
                    end
                end

                state.LastVitality = currentVitality

                if state.RecentHealer ~= nil and currentTime > state.RecentHealerExpiresAt then
                    state.RecentHealer = nil
                end
            end
        end
    end)

    Hook.Add("roundEnd", "Traitormod.Objective.HealCharacters.RoundEnd", function()
        objective.PendingReductionCalls = {}
        objective.CharacterStates = {}
        objective.ActiveObjectives = setmetatable({}, { __mode = "k" })
    end)
end

function objective:CharacterHealed(targetCharacter, healer, healthChange)
    if healer ~= self.Character or self.Awarded or self.Failed then return end
    if targetCharacter == nil or healer == nil then return end

    healthChange = healthChange or 0
    markRecentHealer(targetCharacter, healer)

    if healthChange >= objective.MinimumReportedHeal and not isDuplicateDirectHealing(targetCharacter, healer, healthChange) then
        registerDirectHealing(targetCharacter, healer, healthChange)
    end
end

function objective:Start(target)
    self.Progress = 0
    objective.ActiveObjectives[self] = true

    updateObjectiveText(self)

    return true
end

function objective:OnAwarded()
    objective.ActiveObjectives[self] = nil
end

function objective:IsCompleted()
    return self.Progress >= self.Amount
end

return objective
