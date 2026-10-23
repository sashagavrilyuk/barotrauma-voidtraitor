if SERVER then return {} end

local Common = {}
local originalTextScales = setmetatable({}, { __mode = "k" })

function Common.SetAutoScaleText(block, scale)
    if block == nil then return end
    originalTextScales[block] = scale
    block.TextScale = scale
    block.AutoScaleHorizontal = true
end

function Common.RestoreAutoScaledText(root)
    for component in root.GetAllChildren() do
        local original = originalTextScales[component]
        if original ~= nil and (component.AutoScaleHorizontal or component.AutoScaleVertical) then
            component.TextScale = original
        end
    end
end

function Common.CreateLayout(parent, width, height, anchor, isHorizontal, childAnchor)
    local layout = GUI.LayoutGroup(Common.CreateRect(width, height, parent, anchor),
        isHorizontal == true, childAnchor or GUI.Anchor.TopLeft)
    layout.RelativeSpacing = 0.006
    return layout
end

function Common.CreateFlexibleButton(rect, label, alignment)
    local button = GUI.Button(rect, label, alignment or GUI.Alignment.Center, "GUIButtonFreeScale")
    button.RectTransform.MaxSize = Point(2147483647, Common.SafeIntScale(48))
    Common.SetAutoScaleText(button.TextBlock, 1)
    return button
end

-- VoidTraitor sizes are designed in 1920x1080 pixels. Barotrauma scales layouts with GUI.Scale,
-- but picks font sizes in resolution steps (Content/UI/style.xml), so below 1080p the text keeps
-- its 1080p size. Sizes follow whichever is larger: GUI.Scale or the default font line height
-- relative to its 1080p value. Use GUI.IntScale only to line up with vanilla HUD elements.
local DESIGN_LINE_HEIGHT = 18

function Common.SafeIntScale(value)
    return math.floor(value * math.max(GUI.Scale, GUI.Style.Font.LineHeight / DESIGN_LINE_HEIGHT))
end

-- Window layout follows Space Station 14 (RobustToolbox BoxContainer): rows keep their natural
-- height, taken from the vanilla style or the font, and only rows without a fixed height (lists,
-- text areas) share the space left when a window is resized. GUILayoutGroup.Stretch does the same:
-- children with MinSize = MaxSize keep their height and the others are stretched.
-- Vanilla style heights and fonts step with the resolution together (Content/UI/style.xml).

function Common.GetGap()
    return math.floor(GUI.Style.Font.LineHeight * 0.35)
end

-- The window frame border scales with GUI.Scale (GUI.SlicedSpriteScale), so its margin does too.
function Common.GetWindowPadding()
    return GUI.IntScale(12)
end

function Common.GetStyleHeight(styleName)
    return GUI.Style.GetComponentStyle(styleName).Height
end

function Common.GetTextHeight(font, scale)
    return math.ceil(font.LineHeight * (scale or 1))
end

function Common.SetFixedHeight(component, height)
    component.RectTransform.MinSize = Point(0, height)
    component.RectTransform.MaxSize = Point(2147483647, height)
end

function Common.SetFixedWidth(component, width)
    component.RectTransform.MinSize = Point(width, 0)
    component.RectTransform.MaxSize = Point(width, 2147483647)
end

-- One line of the block's font and scale.
function Common.FitHeightToText(block)
    Common.SetFixedHeight(block, Common.GetTextHeight(block.Font, block.TextScale))
end

-- Space between stacked buttons keeps the 2560x1440 proportion (12 px for 45 px buttons).
function Common.GetButtonSpacing()
    return math.floor(Common.GetStyleHeight("GUIButton") * 12 / 45 + 0.5)
end

-- The vanilla GUIButton style locks the height for this resolution.
function Common.CreateButton(parent, width, label, anchor)
    local button = GUI.Button(Common.CreateRect(width, 1, parent, anchor), label or "", GUI.Alignment.Center, "GUIButton")
    Common.SetAutoScaleText(button.TextBlock, 1)
    return button
