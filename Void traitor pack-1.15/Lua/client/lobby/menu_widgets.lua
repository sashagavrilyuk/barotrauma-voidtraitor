local P = ...
local S = P.State

function P.SetButtonTextScale(button, scale)
    if button == nil or button.TextBlock == nil then return end
    P.Common.SetAutoScaleText(button.TextBlock, scale)
end


function P.CreateMenuButton(parent, label, enabled)
    local button = P.Common.CreateButton(parent, 1, label)
    button.Enabled = enabled ~= false
    return button
end

P.CreateDivider = P.Common.CreateDivider

function P.CreateCategoryHeader(parent, label)
    local text = P.CreateText(parent, 1, 1, nil, string.upper(tostring(label or "")), GUI.Alignment.BottomLeft, 0.88, Color(205, 220, 200, 255), false)
    text.Font = GUI.Style.SubHeadingFont
    P.Common.FitHeightToText(text)
    return text
end

-- Vanilla text boxes have no placeholder: like the lobby's submarine filter, a text block lies over the box while it
-- is empty. onChanged, if given, also gets each new text.
function P.SetTextBoxHint(input, hintText, onChanged)
    local hint = P.CreateText(input, 1, 1, nil, hintText, GUI.Alignment.CenterLeft, 0.86, Color(140, 150, 140, 255), false)
    hint.Padding = input.TextBlock.Padding
    hint.CanBeFocused = false
    hint.Visible = input.Text == ""
    input.OnTextChangedDelegate = function(_, value)
        hint.Visible = value == ""
        if onChanged ~= nil then onChanged(value) end
        return true
    end
end

-- A command that takes a value: the box, with its hint while it is empty, and the command's button beside it, which
-- hands the value to onSubmit and clears the box. Returns the box and the button.
function P.CreateTextInputRow(parent, label, placeholder, onSubmit, enabled, tooltip)
    local isEnabled = enabled ~= false
    local row = GUI.LayoutGroup(P.CreateRect(1, 1, parent, nil), true, GUI.Anchor.CenterLeft)
    P.Common.SetFixedHeight(row, P.Common.GetStyleHeight("GUIButton"))
    row.Stretch = true
    row.AbsoluteSpacing = P.Common.GetButtonSpacing()

    local input = GUI.TextBox(P.CreateRect(1, 1, row, nil), "")
    input.Enabled = isEnabled
    input.ToolTip = tooltip or ""
    if input.TextBlock ~= nil then input.TextBlock.TextScale = 0.86 end
    P.SetTextBoxHint(input, placeholder or "")

    local sendButton = P.Common.CreateButton(row, 1, label)
    sendButton.Enabled = isEnabled
    sendButton.ToolTip = tooltip or ""
    sendButton.OnClicked = function()
        onSubmit(input.Text or "")
        input.Text = ""
        return true
    end

    return input, sendButton
end

-- A button for an action that can't be undone, red like the nuclear console's arm button (station/nuclear.lua).
function P.SetDangerButton(button)
    button.Color, button.HoverColor, button.PressedColor = Color(200, 70, 70, 255), Color(235, 100, 100, 255), Color(160, 50, 50, 255)
end

-- Buttons in rows of `columns`; a short last row keeps the width of the other rows' cells.
-- Each item has a Label, a ToolTip, Enabled and OnClicked, which gets the button.
function P.CreateButtonGrid(parent, columns, items)
    local buttons = {}
    for first = 1, #items, columns do
        local row = GUI.LayoutGroup(P.CreateRect(1, 1, parent, nil), true, GUI.Anchor.CenterLeft)
        P.Common.SetFixedHeight(row, P.Common.GetStyleHeight("GUIButton"))
        row.Stretch = true
        row.AbsoluteSpacing = P.Common.GetButtonSpacing()
        row.CanBeFocused = false
        for index = first, first + columns - 1 do
            local item = items[index]
            if item == nil then
                local cell = GUI.Frame(P.CreateRect(1, 1, row, nil), nil)
                cell.Color = Color(0, 0, 0, 0)
                cell.CanBeFocused = false
            else
                local button = P.CreateMenuButton(row, item.Label, item.Enabled)
                button.ToolTip = item.ToolTip or ""
                button.OnClicked = function()
                    item.OnClicked(button)
                    return true
                end
                buttons[index] = button
            end
        end
    end
    return buttons
end

function P.CreateMenuList(parent)
    local frame = GUI.Frame(P.CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    frame.CanBeFocused = false

    local list = GUI.ListBox(P.CreateRect(1, 0.985, frame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then list.ContentBackground.Color = Color(0, 0, 0, 0) end
    list.KeepSpaceForScrollBar = true
    list.Spacing = P.Common.GetButtonSpacing()
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
    CreateMenuList = P.CreateMenuList,
    CreateButtonGrid = P.CreateButtonGrid,
    CreateTextInputRow = P.CreateTextInputRow,
    SetTextBoxHint = P.SetTextBoxHint,
    SetDangerButton = P.SetDangerButton,
    ShowEvents = function(tab) P.ShowEventsWindow(tab) end,
    ShowRoleTimes = function(key) P.ShowRoleTimesWindow(key) end,
})

P.Admin.OnAvailabilityChanged = function()
    if S.currentMenuKind ~= "vt" then
        if not P.Admin.IsAvailable() then
            S.vtActiveTab = "main"
            if S.currentMenuKind == "events" then P.CloseMenu() end
        end
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

function P.GetVoidTraitorMenuMinHeight()
    return P.SafeIntScale(S.vtActiveTab == "admin" and P.VT_ADMIN_MENU_MIN_HEIGHT_PIXELS or P.VT_MENU_MIN_HEIGHT_PIXELS)
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
        P.GetVoidTraitorMenuMinHeight(),
        S.vtMenuList,
        S.vtMenuX,
        S.vtMenuY,
        S.vtMenuHeight
    )
end
