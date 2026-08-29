if SERVER then return end

local packPath, Common = ...
local Admin

-- Void Traitor quick menu.
-- Client-side buttons only. Every action is validated and executed on the server.

local NET_READY = "VoidTraitor_ClientMenuGuiReady"
local NET_REQUEST = "VoidTraitor_ClientMenuRequest"
local NET_SNAPSHOT = "VoidTraitor_ClientMenuSnapshot"
local NET_RUN = "VoidTraitor_ClientMenuRun"
local NET_POINTSHOP_REQUEST = "VoidTraitor_PointshopRequest"
local NET_VOTE_READY = "VoidTraitor_LobbyVoteGuiReady"
local NET_VOTE_REQUEST = "VoidTraitor_LobbyVoteRequest"
local NET_VOTE_SNAPSHOT = "VoidTraitor_LobbyVoteSnapshot"
local NET_VOTE_START = "VoidTraitor_LobbyVoteStart"
local NET_VOTE_CAST = "VoidTraitor_LobbyVoteCast"

local DISABLED_ACTION_PREFIX = "__vt_disabled__:"

local GLOBAL_STATE_KEY = "VoidTraitorClientMenuState"
local HUD_PATCH_ID = "VoidTraitor.ClientMenu.Hud"
local PAUSE_PATCH_ID = "VoidTraitor.ClientMenu.Pause"

local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
    Common.RemoveGuiComponent(previousState.ButtonRoot)
    Common.RemoveGuiComponent(previousState.VoteButtonRoot)
    Common.RemoveGuiComponent(previousState.GuiRoot)
end

local sharedState = { Disabled = false }
_G[GLOBAL_STATE_KEY] = sharedState

local buttonRoot = nil
local voteButtonRoot = nil
local voteButtonParent = nil
local guiRoot = nil
local currentMenu = nil
local currentMenuKind = ""
local activeVoteUi = nil
local lastResolutionX = -1
local lastResolutionY = -1
local escapeClosePending = false
local menuEntries = nil
local vtActiveTab = "main"
local pendingMenuOpen = false
local voteSnapshot = nil
local pendingVoteMenuOpen = false
local lastActiveVoteId = ""
local lastShownActiveVoteId = ""
local lastVoteButtonResolutionX = -1
local lastVoteButtonResolutionY = -1
local uiStateCheckTimer = 0
local vtMenuList = nil
local vtMainList = nil
local vtAdminList = nil
local vtMainListFrame = nil
local vtAdminListFrame = nil
local vtMenuScroll = 0
local vtAdminScroll = 0
local vtMenuX = nil
local vtMenuY = nil
local vtMenuHeight = nil
local vtResizeTopTargets = {}
local vtResizeBottomTargets = {}
local vtResizeState = nil
local uiText = {
    Title = "VOID TRAITOR",
    ShopButton = "SHOP",
    MainButton = "VT",
    ShopTooltip = "Open Void Traitor Pointshop",
    MainTooltip = "Open Void Traitor command menu",
    NoCommands = "No commands were received from the server.",
    GenericCommand = "Command",
    DefaultConfirmTitle = "Confirmation",
    Cancel = "Cancel",
    Yes = "Yes",
    Ok = "OK",
}


local voteUiText = {
    Button = "Начать голосование",
    Tooltip = "Открыть меню голосования в лобби",
    StartTitle = "Vote",
    StartMode = "Start game mode vote",
    StartMap = "Start submarine vote",
    StartBlockedReason = "",
    Close = "Close",
    NoActive = "No active vote right now.",
    StartedBy = "Started by",
    Timer = "Time left",
    Votes = "votes",
}

local BUTTON_DRAW_ORDER = 100
local MENU_DRAW_ORDER = 125
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.NetLobbyScreen"], "respawnTabButton")
local VT_MENU_WIDTH_PIXELS = 370
local VT_MENU_DEFAULT_HEIGHT_PIXELS = 580
local VT_MENU_MIN_HEIGHT_PIXELS = 340
local VT_MENU_MARGIN_PIXELS = 0
local VT_BUTTON_HEIGHT_PIXELS = 36
local VT_CATEGORY_HEIGHT_PIXELS = 30
local VT_DIVIDER_HEIGHT_PIXELS = 10
local VT_INPUT_LABEL_HEIGHT_PIXELS = 24
local VT_INPUT_ROW_HEIGHT_PIXELS = 40
local VT_LIST_SIDE_PADDING_PIXELS = 6

local SafeIntScale = Common.SafeIntScale
local GetScreenSize = Common.GetScreenSize
local Clamp = Common.Clamp

local CreateRect = Common.CreateRect

local function CreatePixelRect(width, height, parent, anchor)
    return GUI.RectTransform(
        Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))),
        parent ~= nil and parent.RectTransform or nil,
        anchor
    )
end

local function SetFixedHeight(component, pixels)
    if component == nil or component.RectTransform == nil then return end
    local height = SafeIntScale(pixels)
    component.RectTransform.MinSize = Point(0, height)
    component.RectTransform.MaxSize = Point(100000, height)
end

guiRoot = GUI.Frame(CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
guiRoot.Color = Color(0, 0, 0, 0)
guiRoot.CanBeFocused = false
guiRoot.IgnoreLayoutGroups = true
sharedState.GuiRoot = guiRoot
guiRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER)

