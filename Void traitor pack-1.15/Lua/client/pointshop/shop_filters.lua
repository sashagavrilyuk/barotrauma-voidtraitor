local P = ...
local S = P.State

function P.GetSelectedFilterLabel()
    if S.selectedFilter == "available" then return P.GetText("FilterAvailable") end
    if S.selectedFilter == "affordable" then return P.GetText("FilterAffordable") end
    return P.GetText("FilterAll")
end

P.CloseFilterPopup = function()
    if S.filterPopup == nil then return end
    if S.filterButton ~= nil then S.filterButton.Selected = false end
    P.Common.RemoveGuiComponent(S.filterPopup)
    S.filterPopup = nil
end

function P.ToggleFilterPopup(button)
    if S.filterPopup ~= nil then
        P.CloseFilterPopup()
        return
    end
    if S.currentMenu == nil or button == nil then return end

    -- The popup goes into the menu itself, not the filter button's layout,
    -- otherwise the product list (added later) is drawn over it.
    local menuWidth = math.max(S.currentMenu.Rect.Width, 1)
    local menuHeight = math.max(S.currentMenu.Rect.Height, 1)
    local popupWidth = math.max(button.Rect.Width, 1)
    local popupHeight = math.max(button.Rect.Height * 3, 3)
    local popupRect = GUI.RectTransform(
        -- RectTransform rounds relative sizes down to whole pixels; the extra 0.25
        -- keeps the popup from ending up 1 px narrower than the button.
        Vector2((popupWidth + 0.25) / menuWidth, (popupHeight + 0.25) / menuHeight),
        S.currentMenu.RectTransform,
        GUI.Anchor.TopLeft,
        GUI.Pivot.TopLeft
    )
    popupRect.ScreenSpaceOffset = Point(
        button.Rect.X - S.currentMenu.Rect.X,
        button.Rect.Bottom - S.currentMenu.Rect.Y + 1
    )

    -- Same frame as the vanilla drop-down list, but a plain layout instead of a GUIListBox,
    -- which would reserve space for a scrollbar even when all three entries fit.
    local popup = GUI.Frame(popupRect, "GUIFrameListBox")
    popup.IgnoreLayoutGroups = true
    popup.CanBeFocused = true
    GUI.Style.Apply(popup, "GUIListBox", button)
    S.filterPopup = popup
    button.Selected = true

    local options = GUI.LayoutGroup(P.CreateRect(0.98, 0.96, popup, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    options.Stretch = true
    options.RelativeSpacing = 0

    local entries = {
        { Value = "all", Label = P.GetText("FilterAll") },
        { Value = "available", Label = P.GetText("FilterAvailable") },
        { Value = "affordable", Label = P.GetText("FilterAffordable") },
    }
    for _, entry in ipairs(entries) do
        local optionValue = entry.Value
        local optionLabel = entry.Label
        local option = GUI.Button(P.CreateRect(1, 0.333, options, nil), "", GUI.Alignment.CenterLeft, "ListBoxElement")
        P.SetButtonStyle(option, true, S.selectedFilter == optionValue)
        -- the GUITextBlock style already has a 10 px padding, so no extra inset here
        local optionText = P.CreateText(option, 1, 1, GUI.Anchor.Center, optionLabel, GUI.Alignment.CenterLeft, 0.96, Color(235, 225, 180, 255), false)
        optionText.CanBeFocused = false
        option.OnClicked = function()
            S.selectedFilter = optionValue
            if S.filterButton ~= nil then
                S.filterButton.Text = P.GetSelectedFilterLabel()
            end
            P.CloseFilterPopup()
            if S.rebuildProductList ~= nil then S.rebuildProductList() end
            return true
        end
    end

    -- Keep the popup above the product list in both draw and input order.
    popup:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER + 60)
end

-- A heading line above the drop-down and the text box.
function P.GetFilterBarHeight()
    return P.Common.GetTextHeight(GUI.Style.SubHeadingFont) + P.Common.GetGap()
        + math.max(P.Common.GetStyleHeight("GUIDropDown"), P.Common.GetStyleHeight("GUITextBox"))
end

local function CreateFilterGroup(bar, width, label)
    local group = P.CreateLayout(bar, width, 1, nil, false, GUI.Anchor.TopLeft)
    group.RelativeSpacing = 0
    group.AbsoluteSpacing = P.Common.GetGap()
    local text = P.CreateText(group, 1, 1, nil, label, GUI.Alignment.BottomLeft, 1, Color(235, 225, 180, 255), false)
    text.Font = GUI.Style.SubHeadingFont
    text.AutoScaleHorizontal = true
    P.Common.FitHeightToText(text)
    return group
end

function P.BuildFilterBar(parent)
    local bar = P.CreateLayout(parent, 1, 1, nil, true, GUI.Anchor.TopLeft)
    P.Common.SetFixedHeight(bar, P.GetFilterBarHeight())
    bar.RelativeSpacing = 0.018

    local filterGroup = CreateFilterGroup(bar, 0.40, P.GetText("Filter"))
    S.filterButton = GUI.Button(P.CreateRect(1, 1, filterGroup, nil), P.GetSelectedFilterLabel(), GUI.Alignment.CenterLeft, "GUIDropDown")
    P.SetButtonStyle(S.filterButton, true, false)
    S.filterButton.ForceUpperCase = P.ForceUpperCase.No
    S.filterButton.TextBlock.TextScale = 0.98
    -- DropDownIcon is a child style of GUIDropDown: passing its name to GUI.Image logs an error,
    -- so it is applied through GUI.Style.Apply instead.
    local dropDownIcon = GUI.Image(P.CreateRect(0.12, 0.58, S.filterButton, GUI.Anchor.CenterRight), nil, true)
    GUI.Style.Apply(dropDownIcon, "DropDownIcon", S.filterButton)
    dropDownIcon.CanBeFocused = false
    dropDownIcon.IgnoreLayoutGroups = true
    dropDownIcon.RectTransform.AbsoluteOffset = Point(5, 0)
    S.filterButton.OnClicked = function(button)
        P.ToggleFilterPopup(button)
        return true
    end

    local searchGroup = CreateFilterGroup(bar, 0.60, P.GetText("Search"))
    local searchBox = GUI.TextBox(P.CreateRect(1, 1, searchGroup, nil), S.searchText)
    searchBox.OnTextChangedDelegate = function(_, value)
        P.CloseFilterPopup()
        S.searchText = tostring(value or "")
        S.normalizedSearchText = P.NormalizeSearchText(S.searchText)
        if S.rebuildProductList ~= nil then S.rebuildProductList() end
        return true
    end
end
