local roundsummary = {}

local function buildSummary()
    local lines = {
        Traitormod.Language.RoundSummary,
        "",
        Traitormod.Language.DiscordFieldRound .. " " .. Traitormod.Discord.GetRoundLabel(),
        Traitormod.Language.DiscordFieldMode .. ": " .. Traitormod.Discord.GetModeDisplayName(),
        Traitormod.Language.DiscordFieldDuration .. ": " .. Traitormod.Discord.FormatDuration(Traitormod.RoundTime),
        "",
    }

    local antagonists = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        if role.IsAntagonist then
            table.insert(antagonists, { Character = character, Role = role })
        end
    end

    table.sort(antagonists, function(a, b)
        return tostring(a.Character.Name) < tostring(b.Character.Name)
    end)

    if #antagonists == 0 then
        table.insert(lines, Traitormod.Language.NoTraitors)
        return table.concat(lines, "\n")
    end

    table.insert(lines, Traitormod.Language.TraitorsRound .. " " .. #antagonists)

    for _, antagonist in ipairs(antagonists) do
        local character = antagonist.Character
        local role = antagonist.Role
        local roleText

        if role.Name == "Traitor" then
            roleText = string.format(Traitormod.Language.TraitorOther, character.Name)
        elseif role.Name == "Cultist" then
            roleText = string.format(Traitormod.Language.CultistOther, character.Name)
        elseif role.Name == "Clown" then
            roleText = string.format(Traitormod.Language.HonkMotherOther, character.Name)
        else
            roleText = role.Name .. " " .. character.Name
        end

        local client = Traitormod.FindClientCharacter(character)
        roleText = roleText .. " — " .. Traitormod.GetJobString(character)
        if client then
            roleText = roleText .. " (" .. client.Name .. ")"
        end

        table.insert(lines, "")
        table.insert(lines, roleText)

        if character.IsDead then
            table.insert(lines, Traitormod.Language.DiscordFieldStatus .. ": " .. Traitormod.Language.Dead)
        else
            local item = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
            if item ~= nil and item.Prefab.Identifier == "handcuffs" then
                table.insert(lines, string.format(Traitormod.Language.TraitorHandcuffed, character.Name))
            else
                table.insert(lines, Traitormod.Language.DiscordFieldStatus .. ": " .. Traitormod.Language.Alive)
            end
        end

        local completed = 0
        local failed = 0
        local points = 0

        for _, objective in pairs(role.Objectives or {}) do
            local objectiveCompleted = objective.Awarded
            if not objectiveCompleted and objective.EndRoundObjective and not objective.Failed and not character.IsDead then
                objectiveCompleted = objective:IsCompleted()
            end

            if objectiveCompleted then
                completed = completed + 1
                points = points + (objective.AmountPoints or 0)
                table.insert(lines, " > " .. objective.Text .. " " .. Traitormod.Language.Completed)
            else
                failed = failed + 1
                table.insert(lines, " > " .. objective.Text .. " " .. Traitormod.Language.Failed)
            end
        end

        table.insert(lines, string.format(Traitormod.Language.ObjectiveCompleted, completed) .. string.format(Traitormod.Language.Points, points))
        table.insert(lines, string.format(Traitormod.Language.ObjectiveFailed, failed))
    end

    return table.concat(lines, "\n")
end

Hook.Patch(
    "Traitormod.RoundSummary.Prepare",
    "Barotrauma.Networking.GameServer",
    "EndGame",
    function ()
        roundsummary.Message = nil
        if Traitormod.SelectedGamemode == nil then return end

        roundsummary.Message = buildSummary()
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "Traitormod.RoundSummary.EndMessage",
    "Barotrauma.TextManager",
    "FormatServerMessage",
    { "System.String" },
    function (_, ptable)
        if ptable["str"] == "RoundSummaryRoundHasEnded" and roundsummary.Message ~= nil then
            ptable.ReturnValue = roundsummary.Message
        end
    end,
    Hook.HookMethodType.After
)

return roundsummary
