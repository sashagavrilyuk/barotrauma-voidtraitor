local P = ...
local S = P.State

-- onClosed runs after either answer, e.g. to bring back the window the question came from
function P.ShowConfirm(title, text, onConfirm, onClosed)
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

    -- the box gets the height of its rows: the title, the wrapped question and the buttons
    local screenWidth, screenHeight = P.GetScreenSize()
    local box = GUI.Frame(P.CreatePixelRect(math.min(P.SafeIntScale(460), screenWidth * 0.9), P.SafeIntScale(200), overlay, GUI.Anchor.Center), "GUIFrame")
    box.CanBeFocused = true
    local content, frame = P.Common.CreateWindowContent(box)

    local titleBlock = P.CreateText(content, 1, 1, nil, title, GUI.Alignment.Center, 1, Color(255, 235, 170, 255), false)
    titleBlock.Font = GUI.Style.LargeFont
    P.Common.FitHeightToText(titleBlock)
    local question = P.CreateText(content, 1, 1, nil, text, GUI.Alignment.Center, 1, Color(230, 230, 220, 255), true)
    question.CalculateHeightFromText()
    P.Common.SetFixedHeight(question, question.Rect.Height)

    local buttons = GUI.LayoutGroup(P.CreateRect(1, 1, content, nil), true, GUI.Anchor.CenterLeft)
    P.Common.SetFixedHeight(buttons, P.Common.GetStyleHeight("GUIButton"))
    buttons.Stretch = true
    buttons.AbsoluteSpacing = P.Common.GetGap()

    local cancel = P.Common.CreateButton(buttons, 0.5, P.UiText.Cancel)
    cancel.OnClicked = function()
        P.CloseMenu()
        if onClosed ~= nil then onClosed() end
        return true
    end

    local confirm = P.Common.CreateButton(buttons, 0.5, P.UiText.Yes)
    confirm.OnClicked = function()
        onConfirm()
        P.CloseMenu()
        if onClosed ~= nil then onClosed() end
        return true
    end

    box.RectTransform:Resize(Point(box.Rect.Width, math.min(P.Common.GetMinimumHeight(frame), screenHeight)), true)
end


function P.CreateTopButtons()
    if S.buttonRoot ~= nil then
        P.Common.RemoveGuiComponent(S.buttonRoot)
        S.buttonRoot = nil
    end

    local buttonWidth, buttonHeight = P.GetTopButtonSize()
    local padding = P.GetTopButtonSpacing()

    -- Labels take the same share of the button height at every resolution.
    local labelScale = buttonHeight * 0.5 / GUI.Style.Font.LineHeight
    local root = GUI.LayoutGroup(P.CreateButtonAreaRect(buttonWidth, S.shopAvailable == false and 1 or 2, padding), true, GUI.Anchor.CenterLeft)
    root.AbsoluteSpacing = padding
    root.Stretch = false
    root.CanBeFocused = true
    S.buttonRoot = root
    S.sharedState.ButtonRoot = S.buttonRoot

    if S.shopAvailable ~= false then
        local shop = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), P.UiText.ShopButton, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
        shop.CanBeFocused = true
        shop.ToolTip = P.UiText.ShopTooltip
        P.SetButtonTextScale(shop, labelScale)
        shop.OnClicked = function(button, userData)
            if S.currentMenu ~= nil then P.CloseMenu() end
            P.SendNetMessage(P.NET_POINTSHOP_REQUEST)
            return true
        end
    end

    local vt = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), P.UiText.MainButton, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    vt.CanBeFocused = true
    vt.ToolTip = P.UiText.MainTooltip
    P.SetButtonTextScale(vt, labelScale)
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
