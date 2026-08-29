if SERVER then return {} end

local Common, UI = ...

local Admin = {}

local NET_REQUEST = "VoidTraitor_ClientMenuAdminRequest"
local NET_SNAPSHOT = "VoidTraitor_ClientMenuAdminSnapshot"
local NET_DATA_REQUEST = "VoidTraitor_ClientMenuAdminDataRequest"
local NET_DATA = "VoidTraitor_ClientMenuAdminData"
local NET_RUN = "VoidTraitor_ClientMenuAdminRunV2"

local PLAYER_LIST_HEIGHT = 120
local OPTION_LIST_HEIGHT = 100
local ROW_HEIGHT = 32
local INPUT_LABEL_HEIGHT = 24
local INPUT_ROW_HEIGHT = 40

local available = false
local mainTabText = "Main"
local adminTabText = "Admin"
local entryById = {}
local players = {}
local playerByKey = {}
local roles = {}
local events = {}
local selectedPlayerKey = nil
local selectedRoleId = nil
local selectedEvent = nil
local ghostCharacters = {}
local selectedGhostCharacterName = nil
local dataLoaded = false
local dataRequestPending = false
local pendingReady = nil

local text = {
    SelectedPlayer = "Player: %s",
    NoPlayers = "No connected players.",
    Alive = "Alive",
    Dead = "Dead",
    NoCharacter = "No character",
    SelectRole = "Select a role",
    NoRoles = "No roles are registered.",
    SelectEvent = "Select an event",
    NoEvents = "No events are registered.",
    SelectCharacter = "Select a character",
    NoCharacters = "No living characters.",
}

local playerButtons = {}
local roleButtons = {}
local eventButtons = {}
local ghostCharacterButtons = {}
local selectedPlayerText = nil
local playerDependentButtons = {}
local assignRoleButton = nil
local triggerEventButton = nil
local ghostRoleButton = nil

local CreateRect = UI.CreateRect
local CreateText = Common.CreateText
local SetFixedHeight = UI.SetFixedHeight
local SetButtonTextScale = UI.SetButtonTextScale
local CreateMenuButton = UI.CreateMenuButton
local CreateDivider = UI.CreateDivider
local CreateCategoryHeader = UI.CreateCategoryHeader

local function send(identifier, writer)
    local msg = Networking.Start(identifier)
    if writer ~= nil then writer(msg) end
    Networking.Send(msg)
end

local function sendAction(actionId, targetKey, value)
    send(NET_RUN, function(msg)
        msg.WriteString(actionId or "")
        msg.WriteString(tostring(targetKey or ""))
        msg.WriteString(tostring(value or ""))
    end)
end

local function validateSelections()
    if playerByKey[selectedPlayerKey] == nil then
        selectedPlayerKey = players[1] ~= nil and players[1].Key or nil
    end

    local roleFound = false
    for _, role in ipairs(roles) do
        if role.Id == selectedRoleId then roleFound = true break end
    end
    if not roleFound then
        selectedRoleId = roles[1] ~= nil and roles[1].Id or nil
    end

    local eventFound = false
    for _, eventName in ipairs(events) do
        if eventName == selectedEvent then eventFound = true break end
    end
    if not eventFound then selectedEvent = events[1] end
end

local function playerLabel(player)
    local stateText = text.NoCharacter
    if player.HasCharacter then
        stateText = player.IsDead and text.Dead or text.Alive
    end
    return tostring(player.Name) .. " — " .. stateText
end

