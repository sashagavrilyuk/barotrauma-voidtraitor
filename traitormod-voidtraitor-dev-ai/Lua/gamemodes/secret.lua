local weightedRandom = dofile(Traitormod.Path .. "/Lua/weightedrandom.lua")
local gm = Traitormod.Gamemodes.Gamemode:new()

local missionDescriptor = Descriptors["Barotrauma.Mission"] or LuaUserData.RegisterType("Barotrauma.Mission")
if not LuaUserData.IsRegistered("Barotrauma.CheckDataAction") then LuaUserData.RegisterType("Barotrauma.CheckDataAction") end
local gameServerDescriptor = Descriptors["Barotrauma.Networking.GameServer"] or LuaUserData.RegisterType("Barotrauma.Networking.GameServer")

local transitionTypes = LuaUserData.CreateEnumTable("Barotrauma.CampaignMode+TransitionType")
local voteTypes = LuaUserData.CreateEnumTable("Barotrauma.Networking.VoteType")
LuaUserData.MakeMethodAccessible(missionDescriptor, "DetermineCompleted")
LuaUserData.MakeFieldAccessible(missionDescriptor, "completeCheckDataAction")
LuaUserData.MakePropertyAccessible(gameServerDescriptor, "EndRoundTimer")

local summaryNetMessage = "VoidTraitor_RoundSummary"
local softEndDelaySeconds = 60
local updatingVoteStatus = false

gm.Name = "Secret"

local function missionWouldComplete(mission)
    if mission == nil or mission.ForceFailure then return false end
    if mission.Completed then return true end
    if not mission.DetermineCompleted(transitionTypes.None) then return false end

    local completeCheck = mission.completeCheckDataAction
    return completeCheck == nil or completeCheck.GetSuccess()
end

local function reachedLevelEnd()
    local mainSub = Submarine.MainSub
    local level = Level.Loaded
    if mainSub == nil or level == nil then return false end

    local endOutpost = level.EndOutpost
    if endOutpost == nil then
        return mainSub.AtEndExit
    end

    local charactersInsideOutpost = 0
    local charactersOutsideOutpost = 0
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and not character.IsDead and not character.IsUnconscious then
            if character.Submarine == endOutpost then
                charactersInsideOutpost = charactersInsideOutpost + 1
            else
                charactersOutsideOutpost = charactersOutsideOutpost + 1
            end
        end
    end

    return mainSub.DockedTo.Contains(endOutpost)
        or (mainSub.AtEndExit and charactersInsideOutpost > 0)
        or charactersInsideOutpost > charactersOutsideOutpost
end


local function finalizePointshopRefunds()
    if Traitormod.Config.TestMode or not Traitormod.Config.PointShopConfig.DeathSpawnRefundAtEndRound then return end

    for client, refund in pairs(Traitormod.Pointshop.Refunds) do
        if client.Character ~= nil and not client.Character.IsPet then
            local price = refund.Price * math.min(client.Character.Vitality / client.Character.MaxVitality, 1)
            Traitormod.AwardPoints(client, price)
            Traitormod.SendMessage(client, string.format(Traitormod.Language.PointshopRefunded, price, Traitormod.Pointshop.GetProductName(refund.Product)))
        end
        Traitormod.Pointshop.Refunds[client] = nil
    end
end

local function lockProgress(self)
    self.OriginalSetData = Traitormod.SetData
    self.OriginalAwardPoints = Traitormod.AwardPoints
    self.OriginalAdjustLives = Traitormod.AdjustLives
    self.OriginalActivateProduct = Traitormod.Pointshop.ActivateProduct

    Traitormod.SetData = function(client, name, amount)
        if self.Ending and (name == "Points" or name == "Lives") then return end
        return self.OriginalSetData(client, name, amount)
    end

    Traitormod.AwardPoints = function(client, amount, isMissionXP)
        if self.Ending then return 0 end
        return self.OriginalAwardPoints(client, amount, isMissionXP)
    end

    Traitormod.AdjustLives = function(client, amount)
        if self.Ending then return end
        return self.OriginalAdjustLives(client, amount)
    end

    Traitormod.Pointshop.ActivateProduct = function(client, product, paidPrice, itemsToSpawn)
        if self.Ending then paidPrice = 0 end
        return self.OriginalActivateProduct(client, product, paidPrice, itemsToSpawn)
    end
end

