if SERVER then return end

local packPath, Common = ...
local P = { PackPath = packPath, Common = Common, State = {} }
local S = P.State

-- Void Traitor quick menu.
-- Client-side buttons only. Every action is validated and executed on the server.

P.NET_READY = "VoidTraitor_ClientMenuGuiReady"
P.NET_REQUEST = "VoidTraitor_ClientMenuRequest"
P.NET_SNAPSHOT = "VoidTraitor_ClientMenuSnapshot"
P.NET_RUN = "VoidTraitor_ClientMenuRun"
P.NET_POINTSHOP_REQUEST = "VoidTraitor_PointshopRequest"

P.DISABLED_ACTION_PREFIX = "__vt_disabled__:"

P.GLOBAL_STATE_KEY = "VoidTraitorClientMenuState"
P.HUD_PATCH_ID = "VoidTraitor.ClientMenu.Hud"
P.PAUSE_PATCH_ID = "VoidTraitor.ClientMenu.Pause"

local previousState = rawget(_G, P.GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
    Common.RemoveGuiComponent(previousState.ButtonRoot)
    Common.RemoveGuiComponent(previousState.VoteButtonRoot)
    Common.RemoveGuiComponent(previousState.GuiRoot)
end

S.sharedState = { Disabled = false }
_G[P.GLOBAL_STATE_KEY] = S.sharedState

S.buttonRoot = nil
S.guiRoot = nil
S.currentMenu = nil
S.currentMenuKind = ""
S.lastResolutionX = -1
S.lastResolutionY = -1
S.escapeClosePending = false
S.menuEntries = nil
S.vtActiveTab = "main"
S.pendingMenuOpen = false
S.uiStateCheckTimer = 0
S.vtMenuList = nil
S.vtMainList = nil
S.vtAdminList = nil
S.vtMainListFrame = nil
S.vtAdminListFrame = nil
S.vtMenuScroll = 0
S.vtAdminScroll = 0
S.vtMenuX = nil
S.vtMenuY = nil
S.vtMenuHeight = nil
S.vtResizeTopTargets = {}
S.vtResizeBottomTargets = {}
S.vtResizeState = nil
P.UiText = {
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



P.BUTTON_DRAW_ORDER = 100
P.MENU_DRAW_ORDER = 125
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.NetLobbyScreen"], "respawnTabButton")
P.VT_MENU_WIDTH_PIXELS = 370
P.VT_MENU_DEFAULT_HEIGHT_PIXELS = 580
P.VT_MENU_MIN_HEIGHT_PIXELS = 340
P.VT_MENU_MARGIN_PIXELS = 0
P.VT_BUTTON_HEIGHT_PIXELS = 36
P.VT_CATEGORY_HEIGHT_PIXELS = 30
P.VT_DIVIDER_HEIGHT_PIXELS = 10
P.VT_INPUT_LABEL_HEIGHT_PIXELS = 24
P.VT_INPUT_ROW_HEIGHT_PIXELS = 40
P.VT_LIST_SIDE_PADDING_PIXELS = 6

P.SafeIntScale = Common.SafeIntScale
P.GetScreenSize = Common.GetScreenSize
P.Clamp = Common.Clamp

P.CreateRect = Common.CreateRect

function P.CreatePixelRect(width, height, parent, anchor)
    return GUI.RectTransform(
        Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))),
        parent ~= nil and parent.RectTransform or nil,
        anchor
    )
end

function P.SetFixedHeight(component, pixels)
    if component == nil or component.RectTransform == nil then return end
    local height = P.SafeIntScale(pixels)
    component.RectTransform.MinSize = Point(0, height)
    component.RectTransform.MaxSize = Point(100000, height)
end

S.guiRoot = GUI.Frame(P.CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
S.guiRoot.Color = Color(0, 0, 0, 0)
S.guiRoot.CanBeFocused = false
S.guiRoot.IgnoreLayoutGroups = true
S.sharedState.GuiRoot = S.guiRoot
S.guiRoot:AddToGUIUpdateList(false, P.MENU_DRAW_ORDER)

function P.CreateButtonAreaRect(buttonWidth, buttonHeight, buttonCount, padding)
    buttonCount = buttonCount or 2
    padding = padding or P.SafeIntScale(11)

    local rectTransform = GUI.RectTransform(Point((buttonWidth * buttonCount) + padding, buttonHeight), nil, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(P.SafeIntScale(11) + ((buttonWidth + padding) * 3), P.SafeIntScale(11))
    return rectTransform
end

function P.GetTopButtonSize()
    local buttonHeight = P.SafeIntScale(40)
    return math.floor(buttonHeight * 1.72), buttonHeight
end

function P.GetTopButtonSpacing()
    return P.SafeIntScale(11)
end

function P.SendNetMessage(identifier, writer)
    local msg = Networking.Start(identifier)
    if writer ~= nil then writer(msg) end
    Networking.Send(msg)
end

function P.GetTime()
    return Timer.GetTime()
end

function P.SendReady()
    P.SendNetMessage(P.NET_READY)
    if P.Admin ~= nil then P.Admin.RequestMetadata() end
end

function P.SendCommand(command, input)
    P.SendNetMessage(P.NET_RUN, function(msg)
        msg.WriteString(command or "")
        msg.WriteString(tostring(input or ""))
    end)
end

function P.RequestMenuSnapshot(openAfterResponse)
    S.pendingMenuOpen = openAfterResponse == true
    P.SendNetMessage(P.NET_REQUEST)
    P.Admin.RequestMetadata()
end





function P.SaveVoidTraitorMenuGeometry()
    if S.currentMenu == nil or S.currentMenuKind ~= "vt" then return end

    local rect = S.currentMenu.Rect
    S.vtMenuX = rect.X
    S.vtMenuY = rect.Y
    S.vtMenuHeight = rect.Height
    if S.vtMainList ~= nil then S.vtMenuScroll = S.vtMainList.BarScroll end
    if S.vtAdminList ~= nil then S.vtAdminScroll = S.vtAdminList.BarScroll end
end

P.CloseMenu = function()
    P.SaveVoidTraitorMenuGeometry()

    Common.RemoveGuiComponent(S.currentMenu)

    S.currentMenu = nil
    S.currentMenuKind = ""
    S.activeVoteUi = nil
    S.vtMenuList = nil
    S.vtMainList = nil
    S.vtAdminList = nil
    S.vtMainListFrame = nil
    S.vtAdminListFrame = nil
    S.vtResizeTopTargets = {}
    S.vtResizeBottomTargets = {}
    S.vtResizeState = nil
    if P.Admin ~= nil then P.Admin.ClearView() end
    S.sharedState.CurrentMenu = nil
    S.sharedState.CurrentMenuKind = ""
    S.escapeClosePending = false
end

S.sharedState.CloseMenu = P.CloseMenu

function P.RequestEscapeClose()
    if S.currentMenu == nil or S.escapeClosePending then return end

    if S.currentMenuKind == "voteactive" then
        return
    end

    S.escapeClosePending = true
    S.sharedState.BlockPauseMenu = true
    P.CloseMenu()
    Timer.Wait(function()
        S.sharedState.BlockPauseMenu = false
    end, 250)
end

P.CreateText = Common.CreateText


return P
