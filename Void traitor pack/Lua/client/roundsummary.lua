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
local resizeTopTargets = {}
local resizeBottomTargets = {}
local resizeSideTargets = {}
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
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeSideTargets = {}
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
    if edge == "top" then
        table.insert(resizeTopTargets, target)
    elseif edge == "bottom" then
        table.insert(resizeBottomTargets, target)
    elseif edge == "left" or edge == "right" then
        table.insert(resizeSideTargets[edge], target)
    else
        table.insert(resizeSideTargets.corners, { Handle = target, Edge = edge })
    end
end

local function addResizeHandles(panel)
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeSideTargets = { left = {}, right = {}, corners = {}, minimumWidth = MIN_WIDTH_PIXELS }

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

local function updateResize()
    resizeState, menuX, menuY, menuHeight = Common.UpdateMenuInteraction(currentMenu,
        resizeState, resizeTopTargets, resizeBottomTargets, MIN_HEIGHT_PIXELS,
        summaryList, menuX, menuY, menuHeight, resizeSideTargets)
    if currentMenu ~= nil then menuWidth = currentMenu.Rect.Width end
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

    Common.CreateWindowHeader(content, currentMenu, title, closeText or "Close", function()
        closeSummary()
        return true
    end, { height = 0.07, dragWidth = 0.90, indicatorWidth = 0.045,
        indicatorHeight = 0.70, titleWidth = 0.94, titleScale = 1.15,
        titleNoFocus = true, closeWidth = 0.075 })

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
    bodyText.SetRichText(body)
    bodyText.CalculateHeightFromText()
    summaryList:RecalculateChildren()
    summaryList:UpdateScrollBarSize()

    addResizeHandles(panel)
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
end

Common.InstallHudPatch(HUD_PATCH_ID, STATE_KEY, MENU_DRAW_ORDER, MENU_DRAW_ORDER)

Networking.Receive(NET_SUMMARY, function(message)
    showSummary(message.ReadString(), Common.Language.Common.Close)
end)

Hook.Add("think", "VoidTraitor.RoundSummary.Think", function()
    if state.Disabled then return end
    updateResize()
end)

Hook.Add("roundEnd", "VoidTraitor.RoundSummary.RoundEnd", closeSummary)
Hook.Add("roundStart", "VoidTraitor.RoundSummary.RoundStart", closeSummary)
