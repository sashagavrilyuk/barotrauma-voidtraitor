if SERVER then return end

local packPath, Common = ...
local NET_SUMMARY = "VoidTraitor_RoundSummary"
local STATE_KEY = "VoidTraitorRoundSummaryState"
local HUD_PATCH_ID = "VoidTraitor.RoundSummary.Hud"

local previousState = rawget(_G, STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
end

local state = { Disabled = false }
_G[STATE_KEY] = state

local currentMenu = nil
local summaryList = nil
local resizeTargets = {}
local resizeState = nil
local menuX = nil
local menuY = nil
local menuWidth = nil
local menuHeight = nil

local DEFAULT_WIDTH_PIXELS = 450
local DEFAULT_HEIGHT_PIXELS = 630
local MIN_WIDTH_PIXELS = 370
local MIN_HEIGHT_PIXELS = 370
local MENU_DRAW_ORDER = 124

local SafeIntScale = Common.SafeIntScale
local GetScreenSize = Common.GetScreenSize
local CreateRect = Common.CreateRect
local CreateCanvasRect = Common.CreateCanvasRect
local Clamp = Common.Clamp

local function saveGeometry()
    if currentMenu == nil then return end
    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuWidth = currentMenu.Rect.Width
    menuHeight = currentMenu.Rect.Height
end

local function closeSummary()
    saveGeometry()
    resizeTargets = {}
    resizeState = nil
    summaryList = nil

    if currentMenu ~= nil then
        Common.RemoveGuiComponent(currentMenu)
        currentMenu = nil
    end

    state.MenuRoot = nil
end

state.CloseMenu = closeSummary

local function addResizeTarget(panel, edge, width, height, anchor)
    local target = GUI.Frame(CreateRect(width, height, panel, anchor), nil)
    target.Color = Color(0, 0, 0, 0)
    target.CanBeFocused = false
    table.insert(resizeTargets, { Component = target, Edge = edge })
end

local function addResizeHandles(panel)
    resizeTargets = {}

    addResizeTarget(panel, "top-left", 0.05, 0.05, GUI.Anchor.TopLeft)
    addResizeTarget(panel, "top-right", 0.05, 0.05, GUI.Anchor.TopRight)
    addResizeTarget(panel, "bottom-left", 0.05, 0.05, GUI.Anchor.BottomLeft)
    addResizeTarget(panel, "bottom-right", 0.05, 0.05, GUI.Anchor.BottomRight)

    addResizeTarget(panel, "top", 0.90, 0.025, GUI.Anchor.TopCenter)
    addResizeTarget(panel, "bottom", 0.90, 0.025, GUI.Anchor.BottomCenter)
    addResizeTarget(panel, "left", 0.025, 0.90, GUI.Anchor.CenterLeft)
    addResizeTarget(panel, "right", 0.025, 0.90, GUI.Anchor.CenterRight)

    local topIndicator = GUI.Image(CreateRect(0.18, 0.018, panel, GUI.Anchor.TopCenter), "GUIDragIndicatorHorizontal")
    topIndicator.CanBeFocused = false
    local bottomIndicator = GUI.Image(CreateRect(0.18, 0.018, panel, GUI.Anchor.BottomCenter), "GUIDragIndicatorHorizontal")
    bottomIndicator.CanBeFocused = false
    local leftIndicator = GUI.Image(CreateRect(0.018, 0.18, panel, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    leftIndicator.CanBeFocused = false
    local rightIndicator = GUI.Image(CreateRect(0.018, 0.18, panel, GUI.Anchor.CenterRight), "GUIDragIndicator")
    rightIndicator.CanBeFocused = false
end

local function getResizeEdge()
    local mousePosition = PlayerInput.MousePosition
    for _, target in ipairs(resizeTargets) do
        if target.Component ~= nil and target.Component.Rect.Contains(mousePosition) then
            return target.Edge
        end
    end
    return nil
end

local function updateResize()
    if currentMenu == nil then
        resizeState = nil
        return
    end

    local mouseDown = PlayerInput.PrimaryMouseButtonDown()
    local mouseHeld = PlayerInput.PrimaryMouseButtonHeld()

    if mouseDown and resizeState == nil then
        local edge = getResizeEdge()
        if edge ~= nil then
            local rectTransform = currentMenu.RectTransform
            resizeState = {
                Edge = edge,
                MouseX = PlayerInput.MousePosition.X,
                MouseY = PlayerInput.MousePosition.Y,
                Left = currentMenu.Rect.X,
                Top = currentMenu.Rect.Y,
                Right = currentMenu.Rect.Right,
                Bottom = currentMenu.Rect.Bottom,
                ScreenOffsetX = rectTransform.ScreenSpaceOffset.X,
                ScreenOffsetY = rectTransform.ScreenSpaceOffset.Y,
            }
        end
    end

    if not mouseHeld then
        resizeState = nil
        return
    end
    if resizeState == nil then return end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumWidth = SafeIntScale(MIN_WIDTH_PIXELS)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local dx = PlayerInput.MousePosition.X - resizeState.MouseX
    local dy = PlayerInput.MousePosition.Y - resizeState.MouseY

    local left = resizeState.Left
    local right = resizeState.Right
    local top = resizeState.Top
    local bottom = resizeState.Bottom
    local edge = resizeState.Edge

    if string.find(edge, "left", 1, true) ~= nil then
        left = Clamp(resizeState.Left + dx, margin, resizeState.Right - minimumWidth)
    elseif string.find(edge, "right", 1, true) ~= nil then
        right = Clamp(resizeState.Right + dx, resizeState.Left + minimumWidth, screenWidth - margin)
    end

    if string.find(edge, "top", 1, true) ~= nil then
        top = Clamp(resizeState.Top + dy, margin, resizeState.Bottom - minimumHeight)
    elseif string.find(edge, "bottom", 1, true) ~= nil then
        bottom = Clamp(resizeState.Bottom + dy, resizeState.Top + minimumHeight, screenHeight - margin)
    end

    local rectTransform = currentMenu.RectTransform
    local scaleX = rectTransform.Scale.X
    local scaleY = rectTransform.Scale.Y
    local width = right - left
    local height = bottom - top
    rectTransform:Resize(Point(
        math.max(1, math.floor(width / scaleX + 0.5)),
        math.max(1, math.floor(height / scaleY + 0.5))
    ), true)
    rectTransform.ScreenSpaceOffset = Point(
        resizeState.ScreenOffsetX + (left - resizeState.Left),
        resizeState.ScreenOffsetY + (top - resizeState.Top)
    )

    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuWidth = currentMenu.Rect.Width
    menuHeight = currentMenu.Rect.Height

    if summaryList ~= nil then
        summaryList:RecalculateChildren()
        summaryList:UpdateScrollBarSize()
    end
end

local function showSummary(summary, closeText)
    closeSummary()

    summary = tostring(summary or "")
    if summary == "" then return end

    local title = summary
    local body = ""
    local lineBreak = string.find(summary, "\n", 1, true)
    if lineBreak ~= nil then
        title = string.sub(summary, 1, lineBreak - 1)
        body = string.sub(summary, lineBreak + 1)
    end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumWidth = SafeIntScale(MIN_WIDTH_PIXELS)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local maximumWidth = math.max(minimumWidth, screenWidth - margin * 2)
    local maximumHeight = math.max(minimumHeight, screenHeight - margin * 2)
    local width = Clamp(menuWidth or SafeIntScale(DEFAULT_WIDTH_PIXELS), minimumWidth, maximumWidth)
    local height = Clamp(menuHeight or SafeIntScale(DEFAULT_HEIGHT_PIXELS), minimumHeight, maximumHeight)
    local x = menuX or math.floor((screenWidth - width) / 2)
    local y = menuY or math.floor((screenHeight - height) / 2)
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))

    local menuRect = CreateCanvasRect(x, y, width, height)
    if menuRect == nil then return end

    currentMenu = GUI.Frame(menuRect, nil)
    currentMenu.Color = Color(0, 0, 0, 0)
    currentMenu.CanBeFocused = false
    currentMenu.IgnoreLayoutGroups = true
    state.MenuRoot = currentMenu

    local panel = GUI.Frame(CreateRect(1, 1, currentMenu, GUI.Anchor.Center), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.004

    local header = GUI.Frame(CreateRect(1, 0.07, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.90, 1, header, GUI.Anchor.TopLeft), currentMenu.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.045, 0.70, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false

    local headerText = Common.CreateText(dragArea, 0.94, 1, GUI.Anchor.CenterRight, title, GUI.Alignment.Left, 1.15, Color(235, 205, 145, 255), false)
    headerText.Font = GUI.Style.SubHeadingFont
    headerText.CanBeFocused = false

    local close = GUI.Button(CreateRect(0.075, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.ToolTip = closeText or "Close"
    close.OnClicked = function()
        closeSummary()
        return true
    end

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local listFrame = GUI.Frame(CreateRect(1, 0.90, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    summaryList = GUI.ListBox(CreateRect(0.985, 0.975, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    summaryList.CanBeFocused = false
    summaryList.Color = Color(0, 0, 0, 0)
    if summaryList.ContentBackground ~= nil then summaryList.ContentBackground.Color = Color(0, 0, 0, 0) end
    summaryList.KeepSpaceForScrollBar = true

    local bodyText = Common.CreateText(summaryList.Content, 0.975, 0.20, GUI.Anchor.TopLeft, body, GUI.Alignment.TopLeft, 1.25, Color(220, 220, 210, 255), true)
    bodyText.CanBeFocused = false
    bodyText.CalculateHeightFromText()
    summaryList:RecalculateChildren()
    summaryList:UpdateScrollBarSize()

    addResizeHandles(panel)
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
end

Common.InstallHudPatch(HUD_PATCH_ID, STATE_KEY, MENU_DRAW_ORDER, MENU_DRAW_ORDER)

Networking.Receive(NET_SUMMARY, function(message)
    showSummary(message.ReadString(), message.ReadString())
end)

Hook.Add("think", "VoidTraitor.RoundSummary.Think", function()
    if state.Disabled then return end
    updateResize()
end)

Hook.Add("roundEnd", "VoidTraitor.RoundSummary.RoundEnd", closeSummary)
Hook.Add("roundStart", "VoidTraitor.RoundSummary.RoundStart", closeSummary)
