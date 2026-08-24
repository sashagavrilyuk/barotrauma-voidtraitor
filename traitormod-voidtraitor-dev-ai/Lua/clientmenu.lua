---@class ClientMenu
local cm = {}

local vtNet = {
    Ready = "VoidTraitor_ClientMenuGuiReady",
    Request = "VoidTraitor_ClientMenuRequest",
    Snapshot = "VoidTraitor_ClientMenuSnapshot",
    Run = "VoidTraitor_ClientMenuRun",
}

local voteNet = {
    Ready = "VoidTraitor_LobbyVoteGuiReady",
    Request = "VoidTraitor_LobbyVoteRequest",
    Snapshot = "VoidTraitor_LobbyVoteSnapshot",
    Start = "VoidTraitor_LobbyVoteStart",
    Cast = "VoidTraitor_LobbyVoteCast",
}

local function lang(key)
    return Traitormod.GetText(key)
end

local function parseInput(input)
    return Traitormod.ParseCommand(tostring(input or ""))
end

local function sendActionLog(client, actionId)
    Traitormod.Log(Traitormod.ClientLogName(client) .. " used client menu action: " .. tostring(actionId))
end

local function sendOClock(value)
    local oClock = math.floor(value / 30)
    if oClock == 0 then oClock = 12 end
    return Traitormod.FormatText("CMDOClock", oClock)
end

local function getGamemodeName()
    if Traitormod.SelectedGamemode == nil then return "" end
    return string.lower(tostring(Traitormod.SelectedGamemode.Name or ""))
end

local function isGamemode(name)
    return getGamemodeName() == string.lower(tostring(name or ""))
end

local function isAdmin(client)
    return client ~= nil and client.HasPermission(ClientPermissions.ConsoleCommands)
end

local function isAlive(client)
    return client ~= nil and client.Character ~= nil and not client.Character.IsDead
end

local function canUseAlive(client)
    return isAdmin(client) or not isAlive(client)
end

local function canLocateSub(client)
    if not isAlive(client) or not client.InGame then return false end
    if client.Character.IsHuman and client.Character.TeamID == CharacterTeamType.Team1 then return false end
    return true
end

local function canUseSuicide(client)
    return isAlive(client)
end

local function canDropPoints(client)
    if not isAlive(client) or client.Character.Inventory == nil then return false end
    return math.floor(tonumber(Traitormod.GetData(client, "Points") or 0) or 0) >= 100
end

local function canUseFakeHandcuffs(client)
    if not isAlive(client) or not client.Character.IsHuman or client.Character.Inventory == nil then return false end

    local item = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    return item ~= nil and item.Prefab.Identifier == "handcuffs" and item.HasTag("fakehandcuffs")
end

local dropPointsCooldown = {}

local actions = {}
local orderedActions = {}

local function addAction(id, labelKey, hintKey, categoryKey, order, callback, inputType, inputHintKey, confirmTitleKey, confirmTextKey, condition)
    local action = {
        Id = id,
        LabelKey = labelKey,
        HintKey = hintKey,
        CategoryKey = categoryKey or "ClientMenuCategoryMain",
        Order = order or 0,
        Callback = callback,
        InputType = inputType or "",
        InputHintKey = inputHintKey or "",
        ConfirmTitleKey = confirmTitleKey or "",
        ConfirmTextKey = confirmTextKey or "",
        Condition = condition,
    }

    actions[id] = action
    table.insert(orderedActions, action)
end

addAction("role", "ClientMenuRole", "ClientMenuHintRole", "ClientMenuCategoryMain", 10, function(client)
    if client.Character == nil or client.Character.IsDead then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAliveToUse)
        return true
    end

    local role = Traitormod.RoleManager.GetRole(client.Character)
    if role == nil then
        Traitormod.SendMessage(client, Traitormod.Language.CMDNoRole)
    else
        if Traitormod.ObjectiveHud ~= nil then
            Traitormod.ObjectiveHud.SyncRole(role)
        end
        Traitormod.SendMessage(client, role:Greet())
    end
    return true
end, nil, nil, nil, nil, isAlive)

addAction("points", "ClientMenuPoints", "ClientMenuHintPoints", "ClientMenuCategoryMain", 11, function(client)
    Traitormod.SendMessage(client, Traitormod.GetDataInfo(client, true))
    return true
end)