local function unlockProgress(self)
    if self.OriginalSetData == nil then return end

    Traitormod.SetData = self.OriginalSetData
    Traitormod.AwardPoints = self.OriginalAwardPoints
    Traitormod.AdjustLives = self.OriginalAdjustLives
    Traitormod.Pointshop.ActivateProduct = self.OriginalActivateProduct

    self.OriginalSetData = nil
    self.OriginalAwardPoints = nil
    self.OriginalAdjustLives = nil
    self.OriginalActivateProduct = nil
end

local function sendSummaryPopup(client, summary)
    if Traitormod.ClientHasLua ~= nil and Traitormod.ClientHasLua(client) then
        local message = Networking.Start(summaryNetMessage)
        message.WriteString(summary)
        message.WriteString(Traitormod.GetText("GhostRolesMenuCancel"))
        Networking.Send(message, client.Connection)
    else
        Game.SendDirectChatMessage("", summary, nil, ChatMessageType.ServerMessageBoxInGame, client, "InfoFrameTabButton.Mission")
    end
end

function gm:CharacterDeath(character)
    if self.Ending then return end
    local client = Traitormod.FindClientCharacter(character)

    -- if character is valid player
    if client == nil or
        character == nil or
        character.IsHuman == false or
        character.ClientDisconnected == true or
        character.TeamID == 0 then
        return
    end

    if Traitormod.RoundTime < Traitormod.Config.MinRoundTimeToLooseLives then
        return
    end

    local accountKey = Traitormod.GetClientAccountKey(client)
    if Traitormod.LostLivesThisRound[accountKey] == nil then
        Traitormod.LostLivesThisRound[accountKey] = true
    else
        return
    end

    local liveMsg, liveIcon = Traitormod.AdjustLives(client, -1)

    Traitormod.SendMessage(client, liveMsg, liveIcon)
end

function gm:Start()
    local this = self

    self.Ending = false
    self.ResultsFinalized = false
    self.AllowRealEndGame = false
    self.FinalSummary = nil

    if self.EnableRandomEvents then
        Traitormod.RoundEvents.Initialize()
    end

    Hook.Add("characterDeath", "Traitormod.Secret.CharacterDeath", function(character, affliction)
        this:CharacterDeath(character)
    end)

    self:SelectAntagonists()
end

function gm:AssignAntagonists(antagonists)
    local function AssignCrew()
        for key, value in pairs(Client.ClientList) do
            if value.Character ~= nil and value.Character.IsHuman and not value.SpectateOnly and not value.Character.IsDead and value.Character.TeamID == CharacterTeamType.Team1 then
                local role = Traitormod.RoleManager.GetRole(value.Character)
                if role == nil then
                    role = Traitormod.RoleManager.Roles["Crew"]
                    Traitormod.RoleManager.AssignRole(value.Character, role:new())
                end
            end
        end

        Hook.Add("traitormod.midroundspawn", "Traitormod.Secret.MidRoundSpawn", function (client, character)
            local role = Traitormod.RoleManager.GetRole(character)
            if role == nil then
                role = Traitormod.RoleManager.Roles["Crew"]
                Traitormod.RoleManager.AssignRole(character, role:new())
            end
        end)
    end

    local function Assign(roles)
        for key, role in pairs(roles) do
            if role.Name == "Cultist" then
                self.RoundEndIcon = "oneofus"
                Game.EnableControlHusk(true)
            end
        end

        local newRoles = {}

        for key, value in pairs(antagonists) do
            table.insert(newRoles, roles[key]:new())
        end

        Traitormod.RoleManager.AssignRoles(antagonists, newRoles)

        AssignCrew()
    end

    if self.TraitorTypeSelectionMode == "Random" then
        local role = Traitormod.RoleManager.Roles[weightedRandom.Choose(self.TraitorTypeChance)]

        local roles = {}
        for key, value in pairs(antagonists) do
            table.insert(roles, role)
        end
        Assign(roles)
    else
        local options = {}
        for key, value in pairs(self.TraitorTypeChance) do
            table.insert(options, key)
        end

        local clients = {}

        for key, value in pairs(antagonists) do
            local client = Traitormod.FindClientCharacter(value)
            if client then
                table.insert(clients, client)
            end
        end

        if #clients == 0 then
            Assign({})
            return
        end

        Traitormod.Voting.StartVote(Traitormod.Language.SecretTraitorAssigned, options, 25, function (results, clientVotes)
            local highestVoted = nil
            local highestedVotedRole = nil
            for key, value in pairs(options) do
                if highestVoted == nil or results[key] > highestVoted then
                    highestVoted = results[key]
                    highestedVotedRole = value
                end
            end

            local roles = {}
            for key, value in pairs(clientVotes) do
                local role = ""
                if value == -1 then
                    role = Traitormod.RoleManager.Roles[highestedVotedRole]
                else
                    role = Traitormod.RoleManager.Roles[options[value]]
                end

                table.insert(roles, role)
            end
            Assign(roles)
        end, clients)
    end
