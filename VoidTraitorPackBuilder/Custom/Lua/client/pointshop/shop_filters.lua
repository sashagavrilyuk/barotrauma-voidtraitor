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

    -- Keep the exact screen geometry of the button, but make the popup the last
    -- child of the menu overlay. If it stays inside the filter button's layout
    -- branch, the product list is added later and gets drawn over the options.
    local menuWidth = math.max(S.currentMenu.Rect.Width, 1)
    local menuHeight = math.max(S.currentMenu.Rect.Height, 1)
    local popupWidth = math.max(button.Rect.Width, 1)
    local popupHeight = math.max(button.Rect.Height * 3, 3)
    local popupRect = GUI.RectTransform(
        -- RectTransform truncates relative sizes to whole pixels. The small
        -- subpixel guard prevents an exact button width from becoming 1 px
        -- narrower after the screen-space reparenting.
        Vector2((popupWidth + 0.25) / menuWidth, (popupHeight + 0.25) / menuHeight),
        S.currentMenu.RectTransform,
        GUI.Anchor.TopLeft,
        GUI.Pivot.TopLeft
    )
    popupRect.ScreenSpaceOffset = Point(
        button.Rect.X - S.currentMenu.Rect.X,
        button.Rect.Bottom - S.currentMenu.Rect.Y + 1
    )

    -- Draw the same single frame as the vanilla GUIDropDown list, but keep the
    -- three choices in a plain layout. A GUIListBox would reserve/restore its
    -- scrollbar on the next update even when all three entries fit.
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
        -- The vanilla GUITextBlock style already provides a 10 px padding.
        -- Do not combine it with an additional percentage-based inset.
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

function P.BuildFilterBar(parent)
    local bar = P.CreateLayout(parent, 1, 0.082, nil, true, GUI.Anchor.TopLeft)
    bar.RelativeSpacing = 0.018

    local filterGroup = P.CreateLayout(bar, 0.40, 1, nil, false, GUI.Anchor.TopLeft)
    filterGroup.RelativeSpacing = 0.002
    local filterLabel = P.CreateText(filterGroup, 1, 0.38, nil, P.GetText("Filter"), GUI.Alignment.BottomLeft, 1.70, Color(235, 225, 180, 255), false)
    filterLabel.TextOffset = Vector2(0, -2)
    S.filterButton = GUI.Button(P.CreateRect(1, 0.60, filterGroup, nil), P.GetSelectedFilterLabel(), GUI.Alignment.CenterLeft, "GUIDropDown")
    P.SetButtonStyle(S.filterButton, true, false)
    S.filterButton.ForceUpperCase = P.ForceUpperCase.No
    S.filterButton.TextBlock.TextScale = 0.98
    -- DropDownIcon is a child style of GUIDropDown, not a global GUI style.
    -- Constructing GUI.Image with the string "DropDownIcon" logs an error.
    local dropDownIcon = GUI.Image(P.CreateRect(0.12, 0.58, S.filterButton, GUI.Anchor.CenterRight), nil, true)
    GUI.Style.Apply(dropDownIcon, "DropDownIcon", S.filterButton)
    dropDownIcon.CanBeFocused = false
    dropDownIcon.IgnoreLayoutGroups = true
    dropDownIcon.RectTransform.AbsoluteOffset = Point(5, 0)
    S.filterButton.OnClicked = function(button)
        P.ToggleFilterPopup(button)
        return true
    end

    local searchGroup = P.CreateLayout(bar, 0.60, 1, nil, false, GUI.Anchor.TopLeft)
    searchGroup.RelativeSpacing = 0.002
    local searchLabel = P.CreateText(searchGroup, 1, 0.38, nil, P.GetText("Search"), GUI.Alignment.BottomLeft, 1.70, Color(235, 225, 180, 255), false)
    searchLabel.TextOffset = Vector2(0, -2)
    local searchBox = GUI.TextBox(P.CreateRect(1, 0.60, searchGroup, nil), S.searchText)
    searchBox.OnTextChangedDelegate = function(_, value)
        P.CloseFilterPopup()
        S.searchText = tostring(value or "")
        S.normalizedSearchText = P.NormalizeSearchText(S.searchText)
        if S.rebuildProductList ~= nil then S.rebuildProductList() end
        return true
    end
end