addAction("status", "ClientMenuStatus", "ClientMenuHintStatus", "ClientMenuCategoryMain", 12, function(client)
    if client.Character == nil or client.Character.IsDead then
        Traitormod.SendMessage(client, Traitormod.Language.StatusAliveRequired)
        return true
    end
    Traitormod.SendMessage(client, Traitormod.GetStatusMessage(client.Character))
    return true
end, nil, nil, nil, nil, isAlive)

addAction("toggletraitor", "ClientMenuToggleTraitor", "ClientMenuHintToggleTraitor", "ClientMenuCategoryMain", 13, function(client, input)
    local args = parseInput(input)
    local text = Traitormod.Language.CommandNotActive

    if Traitormod.Config.OptionalTraitors then
        local toggle = false
        if #args > 0 then
            toggle = string.lower(args[1]) == "on"
        else
            toggle = Traitormod.GetData(client, "NonTraitor") == true
        end

        text = toggle and Traitormod.Language.TraitorOn or Traitormod.Language.TraitorOff
        Traitormod.SetData(client, "NonTraitor", not toggle)
        Traitormod.SaveData()
        Traitormod.Log(Traitormod.ClientLogName(client) .. " can become traitor: " .. tostring(toggle))
    end

    Traitormod.SendMessage(client, text)
    return true
end, nil, nil, nil, nil, function() return Traitormod.Config.OptionalTraitors == true end)

addAction("suicide", "ClientMenuSuicide", "ClientMenuHintSuicide", "ClientMenuCategoryCharacter", 20, function(client)
    if client.Character == nil or client.Character.IsDead then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAlreadyDead)
        return true
    end

    if Traitormod.SelectedGamemode.TraitormodSettings.LimitedSuicide and client.Character.IsHuman then
        local item = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
        if item ~= nil and item.Prefab.Identifier == "handcuffs" then
            Traitormod.SendMessage(client, Traitormod.Language.CMDHandcuffed)
            return true
        end

        if client.Character.IsKnockedDown then
            Traitormod.SendMessage(client, Traitormod.Language.CMDKnockedDown)
            return true
        end
    end

    if Traitormod.GhostRoles.ReturnGhostRole(client.Character) then
        client.SetClientCharacter(nil)
    else
        client.Character.Kill(CauseOfDeathType.Unknown)
    end
    return true
end, "", "", "ClientMenuConfirmTitle", "ClientMenuConfirmSuicide", canUseSuicide)

addAction("droppoints", "ClientMenuDropPoints", "ClientMenuHintDropPoints", "ClientMenuCategoryCharacter", 21, function(client, input)
    if dropPointsCooldown[client] ~= nil and Timer.GetTime() < dropPointsCooldown[client] then
        Traitormod.SendMessage(client, Traitormod.GetText("CMDCommandCooldown"))
        return true
    end

    if client.Character == nil or client.Character.IsDead or client.Character.Inventory == nil then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAliveToUse)
        return true
    end

    local amount = tonumber((parseInput(input))[1])
    if amount == nil or amount ~= amount or amount < 100 or amount > 100000 then
        Traitormod.SendMessage(client, Traitormod.GetText("CMDDropPointsInvalidAmount"))
        return true
    end

    local availablePoints = Traitormod.GetData(client, "Points") or 0
    if amount > availablePoints then
        Traitormod.SendMessage(client, Traitormod.GetText("CMDDropPointsNotEnough"))
        return true
    end

    if Traitormod.DropPointItem == nil or not Traitormod.DropPointItem(client, amount) then
        Traitormod.SendMessage(client, Traitormod.GetText("CMDDropPointsFailed"))
        return true
    end

    dropPointsCooldown[client] = Timer.GetTime() + 5
    return true
end, "number", "ClientMenuInputDropPoints", nil, nil, canDropPoints)

addAction("freehandcuffs", "ClientMenuFreeHandcuffs", "ClientMenuHintFreeHandcuffs", "ClientMenuCategoryCharacter", 23, function(client)
    if client.Character == nil or client.Character.IsDead then
        Traitormod.SendMessage(client, Traitormod.Language.CMDFreeHandcuffsDead)
        return true
    end
    if not client.Character.IsHuman then return true end

    local item = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    if item ~= nil and item.Prefab.Identifier == "handcuffs" then
        if not item.HasTag("fakehandcuffs") then
            Traitormod.SendMessage(client, Traitormod.Language.CMDFreeHandcuffsNotFake)
            return true
        end
        item.Drop(client.Character)
    end
    return true
end, nil, nil, nil, nil, canUseFakeHandcuffs)

