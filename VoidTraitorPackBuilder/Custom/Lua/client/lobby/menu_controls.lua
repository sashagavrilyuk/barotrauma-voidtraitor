local P = ...
local S = P.State

function P.ShowConfirm(title, text, action)
    P.SaveVoidTraitorMenuGeometry()
    P.Common.RemoveGuiComponent(S.currentMenu)

    local overlay = GUI.Frame(P.CreateRect(1, 1, S.guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 110)
    overlay.CanBeFocused = true
    overlay.IgnoreLayoutGroups = true
    S.currentMenu = overlay
    S.currentMenuKind = "confirm"
    S.sharedState.CurrentMenu = overlay
    S.sharedState.CurrentMenuKind = S.currentMenuKind

    local box = GUI.Frame(P.CreateRect(0.20, 0.165, overlay, GUI.Anchor.Center), "GUIFrame")
    box.CanBeFocused = true

    local titleBlock = P.CreateText(box, 0.90, 0.22, GUI.Anchor.TopCenter, title, GUI.Alignment.Center, 1.02, Color(255, 235, 170, 255), false)
    titleBlock.RectTransform.AbsoluteOffset = Point(0, P.SafeIntScale(8))
    titleBlock.Font = GUI.Style.LargeFont
    P.CreateText(box, 0.86, 0.30, GUI.Anchor.Center, text, GUI.Alignment.Center, 1.08, Color(230, 230, 220, 255), true)

    local buttons = GUI.Frame(P.CreateRect(0.76, 0.20, box, GUI.Anchor.BottomCenter), nil)
    buttons.RectTransform.AbsoluteOffset = Point(0, P.SafeIntScale(18))
    buttons.Color = Color(0, 0, 0, 0)
    buttons.CanBeFocused = false

    local cancel = GUI.Button(P.CreateRect(0.47, 1, buttons, GUI.Anchor.CenterLeft), P.UiText.Cancel, GUI.Alignment.Center, "GUIButton")
    P.SetButtonTextScale(cancel, 1.00)
    cancel.OnClicked = function()
        P.CloseMenu()
        return true
    end

    local confirm = GUI.Button(P.CreateRect(0.47, 1, buttons, GUI.Anchor.CenterRight), P.UiText.Yes, GUI.Alignment.Center, "GUIButton")
    P.SetButtonTextScale(confirm, 1.00)
    confirm.OnClicked = function()
        P.SendCommand(action)
        P.CloseMenu()
        return true
    end
end


function P.CreateTopButtons()
    if S.buttonRoot ~= nil then
        P.Common.RemoveGuiComponent(S.buttonRoot)
        S.buttonRoot = nil
    end

    local buttonWidth, buttonHeight = P.GetTopButtonSize()
    local padding = P.GetTopButtonSpacing()

    local root = GUI.LayoutGroup(P.CreateButtonAreaRect(buttonWidth, buttonHeight, 2, padding), true, GUI.Anchor.CenterLeft)
    root.AbsoluteSpacing = padding
    root.Stretch = false
    root.CanBeFocused = true
    S.buttonRoot = root
    S.sharedState.ButtonRoot = S.buttonRoot

    local shop = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), P.UiText.ShopButton, GUI.Alignment.Center, "GUIButtonSmall")
    shop.CanBeFocused = true
    shop.ToolTip = P.UiText.ShopTooltip
    P.SetButtonTextScale(shop, 0.74)
    shop.OnClicked = function(button, userData)
        if S.currentMenu ~= nil then P.CloseMenu() end
        P.SendNetMessage(P.NET_POINTSHOP_REQUEST)
        return true
    end

    local vt = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), P.UiText.MainButton, GUI.Alignment.Center, "GUIButtonSmall")
    vt.CanBeFocused = true
    vt.ToolTip = P.UiText.MainTooltip
    P.SetButtonTextScale(vt, 0.88)
    vt.OnClicked = function(button, userData)
        if S.currentMenu ~= nil then
            P.CloseMenu()
        else
            P.RequestMenuSnapshot(true)
        end
        return true
    end

end

function P.EnsureTopButtons()
    if S.sharedState.Disabled then return end

    local width, height = P.GetScreenSize()
    if S.buttonRoot == nil or width ~= S.lastResolutionX or height ~= S.lastResolutionY then
        S.lastResolutionX = width
        S.lastResolutionY = height
        P.CreateTopButtons()
    end
end

S.sharedState.EnsureTopButtons = P.EnsureTopButtons
