if SERVER then return {} end

local Common, UI = ...

local Admin = {}

local NET_REQUEST = "VoidTraitor_ClientMenuAdminRequest"
local NET_SNAPSHOT = "VoidTraitor_ClientMenuAdminSnapshot"
local NET_DATA_REQUEST = "VoidTraitor_ClientMenuAdminDataRequest"
local NET_DATA = "VoidTraitor_ClientMenuAdminData"
local NET_RUN = "VoidTraitor_ClientMenuAdminRunV2"

local ROW_HEIGHT = 32
local MAX_ROLES_SHOWN = 8

local language = Common.Language.AdminMenu
local available = false
local mainTabText = language.MainTab
local adminTabText = language.AdminTab
local entryById = {}
local players = {}
local playerByKey = {}
local maxLives = 0
local roles = {}
local events = {}
local stationRound = false
local selectedPlayerKey = nil
local selectedRoleId = nil
local selectedGhostCharacterName = nil
-- the open page and the player search, kept while the window is closed
local activePage = "Main"
local playerSearch = ""
local dataLoaded = false
local dataRequestPending = false
local pendingReady = nil

-- the open page's widgets that show the selection
local playerButtons = {}
local ghostCharacterButtons = {}
local selectedPlayerText = nil
local playerDependentButtons = {}
local assignRoleButton = nil
local ghostRoleButton = nil

local CreateRect = UI.CreateRect
local CreateText = Common.CreateText
local SetFixedHeight = UI.SetFixedHeight
local SetButtonTextScale = UI.SetButtonTextScale

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
end

local function getPlayerState(player)
    local state = language.NoCharacter
    if player.HasCharacter then
        state = player.IsDead and language.Dead or language.Alive
    end
    if player.Role ~= "" then state = state .. " · " .. player.Role end
    return state
end

local function playerLabel(player)
    return tostring(player.Name) .. " — " .. getPlayerState(player)
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
    for characterName, button in pairs(ghostCharacterButtons) do button.Selected = characterName == selectedGhostCharacterName end

    if selectedPlayerText ~= nil then
        selectedPlayerText.Text = selectedPlayer ~= nil and string.format(language.PlayerInfo, selectedPlayer.Name,
            getPlayerState(selectedPlayer), selectedPlayer.Points, selectedPlayer.Lives, maxLives) or language.NoPlayers
    end

    local hasPlayer = selectedPlayer ~= nil
    for _, button in ipairs(playerDependentButtons) do button.Enabled = hasPlayer end
    if assignRoleButton ~= nil then assignRoleButton.Enabled = hasPlayer and selectedRoleId ~= nil end
    if ghostRoleButton ~= nil then ghostRoleButton.Enabled = selectedGhostCharacterName ~= nil end
end

-- A list in a frame that takes the rest of its column's height.
local function createList(parent)
    local frame = GUI.Frame(CreateRect(1, 1, parent, nil), "GUIFrameListBox")
    frame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 0.96, frame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then list.ContentBackground.Color = Color(0, 0, 0, 0) end
    list.KeepSpaceForScrollBar = true
    return list
end

local function createListRow(list, label, onClicked)
    local button = GUI.Button(CreateRect(1, 0.12, list.Content, nil), label, GUI.Alignment.Left, "ListBoxElement")
    SetFixedHeight(button, ROW_HEIGHT)
    SetButtonTextScale(button, 0.82)
    button.OnClicked = function()
        onClicked()
        return true
    end
    return button
end

local function createColumn(parent, width, stretch)
    local column = GUI.LayoutGroup(CreateRect(width, 1, parent, nil), false)
    column.Stretch = stretch
    column.AbsoluteSpacing = Common.GetGap()
    column.CanBeFocused = false
    return column
end

local function actionItem(actionId, onClicked)
    local entry = entryById[actionId]
    if entry == nil then return nil end
    return { Label = entry.Label, ToolTip = tostring(entry.Hint or ""), Enabled = true,
        OnClicked = onClicked or function() sendAction(actionId, "", "") end }
end