end

function gm:SelectAntagonists()
    local this = self
    local thisRoundNumber = Traitormod.RoundNumber

    local delay = math.random(self.TraitorSelectDelayMin, self.TraitorSelectDelayMax)

    Timer.Wait(function()
        if thisRoundNumber ~= Traitormod.RoundNumber or not Game.RoundStarted then return end

        local clientWeight = {}
        local traitorChoices = 0
        local playerInGame = 0
        for key, value in pairs(Client.ClientList) do
            -- valid traitor choices must be ingame, player was spawned before (has a character), is no spectator
            if value.InGame and value.Character and not value.SpectateOnly then
                -- filter by config
                if this.TraitorFilter(value) > 0 and Traitormod.GetData(value, "NonTraitor") ~= true then
                    -- players are alive or if respawning is on and config allows dead traitors (not supported yet)
                    if not value.Character.IsDead and Traitormod.RoleManager.GetRole(value.Character) == nil then
                        clientWeight[value] = (Traitormod.GetData(value, "Weight") or 0) * this.TraitorFilter(value)
                        traitorChoices = traitorChoices + 1
                    end
                end
                playerInGame = playerInGame + 1
            end
        end

        if traitorChoices == 0 then
            this:AssignAntagonists({})
            Traitormod.Log("No players to assign traitors")
            return
        end

        local amountTraitors = this.AmountTraitors(playerInGame)
        if amountTraitors > traitorChoices then
            amountTraitors = traitorChoices
            Traitormod.Log("Not enough valid players to assign all traitors... New amount: " .. tostring(amountTraitors))
        end

        local antagonists = {}

        for i = 1, amountTraitors, 1 do
            local index = weightedRandom.Choose(clientWeight)

            if index ~= nil then
                Traitormod.Log("Chose " ..
                    index.Character.Name .. " as traitor. Weight: " .. math.floor(clientWeight[index] * 100) / 100)

                table.insert(antagonists, index.Character)

                clientWeight[index] = nil

                Traitormod.SetData(index, "Weight", 0)
            end
        end

        self:AssignAntagonists(antagonists)
    end, delay * 1000)
end

function gm:AwardCrew(missions)
    local missionReward = 0
    for _, mission in pairs(missions or {}) do
        if missionWouldComplete(mission) then
            local missionValue = self.MissionPoints.Default

            for key, value in pairs(self.MissionPoints) do
                if key == mission.Prefab.Type then
                    missionValue = value
                end
            end

            missionReward = missionReward + missionValue
        end
    end

    if self.MissionEndAdditionalReward then
        missionReward = missionReward + self.MissionEndAdditionalReward()
    end

    for key, value in pairs(Client.ClientList) do
        if value.Character ~= nil
            and value.Character.IsHuman
            and not value.SpectateOnly
            and not value.Character.IsDead
        then
            local role = Traitormod.RoleManager.GetRole(value.Character)

            local wasAntagonist = false
            if role ~= nil then
                wasAntagonist = role.IsAntagonist
            end

            -- if client was no traitor, and in reach of end position, gain a live
            if not wasAntagonist and Traitormod.EndReached(value.Character, self.DistanceToEndOutpostRequired) then
                local msg = ""

                -- award points for mission completion
                if missionReward > 0 then
                    local points = Traitormod.AwardPoints(value, missionReward
                        , true)
                    msg = msg ..
                        Traitormod.Language.CrewWins ..
                        " " .. string.format(Traitormod.Language.PointsAwarded, points) .. "\n\n"
                end

                local lifeMsg, icon = Traitormod.AdjustLives(value,
                    (self.LivesGainedFromCrewMissionsCompleted or 1))
                if lifeMsg then
                    msg = msg .. lifeMsg .. "\n\n"
                end

                if msg ~= "" then
                    Traitormod.SendMessage(value, msg, icon)
                end
            end
        end
    end
end