end

-- Rows go into the returned layout; it keeps a fixed margin from the window frame.
function Common.CreateWindowContent(panel)
    local padding = Common.GetWindowPadding()
    local function spacer(parent, isHorizontal)
        local frame = GUI.Frame(Common.CreateRect(1, 1, parent), nil)
        frame.Color = Color(0, 0, 0, 0)
        frame.CanBeFocused = false
        if isHorizontal then Common.SetFixedWidth(frame, padding) else Common.SetFixedHeight(frame, padding) end
    end

    local outer = GUI.LayoutGroup(Common.CreateRect(1, 1, panel, GUI.Anchor.Center), false)
    outer.Stretch = true
    spacer(outer, false)
    local middle = GUI.LayoutGroup(Common.CreateRect(1, 1, outer), true)
    middle.Stretch = true
    spacer(middle, true)
    local content = GUI.LayoutGroup(Common.CreateRect(1, 1, middle), false)
    content.Stretch = true
    content.AbsoluteSpacing = Common.GetGap()
    spacer(middle, true)
    spacer(outer, false)
    return content
end

function Common.FitWindowWidth(preferredWidth, minimumWidth, margin)
    local screenWidth = Common.GetScreenSize()
    return math.min(math.max(1, screenWidth - (margin or 0) * 2), math.max(preferredWidth, Common.SafeIntScale(minimumWidth)))
end

function Common.FitWindowHeight(preferredHeight, minimumHeight, margin)
    local _, screenHeight = Common.GetScreenSize()
    return math.min(math.max(1, screenHeight - (margin or 0) * 2), math.max(preferredHeight, Common.SafeIntScale(minimumHeight)))
end

function Common.GetScreenSize()
    local width, height = 1920, 1080
    local gameScreen = Game.GameScreen
    local camera = gameScreen ~= nil and gameScreen.Cam or nil
    local resolution = camera ~= nil and camera.Resolution or nil
    if resolution ~= nil then
        width = tonumber(resolution.X) or width
        height = tonumber(resolution.Y) or height
    end
    return width, height
end

function Common.CreateRect(width, height, parent, anchor)
    local parentRect = parent ~= nil and parent.RectTransform or nil
    return GUI.RectTransform(Vector2(width, height), parentRect, anchor)
end

function Common.CreateCanvasRect(x, y, width, height)
    local rectTransform = GUI.RectTransform(
        Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))),
        nil,
        GUI.Anchor.TopLeft
    )
    rectTransform.AbsoluteOffset = Point(math.floor(x), math.floor(y))
    return rectTransform
end

function Common.Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Common.GetCharacterById(characterId)
    characterId = math.floor(tonumber(characterId) or 0)
    if characterId <= 0 or characterId > 65535 then return nil end

    local entity = Entity.FindEntityByID(characterId)
    if entity ~= nil and LuaUserData.IsTargetType(entity, "Barotrauma.Character") then
        return entity
    end

    return nil
end

function Common.GetPrefabIconData(iconIdentifier)
    iconIdentifier = tostring(iconIdentifier or "")

    if string.sub(iconIdentifier, 1, 4) == "job:" then
        local prefab = JobPrefab.Get(string.sub(iconIdentifier, 5))
        if prefab == nil then return nil, nil end

        local sprite = prefab.Icon or prefab.IconSmall
        if sprite == nil then return nil, nil end
        return sprite, prefab.UIColor or Color(255, 255, 255, 255)
    elseif iconIdentifier ~= "" and iconIdentifier ~= "character" then
        local prefab = ItemPrefab.GetItemPrefab(iconIdentifier)
        if prefab ~= nil then
            if prefab.InventoryIcon ~= nil then
                return prefab.InventoryIcon, prefab.InventoryIconColor
            elseif prefab.Sprite ~= nil then
                return prefab.Sprite, prefab.SpriteColor
            end
        end
    end

    return nil, nil
