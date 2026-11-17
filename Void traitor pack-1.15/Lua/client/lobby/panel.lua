local P = ...
local S = P.State
local Common = P.Common
local text = Common.Language.Lobby

-- The right column of the lobby, laid out like SS14: round info on top, then the vanilla spectate/AFK row,
-- the player's name, character and buttons, and the vote button at the bottom. The vanilla job and appearance
-- editor moves into a window while it is open. Settings panels under the server banner are left only to those
-- who can change them, and they can hide them with a button next to the banner's description button.

local screenType = Descriptors["Barotrauma.NetLobbyScreen"]
LuaUserData.MakeFieldAccessible(screenType, "playerInfoContent")
LuaUserData.MakeFieldAccessible(screenType, "characterInfoFrame")
LuaUserData.MakeFieldAccessible(screenType, "jobPreferencesButton")
LuaUserData.MakeFieldAccessible(screenType, "appearanceButton")
LuaUserData.MakeMethodAccessible(screenType, "SelectJobPreferencesTab")
LuaUserData.MakeMethodAccessible(screenType, "SelectAppearanceTab")

local STATUS_COLOR = Color(170, 175, 165, 255)
-- height of the character picture in 1920x1080 pixels; a picture scales with the screen like the vanilla HUD,
-- while the text rows keep the font's size, which does not shrink below 1080p
local PREVIEW_HEIGHT = 220

S.lobbyInfo = nil
S.lobbyInfoCheckTime = 0
S.lobbyPanel = nil
S.card = nil
S.settingsHidden = false
S.wideCardWindow = false

local function canEditSettings()
    return Game.Client.HasPermission(ClientPermissions.ManageSettings)
        or Game.Client.HasPermission(ClientPermissions.SelectSub)
        or Game.Client.HasPermission(ClientPermissions.SelectMode)
end

-- MoonSharp resolves GetChild(index) to the generic GetChild<T>() overload, so children are walked instead.
local function firstChild(component)
    for child in component.Children do return child end
end