local function refreshSelection()
    local selectedPlayer = playerByKey[selectedPlayerKey]

    for key, button in pairs(playerButtons) do
        button.Selected = key == selectedPlayerKey
        local player = playerByKey[key]
        if player ~= nil and button.TextBlock ~= nil then
            button.TextBlock.Text = playerLabel(player)
        end
    end
    for id, button in pairs(roleButtons) do button.Selected = id == selectedRoleId end
    for eventName, button in pairs(eventButtons) do button.Selected = eventName == selectedEvent end
    for characterName, button in pairs(ghostCharacterButtons) do button.Selected = characterName == selectedGhostCharacterName end

    if selectedPlayerText ~= nil then
        selectedPlayerText.Text = selectedPlayer ~= nil and string.format(text.SelectedPlayer, selectedPlayer.Name) or text.NoPlayers
    end

    local hasPlayer = selectedPlayer ~= nil
    for _, button in ipairs(playerDependentButtons) do button.Enabled = hasPlayer end
    if assignRoleButton ~= nil then assignRoleButton.Enabled = hasPlayer and selectedRoleId ~= nil end
    if triggerEventButton ~= nil then triggerEventButton.Enabled = selectedEvent ~= nil end
    if ghostRoleButton ~= nil then ghostRoleButton.Enabled = selectedGhostCharacterName ~= nil end
end

local function createFixedList(parent, heightPixels)
    local frame = GUI.Frame(CreateRect(1, 0.20, parent, nil), "GUIFrameListBox")
    SetFixedHeight(frame, heightPixels)
    frame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 0.96, frame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then list.ContentBackground.Color = Color(0, 0, 0, 0) end
    list.KeepSpaceForScrollBar = true
    return list
end