end

function Common.GetIconData(entry)
    local sprite, color = Common.GetPrefabIconData(entry.Icon)
    if sprite ~= nil then return sprite, color end

    local character = Common.GetCharacterById(entry.CharacterId)
    if character ~= nil and character.AnimController ~= nil and character.AnimController.MainLimb ~= nil then
        local sprite = character.AnimController.MainLimb.ActiveSprite
        if sprite ~= nil then return sprite, Color(255, 255, 255, 255) end
    end

    return nil, nil
end

-- One row like the SS14 FancyWindow header: drag handle with the title, then the close button
-- vertically centred in the same row. The row height follows the title font.
function Common.CreateWindowHeader(content, root, label, tooltip, onClose, options)
    options = options or {}
    local height = Common.GetTextHeight(GUI.Style.SubHeadingFont, 1.5)
    local header = GUI.LayoutGroup(Common.CreateRect(1, 1, content), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(header, height)
    header.Stretch = true
    header.AbsoluteSpacing = Common.GetGap()
    header.CanBeFocused = false

    local drag = GUI.DragHandle(Common.CreateRect(options.rightLabel ~= nil and 0.60 or 1, 1, header), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    drag.Color = transparent
    drag.HoverColor = transparent
    drag.SelectedColor = transparent
    drag.PressedColor = transparent

    local dragRow = GUI.LayoutGroup(Common.CreateRect(1, 1, drag), true, GUI.Anchor.CenterLeft)
    dragRow.Stretch = true
    dragRow.AbsoluteSpacing = Common.GetGap()
    dragRow.CanBeFocused = false
    local indicatorSize = math.floor(height * 0.6)
    local indicator = GUI.Image(GUI.RectTransform(Point(indicatorSize, indicatorSize), dragRow.RectTransform), "GUIDragIndicator")
    indicator.RectTransform.IsFixedSize = true
    indicator.CanBeFocused = false
    local title = Common.CreateText(dragRow, 1, 1, nil,
        label, GUI.Alignment.Left, options.titleScale or 1.00, Color(235, 205, 145, 255), options.wrap == true)
    title.Font = GUI.Style.SubHeadingFont
    Common.SetAutoScaleText(title, options.titleScale or 1.00)
    if options.rightLabel ~= nil then
        local rightLabel = Common.CreateText(header, 0.40, 1, nil, options.rightLabel, GUI.Alignment.Left, 1.0, nil, false)
        rightLabel.CanBeFocused = false
    end
    if options.titleNoFocus then title.CanBeFocused = false end

    local close = GUI.Button(GUI.RectTransform(Point(height, height), header.RectTransform), "", GUI.Alignment.Center, "GUICancelButton")
    close.RectTransform.IsFixedSize = true
    close.ToolTip = tooltip
    close.OnClicked = onClose
    return header
end

function Common.CreateIcon(parent, entry, pixelSize)
    local box = GUI.Frame(Common.CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    box.CanBeFocused = false
    box.RectTransform.IsFixedSize = true
    box.RectTransform.MinSize = Point(pixelSize, pixelSize)
    box.RectTransform.MaxSize = Point(pixelSize, pixelSize)

    local sprite, color = Common.GetIconData(entry)
    if sprite == nil then return box end

    local image = GUI.Image(Common.CreateRect(0.82, 0.82, box, GUI.Anchor.Center), sprite, true)
    image.Color = color
    return box
end

function Common.CreateText(parent, width, height, anchor, value, alignment, scale, color, wrap)
    if wrap == nil then wrap = true end
    local block = GUI.TextBlock(Common.CreateRect(width, height, parent, anchor), value or "", nil, nil, alignment or GUI.Alignment.Left, wrap)
    block.TextScale = scale or 1
    originalTextScales[block] = scale or 1
    block.TextColor = color or Color(230, 230, 220, 255)
    return block
end

function Common.RemoveGuiComponent(component)
    if component == nil then return end
    component:RemoveFromGUIUpdateList(true)
    component.Visible = false
    if component.RectTransform ~= nil then component.RectTransform.Parent = nil end
end

-- Handles fill the window margin (Common.GetWindowPadding), so they never cover the content.
function Common.AddResizeHandles(panel, topTargets, bottomTargets, sideTargets)
    local thickness = Common.GetWindowPadding()
    local topHandle = GUI.Frame(Common.CreateRect(0.50, 1, panel, GUI.Anchor.TopCenter), nil)
    Common.SetFixedHeight(topHandle, thickness)
    topHandle.Color = Color(0, 0, 0, 0)
    topHandle.CanBeFocused = true
    local topIndicator = GUI.Image(Common.CreateRect(0.24, 0.80, topHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    topIndicator.CanBeFocused = false
    table.insert(topTargets, topHandle)

    local bottomHandle = GUI.Frame(Common.CreateRect(0.50, 1, panel, GUI.Anchor.BottomCenter), nil)
    Common.SetFixedHeight(bottomHandle, thickness)
    bottomHandle.Color = Color(0, 0, 0, 0)
    bottomHandle.CanBeFocused = true
    local bottomIndicator = GUI.Image(Common.CreateRect(0.24, 0.80, bottomHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    bottomIndicator.CanBeFocused = false
    table.insert(bottomTargets, bottomHandle)

    if sideTargets ~= nil then
        for _, side in ipairs({ "left", "right" }) do
            local anchor = side == "left" and GUI.Anchor.CenterLeft or GUI.Anchor.CenterRight
            local handle = GUI.Frame(Common.CreateRect(1, 0.38, panel, anchor), nil)
            Common.SetFixedWidth(handle, thickness)
            handle.Color = Color(0, 0, 0, 0)
            handle.CanBeFocused = true
            local indicator = GUI.Image(Common.CreateRect(0.70, 0.35, handle, GUI.Anchor.Center), "GUIDragIndicator")
            indicator.CanBeFocused = false
            table.insert(sideTargets[side], handle)
        end
        sideTargets.corners = {}
        for _, corner in ipairs({
            { "top-left", GUI.Anchor.TopLeft, 0.785398 },
            { "bottom-left", GUI.Anchor.BottomLeft, -0.785398 },
            { "bottom-right", GUI.Anchor.BottomRight, 0.785398 },
        }) do
            local handle = GUI.Frame(GUI.RectTransform(Point(thickness * 2, thickness * 2), panel.RectTransform, corner[2]), nil)
            handle.RectTransform.IsFixedSize = true
            handle.Color = Color(0, 0, 0, 0)
            handle.CanBeFocused = true
            local indicator = GUI.Image(Common.CreateRect(0.7, 0.7, handle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
            indicator.Rotation = corner[3]
            indicator.CanBeFocused = false
            sideTargets.corners[#sideTargets.corners + 1] = { Edge = corner[1], Handle = handle }
        end
    end
end

function Common.GetResizeEdge(topTargets, bottomTargets, sideTargets)
    local mousePosition = PlayerInput.MousePosition
    if sideTargets ~= nil then
        for _, corner in ipairs(sideTargets.corners) do
            if corner.Handle.Rect.Contains(mousePosition) then return corner.Edge end
        end
    end
    for _, target in ipairs(topTargets) do
        if target ~= nil and target.Rect.Contains(mousePosition) then return "top" end
    end
    for _, target in ipairs(bottomTargets) do
        if target ~= nil and target.Rect.Contains(mousePosition) then return "bottom" end
    end
    if sideTargets ~= nil then
        for _, side in ipairs({ "left", "right" }) do
            for _, target in ipairs(sideTargets[side]) do
                if target.Rect.Contains(mousePosition) then return side end
            end
        end
    end
    return nil
end

function Common.UpdateMenuInteraction(currentMenu, resizeState, topTargets, bottomTargets, minimumHeightPixels, list, menuX, menuY, menuHeight, sideTargets)
    if currentMenu == nil then
        return nil, menuX, menuY, menuHeight
    end

    local mouseDown = PlayerInput.PrimaryMouseButtonDown()
    local mouseHeld = PlayerInput.PrimaryMouseButtonHeld()

    if mouseDown and resizeState == nil then
        local edge = Common.GetResizeEdge(topTargets, bottomTargets, sideTargets)
        if edge ~= nil then
            local rectTransform = currentMenu.RectTransform
            resizeState = {
                Edge = edge,
                MouseX = PlayerInput.MousePosition.X,
                MouseY = PlayerInput.MousePosition.Y,
                Left = currentMenu.Rect.X,
                Right = currentMenu.Rect.Right,
                Width = currentMenu.Rect.Width,
                Top = currentMenu.Rect.Y,
                Bottom = currentMenu.Rect.Bottom,
                Height = currentMenu.Rect.Height,
                NonScaledWidth = rectTransform.NonScaledSize.X,
                NonScaledHeight = rectTransform.NonScaledSize.Y,
                ScreenOffsetX = rectTransform.ScreenSpaceOffset.X,
                ScreenOffsetY = rectTransform.ScreenSpaceOffset.Y,
            }
        end
    end

    if not mouseHeld then
        return nil, menuX, menuY, menuHeight
    end
    if resizeState == nil then
        return nil, menuX, menuY, menuHeight
    end

    local screenWidth, screenHeight = Common.GetScreenSize()
    local margin = Common.SafeIntScale(10)
    local minimumHeight = math.min(Common.SafeIntScale(sideTargets ~= nil and sideTargets.minimumHeightPixels
        or minimumHeightPixels), screenHeight - 2 * margin)
    local minimumWidth = sideTargets ~= nil and math.min(
        Common.SafeIntScale(sideTargets.minimumWidthPixels or sideTargets.minimumWidth), screenWidth - 2 * margin) or 0
    local dy = PlayerInput.MousePosition.Y - resizeState.MouseY
    local dx = PlayerInput.MousePosition.X - resizeState.MouseX
    local newHeight, newWidth = resizeState.Height, resizeState.Width
    local newTop, newLeft = resizeState.Top, resizeState.Left

    local edge = resizeState.Edge
    if edge == "top" or edge == "top-left" or edge == "top-right" then
        newTop = Common.Clamp(resizeState.Top + dy, margin, resizeState.Bottom - minimumHeight)
        newHeight = resizeState.Bottom - newTop
    elseif edge == "bottom" or edge == "bottom-left" or edge == "bottom-right" then
        local maximumHeight = math.max(minimumHeight, screenHeight - resizeState.Top - margin)
        newHeight = Common.Clamp(resizeState.Height + dy, minimumHeight, maximumHeight)
    end
    if edge == "left" or edge == "top-left" or edge == "bottom-left" then
        newLeft = Common.Clamp(resizeState.Left + dx, margin, resizeState.Right - minimumWidth)
        newWidth = resizeState.Right - newLeft
    elseif edge == "right" or edge == "top-right" or edge == "bottom-right" then
        newWidth = Common.Clamp(resizeState.Width + dx, minimumWidth, screenWidth - resizeState.Left - margin)
    end

    local rectTransform = currentMenu.RectTransform
    local nonScaledWidth = newWidth ~= resizeState.Width
        and math.max(1, math.floor(newWidth / rectTransform.Scale.X + 0.5)) or resizeState.NonScaledWidth
    local nonScaledHeight = newHeight ~= resizeState.Height
        and math.max(1, math.floor(newHeight / rectTransform.Scale.Y + 0.5)) or resizeState.NonScaledHeight
    rectTransform:Resize(Point(nonScaledWidth, nonScaledHeight), true)

    if sideTargets ~= nil then
        local offset = rectTransform.ScreenSpaceOffset
        rectTransform.ScreenSpaceOffset = Point(
            offset.X + newLeft - currentMenu.Rect.X,
            offset.Y + newTop - currentMenu.Rect.Y
        )
    elseif resizeState.Edge == "top" then
        rectTransform.ScreenSpaceOffset = Point(
            resizeState.ScreenOffsetX,
            resizeState.ScreenOffsetY + (newTop - resizeState.Top)
        )
    end

    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuHeight = currentMenu.Rect.Height

    if list ~= nil then
        list:RecalculateChildren()
        list:UpdateScrollBarSize()
    end

    if newWidth ~= resizeState.Width or newHeight ~= resizeState.Height then
        Common.RestoreAutoScaledText(currentMenu)
    end

    return resizeState, menuX, menuY, menuHeight
end

-- Spectator bottom buttons stand on the row of the vanilla chat input (ChatBox.InputBox) with its
-- height, so they line up with the chat at every resolution; the width follows the label.
function Common.FitBottomButton(button, horizontalPaddingPixels)
    if button == nil or button.TextBlock == nil then return end

    local input = Game.Client.ChatBox.InputBox.Rect
    local textWidth = button.TextBlock.TextSize.X * button.TextBlock.TextScale
    local width = math.max(1, math.ceil(textWidth + Common.SafeIntScale(horizontalPaddingPixels)))
    button.RectTransform:Resize(Point(width, input.Height), true)
    local _, screenHeight = Common.GetScreenSize()
    button.RectTransform.AbsoluteOffset = Point(button.RectTransform.AbsoluteOffset.X, screenHeight - input.Bottom)
end

function Common.IsLocalCandidate()
    local character = Character.Controlled
    return character == nil or character.IsDead == true
end

function Common.IsRoundStarted()
    return Game.RoundStarted == true
end

function Common.IsConnected()
    return Game.Client ~= nil
end

function Common.ShouldShowBottomButton()
    return Common.IsConnected() and Common.IsRoundStarted() and Common.IsLocalCandidate()
end

function Common.UpdateSelectedItemMenu(state, identifier, onSelected)
    if state.Disabled then return nil end
    local character = Character.Controlled
    local item = character ~= nil and not character.IsDead and not character.IsIncapacitated and character.SelectedItem or nil
    if not Networking.IsActive or item == nil or item.Removed or item.Prefab.Identifier ~= identifier
        or not character.CanInteractWith(item) then
        if state.SelectedItem ~= nil then state.CloseMenu() end
        state.SelectedItem = nil
        return nil
    end
    if state.SelectedItem ~= item then
        if state.SelectedItem ~= nil then state.CloseMenu() end
        state.SelectedItem = item
        onSelected(item)
    end
    return item
end

function Common.InstallHudPatch(patchIdentifier, stateKey, menuDrawOrder, buttonDrawOrder)
    Hook.Patch(patchIdentifier, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
        local state = rawget(_G, stateKey)
        if state == nil or state.Disabled then return end
        if GUI.DisableHUD then return end

        if state.MenuRoot ~= nil then
            state.MenuRoot:AddToGUIUpdateList(false, menuDrawOrder)
        end
        if state.ButtonRoot ~= nil then
            state.ButtonRoot:AddToGUIUpdateList(false, buttonDrawOrder)
        end
    end)
end

function Common.InstallPausePatch(patchIdentifier, stateKey)
    Hook.Patch(patchIdentifier, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, p)
        local state = rawget(_G, stateKey)
        if state ~= nil and not state.Disabled and state.CurrentMenu ~= nil then
            if state.CloseMenu ~= nil then state.CloseMenu() end
            if p ~= nil then p.PreventExecution = true end
            return false
        end
    end, Hook.HookMethodType.Before)
end

return Common
