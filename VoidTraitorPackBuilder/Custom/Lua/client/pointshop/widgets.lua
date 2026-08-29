local P = ...
local S = P.State

P.CreateRect = P.Common.CreateRect
P.CreateText = P.Common.CreateText
P.ForceUpperCase = LuaUserData.CreateEnumTable("Barotrauma.ForceUpperCase")

function P.SetButtonStyle(button, enabled, selected)
    if button == nil then return end
    button.Enabled = enabled ~= false
    button.Selected = selected == true
    button.ForceUpperCase = P.ForceUpperCase.Yes
end

function P.CreateButton(parent, width, height, anchor, label, enabled, selected, style)
    local button = GUI.Button(P.CreateRect(width, height, parent, anchor), label or "", GUI.Alignment.Center, style or "GUIButton")
    P.SetButtonStyle(button, enabled ~= false, selected == true)

    if button.TextBlock ~= nil then
        if label ~= nil and string.len(label) > 54 then
            button.TextBlock.TextScale = 0.76
        elseif label ~= nil and string.len(label) > 38 then
            button.TextBlock.TextScale = 0.86
        else
            button.TextBlock.TextScale = 0.98
        end
    end

    return button
end

function P.RegisterClassLimitText(groupName, block, getText)
    if block == nil or getText == nil then return end

    local group = S.classLimitTextBlocks[groupName or "shop"]
    if group == nil then
        group = {}
        S.classLimitTextBlocks[groupName or "shop"] = group
    end

    table.insert(group, { Block = block, GetText = getText })
end

function P.UpdateClassLimitTextBlocks()
    for _, group in pairs(S.classLimitTextBlocks) do
        for _, entry in ipairs(group) do
            entry.Block.Text = entry.GetText() or ""
        end
    end
end

function P.RegisterCooldownText(groupName, block, getText)
    if block == nil or getText == nil then return end

    local group = S.cooldownTextBlocks[groupName or "shop"]
    if group == nil then
        group = {}
        S.cooldownTextBlocks[groupName or "shop"] = group
    end

    table.insert(group, { Block = block, GetText = getText })
end

function P.UpdateCooldownTextBlocks()
    local anyActive = false
    local needsSnapshot = false

    for _, group in pairs(S.cooldownTextBlocks) do
        for index = #group, 1, -1 do
            local entry = group[index]
            local value, active = entry.GetText()
            entry.Block.Text = value or ""
            if active == true then
                anyActive = true
            elseif active == false then
                needsSnapshot = true
                table.remove(group, index)
            end
        end
    end

    if needsSnapshot and not S.cooldownSnapshotRequested then
        S.cooldownSnapshotRequested = true
        Timer.Wait(function()
            S.cooldownSnapshotRequested = false
            if S.currentMenu ~= nil then P.ShowMenu() end
        end, 1)
    end

    return anyActive
end

function P.CreateProductIcon(parent, iconIdentifier, enabled)
    -- Square vanilla-framed icon slot. The row height is sized around this slot,
    -- otherwise Barotrauma compresses the inventory sprite into a wide rectangle.
    local box = GUI.Frame(P.CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    box.CanBeFocused = false

    box.RectTransform.IsFixedSize = true
    box.RectTransform.MinSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)
    box.RectTransform.MaxSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)

    local sprite, spriteColor = P.Common.GetPrefabIconData(iconIdentifier)
    if sprite == nil then return end

    local image = GUI.Image(P.CreateRect(0.82, 0.82, box, GUI.Anchor.Center), sprite, true)
    image.Color = enabled == false and Color(105, 105, 105, 190) or spriteColor
    return image, spriteColor
end

function P.CreateRowInner(row, width, height)
    local inner = GUI.Frame(P.CreateRect(width or 0.94, height or 0.90, row, GUI.Anchor.Center), nil)
    inner.Color = Color(0, 0, 0, 0)
    return GUI.LayoutGroup(P.CreateRect(1, 1, inner, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
end

function P.CreateStoreActionButton(parent, width, style, enabled)
    local holder = GUI.Frame(P.CreateRect(width or 0.155, 1, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local button = GUI.Button(P.CreateRect(0.92, 0.92, holder, GUI.Anchor.Center), "", GUI.Alignment.Center, style)
    button.Enabled = enabled ~= false
    button.RectTransform.IsFixedSize = true
    button.RectTransform.MinSize = Point(P.ACTION_BUTTON_PIXELS, P.ACTION_BUTTON_PIXELS)
    button.RectTransform.MaxSize = Point(math.floor(P.ACTION_BUTTON_PIXELS * 1.12), math.floor(P.ACTION_BUTTON_PIXELS * 1.12))
    if button.TextBlock ~= nil then
        button.TextBlock.Text = ""
    end

    return button
end

function P.CreateLayout(parent, width, height, anchor, isHorizontal, childAnchor)
    local layout = GUI.LayoutGroup(P.CreateRect(width, height, parent, anchor), isHorizontal == true, childAnchor or GUI.Anchor.TopLeft)
    layout.Stretch = true
    layout.RelativeSpacing = 0.006
    return layout
end

function P.CreateDivider(parent, height)
    local frame = GUI.Frame(P.CreateRect(1, height or 0.02, parent), nil)
    frame.Color = Color(0, 0, 0, 0)
    GUI.Image(P.CreateRect(1, 0.55, frame, GUI.Anchor.Center), "HorizontalLine")
    return frame
end

function P.CreatePanelTitle(parent, titleText, iconStyle, alignRight)
    local header = GUI.Frame(P.CreateRect(1, 0.095, parent, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    if not alignRight then
        local layout = GUI.LayoutGroup(P.CreateRect(1, 1, header, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
        layout.Stretch = true
        layout.RelativeSpacing = 0.010

        GUI.Image(P.CreateRect(0.087, 0.98, layout, nil), iconStyle or "StoreTradingIcon", true)

        local title = P.CreateText(layout, 0.88, 1, nil, titleText, GUI.Alignment.Left, 1.42, Color(255, 245, 190, 255), false)
        title.Font = GUI.Style.LargeFont
        return title
    end

    -- Right-anchored horizontal layout fills children from right to left.
    -- Create the icon first, then the title: visually the text goes first,
    -- the icon follows it, and the whole group stays in the right corner.
    local layout = GUI.LayoutGroup(P.CreateRect(0.82, 1, header, GUI.Anchor.TopRight), true, GUI.Anchor.CenterRight)
    layout.Stretch = true
    layout.RelativeSpacing = 0.012

    GUI.Image(P.CreateRect(0.115, 0.92, layout, nil), iconStyle or "StoreShoppingCrateIcon", true)

    local title = P.CreateText(layout, 0.70, 1, nil, titleText, GUI.Alignment.Right, 1.42, Color(255, 245, 190, 255), false)
    title.Font = GUI.Style.LargeFont

    return title
end