-- NetLobbyScreen builds its left column as a frame holding the server banner and two rows of settings panels.
local function findSettings(screen)
    local frame = firstChild(firstChild(firstChild(screen.Frame)))
    local rows = {}
    for child in firstChild(frame).Children do
        rows[#rows + 1] = child
    end
    table.remove(rows, 1)
    return frame, rows
end

local FRAME_COLORS = { "Color", "HoverColor", "SelectedColor", "PressedColor" }
local TRANSPARENT = Color(0, 0, 0, 0)

-- Lets a reload of the client Lua remove what this file added to the lobby.
local function rememberParts()
    local parts = {}
    if S.lobbyPanel ~= nil then
        parts[1] = S.lobbyPanel.Round
        parts[2] = S.lobbyPanel.NameSlot
        parts[3] = S.lobbyPanel.VoteSlot
        parts[4] = S.lobbyPanel.Divider
        parts[5] = S.lobbyPanel.SettingsToggle
        parts[6] = S.lobbyPanel.RoundDivider
    end
    for _, part in ipairs(S.card ~= nil and S.card.Parts or {}) do
        parts[#parts + 1] = part
    end
    S.sharedState.LobbyParts = parts
end

local function createLine(parent, anchor, alignment, color)
    local block = Common.CreateText(parent, 1, 1, anchor, "", alignment, 1, color, false)
    Common.FitHeightToText(block)
    return block
end

-- The card keeps the height its rows need and the chat below takes the rest. A card without editing
-- (job and skills of a permadeath round in progress) keeps the vanilla share.
local function fitCard(panel)
    local card, content, chat = panel.Column.Parent, panel.Content, panel.Chat
    local side = card.Parent
    -- The lobby first lays out its columns over the bottom bar in its update, after the card is built; where the bar's
    -- minimum height (NetLobbyScreen.CreateBottomPanelContents) is more than its share, the columns end up shorter
    -- than they were built, so they are laid out before the column is measured.
    side.Parent.Parent.Parent.Recalculate()
    for _, part in ipairs({ card, content, chat }) do
        part.RectTransform.MinSize = Point(0, 0)
        part.RectTransform.MaxSize = Point(2147483647, 2147483647)
    end
    -- With every row at a fixed height the vanilla stretch (GUILayoutGroup.Recalculate) has nothing to scale,
    -- so one pass places the rows; otherwise it scales the current heights and the spacing and is off after a resize.
    if S.card ~= nil then
        Common.SetFixedHeight(content, Common.GetMinimumHeight(content))
        Common.SetFixedHeight(card, Common.GetMinimumHeight(panel.Column))
        -- the right column only has relative spacing, between its three rows
        local spacing = math.floor(2 * side.RelativeSpacing * side.Rect.Height + 0.5)
        Common.SetFixedHeight(chat, side.Rect.Height - card.RectTransform.MinSize.Y - panel.Divider.RectTransform.MinSize.Y - spacing)
    end
    side.Recalculate()
    panel.Column.Recalculate()
    content.Recalculate()
end

local function layoutRound(panel)
    local height = 0
    for child in panel.Round.RectTransform.Children do
        if not child.GUIComponent.IgnoreLayoutGroups then height = height + child.MinSize.Y end
    end
    Common.SetFixedHeight(panel.Round, height)
    fitCard(panel)
end

local function ensurePanel(screen)
    local column = screen.playerInfoContent.Parent
    if S.lobbyPanel ~= nil and S.lobbyPanel.Column == column then return end

    local panel = { Column = column, Content = screen.playerInfoContent, Shown = {} }
    panel.LeftFrame, panel.SettingsRows = findSettings(screen)
    column.AbsoluteSpacing = Common.GetGap()
    local spectateRow = firstChild(column)
    Common.SetFixedHeight(spectateRow, spectateRow.RectTransform.MinSize.Y)

    local function createSlot()
        local slot = GUI.Frame(Common.CreateRect(1, 1, column), nil)
        slot.Color = TRANSPARENT
        slot.CanBeFocused = false
        Common.SetFixedHeight(slot, Common.GetStyleHeight("GUIButton"))
        return slot
    end

    -- the name lives outside the vanilla card, which spectating clears
    panel.NameSlot = createSlot()
    panel.NameSlot.RectTransform.SetAsFirstChild()
    spectateRow.RectTransform.SetAsFirstChild()

    -- the line under the round info gets the column's spacing above and below
    panel.RoundDivider = Common.CreateDivider(column)
    panel.RoundDivider.RectTransform.SetAsFirstChild()
    panel.Round = GUI.LayoutGroup(Common.CreateRect(1, 1, column), false)
    panel.Round.CanBeFocused = false
    panel.Round.RectTransform.SetAsFirstChild()

    local titleRow = GUI.Frame(Common.CreateRect(1, 1, panel.Round), nil)
    titleRow.Color = TRANSPARENT
    titleRow.CanBeFocused = false
    panel.Title = Common.CreateText(titleRow, 1, 1, GUI.Anchor.CenterLeft, "", GUI.Alignment.CenterLeft, 1, nil, false)
    panel.Title.Font = GUI.Style.SubHeadingFont
    panel.Status = createLine(titleRow, GUI.Anchor.CenterRight, GUI.Alignment.CenterRight, STATUS_COLOR)
    Common.SetFixedHeight(titleRow, Common.GetTextHeight(panel.Title.Font))
    panel.Mode = createLine(panel.Round)
    panel.Map = createLine(panel.Round)
    panel.Players = createLine(panel.Round)

    panel.VoteSlot = createSlot()

    -- the right column holds the card and the chat; the line between them gets the column's spacing on both sides
    local card = column.Parent
    for child in card.Parent.Children do
        if child ~= card then panel.Chat = child end
    end
    panel.Divider = Common.CreateDivider(card.Parent)
    panel.Chat.RectTransform.SetAsLastChild()

    -- same size and row as the banner's description button, right after it
    local description = screen.ServerMessageButton.RectTransform
    local toggleRect = GUI.RectTransform(description.RelativeSize, description.Parent, GUI.Anchor.BottomLeft)
    toggleRect.RelativeOffset = Vector2(description.RelativeSize.X + 0.01, 0)
    panel.SettingsToggle = GUI.Button(toggleRect, "", GUI.Alignment.Center, "GUIButtonSmall")
    panel.SettingsToggle.IgnoreLayoutGroups = true
    Common.SetAutoScaleText(panel.SettingsToggle.TextBlock, 1)
    panel.SettingsToggle.OnClicked = function()
        S.settingsHidden = not S.settingsHidden
        P.ApplyLobbyLayout(screen)
        return true
    end

    S.lobbyPanel = panel
    rememberParts()
    layoutRound(panel)
    P.RefreshRoundInfo()
end

function P.ApplyLobbyLayout(screen)
    ensurePanel(screen)
    local panel = S.lobbyPanel
    local canEdit = canEditSettings()
    local shown = canEdit and not S.settingsHidden
    panel.SettingsToggle.Visible = canEdit
    panel.SettingsToggle.Text = shown and text.HideSettings or text.ShowSettings
    -- a wide card window takes the panels' place under the banner while it is open
    local visible = shown and not S.wideCardWindow
    for _, row in ipairs(panel.SettingsRows) do
        row.Visible = visible
    end
    -- without the panels only the banner is left, so the frame's background goes with them
    local frame = panel.LeftFrame
    for _, key in ipairs(FRAME_COLORS) do
        frame[key] = visible and frame.Style[key] or TRANSPARENT
    end
end

local function setText(panel, name, value)
    if panel.Shown[name] == value then return end
    panel.Shown[name] = value
    panel[name].Text = value
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds % 60) end
    return string.format("%d:%02d", minutes, seconds % 60)
end

function P.RefreshRoundInfo()
    local panel, info = S.lobbyPanel, S.lobbyInfo
    if panel == nil or info == nil then return end

    local map
    if info.Running then
        setText(panel, "Status", string.format(text.Running, formatDuration(P.GetTime() - info.StartTime)))
        map = info.Map
    else
        setText(panel, "Status", text.Waiting)
        local screen = Game.NetLobbyScreen
        local sub = screen.SelectedSub
        map = sub ~= nil and sub.DisplayName.Value or ""
        -- the server names the next round's mode; ask again once the lobby's submarine or mode has changed
        local now = P.GetTime()
        if now >= S.lobbyInfoCheckTime then
            S.lobbyInfoCheckTime = now + 1
            if sub ~= info.Sub or screen.SelectedMode ~= info.Preset then
                info.Sub, info.Preset = sub, screen.SelectedMode
                P.SendNetMessage(P.NET_LOBBY_INFO_REQUEST)
            end
        end
    end
    setText(panel, "Title", string.format(text.Round, info.Number))
    setText(panel, "Mode", string.format(text.Mode, info.Mode))
    setText(panel, "Map", string.format(text.Map, map))
    setText(panel, "Players", string.format(text.Players, #Client.ClientList))

    local showMode = info.Mode ~= ""
    if panel.Mode.Visible ~= showMode then
        panel.Mode.Visible = showMode
        panel.Mode.IgnoreLayoutGroups = not showMode
        layoutRound(panel)
    end
end

-- The card shows the first job preference: its name and the character in its outfit.
-- in a Station lobby the role the player wants most (stationjobs.lua), otherwise the first vanilla job preference
local function refreshCardJob(screen)
    local job, label
    if S.lobbyInfo ~= nil and S.lobbyInfo.Station then
        job, label = P.GetStationCardRole()
    else
        local slot = firstChild(screen.JobList.Content)
        job = slot ~= nil and slot.UserData or nil
        label = job ~= nil and job.Prefab.Name.Value or nil
    end
    S.card.JobLabel.Text = label or text.NoJob
    P.SetFigureJob(S.card.Figure, job)
end

function P.RefreshCardJob()
    if S.card ~= nil then refreshCardJob(Game.NetLobbyScreen) end
end

local function arrangePlayerCard(screen)
    -- the window holds the editor of the card that was just replaced
    if S.currentMenuKind == "character" then P.CloseMenu() end
    S.card = nil
    ensurePanel(screen)
    local panel = S.lobbyPanel

    local nameBox = screen.CharacterNameBox
    if nameBox ~= nil and nameBox.Parent ~= panel.NameSlot then
        panel.NameSlot.ClearChildren()
        nameBox.RectTransform.Parent = panel.NameSlot.RectTransform
        nameBox.RectTransform.RelativeSize = Vector2(1, 1)
    end

    local content = screen.playerInfoContent
    local editor = screen.characterInfoFrame
    -- without editing (a permadeath round in progress, spectating) the vanilla card stays as it is
    if editor == nil or editor.Parent ~= content then
        rememberParts()
        fitCard(panel)
        return
    end

    for _, part in ipairs({ screen.jobPreferencesButton.Parent, editor }) do
        part.Visible = false
        part.IgnoreLayoutGroups = true
    end

    local preview = GUI.Frame(Common.CreateRect(1, 1, content), nil)
    preview.Color = TRANSPARENT
    preview.CanBeFocused = false
    Common.SetFixedHeight(preview, GUI.IntScale(PREVIEW_HEIGHT))
    local figure = P.CreateCharacterFigure(GUI.RectTransform(Vector2(1, 1), preview.RectTransform, GUI.Anchor.Center), content.UserData)

    local jobLabel = Common.CreateText(content, 1, 1, nil, "", GUI.Alignment.Center, 1, nil, false)
    jobLabel.Font = GUI.Style.SubHeadingFont
    Common.FitHeightToText(jobLabel)

    local buttons = GUI.LayoutGroup(Common.CreateRect(1, 1, content), true)
    buttons.Stretch = true
    buttons.AbsoluteSpacing = Common.GetButtonSpacing()
    buttons.CanBeFocused = false
    Common.SetFixedHeight(buttons, Common.GetStyleHeight("GUIButton"))
    local labels = {}
    for _, entry in ipairs({
        { Label = text.Jobs, Open = function()
            if S.lobbyInfo ~= nil and S.lobbyInfo.Station then P.ShowStationJobsWindow() else P.ShowCharacterWindow(false) end
        end },
        { Label = text.Antagonists, Open = function() P.ShowAntagonistsWindow() end },
        { Label = text.Appearance, Open = function() P.ShowCharacterWindow(true) end },
    }) do
        local button = GUI.Button(Common.CreateRect(1 / 3, 1, buttons), entry.Label, GUI.Alignment.Center, "GUIButton")
        labels[#labels + 1] = button.TextBlock
        button.OnClicked = function()
            entry.Open()
            return true
        end
    end

    S.card = { JobList = screen.JobList, JobLabel = jobLabel, Figure = figure, Parts = { preview, jobLabel, buttons } }
    rememberParts()
    refreshCardJob(screen)
    fitCard(panel)
    -- once the buttons have their width: one text size for all three, the one the longest label needs
    GUI.TextBlock.AutoScaleAndNormalize(table.unpack(labels))
end

function P.ArrangePlayerCard(screen)
    local oldCard = S.card
    arrangePlayerCard(screen)
    -- after the new figure has loaded, so the textures both use stay loaded
    if oldCard ~= nil then P.RemoveCharacterFigure(oldCard.Figure) end
end

-- A window beside the player card, with room on the left for the vanilla job grid, which opens to the left of
-- the editor, and as tall as the vanilla card, which takes 0.55 of the right column (CreateSidePanelContents).
-- A wide window takes the place of the settings panels under the server banner, which hide while it is open.
-- Returns the window's content layout.
function P.OpenCardWindow(kind, title, wide)
    local screen = Game.NetLobbyScreen
    if S.currentMenu ~= nil then P.CloseMenu() end

    -- The window's holder covers the lobby but takes no clicks, so the chat and the lobby's buttons stay usable.
    -- All its state colors are set: it counts as hovered while the cursor is over the window.
    local root = GUI.Frame(Common.CreateRect(1, 1, P.GetLobbyGuiFrame()), nil)
    for _, key in ipairs(FRAME_COLORS) do
        root[key] = TRANSPARENT
    end
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    P.SafeSetAsLastChild(root)
    S.currentMenu = root
    S.currentMenuKind = kind
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = S.currentMenuKind

    local windowRect
    if wide then
        local frameRect, top = S.lobbyPanel.LeftFrame.Rect, S.lobbyPanel.SettingsRows[1].Rect.Y
        windowRect = GUI.RectTransform(Point(frameRect.Width, frameRect.Bottom - top), root.RectTransform, GUI.Anchor.TopLeft)
        windowRect.AbsoluteOffset = Point(frameRect.X - root.Rect.X, top - root.Rect.Y)
        S.wideCardWindow = true
        P.ApplyLobbyLayout(screen)
    else
        local card = screen.playerInfoContent.Parent.Parent
        local cardRect, columnRect = card.Rect, card.Parent.Rect
        windowRect = GUI.RectTransform(Point(cardRect.Width, math.floor(columnRect.Height * 0.55)), root.RectTransform, GUI.Anchor.TopLeft)
        windowRect.AbsoluteOffset = Point(cardRect.X - cardRect.Width - Common.GetGap() - root.Rect.X, cardRect.Y - root.Rect.Y)
    end
    local window = GUI.Frame(windowRect, "GUIFrame")
    local content = Common.CreateWindowContent(window)
    Common.CreateWindowHeader(content, window, title, P.UiText.Cancel, function()
        if S.currentMenu == root then P.CloseMenu() end
        return true
    end)
    return content
end

function P.ShowCharacterWindow(showAppearance)
    local screen = Game.NetLobbyScreen
    local content = P.OpenCardWindow("character", showAppearance and text.Appearance or text.Jobs)

    -- only the editor moves: the window's own title replaces the vanilla tabs, which stay hidden in the card
    local editor = screen.characterInfoFrame
    editor.RectTransform.Parent = content.RectTransform
    editor.Visible = true
    editor.IgnoreLayoutGroups = false
    content.Recalculate()

    if showAppearance then
        screen.SelectAppearanceTab(screen.appearanceButton, nil)
    else
        screen.SelectJobPreferencesTab(screen.jobPreferencesButton, nil)
    end
    -- laid out now, or the editor's lists show unplaced for a frame (menu_window.lua)
    S.currentMenu.ForceLayoutRecalculation()
end

-- The job grid is drawn on the canvas, outside the window.
function P.HideJobSelection()
    local screen = Game.NetLobbyScreen
    if screen.JobSelectionFrame == nil then return end
    screen.JobList.Deselect()
    screen.JobSelectionFrame.Visible = false
end

Networking.Receive(P.NET_LOBBY_INFO, function(message)
    if S.sharedState.Disabled then return end

    local info = { Running = message.ReadBoolean(), Number = message.ReadInt32(), Mode = message.ReadString(),
        Station = message.ReadBoolean() }
    if info.Running then
        info.Map = message.ReadString()
        info.StartTime = P.GetTime() - message.ReadInt32()
    else
        info.Sub = Game.NetLobbyScreen.SelectedSub
        info.Preset = Game.NetLobbyScreen.SelectedMode
    end
    local wasStation = S.lobbyInfo ~= nil and S.lobbyInfo.Station
    S.lobbyInfo = info
    P.RefreshRoundInfo()
    -- the card shows the Station role or the vanilla job, whichever the lobby now uses
    if info.Station ~= wasStation then P.RefreshCardJob() end
end)

-- RefreshEnabledElements runs when the lobby opens and whenever the player's permissions change.
Hook.Patch("VoidTraitor.Lobby.Layout", "Barotrauma.NetLobbyScreen", "RefreshEnabledElements", function(instance)
    if S.sharedState.Disabled or Game.Client == nil then return end
    P.ApplyLobbyLayout(instance)
end, Hook.HookMethodType.After)

Hook.Patch("VoidTraitor.Lobby.PlayerCard", "Barotrauma.NetLobbyScreen", "UpdatePlayerFrame",
    { "Barotrauma.CharacterInfo", "System.Boolean", "Barotrauma.GUIComponent", "System.Boolean" },
    function(instance, ptable)
        if S.sharedState.Disabled then return end
        -- CreatePlayerFrame builds the same card for other parents
        if ptable["parent"] ~= instance.playerInfoContent then return end
        P.ArrangePlayerCard(instance)
    end, Hook.HookMethodType.After)

-- Spectating replaces the card with a single vanilla line; the chat takes the space that frees.
Hook.Patch("VoidTraitor.Lobby.Spectate", "Barotrauma.NetLobbyScreen", "SetSpectate", function(instance, ptable)
    if S.sharedState.Disabled or Game.Client == nil or not ptable["spectate"] or S.lobbyPanel == nil then return end
    -- the card's buttons are gone, so are the windows they opened
    local kind = S.currentMenuKind
    if kind == "character" or kind == "antagonists" or kind == "stationjobs" then P.CloseMenu() end
    for line in instance.playerInfoContent.Children do
        Common.FitHeightToText(line)
    end
    fitCard(S.lobbyPanel)
end, Hook.HookMethodType.After)

-- Runs on a change of job, variant or head, and also inside UpdatePlayerFrame for the card being built there.
Hook.Patch("VoidTraitor.Lobby.CardJob", "Barotrauma.NetLobbyScreen", "UpdateJobPreferences", { "Barotrauma.CharacterInfo" },
    function(instance)
        if S.sharedState.Disabled or S.card == nil or S.card.JobList ~= instance.JobList then return end
        refreshCardJob(instance)
    end, Hook.HookMethodType.After)

-- The client Lua can load after the lobby has already built its card.
if Game.Client ~= nil and Game.NetLobbyScreen ~= nil then
    P.ApplyLobbyLayout(Game.NetLobbyScreen)
    P.ArrangePlayerCard(Game.NetLobbyScreen)
end
