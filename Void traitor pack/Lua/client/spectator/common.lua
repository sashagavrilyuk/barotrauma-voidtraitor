if SERVER then return {} end

local Common = {}

function Common.SafeIntScale(value)
    if GUI ~= nil and GUI.IntScale ~= nil then
        return GUI.IntScale(value)
    end
    return math.floor(value)
end

function Common.GetScreenSize()
    local width, height = 1920, 1080
    local gameScreen = Game ~= nil and Game.GameScreen or nil
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
    characterId = tonumber(characterId)
    if characterId == nil or characterId <= 0 then return nil end

    for _, character in pairs(Character.CharacterList) do
        if character ~= nil and tonumber(character.ID) == characterId then
            return character
        end
    end

    return nil
end

function Common.GetIconData(entry)
    local iconIdentifier = tostring(entry.Icon or "")

    if string.sub(iconIdentifier, 1, 4) == "job:" then
        local prefab = JobPrefab.Get(string.sub(iconIdentifier, 5))
        if prefab == nil then return nil, nil end

        local sprite = prefab.Icon or prefab.IconSmall
        if sprite == nil then return nil, nil end
        return sprite, prefab.UIColor or Color(255, 255, 255, 255)
    elseif iconIdentifier ~= "" and iconIdentifier ~= "character" then
        local prefab = ItemPrefab.GetItemPrefab(iconIdentifier)
        if prefab ~= nil then
            local sprite = prefab.InventoryIcon
            local color = Color(255, 255, 255, 255)
            if sprite ~= nil then
                color = prefab.InventoryIconColor
            else
                sprite = prefab.Sprite
            end
            if sprite ~= nil then return sprite, color end
        end
    end

    local character = Common.GetCharacterById(entry.CharacterId)
    if character ~= nil and character.AnimController ~= nil and character.AnimController.MainLimb ~= nil then
        local sprite = character.AnimController.MainLimb.ActiveSprite
        if sprite ~= nil then return sprite, Color(255, 255, 255, 255) end
    end

    return nil, nil
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
    block.TextColor = color or Color(230, 230, 220, 255)
    return block
end

function Common.AddResizeHandles(panel, topTargets, bottomTargets)
    local topHandle = GUI.Frame(Common.CreateRect(0.50, 0.024, panel, GUI.Anchor.TopCenter), nil)
    topHandle.Color = Color(0, 0, 0, 0)
    topHandle.CanBeFocused = true
    local topIndicator = GUI.Image(Common.CreateRect(0.24, 0.80, topHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    topIndicator.CanBeFocused = false
    table.insert(topTargets, topHandle)

    local bottomHandle = GUI.Frame(Common.CreateRect(0.50, 0.024, panel, GUI.Anchor.BottomCenter), nil)
    bottomHandle.Color = Color(0, 0, 0, 0)
    bottomHandle.CanBeFocused = true
    local bottomIndicator = GUI.Image(Common.CreateRect(0.24, 0.80, bottomHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    bottomIndicator.CanBeFocused = false
    table.insert(bottomTargets, bottomHandle)
end

function Common.GetResizeEdge(topTargets, bottomTargets)
    local mousePosition = PlayerInput.MousePosition
    for _, target in ipairs(topTargets) do
        if target ~= nil and target.Rect.Contains(mousePosition) then return "top" end
    end
    for _, target in ipairs(bottomTargets) do
        if target ~= nil and target.Rect.Contains(mousePosition) then return "bottom" end
    end
    return nil
end

function Common.ResizeButtonToText(button, horizontalPaddingPixels, heightPixels)
    if button == nil or button.TextBlock == nil then return end

    local textWidth = button.TextBlock.TextSize.X * button.TextBlock.TextScale
    local width = math.max(1, math.ceil(textWidth + Common.SafeIntScale(horizontalPaddingPixels)))
    button.RectTransform:Resize(Point(width, Common.SafeIntScale(heightPixels)), true)
end

function Common.IsLocalCandidate()
    local character = Character.Controlled
    return character == nil or character.IsDead == true
end

function Common.IsRoundStarted()
    return Game ~= nil and Game.RoundStarted == true
end

function Common.IsConnected()
    return Game ~= nil and Game.Client ~= nil
end

function Common.ShouldShowBottomButton()
    return Common.IsConnected() and Common.IsRoundStarted() and Common.IsLocalCandidate()
end

function Common.InstallHudPatch(patchKey, stateKey, menuDrawOrder, buttonDrawOrder)
    if rawget(_G, patchKey) then return end

    Hook.Patch("Barotrauma.GameSession", "AddToGUIUpdateList", function()
        local state = rawget(_G, stateKey)
        if state == nil or state.Disabled then return end
        if GUI ~= nil and GUI.DisableHUD then return end

        if state.MenuRoot ~= nil then
            state.MenuRoot:AddToGUIUpdateList(false, menuDrawOrder)
        end
        if state.ButtonRoot ~= nil then
            state.ButtonRoot:AddToGUIUpdateList(false, buttonDrawOrder)
        end
    end)
    _G[patchKey] = true
end

function Common.InstallPausePatch(patchKey, stateKey)
    if rawget(_G, patchKey) then return end

    Hook.Patch("Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, p)
        local state = rawget(_G, stateKey)
        if state ~= nil and not state.Disabled and state.CurrentMenu ~= nil then
            if state.CloseMenu ~= nil then state.CloseMenu() end
            if p ~= nil then p.PreventExecution = true end
            return false
        end
    end, Hook.HookMethodType.Before)
    _G[patchKey] = true
end

return Common