-- One page for the players and the round: the players on the left, found by name, the selected one's state and actions
-- on the right, and the round's commands under them. The player list takes the height the window has to spare.
local function buildMainPage(page)
    local layout = createColumn(page, 1, true)
    local columns = GUI.LayoutGroup(CreateRect(1, 1, layout, nil), true)
    columns.Stretch = true
    columns.AbsoluteSpacing = Common.GetGap()
    columns.CanBeFocused = false

    local left = createColumn(columns, 0.4, true)
    local search = GUI.TextBox(CreateRect(1, 1, left, nil), playerSearch)
    Common.SetFixedHeight(search, Common.GetStyleHeight("GUITextBox"))
    local list = createList(left)
    if #players == 0 then
        CreateText(list.Content, 1, 0.70, nil, language.NoPlayers, GUI.Alignment.Center, 0.86, Color(195, 195, 185, 255), true)
    end
    for _, player in ipairs(players) do
        playerButtons[player.Key] = createListRow(list, playerLabel(player), function()
            if selectedPlayerKey ~= player.Key then
                selectedPlayerKey = player.Key
                refreshSelection()
            end
        end)
    end
    local function filter(value)
        playerSearch = value
        local query = Common.NormalizeSearchText(value)
        for key, button in pairs(playerButtons) do
            button.Visible = query == "" or Common.NormalizeSearchText(playerByKey[key].Name):find(query, 1, true) ~= nil
        end
    end
    UI.SetTextBoxHint(search, language.FindPlayer, filter)
    filter(playerSearch)

    local right = createColumn(columns, 0.6, false)
    selectedPlayerText = CreateText(right, 1, 1, nil, "", GUI.Alignment.Left, 1, Color(225, 220, 195, 255), false)
    Common.FitHeightToText(selectedPlayerText)
    Common.SetAutoScaleText(selectedPlayerText, 1)

    local items = {}
    for _, actionId in ipairs({ "revive", "void", "unvoid" }) do
        items[#items + 1] = actionItem(actionId, function()
            if selectedPlayerKey ~= nil then sendAction(actionId, selectedPlayerKey, "") end
        end)
    end
    for _, button in pairs(UI.CreateButtonGrid(right, 3, items)) do table.insert(playerDependentButtons, button) end

    -- the player's time on Station roles, in its own window (roletimes.lua), then the role to give them
    local row = GUI.LayoutGroup(CreateRect(1, 1, right, nil), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(row, Common.GetStyleHeight("GUIButton"))
    row.Stretch = true
    row.AbsoluteSpacing = Common.GetButtonSpacing()
    row.CanBeFocused = false
    local roleTimes = Common.CreateButton(row, 1, language.RoleTimes)
    roleTimes.ToolTip = language.RoleTimesHint
    roleTimes.OnClicked = function()
        if selectedPlayerKey ~= nil then UI.ShowRoleTimes(selectedPlayerKey) end
        return true
    end
    table.insert(playerDependentButtons, roleTimes)
    local assignEntry = entryById.assignrole
    if assignEntry ~= nil then
        local picker = GUI.DropDown(CreateRect(1, 1, row, nil), language.SelectRole, math.max(1, math.min(#roles, MAX_ROLES_SHOWN)))
        for _, role in ipairs(roles) do picker.AddItem(role.Name, role.Id) end
        if selectedRoleId ~= nil then picker.SelectItem(selectedRoleId) end
        picker.OnSelected = function(_, roleId)
            selectedRoleId = roleId
            refreshSelection()
            return true
        end
        assignRoleButton = Common.CreateButton(row, 1, assignEntry.Label)
        assignRoleButton.ToolTip = tostring(assignEntry.Hint or "")
        assignRoleButton.OnClicked = function()
            if selectedPlayerKey ~= nil and selectedRoleId ~= nil then
                sendAction("assignrole", selectedPlayerKey, selectedRoleId)
            end
            return true
        end
    end

    for _, actionId in ipairs({ "addpoint", "addlife" }) do
        local entry = entryById[actionId]
        if entry ~= nil then
            local _, button = UI.CreateTextInputRow(right, entry.Label, entry.InputHint or "", function(value)
                if selectedPlayerKey ~= nil then sendAction(actionId, selectedPlayerKey, value) end
            end, true, tostring(entry.Hint or ""))
            table.insert(playerDependentButtons, button)
        end
    end

    -- what the round's commands report goes to the chat, as it did as chat commands
    Common.CreateDivider(layout)
    local roundItems = {}
    for _, actionId in ipairs({ "roundinfo", "roles", "traitoralive", "allpoints", "ongoingevents", "aghost", "aoverlay" }) do
        roundItems[#roundItems + 1] = actionItem(actionId)
    end
    roundItems[#roundItems + 1] = actionItem("triggerevent", function() UI.ShowEvents(stationRound and "station" or "secret") end)
    local endRound = actionItem("endroundnow")
    roundItems[#roundItems + 1] = endRound
    local buttons = UI.CreateButtonGrid(layout, 3, roundItems)
    if endRound ~= nil then UI.SetDangerButton(buttons[#roundItems]) end
end

-- A ghost role is made from any living character the client knows, a bot or a creature too.
local function buildGhostRolesPage(page)
    local layout = createColumn(page, 1, true)

    local characterNames = {}
    for character in Character.CharacterList do
        if not character.IsDead and tostring(character.Name or "") ~= "" then
            table.insert(characterNames, tostring(character.Name))
        end
    end
    table.sort(characterNames, function(a, b) return string.lower(a) < string.lower(b) end)

    local selectedFound = false
    for _, characterName in ipairs(characterNames) do
        if characterName == selectedGhostCharacterName then selectedFound = true break end
    end
    if not selectedFound then selectedGhostCharacterName = characterNames[1] end

    local label = CreateText(layout, 1, 1, nil, language.SelectCharacter, GUI.Alignment.Left, 0.82, Color(210, 220, 200, 255), false)
    Common.FitHeightToText(label)

    local list = createList(layout)
    if #characterNames == 0 then
        CreateText(list.Content, 1, 0.70, nil, language.NoCharacters, GUI.Alignment.Center, 0.82, Color(195, 195, 185, 255), true)
    end
    for _, characterName in ipairs(characterNames) do
        ghostCharacterButtons[characterName] = createListRow(list, characterName, function()
            if selectedGhostCharacterName ~= characterName then
                selectedGhostCharacterName = characterName
                refreshSelection()
            end
        end)
    end

    local entry = entryById.giveghostrole
    if entry ~= nil then
        local _, button = UI.CreateTextInputRow(layout, entry.Label, entry.InputHint or "", function(value)
            if selectedGhostCharacterName ~= nil then sendAction("giveghostrole", selectedGhostCharacterName, value) end
        end, true, tostring(entry.Hint or ""))
        ghostRoleButton = button
    end
end

local PAGES = {
    { Id = "Main", Build = buildMainPage },
    { Id = "GhostRoles", Build = buildGhostRolesPage },
}

local function clearWidgets()
    playerButtons = {}
    ghostCharacterButtons = {}
    selectedPlayerText = nil
    playerDependentButtons = {}
    assignRoleButton = nil
    ghostRoleButton = nil
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

-- Events with Id, the tabs they belong to (Station, Secret) and State: why they can't start now, "" when they can
function Admin.GetEvents()
    return events
end

function Admin.TriggerEvent(eventId)
    sendAction("triggerevent", "", eventId)
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
    clearWidgets()
    pendingReady = nil
end

-- The admin tab: a row of page tabs over the open page, which is built again when another tab is picked.
function Admin.Build(host)
    Admin.ClearView()

    local layout = createColumn(host, 1, true)
    local tabRow = GUI.LayoutGroup(CreateRect(1, 1, layout, nil), true)
    Common.SetFixedHeight(tabRow, Common.GetStyleHeight("GUIButtonSmall"))
    tabRow.Stretch = true
    tabRow.CanBeFocused = false
    local page = GUI.Frame(CreateRect(1, 1, layout, nil), nil)
    page.Color = Color(0, 0, 0, 0)
    page.CanBeFocused = false

    local tabs = {}
    local function show(pageId)
        activePage = pageId
        clearWidgets()
        page.ClearChildren()
        for _, entry in ipairs(PAGES) do
            tabs[entry.Id].Selected = entry.Id == pageId
            if entry.Id == pageId then entry.Build(page) end
        end
        page.ForceLayoutRecalculation()
        refreshSelection()
    end
    for _, entry in ipairs(PAGES) do
        local tab = GUI.Button(CreateRect(1, 1, tabRow, nil), language.Pages[entry.Id], GUI.Alignment.Center, "GUITabButton")
        SetButtonTextScale(tab, 0.82)
        tab.OnClicked = function()
            if activePage ~= entry.Id then show(entry.Id) end
            return true
        end
        tabs[entry.Id] = tab
    end
    show(activePage)
end

Networking.Receive(NET_SNAPSHOT, function(message)
    local previousAvailable = available
    available = message.ReadBoolean()

    local entries = {}
    local count = message.ReadInt32()
    for _ = 1, count do
        local command = message.ReadString()
        message.ReadString() -- input type is enforced by the server action
        local actionText = language.Actions[command] or {}
        entries[command] = {
            Command = command,
            Label = actionText.Label or command,
            Hint = actionText.Hint or "",
            InputHint = actionText.InputHint or "",
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

    if previousAvailable and not available and Admin.OnAvailabilityChanged ~= nil then
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
        pendingReady = nil
        if changed and Admin.OnAvailabilityChanged ~= nil then Admin.OnAvailabilityChanged() end
        return
    end

    maxLives = message.ReadInt32()
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
            Role = message.ReadString(),
            Points = message.ReadInt32(),
            Lives = message.ReadInt32(),
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

    stationRound = message.ReadBoolean()
    local newEvents = {}
    for _ = 1, message.ReadInt32() do
        table.insert(newEvents, {
            Id = message.ReadString(),
            Station = message.ReadBoolean(),
            Secret = message.ReadBoolean(),
            State = message.ReadString(),
        })
    end
    events = newEvents

    validateSelections()
    dataLoaded = true
    refreshSelection()
    Admin.OnDataChanged()

    local callback = pendingReady
    pendingReady = nil
    if callback ~= nil then callback() end
end)

return Admin