local function CreateButtonAreaRect(buttonWidth, buttonHeight, buttonCount, padding)
    buttonCount = buttonCount or 2
    padding = padding or SafeIntScale(11)

    local rectTransform = GUI.RectTransform(Point((buttonWidth * buttonCount) + padding, buttonHeight), nil, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(SafeIntScale(11) + ((buttonWidth + padding) * 3), SafeIntScale(11))
    return rectTransform
end

local function GetTopButtonSize()
    local buttonHeight = SafeIntScale(40)
    return math.floor(buttonHeight * 1.72), buttonHeight
end

local function GetTopButtonSpacing()
    return SafeIntScale(11)
end

local function SendNetMessage(identifier, writer)
    local msg = Networking.Start(identifier)
    if writer ~= nil then writer(msg) end
    Networking.Send(msg)
end

local function GetTime()
    return Timer.GetTime()
end

local function SendReady()
    SendNetMessage(NET_READY)
    if Admin ~= nil then Admin.RequestMetadata() end
end

local function SendCommand(command, input)
    SendNetMessage(NET_RUN, function(msg)
        msg.WriteString(command or "")
        msg.WriteString(tostring(input or ""))
    end)
end

local function RequestMenuSnapshot(openAfterResponse)
    pendingMenuOpen = openAfterResponse == true
    SendNetMessage(NET_REQUEST)
    Admin.RequestMetadata()
end

local function SendVoteReady()
    SendNetMessage(NET_VOTE_READY)
end

local function RequestVoteSnapshot(openAfterResponse)
    pendingVoteMenuOpen = openAfterResponse == true
    SendNetMessage(NET_VOTE_REQUEST)
end

local function SendVoteStart(voteType)
    SendNetMessage(NET_VOTE_START, function(msg)
        msg.WriteString(tostring(voteType or ""))
    end)
end

local function SendVoteCast(optionId)
    SendNetMessage(NET_VOTE_CAST, function(msg)
        msg.WriteInt32(tonumber(optionId or 0) or 0)
    end)
end

local function SaveVoidTraitorMenuGeometry()
    if currentMenu == nil or currentMenuKind ~= "vt" then return end

    local rect = currentMenu.Rect
    vtMenuX = rect.X
    vtMenuY = rect.Y
    vtMenuHeight = rect.Height
    if vtMainList ~= nil then vtMenuScroll = vtMainList.BarScroll end
    if vtAdminList ~= nil then vtAdminScroll = vtAdminList.BarScroll end
end

local CloseMenu
local ShowVoidTraitorMenu

CloseMenu = function()
    SaveVoidTraitorMenuGeometry()

    Common.RemoveGuiComponent(currentMenu)

    currentMenu = nil
    currentMenuKind = ""
    activeVoteUi = nil
    vtMenuList = nil
    vtMainList = nil
    vtAdminList = nil
    vtMainListFrame = nil
    vtAdminListFrame = nil
    vtResizeTopTargets = {}
    vtResizeBottomTargets = {}
    vtResizeState = nil
    if Admin ~= nil then Admin.ClearView() end
    sharedState.CurrentMenu = nil
    sharedState.CurrentMenuKind = ""
    escapeClosePending = false
end

sharedState.CloseMenu = CloseMenu

local function RequestEscapeClose()
    if currentMenu == nil or escapeClosePending then return end

    if currentMenuKind == "voteactive" then
        return
    end

    escapeClosePending = true
    sharedState.BlockPauseMenu = true
    CloseMenu()
    Timer.Wait(function()
        sharedState.BlockPauseMenu = false
    end, 250)
end

local CreateText = Common.CreateText

local function SetButtonTextScale(button, scale)
    if button == nil or button.TextBlock == nil then return end
    button.TextBlock.TextScale = scale
    button.TextBlock.AutoScaleHorizontal = true
end

local function PlayVoteSound()
    if SoundPlayer.PlaySound("voteding", 1.0) == nil then
        SoundPlayer.PlayUISound(GUI.SoundType.Cart)
    end
end

local function CreateMenuButton(parent, label, enabled)
    local button = GUI.Button(CreateRect(1, 0.10, parent, nil), label or "", GUI.Alignment.Center, "GUIButton")
    SetFixedHeight(button, VT_BUTTON_HEIGHT_PIXELS)
    button.Enabled = enabled ~= false
    SetButtonTextScale(button, 0.92)
    return button
end

local function CreateDivider(parent)
    local frame = GUI.Frame(CreateRect(1, 0.02, parent, nil), nil)
    SetFixedHeight(frame, VT_DIVIDER_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)
    GUI.Image(CreateRect(1, 0.50, frame, GUI.Anchor.Center), "HorizontalLine")
end

local function CreateCategoryHeader(parent, label)
    local frame = GUI.Frame(CreateRect(1, 0.06, parent, nil), nil)
    SetFixedHeight(frame, VT_CATEGORY_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)

    local text = CreateText(frame, 1, 0.82, GUI.Anchor.BottomLeft, string.upper(tostring(label or "")), GUI.Alignment.Left, 0.88, Color(205, 220, 200, 255), false)
    text.Font = GUI.Style.SubHeadingFont
    return frame
end

local function CreateTextInputRow(parent, label, placeholder, action, enabled, tooltip)
    local isEnabled = enabled ~= false
    local labelBlock = CreateText(parent, 1, 0.05, nil, label, GUI.Alignment.Left, 0.86, Color(210, 220, 200, 255), false)
    SetFixedHeight(labelBlock, VT_INPUT_LABEL_HEIGHT_PIXELS)
    labelBlock.Font = GUI.Style.SubHeadingFont
    labelBlock.ToolTip = tooltip or ""

    local row = GUI.LayoutGroup(CreateRect(1, 0.09, parent, nil), true, GUI.Anchor.CenterLeft)
    SetFixedHeight(row, VT_INPUT_ROW_HEIGHT_PIXELS)
    row.Stretch = true
    row.RelativeSpacing = 0.010

    local input = GUI.TextBox(CreateRect(0.66, 1, row, nil), placeholder or "")
    input.Enabled = isEnabled
    input.ToolTip = tooltip or ""
    if input.TextBlock ~= nil then input.TextBlock.TextScale = 0.86 end

    local sendButton = GUI.Button(CreateRect(0.32, 1, row, nil), uiText.Ok, GUI.Alignment.Center, "GUIButton")
    sendButton.Enabled = isEnabled
    sendButton.ToolTip = tooltip or ""
    SetButtonTextScale(sendButton, 0.90)
    sendButton.OnClicked = function()
        local value = input.Text or ""
        SendCommand(action, value)
        input.Text = ""
        return true
    end

    return input
end

local function CreateMenuList(parent)
    local frame = GUI.Frame(CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    frame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 0.985, frame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then list.ContentBackground.Color = Color(0, 0, 0, 0) end
    list.KeepSpaceForScrollBar = true
    local sidePadding = SafeIntScale(VT_LIST_SIDE_PADDING_PIXELS)
    local scrollBarWidth = math.max(0, list.ScrollBar.Rect.Width)
    list.Padding = Vector4(scrollBarWidth + sidePadding, 0, sidePadding, 0)
    list:UpdateDimensions()
    return frame, list
end

Admin = assert(loadfile(packPath .. "/Lua/client/lobby/admin.lua"))(Common, {
    CreateRect = CreateRect,
    SetFixedHeight = SetFixedHeight,
    SetButtonTextScale = SetButtonTextScale,
    CreateMenuButton = CreateMenuButton,
    CreateDivider = CreateDivider,
    CreateCategoryHeader = CreateCategoryHeader,
    GetOkText = function() return uiText.Ok end,
})

Admin.OnAvailabilityChanged = function()
    if currentMenuKind ~= "vt" then
        if not Admin.IsAvailable() then vtActiveTab = "main" end
        return
    end

    CloseMenu()
    if not Admin.IsAvailable() then vtActiveTab = "main" end
    ShowVoidTraitorMenu()
end

local function AddVoidTraitorResizeHandles(panel)
    vtResizeTopTargets = {}
    vtResizeBottomTargets = {}
    Common.AddResizeHandles(panel, vtResizeTopTargets, vtResizeBottomTargets)
end

local function UpdateVoidTraitorMenuInteraction()
    if currentMenu == nil or currentMenuKind ~= "vt" then
        vtResizeState = nil
        return
    end

    vtResizeState, vtMenuX, vtMenuY, vtMenuHeight = Common.UpdateMenuInteraction(
        currentMenu,
        vtResizeState,
        vtResizeTopTargets,
        vtResizeBottomTargets,
        VT_MENU_MIN_HEIGHT_PIXELS,
        vtMenuList,
        vtMenuX,
        vtMenuY,
        vtMenuHeight
    )
end

local function ShowConfirm(title, text, action)
    SaveVoidTraitorMenuGeometry()
    Common.RemoveGuiComponent(currentMenu)

    local overlay = GUI.Frame(CreateRect(1, 1, guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 110)
    overlay.CanBeFocused = true
    overlay.IgnoreLayoutGroups = true
    currentMenu = overlay
    currentMenuKind = "confirm"
    sharedState.CurrentMenu = overlay
    sharedState.CurrentMenuKind = currentMenuKind

    local box = GUI.Frame(CreateRect(0.20, 0.165, overlay, GUI.Anchor.Center), "GUIFrame")
    box.CanBeFocused = true

    local titleBlock = CreateText(box, 0.90, 0.22, GUI.Anchor.TopCenter, title, GUI.Alignment.Center, 1.02, Color(255, 235, 170, 255), false)
    titleBlock.RectTransform.AbsoluteOffset = Point(0, SafeIntScale(8))
    titleBlock.Font = GUI.Style.LargeFont
    CreateText(box, 0.86, 0.30, GUI.Anchor.Center, text, GUI.Alignment.Center, 1.08, Color(230, 230, 220, 255), true)

    local buttons = GUI.Frame(CreateRect(0.76, 0.20, box, GUI.Anchor.BottomCenter), nil)
    buttons.RectTransform.AbsoluteOffset = Point(0, SafeIntScale(18))
    buttons.Color = Color(0, 0, 0, 0)
    buttons.CanBeFocused = false

    local cancel = GUI.Button(CreateRect(0.47, 1, buttons, GUI.Anchor.CenterLeft), uiText.Cancel, GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(cancel, 1.00)
    cancel.OnClicked = function()
        CloseMenu()
        return true
    end

    local confirm = GUI.Button(CreateRect(0.47, 1, buttons, GUI.Anchor.CenterRight), uiText.Yes, GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(confirm, 1.00)
    confirm.OnClicked = function()
        SendCommand(action)
        CloseMenu()
        return true
    end
end

ShowVoidTraitorMenu = function()
    if currentMenu ~= nil then
        CloseMenu()
        return
    end

    if menuEntries == nil then
        RequestMenuSnapshot(true)
        return
    end

    if vtActiveTab == "admin" and not Admin.IsAvailable() then vtActiveTab = "main" end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(VT_MENU_MARGIN_PIXELS)
    local minHeight = SafeIntScale(VT_MENU_MIN_HEIGHT_PIXELS)
    local maxHeight = math.max(minHeight, screenHeight - margin * 2)
    local width = math.min(SafeIntScale(VT_MENU_WIDTH_PIXELS), math.max(1, screenWidth - margin * 2))
    local height = Clamp(vtMenuHeight or SafeIntScale(VT_MENU_DEFAULT_HEIGHT_PIXELS), minHeight, maxHeight)
    local x = vtMenuX or math.floor((screenWidth - width) / 2)
    local y = vtMenuY or math.floor((screenHeight - height) / 2)
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))

    local rootRect = CreatePixelRect(width, height, guiRoot, GUI.Anchor.TopLeft)
    rootRect.AbsoluteOffset = Point(x, y)
    local root = GUI.Frame(rootRect, nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    currentMenu = root
    currentMenuKind = "vt"
    sharedState.CurrentMenu = root
    sharedState.CurrentMenuKind = currentMenuKind

    local panel = GUI.Frame(CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.003

    local header = GUI.Frame(CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.86, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.07, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = CreateText(dragArea, 0.90, 1, GUI.Anchor.CenterRight, uiText.Title, GUI.Alignment.Left, 1.00, Color(235, 205, 145, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    local close = GUI.Button(CreateRect(0.10, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.ToolTip = uiText.Cancel
    close.OnClicked = function()
        CloseMenu()
        return true
    end

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local hasAdmin = Admin.IsAvailable()
    local listHeight = hasAdmin and 0.845 or 0.91
    local mainTab = nil
    local adminTab = nil

    if hasAdmin then
        local tabs = GUI.Frame(CreateRect(1, 0.06, content, nil), nil)
        tabs.Color = Color(0, 0, 0, 0)
        tabs.CanBeFocused = false
        mainTab = GUI.Button(CreateRect(0.5, 1, tabs, GUI.Anchor.CenterLeft), Admin.GetMainTabText(), GUI.Alignment.Center, "GUITabButton")
        adminTab = GUI.Button(CreateRect(0.5, 1, tabs, GUI.Anchor.CenterRight), Admin.GetAdminTabText(), GUI.Alignment.Center, "GUITabButton")
        SetButtonTextScale(mainTab, 0.82)
        SetButtonTextScale(adminTab, 0.82)
    end

    local listHost = GUI.Frame(CreateRect(1, listHeight, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false

    vtMainListFrame, vtMainList = CreateMenuList(listHost)
    vtMenuList = vtMainList

    local entries = menuEntries or {}
    if #entries == 0 then
        CreateText(vtMainListFrame, 0.90, 0.24, GUI.Anchor.Center, uiText.NoCommands, GUI.Alignment.Center, 0.90, Color(195, 195, 185, 255), true)
    end

    local lastCategory = nil
    for _, entry in ipairs(entries) do
        local category = tostring(entry.Category or "")
        if category ~= "" and category ~= lastCategory then
            if lastCategory ~= nil then CreateDivider(vtMainList.Content) end
            CreateCategoryHeader(vtMainList.Content, category)
            lastCategory = category
        end

        local enabled = entry.Enabled ~= false
        local tooltip = tostring(entry.Hint or "")
        if tostring(entry.InputType or "") ~= "" then
            CreateTextInputRow(vtMainList.Content, entry.Label or entry.Command or uiText.GenericCommand, entry.InputHint or "", entry.Command or "", enabled, tooltip)
        else
            local button = CreateMenuButton(vtMainList.Content, entry.Label or entry.Command or uiText.GenericCommand, enabled)
            button.ToolTip = tooltip
            button.OnClicked = function()
                if tostring(entry.ConfirmText or "") ~= "" then
                    ShowConfirm(entry.ConfirmTitle ~= "" and entry.ConfirmTitle or uiText.DefaultConfirmTitle, entry.ConfirmText, entry.Command)
                else
                    SendCommand(entry.Command)
                end
                return true
            end
        end
    end
    vtMainList.BarScroll = vtMenuScroll
    vtMainList:RecalculateChildren()
    vtMainList:UpdateScrollBarSize()

    local function showMainTab()
        vtActiveTab = "main"
        vtMenuList = vtMainList
        vtMainListFrame.Visible = true
        if vtAdminListFrame ~= nil then vtAdminListFrame.Visible = false end
        if mainTab ~= nil then mainTab.Selected = true end
        if adminTab ~= nil then adminTab.Selected = false end
    end

    local function showAdminTab()
        if vtAdminList == nil then Admin.RefreshData() end
        Admin.WhenDataReady(function()
            if currentMenuKind ~= "vt" then return end
            if vtAdminList == nil then
                vtAdminListFrame, vtAdminList = CreateMenuList(listHost)
                Admin.Build(vtAdminList.Content)
                vtAdminList.BarScroll = vtAdminScroll
                vtAdminList:RecalculateChildren()
                vtAdminList:UpdateScrollBarSize()
            end

            vtActiveTab = "admin"
            vtMenuList = vtAdminList
            vtMainListFrame.Visible = false
            vtAdminListFrame.Visible = true
            mainTab.Selected = false
            adminTab.Selected = true
        end)
    end

    if hasAdmin then
        mainTab.OnClicked = function()
            showMainTab()
            return true
        end
        adminTab.OnClicked = function()
            showAdminTab()
            return true
        end

        if vtActiveTab == "admin" then showAdminTab() else showMainTab() end
    else
        showMainTab()
    end

    AddVoidTraitorResizeHandles(panel)
    SaveVoidTraitorMenuGeometry()
end

local function GetNetLobbyScreen()
    return Game.NetLobbyScreen
end

local function IsLobbyScreenAvailable()
    local screen = GetNetLobbyScreen()
    return screen ~= nil and GUI.Screen.Selected == screen
end

local function GetLobbyGuiFrame()
    local screen = GetNetLobbyScreen()
    if screen == nil then return nil end

    local frame = screen.Frame
    if frame ~= nil and frame.RectTransform ~= nil then return frame end
    return nil
end

local function SafeSetAsLastChild(component)
    if component == nil or component.RectTransform == nil or component.RectTransform.Parent == nil then return end
    component.RectTransform.SetAsLastChild()
end

local function ReadRectValue(rect, key, fallback)
    if rect == nil then return fallback or 0 end
    return tonumber(rect[key]) or fallback or 0
end

local function GetComponentRect(component)
    if component == nil then return nil end
    return component.Rect
end

local function GetLobbyComponent(name)
    local screen = GetNetLobbyScreen()
    return screen ~= nil and screen[name] or nil
end

local function GetLobbyComponentRect(name)
    return GetComponentRect(GetLobbyComponent(name))
end

local function GetVoteButtonParent()
    return GetLobbyGuiFrame()
end

local function GetVoteButtonAnchorRect()
    local subRect = GetLobbyComponentRect("SubList")
    local modeRect = GetLobbyComponentRect("ModeList")
    local anchorRect = subRect or modeRect
    if anchorRect == nil then return nil end

    local x = ReadRectValue(anchorRect, "X", 0)
    local y = ReadRectValue(anchorRect, "Y", 0)
    local width = ReadRectValue(anchorRect, "Width", 0)
    local height = ReadRectValue(anchorRect, "Height", 0)
    if width <= 0 or height <= 0 then return nil end

    local buttonWidth = math.max(SafeIntScale(170), math.min(SafeIntScale(245), math.floor(width * 0.324)))
    local buttonY = y + height + SafeIntScale(6)
    local buttonHeight = SafeIntScale(32)
    local respawnRect = GetComponentRect(GetLobbyComponent("respawnTabButton"))
    if respawnRect ~= nil then
        buttonY = ReadRectValue(respawnRect, "Y", buttonY)
        buttonHeight = ReadRectValue(respawnRect, "Height", buttonHeight)
    end

    return {
        X = x + width - buttonWidth - SafeIntScale(6),
        Y = buttonY,
        Width = buttonWidth,
        Height = buttonHeight,
    }
end
local function GetVoteButtonMetrics()
    local anchor = GetVoteButtonAnchorRect()
    if anchor ~= nil then
        return math.max(1, math.floor(anchor.Width)), math.max(SafeIntScale(22), math.floor(anchor.Height)), SafeIntScale(2)
    end

    return SafeIntScale(190), SafeIntScale(26), SafeIntScale(2)
end

local function GetVoteStartOptionMetrics()
    local width, height, gap = GetVoteButtonMetrics()
    local optionHeight = math.max(SafeIntScale(18), math.floor(height * 0.48))
    return width, optionHeight, SafeIntScale(1), gap
end

local function CreateLobbyAbsoluteRect(x, y, width, height)
    local lobbyFrame = GetLobbyGuiFrame()
    if lobbyFrame == nil or lobbyFrame.RectTransform == nil then return nil end

    local frameRect = GetComponentRect(lobbyFrame)
    local frameX = ReadRectValue(frameRect, "X", 0)
    local frameY = ReadRectValue(frameRect, "Y", 0)

    local rectTransform = GUI.RectTransform(Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))), lobbyFrame.RectTransform, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(math.floor(x - frameX), math.floor(y - frameY))
    return rectTransform
end

local function GetVoteButtonRect(parent)
    local anchor = GetVoteButtonAnchorRect()
    if anchor ~= nil then
        local rect = CreateLobbyAbsoluteRect(anchor.X, anchor.Y, anchor.Width, anchor.Height)
        if rect ~= nil then return rect end
    end

    local width, height = GetVoteButtonMetrics()
    return GUI.RectTransform(Point(width, height), parent ~= nil and parent.RectTransform or nil, GUI.Anchor.TopLeft)
end

local function GetVoteStartPanelRect(parent)
    local width, optionHeight, spacing, gap = GetVoteStartOptionMetrics()

    local buttonRect = GetComponentRect(parent)
    if buttonRect ~= nil then
        local x = ReadRectValue(buttonRect, "X", 0)
        local y = ReadRectValue(buttonRect, "Y", 0) + ReadRectValue(buttonRect, "Height", optionHeight) + gap
        local rect = CreateLobbyAbsoluteRect(x, y, width, optionHeight * 2 + spacing)
        if rect ~= nil then return rect end
    end

    local rectTransform = GUI.RectTransform(Point(width, optionHeight * 2 + spacing), parent ~= nil and parent.RectTransform or nil, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(0, optionHeight + gap)
    return rectTransform
end

local function GetVoteTargetComponent(voteType)
    if tostring(voteType or "") == "map" then
        return GetLobbyComponent("SubList")
    end

    return GetLobbyComponent("ModeList")
end

local function DestroyVoteButton()
    Common.RemoveGuiComponent(voteButtonRoot)
    voteButtonRoot = nil
    voteButtonParent = nil
    sharedState.VoteButtonRoot = nil
end

local function AttachVoteGuiRoot()
    if not IsLobbyScreenAvailable() or guiRoot == nil or guiRoot.RectTransform == nil then return false end

    local lobbyFrame = GetLobbyGuiFrame()
    if lobbyFrame == nil then return false end

    guiRoot:RemoveFromGUIUpdateList(true)
    guiRoot.Visible = true
    guiRoot.RectTransform.Parent = lobbyFrame.RectTransform
    guiRoot.RectTransform.RelativeSize = Vector2(1, 1)
    guiRoot.RectTransform.AbsoluteOffset = Point(0, 0)
    SafeSetAsLastChild(guiRoot)

    return true
end

local function GetVoteProgress(active)
    if active == nil then return 0 end
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local remaining = math.max(0, tonumber(active.Remaining or 0) or 0)
    return math.max(0, math.min(1, remaining / duration))
end

local function GetVoteTimeText(active)
    local remaining = 0
    if active ~= nil then remaining = math.max(0, tonumber(active.Remaining or 0) or 0) end
    return string.format("%s: %s", voteUiText.Timer, tostring(math.floor(remaining)))
end

local CreateVoteButton
local IsWelcomeMenuOpen

local function ShowVoteStartMenu()
    if IsWelcomeMenuOpen ~= nil and IsWelcomeMenuOpen() then return end
    if not IsLobbyScreenAvailable() then return end
    if voteButtonRoot == nil then CreateVoteButton() end
    if voteButtonRoot == nil then return end

    local panel = GUI.Frame(GetVoteStartPanelRect(voteButtonRoot), "GUIFrame")
    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    currentMenu = panel
    currentMenuKind = "votestart"
    sharedState.CurrentMenu = panel
    sharedState.CurrentMenuKind = currentMenuKind
    SafeSetAsLastChild(panel)

    local width, optionHeight, spacing = GetVoteStartOptionMetrics()
    local canStart = voteSnapshot == nil or voteSnapshot.CanStart ~= false

    local modeRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    modeRect.AbsoluteOffset = Point(0, 0)
    local modeButton = GUI.Button(modeRect, voteUiText.StartMode, GUI.Alignment.Center, "GUIButtonSmall")
    modeButton.Enabled = canStart
    SetButtonTextScale(modeButton, 0.70)
    modeButton.OnClicked = function()
        SendVoteStart("game")
        CloseMenu()
        return true
    end

    local mapRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    mapRect.AbsoluteOffset = Point(0, optionHeight + spacing)
    local mapButton = GUI.Button(mapRect, voteUiText.StartMap, GUI.Alignment.Center, "GUIButtonSmall")
    mapButton.Enabled = canStart
    SetButtonTextScale(mapButton, 0.70)
    mapButton.OnClicked = function()
        SendVoteStart("map")
        CloseMenu()
        return true
    end
end

local function GetActiveVoteRemaining(active)
    if active == nil then return 0 end
    if active.LocalEndTime ~= nil then
        return math.max(0, math.ceil((tonumber(active.LocalEndTime) or 0) - GetTime()))
    end
    return math.max(0, tonumber(active.Remaining or 0) or 0)
end

local function FormatVoteOptionLabel(option)
    local selectedPrefix = option.Selected and "✓ " or ""
    return string.format("%s%s — %s %s", selectedPrefix, tostring(option.Text or ""), tostring(option.Votes or 0), voteUiText.Votes)
end

local function CreateVoteOverlayOnComponent(target)
    if target == nil or target.RectTransform == nil then return nil end

    local overlayRect = nil
    if target.RectTransform.Parent ~= nil then
        overlayRect = target.RectTransform.Parent.Rect
    end
    if overlayRect == nil then
        overlayRect = GetComponentRect(target)
    end
    if overlayRect == nil then return nil end

    local x = ReadRectValue(overlayRect, "X", 0)
    local y = ReadRectValue(overlayRect, "Y", 0)
    local width = ReadRectValue(overlayRect, "Width", 0)
    local height = ReadRectValue(overlayRect, "Height", 0)
    if width <= 0 or height <= 0 then return nil end

    -- В NetLobbyScreen верхние блоки режима/подлодки создаются как одинаковые
    -- Stretch-панели внутри mainPanelTopLayout, поэтому активное голосование
    -- выравниваем по фактическим границам этих соседних lobby-блоков, а не по
    -- ручному большому запасу вниз.
    local topY = y
    local bottomY = y + height

    local function includeTopVotePanelBounds(componentName)
        local component = GetLobbyComponent(componentName)
        if component == nil or component.RectTransform == nil then return end

        local siblingRect = nil
        if component.RectTransform.Parent ~= nil then
            siblingRect = component.RectTransform.Parent.Rect
        end
        if siblingRect == nil then return end

        local siblingY = ReadRectValue(siblingRect, "Y", topY)
        local siblingHeight = ReadRectValue(siblingRect, "Height", 0)
        if siblingHeight <= 0 then return end

        topY = math.min(topY, siblingY)
        bottomY = math.max(bottomY, siblingY + siblingHeight)
    end

    includeTopVotePanelBounds("ModeList")
    includeTopVotePanelBounds("SubList")

    y = topY + 1
    height = math.max(1, bottomY - topY)

    -- Ванильный NetLobbyScreen использует PanelSpacing = 0.005f. Берём такой же
    -- масштабируемый небольшой нахлёст только на нижний шов, чтобы не было видно
    -- нижнюю линию родного блока, но без прежнего завышенного SafeIntScale(6).
    local seamCover = math.max(SafeIntScale(2), math.floor(height * 0.005 + 0.5))
    height = height + seamCover

    local rectTransform = CreateLobbyAbsoluteRect(x, y, width, height)
    if rectTransform == nil then return nil end

    local panel = GUI.Frame(rectTransform, "GUIFrame")
    panel.Color = Color(255, 255, 255, 255)
    panel.IgnoreLayoutGroups = true
    return panel
end


local function RefreshActiveVoteUi()
    if currentMenuKind ~= "voteactive" or activeVoteUi == nil then return end
    local active = voteSnapshot and voteSnapshot.Active or nil
    if active == nil then return end

    local remaining = GetActiveVoteRemaining(active)
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local progress = math.max(0, math.min(1, remaining / duration))

    if activeVoteUi.TimerText ~= nil then
        activeVoteUi.TimerText.Text = string.format("%s: %s", voteUiText.Timer, tostring(math.floor(remaining)))
    end
    if activeVoteUi.ProgressFill ~= nil and activeVoteUi.ProgressFill.RectTransform ~= nil then
        activeVoteUi.ProgressFill.RectTransform.RelativeSize = Vector2(progress, 1)
    end

    local buttons = activeVoteUi.OptionButtons or {}
    for _, option in ipairs(active.Options or {}) do
        local button = buttons[option.Index]
        if button ~= nil and button.TextBlock ~= nil then
            button.TextBlock.Text = FormatVoteOptionLabel(option)
        end
    end
end

local function ShowActiveVoteMenu()
    if IsWelcomeMenuOpen ~= nil and IsWelcomeMenuOpen() then return end

    local active = voteSnapshot and voteSnapshot.Active or nil
    if active == nil then
        ShowVoteStartMenu()
        return
    end

    if not IsLobbyScreenAvailable() then return end

    local target = GetVoteTargetComponent(active.Type)
    local panel = CreateVoteOverlayOnComponent(target)
    if panel == nil then
        if not AttachVoteGuiRoot() then return end
        panel = GUI.Frame(CreateRect(0.36, 0.30, guiRoot, GUI.Anchor.Center), "GUIFrame")
        panel.Color = Color(255, 255, 255, 255)
    end

    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    currentMenu = panel
    currentMenuKind = "voteactive"
    sharedState.CurrentMenu = panel
    sharedState.CurrentMenuKind = currentMenuKind
    SafeSetAsLastChild(panel)

    activeVoteUi = { Panel = panel, ActiveId = tostring(active.Id or ""), OptionButtons = {} }

    local content = GUI.LayoutGroup(CreateRect(0.985, 0.985, panel, GUI.Anchor.Center), false, GUI.Anchor.TopCenter)
    content.Stretch = true
    content.RelativeSpacing = 0.008

    local header = GUI.LayoutGroup(CreateRect(1, 0.10, content, nil), true, GUI.Anchor.CenterLeft)
    header.Stretch = true
    header.RelativeSpacing = 0.012

    local title = CreateText(header, 0.70, 1, nil, active.Title or voteUiText.StartTitle, GUI.Alignment.Left, 0.95, Color(255, 235, 170, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    activeVoteUi.TimerText = CreateText(header, 0.30, 1, nil, GetVoteTimeText(active), GUI.Alignment.CenterRight, 1.125, Color(210, 220, 200, 255), false)

    local progressFrame = GUI.Frame(CreateRect(1, 0.035, content, nil), "GUIFrame")
    progressFrame.Color = Color(25, 35, 30, 230)
    activeVoteUi.ProgressFill = GUI.Frame(CreateRect(GetVoteProgress(active), 1, progressFrame, GUI.Anchor.CenterLeft), nil)
    activeVoteUi.ProgressFill.Color = Color(120, 170, 130, 230)

    local listArea = GUI.Frame(CreateRect(1, 0.855, content, nil), nil)
    listArea.Color = Color(0, 0, 0, 0)
    listArea.CanBeFocused = false

    -- Слои списка не должны перекрашивать ванильную рамку.
    -- Чёрный фон лежит под GUIFrameListBox, сама зелёная рамка остаётся родной,
    -- а ListBox внутри прозрачный и только держит кнопки вариантов.
    local listBackground = GUI.Frame(CreateRect(0.984, 0.944, listArea, GUI.Anchor.Center), nil)
    listBackground.Color = Color(0, 0, 0, 255)
    listBackground.CanBeFocused = false

    local listFrame = GUI.Frame(CreateRect(1, 1, listArea, GUI.Anchor.Center), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(0.984, 0.944, listFrame, GUI.Anchor.Center), false, Color(0, 0, 0, 0), nil)
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then
        list.ContentBackground.Color = Color(0, 0, 0, 0)
    end
    list.KeepSpaceForScrollBar = false

    for _, option in ipairs(active.Options or {}) do
        local label = FormatVoteOptionLabel(option)
        local button = GUI.Button(CreateRect(1, 0.105, list.Content, nil), label, GUI.Alignment.Center, "GUIButtonSmall")
        SetButtonTextScale(button, 0.73)
        activeVoteUi.OptionButtons[option.Index] = button
        button.OnClicked = function()
            SendVoteCast(option.Index)
            if voteSnapshot ~= nil and voteSnapshot.Active ~= nil then
                for _, localOption in ipairs(voteSnapshot.Active.Options or {}) do
                    localOption.Selected = localOption.Index == option.Index
                end
                RefreshActiveVoteUi()
            end
            return true
        end
    end

    RefreshActiveVoteUi()
end

CreateVoteButton = function()
    DestroyVoteButton()

    if not IsLobbyScreenAvailable() then return end

    local parent = GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then return end

    local root = GUI.Frame(GetVoteButtonRect(parent), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = true
    root.IgnoreLayoutGroups = true
    voteButtonRoot = root
    voteButtonParent = parent
    sharedState.VoteButtonRoot = voteButtonRoot

    SafeSetAsLastChild(root)

    local button = GUI.Button(CreateRect(1, 1, root, GUI.Anchor.Center), voteUiText.Button, GUI.Alignment.Center, "GUITabButton")
    button.CanBeFocused = true
    button.ToolTip = voteUiText.Tooltip
    SetButtonTextScale(button, 1.0)
    button.OnClicked = function()
        if currentMenuKind == "votestart" then
            CloseMenu()
            return true
        end
        RequestVoteSnapshot(true)
        return true
    end
end

IsWelcomeMenuOpen = function()
    local welcomeRoot = rawget(_G, "VoidTraitorWelcomeMenuRoot")
    if welcomeRoot == nil or welcomeRoot.RectTransform == nil then
        return rawget(_G, "VoidTraitorWelcomeMenuOpen") == true
    end

    local hasParent = welcomeRoot.RectTransform.Parent ~= nil
    if not hasParent then _G.VoidTraitorWelcomeMenuOpen = false end
    return hasParent
end

local function EnsureVoteButton()
    if sharedState.Disabled then return end

    if IsWelcomeMenuOpen() then
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
        return
    end

    if not IsLobbyScreenAvailable() then
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
        return
    end

    local parent = GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then
        DestroyVoteButton()
        return
    end

    local width, height = GetScreenSize()
    if voteButtonRoot == nil or voteButtonParent ~= parent or width ~= lastVoteButtonResolutionX or height ~= lastVoteButtonResolutionY then
        lastVoteButtonResolutionX = width
        lastVoteButtonResolutionY = height
        CreateVoteButton()
    end
end

sharedState.EnsureVoteButton = EnsureVoteButton

local function CreateTopButtons()
    if buttonRoot ~= nil then
        Common.RemoveGuiComponent(buttonRoot)
        buttonRoot = nil
    end

    local buttonWidth, buttonHeight = GetTopButtonSize()
    local padding = GetTopButtonSpacing()

    local root = GUI.LayoutGroup(CreateButtonAreaRect(buttonWidth, buttonHeight, 2, padding), true, GUI.Anchor.CenterLeft)
    root.AbsoluteSpacing = padding
    root.Stretch = false
    root.CanBeFocused = true
    buttonRoot = root
    sharedState.ButtonRoot = buttonRoot

    local shop = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), uiText.ShopButton, GUI.Alignment.Center, "GUIButtonSmall")
    shop.CanBeFocused = true
    shop.ToolTip = uiText.ShopTooltip
    SetButtonTextScale(shop, 0.74)
    shop.OnClicked = function(button, userData)
        if currentMenu ~= nil then CloseMenu() end
        SendNetMessage(NET_POINTSHOP_REQUEST)
        return true
    end

    local vt = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), uiText.MainButton, GUI.Alignment.Center, "GUIButtonSmall")
    vt.CanBeFocused = true
    vt.ToolTip = uiText.MainTooltip
    SetButtonTextScale(vt, 0.88)
    vt.OnClicked = function(button, userData)
        if currentMenu ~= nil then
            CloseMenu()
        else
            RequestMenuSnapshot(true)
        end
        return true
    end

end

local function EnsureTopButtons()
    if sharedState.Disabled then return end

    local width, height = GetScreenSize()
    if buttonRoot == nil or width ~= lastResolutionX or height ~= lastResolutionY then
        lastResolutionX = width
        lastResolutionY = height
        CreateTopButtons()
    end
end

sharedState.EnsureTopButtons = EnsureTopButtons

Networking.Receive(NET_SNAPSHOT, function(message)
    if sharedState.Disabled then return end

    uiText.Title = message.ReadString()
    uiText.ShopButton = message.ReadString()
    uiText.MainButton = message.ReadString()
    uiText.ShopTooltip = message.ReadString()
    uiText.MainTooltip = message.ReadString()
    uiText.NoCommands = message.ReadString()
    uiText.GenericCommand = message.ReadString()
    uiText.DefaultConfirmTitle = message.ReadString()
    uiText.Cancel = message.ReadString()
    uiText.Yes = message.ReadString()
    uiText.Ok = message.ReadString()
    local count = message.ReadInt32()
    local entries = {}
    for i = 1, count do
        local command = message.ReadString()
        local enabled = true
        if string.sub(command, 1, #DISABLED_ACTION_PREFIX) == DISABLED_ACTION_PREFIX then
            command = string.sub(command, #DISABLED_ACTION_PREFIX + 1)
            enabled = false
        end

        table.insert(entries, {
            Command = command,
            Label = message.ReadString(),
            Hint = message.ReadString(),
            Category = message.ReadString(),
            InputType = message.ReadString(),
            InputHint = message.ReadString(),
            ConfirmTitle = message.ReadString(),
            ConfirmText = message.ReadString(),
            Enabled = enabled,
        })
    end

    menuEntries = entries
    if buttonRoot ~= nil then
        CreateTopButtons()
    end
    if pendingMenuOpen then
        pendingMenuOpen = false
        ShowVoidTraitorMenu()
    end
end)

Networking.Receive(NET_VOTE_SNAPSHOT, function(message)
    if sharedState.Disabled then return end

    voteUiText.Button = message.ReadString()
    voteUiText.Tooltip = message.ReadString()
    voteUiText.StartTitle = message.ReadString()
    voteUiText.StartMode = message.ReadString()
    voteUiText.StartMap = message.ReadString()
    voteUiText.StartBlockedReason = message.ReadString()
    voteUiText.Close = message.ReadString()
    voteUiText.NoActive = message.ReadString()
    voteUiText.StartedBy = message.ReadString()
    voteUiText.Timer = message.ReadString()
    voteUiText.Votes = message.ReadString()

    local canStart = message.ReadBoolean()
    local hasActive = message.ReadBoolean()
    local snapshot = { CanStart = canStart, Active = nil }

    if hasActive then
        local active = {
            Id = message.ReadString(),
            Type = message.ReadString(),
            Title = message.ReadString(),
            StartedBy = message.ReadString(),
            Remaining = message.ReadInt32(),
            Duration = message.ReadInt32(),
            Options = {},
        }
        active.LocalEndTime = GetTime() + math.max(0, tonumber(active.Remaining or 0) or 0)

        local count = message.ReadInt32()
        for i = 1, count do
            table.insert(active.Options, {
                Index = message.ReadInt32(),
                Text = message.ReadString(),
                Votes = message.ReadInt32(),
                Selected = message.ReadBoolean(),
            })
        end

        snapshot.Active = active
        if active.Id ~= "" and active.Id ~= lastActiveVoteId then
            lastActiveVoteId = active.Id
            PlayVoteSound()
        end
    else
        lastActiveVoteId = ""
        lastShownActiveVoteId = ""
    end

    voteSnapshot = snapshot

    if voteButtonRoot ~= nil and IsLobbyScreenAvailable() and currentMenuKind ~= "votestart" and currentMenuKind ~= "voteactive" then
        CreateVoteButton()
    end

    if pendingVoteMenuOpen then
        pendingVoteMenuOpen = false
        if currentMenu ~= nil then CloseMenu() end
        if voteSnapshot.Active ~= nil then
            lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
            ShowActiveVoteMenu()
        else
            ShowVoteStartMenu()
        end
    elseif currentMenu ~= nil and currentMenuKind == "voteactive" then
        if voteSnapshot.Active == nil then
            CloseMenu()
        elseif activeVoteUi ~= nil and tostring(voteSnapshot.Active.Id or "") == tostring(activeVoteUi.ActiveId or "") then
            RefreshActiveVoteUi()
        else
            CloseMenu()
            lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
            ShowActiveVoteMenu()
        end
    elseif currentMenu ~= nil and currentMenuKind == "votestart" and voteSnapshot.Active ~= nil then
        CloseMenu()
        lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
        ShowActiveVoteMenu()
    elseif voteSnapshot.Active ~= nil and tostring(voteSnapshot.Active.Id or "") ~= "" and tostring(voteSnapshot.Active.Id or "") ~= lastShownActiveVoteId then
        lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
        ShowActiveVoteMenu()
    end
end)

SendReady()
SendVoteReady()
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 2000)
Timer.Wait(function() if not sharedState.Disabled then SendVoteReady() end end, 2500)
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 6000)
Timer.Wait(function() if not sharedState.Disabled then SendVoteReady() end end, 6500)

Hook.Patch(HUD_PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state == nil or state.Disabled then return end
    if GUI.DisableHUD then return end

    if state.GuiRoot ~= nil then
        state.GuiRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
    end
    if state.ButtonRoot == nil and state.EnsureTopButtons ~= nil then
        state.EnsureTopButtons()
    end
    if state.ButtonRoot ~= nil then
        state.ButtonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER)
    end
end)

Hook.Patch(PAUSE_PATCH_ID, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, params)
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
        if state.CurrentMenuKind == "voteactive" and state.BlockPauseMenu ~= true then
            return
        end
        if state.CurrentMenu ~= nil and state.CloseMenu ~= nil then
            state.CloseMenu()
        end
        if params ~= nil then params.PreventExecution = true end
        return false
    end
end, Hook.HookMethodType.Before)

Hook.Remove("think", "VoidTraitor.ClientMenu.KeepPauseBlocked")

Hook.Add("keyUpdate", "VoidTraitor.ClientMenu.PauseGuard", function()
    if sharedState.Disabled then return end
    if currentMenu ~= nil and PlayerInput.KeyHit(Keys.Escape) then
        RequestEscapeClose()
    end
end)

Hook.Add("think", "VoidTraitor.ClientMenu.UiState", function(deltaTime)
    if sharedState.Disabled then return end

    UpdateVoidTraitorMenuInteraction()

    uiStateCheckTimer = uiStateCheckTimer + (tonumber(deltaTime) or 0)
    if uiStateCheckTimer < 0.1 then return end
    uiStateCheckTimer = 0

    EnsureTopButtons()

    if IsLobbyScreenAvailable() then
        EnsureVoteButton()
        RefreshActiveVoteUi()
    else
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
    end
end)