function gm:CheckHandcuffedTraitors(character)
    if character.IsDead then return end
    
    local item = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    if item ~= nil and item.Prefab.Identifier == "handcuffs" then
        for key, value in pairs(Client.ClientList) do
            local role = Traitormod.RoleManager.GetRole(value.Character)
            if (role == nil or not role.IsAntagonist) and value.Character and not value.Character.IsDead and value.Character.TeamID == CharacterTeamType.Team1 then
                local points = Traitormod.AwardPoints(value, self.PointsGainedFromHandcuffedTraitors)
                local text = string.format(Traitormod.Language.TraitorHandcuffed, character.Name)
                text = text .. "\n\n" .. string.format(Traitormod.Language.PointsAwarded, points)
                Traitormod.SendMessage(value, text, "InfoFrameTabButton.Mission")
            end
        end
    end
end

function gm:TraitorResults()
    local success = false

    local sb = Traitormod.StringBuilder:new()

    local antagonists = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        if role.IsAntagonist then
            table.insert(antagonists, character)
        end

        if role.IsAntagonist then
            sb("%s %s", role.Name, character.Name)
            sb("\n")

            local objectives = 0
            local pointsGained = 0

            for key, value in pairs(role.Objectives) do
                if not value.Failed and (value:IsCompleted() or value.Awarded) then
                    objectives = objectives + 1
                    pointsGained = pointsGained + value.AmountPoints
                end
            end

            if objectives > 0 then
                success = true
            end

            sb(Traitormod.Language.SecretSummary, objectives, pointsGained)
        end
    end

    if success then
        Traitormod.Stats.AddStat("Rounds", "Traitor rounds won", 1)
    else
        Traitormod.Stats.AddStat("Rounds", "Crew rounds won", 1)
    end

    -- first arg = mission id, second = message, third = completed, forth = list of characters
    return {TraitorMissionResult(self.RoundEndIcon or Traitormod.MissionIdentifier, sb:concat(), success, antagonists)}
end

function gm:FinalizeResults()
    if self.ResultsFinalized then return end

    for client, value in pairs(Traitormod.PointsToBeGiven) do
        if value > 0 then
            local points = Traitormod.AwardPoints(client, value)
            if client.Character ~= nil and Traitormod.GiveExperience(client.Character, Traitormod.Config.AmountExperienceWithPoints(points)) then
                local text = Traitormod.Language.SkillsIncreased ..
                    "\n" .. string.format(Traitormod.Language.PointsAwarded, math.floor(points))
                Game.SendDirectChatMessage("", text, nil, Traitormod.Config.ChatMessageType, client)
            end
            Traitormod.PointsToBeGiven[client] = 0
        end
    end

    Traitormod.RoleManager.CheckObjectives(false)
    Traitormod.RoleManager.CheckObjectives(true)

    for _, role in pairs(Traitormod.RoleManager.RoundRoles) do
        for _, objective in pairs(role.Objectives or {}) do
            if not objective.Awarded and not objective.Failed then
                objective:Fail()
            end
        end
    end

    for _, character in pairs(Traitormod.RoleManager.FindAntagonists()) do
        self:CheckHandcuffedTraitors(character)
    end

    local missions = Game.GameSession ~= nil and Game.GameSession.Missions or {}
    self:AwardCrew(missions)

    finalizePointshopRefunds()
    Traitormod.RoundEvents.EndRound()

    self.ResultsFinalized = true
end

function gm:RoundSummary()
    if self.FinalSummary ~= nil then return self.FinalSummary end
    if not self.ResultsFinalized then self:FinalizeResults() end

    local sb = Traitormod.StringBuilder:new()
    sb("%s\n", Traitormod.Language.RoundSummary)
    sb(Traitormod.Language.Gamemode, self.Name)
    sb("\n")
    sb("%s: %s\n", Traitormod.Language.DiscordFieldRound, Traitormod.RoundNumber + 1)
    sb("%s: %s\n", Traitormod.Language.DiscordFieldDuration, Traitormod.FormatTime(math.ceil(Traitormod.RoundTime)))

    local entries = {}
    for character, role in pairs(Traitormod.RoleManager.RoundRoles) do
        table.insert(entries, { Character = character, Role = role })
    end
    table.sort(entries, function(a, b)
        return string.lower(tostring(a.Character.Name)) < string.lower(tostring(b.Character.Name))
    end)

    for _, entry in ipairs(entries) do
        local character = entry.Character
        local role = entry.Role
        local state = character.IsDead and Traitormod.Language.Dead or Traitormod.Language.Alive

        sb("\n%s — %s (%s)\n", character.Name, role.Name, state)

        for _, objective in ipairs(role.Objectives or {}) do
            local objectiveState
            if objective.Failed then
                objectiveState = Traitormod.Language.Failed
            else
                objectiveState = Traitormod.Language.Completed .. string.format(Traitormod.Language.Points, objective.AmountPoints or 0)
            end
            sb(" > %s %s\n", objective.Text, string.gsub(objectiveState, "^%s+", ""))
        end
    end

    return sb:concat()