addAction("roundtime", "ClientMenuRoundTime", "ClientMenuHintRoundTime", "ClientMenuCategoryRound", 30, function(client)
    Traitormod.SendMessage(client, string.format(Traitormod.Language.CMDRoundTime, Traitormod.FormatTime(math.ceil(Traitormod.RoundTime))))
    return true
end)

addAction("locatesub", "ClientMenuLocateSub", "ClientMenuHintLocateSub", "ClientMenuCategoryRound", 31, function(client)
    if client.Character == nil or not client.InGame then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAliveToUse)
        return true
    end

    if client.Character.IsHuman and client.Character.TeamID == CharacterTeamType.Team1 then
        Traitormod.SendMessage(client, Traitormod.Language.CMDOnlyMonsters)
        return true
    end

    local center = client.Character.WorldPosition
    local target = Submarine.MainSub.WorldPosition
    local distance = Vector2.Distance(center, target) * Physics.DisplayToRealWorldRatio
    local diff = center - target
    local angle = math.deg(math.atan2(diff.X, diff.Y)) + 180

    Game.SendDirectChatMessage("", string.format(Traitormod.Language.CMDLocateSub, math.floor(distance), sendOClock(angle)), nil, ChatMessageType.Error, client)
    return true
end, nil, nil, nil, nil, canLocateSub)

addAction("alive", "ClientMenuAlive", "ClientMenuHintAlive", "ClientMenuCategoryRound", 32, function(client)
    if not canUseAlive(client) then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAliveDeadOnly)
        return true
    end

    if not Game.RoundStarted or Traitormod.SelectedGamemode == nil then
        Traitormod.SendMessage(client, Traitormod.Language.RoundNotStarted)
        return true
    end

    local message = ""
    for _, character in pairs(Character.CharacterList) do
        if character.IsHuman and not character.IsBot then
            message = message .. character.Name .. (character.IsDead and " ---- " or " ++++ ") .. (character.IsDead and Traitormod.Language.Dead or Traitormod.Language.Alive) .. "\n"
        end
    end

    Traitormod.SendMessage(client, message)
    return true
end, nil, nil, nil, nil, canUseAlive)

addAction("players", "ClientMenuPlayers", "ClientMenuHintPlayers", "ClientMenuCategoryRound", 33, function(client)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "SubmarineRoyale" then
        Traitormod.SendMessage(client, Traitormod.Language.CommandNotActive)
        return true
    end

    if client.Character == nil or not client.InGame then
        Traitormod.SendMessage(client, Traitormod.Language.CMDAliveToUse)
        return true
    end

    local text = ""
    local center = client.Character.WorldPosition
    for _, targetClient in pairs(Client.ClientList) do
        if targetClient.Character and not targetClient.Character.IsDead then
            local target = targetClient.Character.WorldPosition
            local distance = Vector2.Distance(center, target) * Physics.DisplayToRealWorldRatio
            local diff = center - target
            local angle = math.deg(math.atan2(diff.X, diff.Y)) + 180
            local submarineName = targetClient.Character.Submarine and targetClient.Character.Submarine.Info.Name or Traitormod.Language.Unknown
            text = text .. string.format(Traitormod.Language.CMDLocatePlayer, targetClient.Name, math.floor(distance), sendOClock(angle), submarineName) .. "\n"
        end
    end

    Game.SendDirectChatMessage("", text, nil, ChatMessageType.Error, client)
    return true
end, nil, nil, nil, nil, function(client) return isGamemode("SubmarineRoyale") and isAlive(client) end)

addAction("info", "ClientMenuInfo", "ClientMenuHintInfo", "ClientMenuCategoryInfo", 40, function(client)
    Traitormod.SendWelcome(client)
    return true
end)

addAction("playtime", "ClientMenuPlaytime", "ClientMenuHintPlaytime", "ClientMenuCategoryInfo", 41, function(client)
    Traitormod.SendChatMessage(
        client,
        string.format(Traitormod.Language.CMDPlaytime, Traitormod.FormatTime(math.ceil(Traitormod.GetData(client, "Playtime") or 0))),
        Color.Green
    )
    return true
end)

