if SERVER then return end

local Common = select(2, ...)

local NET_READY = "VoidTraitor_CameraTeleportGuiReady"
local NET_REQUEST = "VoidTraitor_CameraTeleportRequest"
local NET_SNAPSHOT = "VoidTraitor_CameraTeleportSnapshot"

local GLOBAL_STATE_KEY = "VoidTraitorCameraTeleportGuiState"
local GHOST_STATE_KEY = "VoidTraitorGhostRolesGuiState"
local HUD_PATCH_ID = "VoidTraitor.CameraTeleportGui.Hud"
local PAUSE_PATCH_ID = "VoidTraitor.CameraTeleportGui.Pause"

local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end

    for _, key in ipairs({ "MenuRoot", "ButtonRoot" }) do
        Common.RemoveGuiComponent(previousState[key])
    end
end

local sharedState = { Disabled = false }
_G[GLOBAL_STATE_KEY] = sharedState

local buttonRoot = nil
local bottomButton = nil
local currentMenu = nil
local canUse = false
local targets = {}
local targetById = {}
local targetSignature = ""
local targetList = nil
local targetListScroll = 0
local resizeTopTargets = {}
local resizeBottomTargets = {}
local resizeState = nil
local menuX = nil
local menuY = nil
local menuHeight = nil
local lastLocalCandidate = nil
local lastRoundStarted = nil
local lastConnected = nil
local lastResolutionX = -1
local lastResolutionY = -1
local nextRefreshTime = 0
local stateCheckTimer = 0

local text = {
    Title = "CAMERA TELEPORT",
    Button = "Camera teleport",
    Player = "Player",
    Follow = "Follow",
    Close = "Close",
    Empty = "There are no players with a living controlled character right now.",
}

local MENU_DRAW_ORDER = 122
local BUTTON_DRAW_ORDER = 121
local MENU_WIDTH_PIXELS = 370
local DEFAULT_HEIGHT_PIXELS = 420
local MIN_HEIGHT_PIXELS = 320
local ROW_HEIGHT_PIXELS = 70
local ICON_PIXELS = 40
local BOTTOM_BUTTON_TEXT_SCALE = 0.90
local BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS = 22
local BOTTOM_BUTTON_GAP_PIXELS = 6
local BOTTOM_BUTTON_Y_PIXELS = 18

local SafeIntScale = Common.SafeIntScale
local GetScreenSize = Common.GetScreenSize
local CreateRect = Common.CreateRect
local CreateCanvasRect = Common.CreateCanvasRect
local Clamp = Common.Clamp

local function SendReady()
    local message = Networking.Start(NET_READY)
    Networking.Send(message)
end

local function RequestSnapshot(openMenu)
    local message = Networking.Start(NET_REQUEST)
    message.WriteBoolean(openMenu == true)
    Networking.Send(message)
end

local CreateText = Common.CreateText

local function SaveMenuGeometry()
    if currentMenu == nil then return end
    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuHeight = currentMenu.Rect.Height
    if targetList ~= nil then targetListScroll = targetList.BarScroll end
end

local function CloseMenu()
    if currentMenu == nil then return end

    SaveMenuGeometry()
    Common.RemoveGuiComponent(currentMenu)
    currentMenu = nil
    targetList = nil
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil
    sharedState.CurrentMenu = nil
    sharedState.MenuRoot = nil
end

sharedState.CloseMenu = CloseMenu

local function DestroyBottomButton()
    if buttonRoot == nil then return end
    Common.RemoveGuiComponent(buttonRoot)
    buttonRoot = nil
    bottomButton = nil
    sharedState.ButtonRoot = nil
end

local ShouldShowBottomButton = Common.ShouldShowBottomButton

local function ResizeBottomButtonToText()
    Common.ResizeButtonToText(bottomButton, BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS, 32)
end

local function UpdateBottomButtonPosition()
    if bottomButton == nil then return end

    local ghostState = rawget(_G, GHOST_STATE_KEY)
    local ghostWidth = 0
    if ghostState ~= nil and ghostState.GetButtonWidth ~= nil then
        ghostWidth = tonumber(ghostState.GetButtonWidth()) or 0
    end

    local width = bottomButton.Rect.Width
    local offsetX = -math.floor((ghostWidth + width) / 2 + SafeIntScale(BOTTOM_BUTTON_GAP_PIXELS))
    bottomButton.RectTransform.AbsoluteOffset = Point(offsetX, SafeIntScale(BOTTOM_BUTTON_Y_PIXELS))
end

local function CreateBottomButton()
    DestroyBottomButton()

    local canvas = GUI.Canvas.Instance
    local rectTransform = GUI.RectTransform(Point(SafeIntScale(180), SafeIntScale(32)), canvas, GUI.Anchor.BottomCenter)
    bottomButton = GUI.Button(rectTransform, text.Button, GUI.Alignment.Center, "GUIButtonSmall")
    bottomButton.CanBeFocused = true

    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end
    UpdateBottomButtonPosition()

    bottomButton.OnClicked = function()
        RequestSnapshot(true)
        return true
    end

    buttonRoot = bottomButton
    sharedState.ButtonRoot = buttonRoot
    buttonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER)