end

function gm:BeginEnding(reason)
    if self.Ending or not Game.RoundStarted then return end

    self:FinalizeResults()
    self.Ending = true
    self.EndReason = reason
    lockProgress(self)

    if Game.Server ~= nil then
        Game.Server.EndRoundTimer = 0
    end
    for _, client in pairs(Client.ClientList) do
        client.SetVote(voteTypes.EndRound, false)
    end

    self.FinalSummary = self:RoundSummary()
    Traitormod.LastRoundSummary = self.FinalSummary

    local delay = softEndDelaySeconds
    local message = string.format(Traitormod.Language.HideAndSeekRoundCountdown, delay)
    if reason == "traitors" then
        message = Traitormod.Language.TraitorsWin .. "\n" .. message
    elseif reason == "crew" then
        local reachedText = tostring(TextManager.Get("hint.onavailabletransition.progresstonextemptylocation"))
        reachedText = string.match(reachedText, "^(.-%.)") or reachedText
        message = reachedText .. "\n" .. message
    end

    Traitormod.SendMessageEveryone(message)
    Traitormod.SendMessageEveryone(Traitormod.HighlightClientNames(self.FinalSummary, Color.Red))

    for _, client in pairs(Client.ClientList) do
        sendSummaryPopup(client, self.FinalSummary)
    end

    Traitormod.Log("Secret round result finalized. Ending round in " .. delay .. " seconds.")

    Timer.Wait(function ()
        if not Game.RoundStarted then return end
        self.AllowRealEndGame = true
        Game.EndGame()
    end, delay * 1000)
end

function gm:End()
    if not self.ResultsFinalized then
        self:FinalizeResults()
    end

    unlockProgress(self)
    Game.EnableControlHusk(false)

    Hook.Remove("characterDeath", "Traitormod.Secret.CharacterDeath")
    Hook.Remove("traitormod.midroundspawn", "Traitormod.Secret.MidRoundSpawn")
end

function gm:Think()
    if not Game.RoundStarted then return end

    if self.Ending then
        Traitormod.PointsToBeGiven = {}
        if not self.AllowRealEndGame and Game.Server ~= nil then
            Game.Server.EndRoundTimer = 0
        end
        return
    end

    if reachedLevelEnd() then
        self:BeginEnding("crew")
        return
    end

    if not self.EndOnComplete then return end

    local ended = true
    local anyTraitorMission = false

    for _, value in pairs(Character.CharacterList) do
        if not value.IsDead and value.IsHuman and value.TeamID == CharacterTeamType.Team1 then
            local role = Traitormod.RoleManager.GetRole(value)
            if role == nil or not role.IsAntagonist then
                ended = false
            elseif role.Objectives then
                for _, objective in pairs(role.Objectives) do
                    if objective.Name == "Assassinate" or objective.Name == "Husk" then
                        anyTraitorMission = true
                    end
                end
            end
        end
    end

    if anyTraitorMission and ended then
        self:BeginEnding("traitors")
    end
end

Hook.Patch("Traitormod.Secret.UpdateVoteStatus.Before", "Barotrauma.Networking.GameServer", "UpdateVoteStatus", function ()
    updatingVoteStatus = true
end, Hook.HookMethodType.Before)

Hook.Patch("Traitormod.Secret.UpdateVoteStatus.After", "Barotrauma.Networking.GameServer", "UpdateVoteStatus", function ()
    updatingVoteStatus = false
end, Hook.HookMethodType.After)

Hook.Patch("Traitormod.Secret.EndGame.Before", "Barotrauma.Networking.GameServer", "EndGame", function (instance, ptable)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Secret" then return end

    if selected.AllowRealEndGame then return end

    if selected.Ending then
        ptable.PreventExecution = true
        return
    end

    if updatingVoteStatus then
        selected:BeginEnding("vote")
        ptable.PreventExecution = true
    end
end, Hook.HookMethodType.Before)


return gm