addAction("stats", "ClientMenuStats", "ClientMenuHintStats", "ClientMenuCategoryInfo", 42, function(client)
    if Traitormod.Stats ~= nil and Traitormod.Stats.Command ~= nil then
        return Traitormod.Stats.Command(client, {})
    end
    return true
end)

addAction("version", "ClientMenuVersion", "ClientMenuHintVersion", "ClientMenuCategoryInfo", 43, function(client)
    Traitormod.SendMessage(client, string.format(Traitormod.Language.CMDVersion, Traitormod.VERSION))
    return true
end)

table.sort(orderedActions, function(a, b)
    if a.Order ~= b.Order then return a.Order < b.Order end
    return lang(a.LabelKey) < lang(b.LabelKey)
end)

local function getVisibleActions(client)
    local visible = {}

    for _, action in ipairs(orderedActions) do
        if action.Condition == nil or action.Condition(client) == true then
            table.insert(visible, action)
        end
    end

    return visible
end

function cm.SendSnapshot(client)
    if client == nil or client.Connection == nil then return false end

    local visibleActions = getVisibleActions(client)
    local netMessage = Networking.Start(vtNet.Snapshot)
    netMessage.WriteString(lang("ClientMenuTitle"))
    netMessage.WriteString(lang("ClientMenuShopButton"))
    netMessage.WriteString(lang("ClientMenuMainButton"))
    netMessage.WriteString(lang("ClientMenuShopTooltip"))
    netMessage.WriteString(lang("ClientMenuMainTooltip"))
    netMessage.WriteString(lang("ClientMenuNoCommands"))
    netMessage.WriteString(lang("ClientMenuGenericCommand"))
    netMessage.WriteString(lang("ClientMenuDefaultConfirmTitle"))
    netMessage.WriteString(lang("ClientMenuCancel"))
    netMessage.WriteString(lang("ClientMenuYes"))
    netMessage.WriteString(lang("ClientMenuOk"))
    netMessage.WriteInt32(#visibleActions)

    for _, action in ipairs(visibleActions) do
        netMessage.WriteString(action.Id)
        netMessage.WriteString(lang(action.LabelKey))
        netMessage.WriteString(lang(action.HintKey))
        netMessage.WriteString(lang(action.CategoryKey))
        netMessage.WriteString(action.InputType)
        netMessage.WriteString(action.InputHintKey ~= "" and lang(action.InputHintKey) or "")
        netMessage.WriteString(action.ConfirmTitleKey ~= "" and lang(action.ConfirmTitleKey) or "")
        netMessage.WriteString(action.ConfirmTextKey ~= "" and lang(action.ConfirmTextKey) or "")
    end

    Networking.Send(netMessage, client.Connection)
    return true
end

function cm.RunAction(client, actionId, input)
    if client == nil then return true end

    actionId = tostring(actionId or "")
    local action = actions[actionId]
    if action == nil or action.Callback == nil then return true end
    if action.Condition ~= nil and action.Condition(client) ~= true then return true end

    sendActionLog(client, actionId)
    return action.Callback(client, input)
end

Networking.Receive(vtNet.Ready, function(message, client)
    return cm.SendSnapshot(client)
end)

Networking.Receive(vtNet.Request, function(message, client)
    return cm.SendSnapshot(client)
end)

Networking.Receive(vtNet.Run, function(message, client)
    local actionId = message.ReadString()
    local input = message.ReadString()
    return cm.RunAction(client, actionId, input)
end)

local function writeVoteSnapshot(netMessage, client)
    local snapshot = nil
    if Traitormod.Voting ~= nil and Traitormod.Voting.GetGuiSnapshot ~= nil then
        snapshot = Traitormod.Voting.GetGuiSnapshot(client)
    end

    snapshot = snapshot or {}
    netMessage.WriteString(tostring(snapshot.ButtonText or lang("LobbyVoteGuiButton")))
    netMessage.WriteString(tostring(snapshot.ButtonTooltip or lang("LobbyVoteGuiButtonTooltip")))
    netMessage.WriteString(tostring(snapshot.StartTitle or lang("LobbyVoteGuiStartTitle")))
    netMessage.WriteString(tostring(snapshot.StartModeText or lang("LobbyVoteGuiStartMode")))
    netMessage.WriteString(tostring(snapshot.StartMapText or lang("LobbyVoteGuiStartMap")))
    netMessage.WriteString(tostring(snapshot.StartBlockedReason or ""))
    netMessage.WriteString(tostring(snapshot.CloseText or lang("LobbyVoteGuiClose")))
    netMessage.WriteString(tostring(snapshot.NoActiveText or lang("LobbyVoteGuiNoActive")))
    netMessage.WriteString(tostring(snapshot.StartedByLabel or lang("LobbyVoteGuiStartedBy")))
    netMessage.WriteString(tostring(snapshot.TimerLabel or lang("LobbyVoteGuiTimer")))
    netMessage.WriteString(tostring(snapshot.VotesLabel or lang("LobbyVoteGuiVotes")))
    netMessage.WriteBoolean(snapshot.CanStart == true)

    local active = snapshot.Active
    netMessage.WriteBoolean(active ~= nil)
    if active == nil then return end

    netMessage.WriteString(tostring(active.Id or ""))
    netMessage.WriteString(tostring(active.Type or ""))
    netMessage.WriteString(tostring(active.Title or ""))
    netMessage.WriteString(tostring(active.StartedBy or ""))
    netMessage.WriteInt32(math.max(0, math.floor(tonumber(active.Remaining or 0) or 0)))
    netMessage.WriteInt32(math.max(1, math.floor(tonumber(active.Duration or 1) or 1)))

    local options = active.Options or {}
    netMessage.WriteInt32(#options)
    for _, option in ipairs(options) do
        netMessage.WriteInt32(tonumber(option.Index or 0) or 0)
        netMessage.WriteString(tostring(option.Text or ""))
        netMessage.WriteInt32(math.max(0, math.floor(tonumber(option.Votes or 0) or 0)))
        netMessage.WriteBoolean(option.Selected == true)
    end
end

function cm.SendVoteSnapshot(client)
    if client == nil or client.Connection == nil then return false end

    local netMessage = Networking.Start(voteNet.Snapshot)
    writeVoteSnapshot(netMessage, client)
    Networking.Send(netMessage, client.Connection)
    return true
end

function cm.SendVoteSnapshotEveryone()
    for _, client in pairs(Client.ClientList) do
        cm.SendVoteSnapshot(client)
    end
end

Networking.Receive(voteNet.Ready, function(message, client)
    return cm.SendVoteSnapshot(client)
end)

Networking.Receive(voteNet.Request, function(message, client)
    return cm.SendVoteSnapshot(client)
end)

Networking.Receive(voteNet.Start, function(message, client)
    local voteType = message.ReadString()
    if Traitormod.Voting ~= nil and Traitormod.Voting.StartGuiVote ~= nil then
        Traitormod.Voting.StartGuiVote(client, voteType)
    end
    return cm.SendVoteSnapshot(client)
end)

Networking.Receive(voteNet.Cast, function(message, client)
    local optionId = message.ReadInt32()
    if Traitormod.Voting ~= nil and Traitormod.Voting.CastGuiVote ~= nil then
        Traitormod.Voting.CastGuiVote(client, optionId)
    end
    return cm.SendVoteSnapshotEveryone()
end)

local pointshopNet = Traitormod.Pointshop and Traitormod.Pointshop.GuiNet or nil
if pointshopNet ~= nil then
    Networking.Receive(pointshopNet.Ready, function(message, client)
        return Traitormod.Pointshop.MarkGuiClientReady(client)
    end)

    Networking.Receive(pointshopNet.Request, function(message, client)
        return Traitormod.Pointshop.RequestGuiSnapshot(client)
    end)

    Networking.Receive(pointshopNet.BuyCart, function(message, client)
        local count = math.clamp(message.ReadInt32(), 0, 32)
        local entries = {}
        for i = 1, count do
            table.insert(entries, {
                Id = message.ReadString(),
                Quantity = message.ReadInt32(),
            })
        end

        return Traitormod.Pointshop.HandleGuiCart(client, entries)
    end)
end

Hook.Add("client.disconnected", "Traitormod.ClientMenu.Disconnect", function(client)
    dropPointsCooldown[client] = nil
    if Traitormod.Pointshop ~= nil and Traitormod.Pointshop.ForgetGuiClient ~= nil then
        Traitormod.Pointshop.ForgetGuiClient(client)
    end
end)

return cm