end

local function EnsureBottomButton()
    if sharedState.Disabled or not ShouldShowBottomButton() then return end
    if buttonRoot == nil then CreateBottomButton() end
    UpdateBottomButtonPosition()
end

sharedState.EnsureBottomButton = EnsureBottomButton

local function UpdateBottomButton()
    if not ShouldShowBottomButton() then
        if buttonRoot ~= nil then buttonRoot.Visible = false end
        return
    end

    EnsureBottomButton()
    if bottomButton == nil then return end
    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.Text = text.Button
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end
    UpdateBottomButtonPosition()
    buttonRoot.Visible = not GUI.DisableHUD
end

local function StartFollow(target)
    local ghostState = rawget(_G, GHOST_STATE_KEY)
    if ghostState == nil or ghostState.StartFollow == nil then
        error("VoidTraitor CameraTeleport: GhostRoles camera follow controller is unavailable.")
    end

    ghostState.StartFollow(
        target.CharacterId,
        Vector2(tonumber(target.WorldX) or 0, tonumber(target.WorldY) or 0)
    )
end

local function CreateTargetRow(list, target)
    local row = GUI.Frame(CreateRect(1, 0.12, list.Content, GUI.Anchor.TopLeft), nil)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false
    local rowHeight = SafeIntScale(ROW_HEIGHT_PIXELS)
    row.RectTransform.MinSize = Point(0, rowHeight)
    row.RectTransform.MaxSize = Point(100000, rowHeight)

    local selectButton = GUI.Button(CreateRect(1, 1, row, GUI.Anchor.TopCenter), "", GUI.Alignment.Center, "ListBoxElement")
    if selectButton.TextBlock ~= nil then selectButton.TextBlock.Text = "" end

    local iconHolder = GUI.Frame(CreateRect(0.18, 0.88, selectButton, GUI.Anchor.CenterLeft), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    Common.CreateIcon(iconHolder, target, ICON_PIXELS)

    local content = GUI.Frame(CreateRect(0.78, 0.86, selectButton, GUI.Anchor.CenterRight), nil)
    content.Color = Color(0, 0, 0, 0)
    content.CanBeFocused = false

    local name = CreateText(content, 1, 0.52, GUI.Anchor.TopLeft, tostring(target.CharacterName or ""), GUI.Alignment.Left, 0.88, Color(235, 225, 190, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    CreateText(content, 1, 0.40, GUI.Anchor.BottomLeft, text.Player .. ": " .. tostring(target.PlayerName or ""), GUI.Alignment.Left, 1.28, Color(145, 205, 145, 255), false)

    local targetId = target.CharacterId
    selectButton.OnClicked = function()
        local currentTarget = targetById[targetId]
        if currentTarget ~= nil then
            StartFollow(currentTarget)
            CloseMenu()
            UpdateBottomButton()
        end
        return true
    end
end

local function BuildPanel(root)
    local panel = GUI.Frame(CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.003

    local header = GUI.Frame(CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.84, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.07, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = CreateText(dragArea, 0.90, 1, GUI.Anchor.CenterRight, text.Title, GUI.Alignment.Left, 1.00, Color(235, 205, 145, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    local close = GUI.Button(CreateRect(0.10, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.OnClicked = function()
        CloseMenu()
        UpdateBottomButton()
        return true
    end
    close.ToolTip = text.Close

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local listFrame = GUI.Frame(CreateRect(1, 0.91, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    if #targets == 0 then
        CreateText(listFrame, 0.90, 0.24, GUI.Anchor.Center, text.Empty, GUI.Alignment.Center, 0.88, Color(195, 195, 185, 255), true)
        targetList = nil
    else
        targetList = GUI.ListBox(CreateRect(1, 0.985, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
        targetList.Color = Color(0, 0, 0, 0)
        targetList.ContentBackground.Color = Color(0, 0, 0, 0)
        targetList.KeepSpaceForScrollBar = true

        for _, target in ipairs(targets) do CreateTargetRow(targetList, target) end
        targetList.BarScroll = targetListScroll
        targetList:RecalculateChildren()
        targetList:UpdateScrollBarSize()
    end

    Common.AddResizeHandles(panel, resizeTopTargets, resizeBottomTargets)
end

local function ShowMenu()
    if not canUse then
        CloseMenu()
        UpdateBottomButton()
        return
    end

    CloseMenu()

    local width = SafeIntScale(MENU_WIDTH_PIXELS)
    local height = menuHeight or SafeIntScale(DEFAULT_HEIGHT_PIXELS)
    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local maximumHeight = math.max(minimumHeight, screenHeight - (margin * 2))
    height = Clamp(height, minimumHeight, maximumHeight)
    menuHeight = height

    local x = menuX
    local y = menuY
    if x == nil then x = math.floor((screenWidth - width) / 2) end
    if y == nil then y = math.floor((screenHeight - height) / 2) end
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))
    menuX = x
    menuY = y

    currentMenu = GUI.Frame(CreateCanvasRect(x, y, width, height), nil)
    currentMenu.Color = Color(0, 0, 0, 0)
    currentMenu.CanBeFocused = false
    currentMenu.IgnoreLayoutGroups = true
    sharedState.CurrentMenu = currentMenu
    sharedState.MenuRoot = currentMenu

    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil

    BuildPanel(currentMenu)
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
    UpdateBottomButton()
end

local function ReadSnapshot(message)
    nextRefreshTime = Timer.GetTime() + 1
    local openMenu = message.ReadBoolean()
    canUse = message.ReadBoolean()

    local newTargets = {}
    local newTargetById = {}
    local signatureParts = {}
    local count = message.ReadInt32()
    for _ = 1, count do
        local target = {
            CharacterId = message.ReadInt32(),
            CharacterName = message.ReadString(),
            PlayerName = message.ReadString(),
            WorldX = message.ReadSingle(),
            WorldY = message.ReadSingle(),
            Icon = message.ReadString(),
        }
        table.insert(newTargets, target)
        newTargetById[target.CharacterId] = target
        table.insert(signatureParts, tostring(target.CharacterId) .. ":" .. tostring(target.CharacterName) .. ":" .. tostring(target.PlayerName) .. ":" .. tostring(target.Icon))
    end

    local newSignature = table.concat(signatureParts, "|")
    local listChanged = newSignature ~= targetSignature
    targets = newTargets
    targetById = newTargetById
    targetSignature = newSignature

    local textCount = message.ReadInt32()
    for _ = 1, textCount do
        local key = message.ReadString()
        local value = message.ReadString()
        if key ~= nil and key ~= "" then text[key] = value or "" end
    end

    UpdateBottomButton()

    if not canUse then
        CloseMenu()
    elseif openMenu or (currentMenu ~= nil and listChanged) then
        ShowMenu()
    end
end

local IsLocalCandidate = Common.IsLocalCandidate
local IsRoundStarted = Common.IsRoundStarted
local IsConnected = Common.IsConnected

local function UpdateMenuInteraction()
    resizeState, menuX, menuY, menuHeight = Common.UpdateMenuInteraction(
        currentMenu, resizeState, resizeTopTargets, resizeBottomTargets,
        MIN_HEIGHT_PIXELS, targetList, menuX, menuY, menuHeight
    )
end

Common.InstallHudPatch(HUD_PATCH_ID, GLOBAL_STATE_KEY, MENU_DRAW_ORDER, BUTTON_DRAW_ORDER)
Common.InstallPausePatch(PAUSE_PATCH_ID, GLOBAL_STATE_KEY)

Hook.Add("think", "VoidTraitor.CameraTeleportGui.Think", function(deltaTime)
    if sharedState.Disabled then return end

    UpdateMenuInteraction()

    stateCheckTimer = stateCheckTimer + (tonumber(deltaTime) or 0)
    if stateCheckTimer < 0.1 then return end
    stateCheckTimer = 0

    local width, height = GetScreenSize()
    if width ~= lastResolutionX or height ~= lastResolutionY then
        lastResolutionX = width
        lastResolutionY = height
        DestroyBottomButton()
        if currentMenu ~= nil then ShowMenu() end
    end

    local refreshNeeded = false
    local candidate = IsLocalCandidate()
    if candidate ~= lastLocalCandidate then
        lastLocalCandidate = candidate
        refreshNeeded = true
    end

    local roundStarted = IsRoundStarted()
    if roundStarted ~= lastRoundStarted then
        lastRoundStarted = roundStarted
        refreshNeeded = true
    end

    local connected = IsConnected()
    if connected ~= lastConnected then
        lastConnected = connected
        if connected then
            refreshNeeded = true
        else
            CloseMenu()
        end
    end

    if refreshNeeded and connected then SendReady() end

    local showBottomButton = ShouldShowBottomButton()
    if showBottomButton then EnsureBottomButton() end
    if buttonRoot ~= nil then
        buttonRoot.Visible = showBottomButton and not GUI.DisableHUD
        UpdateBottomButtonPosition()
    end

    if currentMenu ~= nil and connected then
        local now = Timer.GetTime()
        if now >= nextRefreshTime then
            nextRefreshTime = now + 1
            RequestSnapshot(false)
        end
    end
end)

Networking.Receive(NET_SNAPSHOT, function(message)
    if sharedState.Disabled then return end
    ReadSnapshot(message)
end)

UpdateBottomButton()
SendReady()
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 2000)
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 6000)
