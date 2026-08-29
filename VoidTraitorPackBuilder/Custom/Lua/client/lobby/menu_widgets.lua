local P = ...
local S = P.State

function P.SetButtonTextScale(button, scale)
    if button == nil or button.TextBlock == nil then return end
    button.TextBlock.TextScale = scale
    button.TextBlock.AutoScaleHorizontal = true
end


function P.CreateMenuButton(parent, label, enabled)
    local button = GUI.Button(P.CreateRect(1, 0.10, parent, nil), label or "", GUI.Alignment.Center, "GUIButton")
    P.SetFixedHeight(button, P.VT_BUTTON_HEIGHT_PIXELS)
    button.Enabled = enabled ~= false
    P.SetButtonTextScale(button, 0.92)
    return button
end

function P.CreateDivider(parent)
    local frame = GUI.Frame(P.CreateRect(1, 0.02, parent, nil), nil)
    P.SetFixedHeight(frame, P.VT_DIVIDER_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)
    GUI.Image(P.CreateRect(1, 0.50, frame, GUI.Anchor.Center), "HorizontalLine")
end

function P.CreateCategoryHeader(parent, label)
    local frame = GUI.Frame(P.CreateRect(1, 0.06, parent, nil), nil)
    P.SetFixedHeight(frame, P.VT_CATEGORY_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)

    local text = P.CreateText(frame, 1, 0.82, GUI.Anchor.BottomLeft, string.upper(tostring(label or "")), GUI.Alignment.Left, 0.88, Color(205, 220, 200, 255), false)
    text.Font = GUI.Style.SubHeadingFont
    return frame
end

function P.CreateTextInputRow(parent, label, placeholder, action, enabled, tooltip)
    local isEnabled = enabled ~= false
    local labelBlock = P.CreateText(parent, 1, 0.05, nil, label, GUI.Alignment.Left, 0.86, Color(210, 220, 200, 255), false)
    P.SetFixedHeight(labelBlock, P.VT_INPUT_LABEL_HEIGHT_PIXELS)
    labelBlock.Font = GUI.Style.SubHeadingFont
    labelBlock.ToolTip = tooltip or ""

    local row = GUI.LayoutGroup(P.CreateRect(1, 0.09, parent, nil), true, GUI.Anchor.CenterLeft)
    P.SetFixedHeight(row, P.VT_INPUT_ROW_HEIGHT_PIXELS)
    row.Stretch = true
    row.RelativeSpacing = 0.010

    local input = GUI.TextBox(P.CreateRect(0.66, 1, row, nil), placeholder or "")
    input.Enabled = isEnabled
    input.ToolTip = tooltip or ""
    if input.TextBlock ~= nil then input.TextBlock.TextScale = 0.86 end

    local sendButton = GUI.Button(P.CreateRect(0.32, 1, row, nil), P.UiText.Ok, GUI.Alignment.Center, "GUIButton")
    sendButton.Enabled = isEnabled
    sendButton.ToolTip = tooltip or ""
    P.SetButtonTextScale(sendButton, 0.90)
    sendButton.OnClicked = function()
        local value = input.Text or ""
        P.SendCommand(action, value)
        input.Text = ""
        return true
    end

    return input
end

function P.CreateMenuList(parent)
    local frame = GUI.Frame(P.CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    frame.CanBeFocused = false

    local list = GUI.ListBox(P.CreateRect(1, 0.985, frame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then list.ContentBackground.Color = Color(0, 0, 0, 0) end
    list.KeepSpaceForScrollBar = true
    local sidePadding = P.SafeIntScale(P.VT_LIST_SIDE_PADDING_PIXELS)
    local scrollBarWidth = math.max(0, list.ScrollBar.Rect.Width)
    list.Padding = Vector4(scrollBarWidth + sidePadding, 0, sidePadding, 0)
    list:UpdateDimensions()
    return frame, list
end

P.Admin = assert(loadfile(P.PackPath .. "/Lua/client/lobby/admin.lua"))(P.Common, {
    CreateRect = P.CreateRect,
    SetFixedHeight = P.SetFixedHeight,
    SetButtonTextScale = P.SetButtonTextScale,
    CreateMenuButton = P.CreateMenuButton,
    CreateDivider = P.CreateDivider,
    CreateCategoryHeader = P.CreateCategoryHeader,
    GetOkText = function() return P.UiText.Ok end,
})

P.Admin.OnAvailabilityChanged = function()
    if S.currentMenuKind ~= "vt" then
        if not P.Admin.IsAvailable() then S.vtActiveTab = "main" end
        return
    end

    P.CloseMenu()
    if not P.Admin.IsAvailable() then S.vtActiveTab = "main" end
    P.ShowVoidTraitorMenu()
end

function P.AddVoidTraitorResizeHandles(panel)
    S.vtResizeTopTargets = {}
    S.vtResizeBottomTargets = {}
    P.Common.AddResizeHandles(panel, S.vtResizeTopTargets, S.vtResizeBottomTargets)
end

function P.UpdateVoidTraitorMenuInteraction()
    if S.currentMenu == nil or S.currentMenuKind ~= "vt" then
        S.vtResizeState = nil
        return
    end

    S.vtResizeState, S.vtMenuX, S.vtMenuY, S.vtMenuHeight = P.Common.UpdateMenuInteraction(
        S.currentMenu,
        S.vtResizeState,
        S.vtResizeTopTargets,
        S.vtResizeBottomTargets,
        P.VT_MENU_MIN_HEIGHT_PIXELS,
        S.vtMenuList,
        S.vtMenuX,
        S.vtMenuY,
        S.vtMenuHeight
    )
end