local function createPlayerValueAction(parent, actionId)
    local entry = entryById[actionId]
    if entry == nil then return end

    local label = CreateText(parent, 1, 0.05, nil, entry.Label, GUI.Alignment.Left, 0.86, Color(210, 220, 200, 255), false)
    SetFixedHeight(label, INPUT_LABEL_HEIGHT)
    label.Font = GUI.Style.SubHeadingFont
    label.ToolTip = tostring(entry.Hint or "")

    local row = GUI.Frame(CreateRect(1, 0.09, parent, nil), nil)
    SetFixedHeight(row, INPUT_ROW_HEIGHT)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false

    local input = GUI.TextBox(CreateRect(0.68, 1, row, GUI.Anchor.CenterLeft), entry.InputHint or "")
    if input.TextBlock ~= nil then input.TextBlock.TextScale = 0.86 end
    input.ToolTip = tostring(entry.Hint or "")

    local button = GUI.Button(CreateRect(0.30, 1, row, GUI.Anchor.CenterRight), UI.GetOkText(), GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(button, 0.90)
    button.ToolTip = tostring(entry.Hint or "")
    button.Enabled = playerByKey[selectedPlayerKey] ~= nil
    button.OnClicked = function()
        if selectedPlayerKey ~= nil then
            sendAction(actionId, selectedPlayerKey, input.Text or "")
        end
        return true
    end

    table.insert(playerDependentButtons, button)
end

function Admin.RequestMetadata()
    send(NET_REQUEST)
end

function Admin.RefreshData()
    if not available or dataRequestPending then return end
    dataRequestPending = true
    send(NET_DATA_REQUEST)
end

function Admin.WhenDataReady(callback)
    if dataRequestPending then
        pendingReady = callback
        return
    end
    if dataLoaded then
        callback()
        return
    end

    pendingReady = callback
    dataRequestPending = true
    send(NET_DATA_REQUEST)
end

function Admin.IsAvailable()
    return available
end

function Admin.GetMainTabText()
    return mainTabText
end

function Admin.GetAdminTabText()
    return adminTabText
end

function Admin.ClearView()
    playerButtons = {}
    roleButtons = {}
    eventButtons = {}
    ghostCharacterButtons = {}
    selectedPlayerText = nil
    playerDependentButtons = {}
    assignRoleButton = nil
    triggerEventButton = nil
    ghostRoleButton = nil
    pendingReady = nil
end

function Admin.Build(parent)
    Admin.ClearView()

    local infoEntry = entryById.roundinfo
    if infoEntry ~= nil then
        CreateCategoryHeader(parent, infoEntry.Category)
        for _, actionId in ipairs({ "roundinfo", "roles", "traitoralive", "allpoints", "ongoingevents" }) do
            local entry = entryById[actionId]
            if entry ~= nil then
                local button = CreateMenuButton(parent, entry.Label, true)
                button.ToolTip = tostring(entry.Hint or "")
                button.OnClicked = function()
                    sendAction(actionId, "", "")
                    return true
                end
            end
        end
        CreateDivider(parent)
    end

    local playerEntry = entryById.revive
    if playerEntry ~= nil then CreateCategoryHeader(parent, playerEntry.Category) end

    local playerList = createFixedList(parent, PLAYER_LIST_HEIGHT)
    if #players == 0 then
        CreateText(playerList.Content, 1, 0.70, nil, text.NoPlayers, GUI.Alignment.Center, 0.86, Color(195, 195, 185, 255), true)
    else
        for _, player in ipairs(players) do
            local button = GUI.Button(CreateRect(1, 0.12, playerList.Content, nil), playerLabel(player), GUI.Alignment.Left, "ListBoxElement")
            SetFixedHeight(button, ROW_HEIGHT)
            SetButtonTextScale(button, 0.82)
            playerButtons[player.Key] = button
            button.OnClicked = function()
                if selectedPlayerKey ~= player.Key then
                    selectedPlayerKey = player.Key
                    refreshSelection()
                end
                return true
            end
        end
        playerList:RecalculateChildren()
        playerList:UpdateScrollBarSize()
    end

    selectedPlayerText = CreateText(parent, 1, 0.05, nil, "", GUI.Alignment.Left, 0.82, Color(225, 220, 195, 255), false)
    SetFixedHeight(selectedPlayerText, INPUT_LABEL_HEIGHT)

    local playerActions = GUI.LayoutGroup(CreateRect(1, 0.09, parent, nil), true, GUI.Anchor.CenterLeft)
    SetFixedHeight(playerActions, INPUT_ROW_HEIGHT)
    playerActions.Stretch = true
    playerActions.RelativeSpacing = 0.008

    for _, actionId in ipairs({ "revive", "void", "unvoid" }) do
        local entry = entryById[actionId]
        if entry ~= nil then
            local button = GUI.Button(CreateRect(0.325, 1, playerActions, nil), entry.Label, GUI.Alignment.Center, "GUIButton")
            button.ToolTip = tostring(entry.Hint or "")
            SetButtonTextScale(button, 0.72)
            table.insert(playerDependentButtons, button)
            button.OnClicked = function()
                if selectedPlayerKey ~= nil then sendAction(actionId, selectedPlayerKey, "") end
                return true
            end
        end
    end

    createPlayerValueAction(parent, "addpoint")
    createPlayerValueAction(parent, "addlife")

    local assignEntry = entryById.assignrole
    if assignEntry ~= nil then
        CreateDivider(parent)
        CreateCategoryHeader(parent, assignEntry.Category)
        local roleLabel = CreateText(parent, 1, 0.05, nil, text.SelectRole, GUI.Alignment.Left, 0.82, Color(210, 220, 200, 255), false)
        SetFixedHeight(roleLabel, INPUT_LABEL_HEIGHT)

        local roleList = createFixedList(parent, OPTION_LIST_HEIGHT)
        if #roles == 0 then
            CreateText(roleList.Content, 1, 0.70, nil, text.NoRoles, GUI.Alignment.Center, 0.82, Color(195, 195, 185, 255), true)
        else
            for _, role in ipairs(roles) do
                local button = GUI.Button(CreateRect(1, 0.12, roleList.Content, nil), role.Name, GUI.Alignment.Left, "ListBoxElement")
                SetFixedHeight(button, ROW_HEIGHT)
                SetButtonTextScale(button, 0.82)
                roleButtons[role.Id] = button
                button.OnClicked = function()
                    if selectedRoleId ~= role.Id then
                        selectedRoleId = role.Id
                        refreshSelection()
                    end
                    return true
                end
            end
            roleList:RecalculateChildren()
            roleList:UpdateScrollBarSize()
        end

        assignRoleButton = CreateMenuButton(parent, assignEntry.Label, false)
        assignRoleButton.ToolTip = tostring(assignEntry.Hint or "")
        assignRoleButton.OnClicked = function()
            if selectedPlayerKey ~= nil and selectedRoleId ~= nil then
                sendAction("assignrole", selectedPlayerKey, selectedRoleId)
            end
            return true
        end
    end

    local ghostEntry = entryById.giveghostrole
    if ghostEntry ~= nil then
        CreateDivider(parent)
        CreateCategoryHeader(parent, ghostEntry.Category)

        ghostCharacters = {}
        for character in Character.CharacterList do
            if not character.IsDead and tostring(character.Name or "") ~= "" then
                table.insert(ghostCharacters, tostring(character.Name))
            end
        end
        table.sort(ghostCharacters, function(a, b) return string.lower(a) < string.lower(b) end)

        local selectedFound = false
        for _, characterName in ipairs(ghostCharacters) do
            if characterName == selectedGhostCharacterName then selectedFound = true break end
        end
        if not selectedFound then selectedGhostCharacterName = ghostCharacters[1] end

        local characterLabel = CreateText(parent, 1, 0.05, nil, text.SelectCharacter, GUI.Alignment.Left, 0.82, Color(210, 220, 200, 255), false)
        SetFixedHeight(characterLabel, INPUT_LABEL_HEIGHT)

        local characterList = createFixedList(parent, OPTION_LIST_HEIGHT)
        if #ghostCharacters == 0 then
            CreateText(characterList.Content, 1, 0.70, nil, text.NoCharacters, GUI.Alignment.Center, 0.82, Color(195, 195, 185, 255), true)
        else
            for _, characterName in ipairs(ghostCharacters) do
                local button = GUI.Button(CreateRect(1, 0.12, characterList.Content, nil), characterName, GUI.Alignment.Left, "ListBoxElement")
                SetFixedHeight(button, ROW_HEIGHT)
                SetButtonTextScale(button, 0.82)
                ghostCharacterButtons[characterName] = button
                button.OnClicked = function()
                    if selectedGhostCharacterName ~= characterName then
                        selectedGhostCharacterName = characterName
                        refreshSelection()
                    end
                    return true
                end
            end
            characterList:RecalculateChildren()
            characterList:UpdateScrollBarSize()
        end

        local row = GUI.Frame(CreateRect(1, 0.09, parent, nil), nil)
        SetFixedHeight(row, INPUT_ROW_HEIGHT)
        row.Color = Color(0, 0, 0, 0)
        row.CanBeFocused = false

        local input = GUI.TextBox(CreateRect(0.68, 1, row, GUI.Anchor.CenterLeft), ghostEntry.InputHint or "")
        if input.TextBlock ~= nil then input.TextBlock.TextScale = 0.86 end
        input.ToolTip = tostring(ghostEntry.Hint or "")

        ghostRoleButton = GUI.Button(CreateRect(0.30, 1, row, GUI.Anchor.CenterRight), UI.GetOkText(), GUI.Alignment.Center, "GUIButton")
        SetButtonTextScale(ghostRoleButton, 0.90)
        ghostRoleButton.ToolTip = tostring(ghostEntry.Hint or "")
        ghostRoleButton.OnClicked = function()
            if selectedGhostCharacterName ~= nil then
                sendAction("giveghostrole", selectedGhostCharacterName, input.Text or "")
            end
            return true
        end
    end

    local eventEntry = entryById.triggerevent
    if eventEntry ~= nil then
        CreateDivider(parent)
        CreateCategoryHeader(parent, eventEntry.Category)
        local eventLabel = CreateText(parent, 1, 0.05, nil, text.SelectEvent, GUI.Alignment.Left, 0.82, Color(210, 220, 200, 255), false)
        SetFixedHeight(eventLabel, INPUT_LABEL_HEIGHT)

        local eventList = createFixedList(parent, OPTION_LIST_HEIGHT)
        if #events == 0 then
            CreateText(eventList.Content, 1, 0.70, nil, text.NoEvents, GUI.Alignment.Center, 0.82, Color(195, 195, 185, 255), true)
        else
            for _, eventName in ipairs(events) do
                local button = GUI.Button(CreateRect(1, 0.12, eventList.Content, nil), eventName, GUI.Alignment.Left, "ListBoxElement")
                SetFixedHeight(button, ROW_HEIGHT)
                SetButtonTextScale(button, 0.82)
                eventButtons[eventName] = button
                button.OnClicked = function()
                    if selectedEvent ~= eventName then
                        selectedEvent = eventName
                        refreshSelection()
                    end
                    return true
                end
            end
            eventList:RecalculateChildren()
            eventList:UpdateScrollBarSize()
        end

        triggerEventButton = CreateMenuButton(parent, eventEntry.Label, false)
        triggerEventButton.ToolTip = tostring(eventEntry.Hint or "")
        triggerEventButton.OnClicked = function()
            if selectedEvent ~= nil then sendAction("triggerevent", "", selectedEvent) end
            return true
        end
    end

    refreshSelection()
end

Networking.Receive(NET_SNAPSHOT, function(message)
    local previousAvailable = available
    available = message.ReadBoolean()
    mainTabText = message.ReadString()
    adminTabText = message.ReadString()

    local entries = {}
    local count = message.ReadInt32()
    for _ = 1, count do
        local command = message.ReadString()
        local label = message.ReadString()
        local hint = message.ReadString()
        local category = message.ReadString()
        message.ReadString() -- input type is enforced by the server action
        local inputHint = message.ReadString()
        message.ReadString() -- reserved confirm title
        message.ReadString() -- reserved confirm text
        entries[command] = {
            Command = command,
            Label = label,
            Hint = hint,
            Category = category,
            InputHint = inputHint,
        }
    end
    entryById = entries

    if not available then
        dataLoaded = false
        players = {}
        playerByKey = {}
        roles = {}
        events = {}
    end

    if previousAvailable ~= available and Admin.OnAvailabilityChanged ~= nil then
        Admin.OnAvailabilityChanged()
    end
end)

Networking.Receive(NET_DATA, function(message)
    dataRequestPending = false

    local hasAccess = message.ReadBoolean()
    if not hasAccess then
        local changed = available
        available = false
        dataLoaded = false
        players = {}
        playerByKey = {}
        roles = {}
        events = {}
        selectedPlayerKey = nil
        selectedRoleId = nil
        selectedEvent = nil
        pendingReady = nil
        if changed and Admin.OnAvailabilityChanged ~= nil then Admin.OnAvailabilityChanged() end
        return
    end

    local newPlayers = {}
    local newPlayerByKey = {}
    for _ = 1, message.ReadInt32() do
        local key = message.ReadString()
        local name = message.ReadString()
        message.ReadString() -- character name is not needed by this menu
        local player = {
            Key = key,
            Name = name,
            HasCharacter = message.ReadBoolean(),
            IsDead = message.ReadBoolean(),
        }
        table.insert(newPlayers, player)
        newPlayerByKey[key] = player
    end
    players = newPlayers
    playerByKey = newPlayerByKey

    local newRoles = {}
    for _ = 1, message.ReadInt32() do
        table.insert(newRoles, { Id = message.ReadString(), Name = message.ReadString() })
    end
    roles = newRoles

    local newEvents = {}
    for _ = 1, message.ReadInt32() do table.insert(newEvents, message.ReadString()) end
    events = newEvents

    for _ = 1, message.ReadInt32() do
        text[message.ReadString()] = message.ReadString()
    end

    validateSelections()
    dataLoaded = true
    refreshSelection()

    local callback = pendingReady
    pendingReady = nil
    if callback ~= nil then callback() end
end)

return Admin
