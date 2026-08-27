if SERVER then return end

local NET_READY = "VoidTraitor_CameraTeleportGuiReady"
local NET_REQUEST = "VoidTraitor_CameraTeleportRequest"
local NET_SNAPSHOT = "VoidTraitor_CameraTeleportSnapshot"

local GLOBAL_STATE_KEY = "VoidTraitorCameraTeleportGuiState"
local GHOST_STATE_KEY = "VoidTraitorGhostRolesGuiState"
local GLOBAL_HUD_PATCH_KEY = "VoidTraitorCameraTeleportGuiHudPatchInstalled"
local GLOBAL_PAUSE_PATCH_KEY = "VoidTraitorCameraTeleportGuiPausePatchInstalled"

local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end

    for _, key in ipairs({ "MenuRoot", "ButtonRoot" }) do
        local component = previousState[key]
        if component ~= nil then
            component:RemoveFromGUIUpdateList(true)
            component.Visible = false
            if component.RectTransform ~= nil then
                component.RectTransform.Parent = nil
            end
        end
    end
end

local sharedState = { Disabled = false }
_G[GLOBAL_STATE_KEY] = sharedState

local buttonRoot = nil
local bottomButton = nil
local currentMenu = nil
local canUse = false
local targets = {}
local targetById = {}
local targetSignature = ""
local targetList = nil
local targetListScroll = 0
local resizeTopTargets = {}
local resizeBottomTargets = {}
local resizeState = nil
local menuX = nil
local menuY = nil
local menuHeight = nil
local lastLocalCandidate = nil
local lastRoundStarted = nil
local lastConnected = nil
local lastResolutionX = -1
local lastResolutionY = -1
local nextRefreshTime = 0
local stateCheckTimer = 0

local text = {
    Title = "CAMERA TELEPORT",
    Button = "Camera teleport",
    Player = "Player",
    Follow = "Follow",
    Close = "Close",
    Empty = "There are no players with a living controlled character right now.",
}

local MENU_DRAW_ORDER = 122
local BUTTON_DRAW_ORDER = 121
local MENU_WIDTH_PIXELS = 370
local DEFAULT_HEIGHT_PIXELS = 420
local MIN_HEIGHT_PIXELS = 320
local ROW_HEIGHT_PIXELS = 70
local ICON_PIXELS = 40
local BOTTOM_BUTTON_TEXT_SCALE = 0.90
local BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS = 22
local BOTTOM_BUTTON_GAP_PIXELS = 6
local BOTTOM_BUTTON_Y_PIXELS = 18

local function SafeIntScale(value)
    if GUI ~= nil and GUI.IntScale ~= nil then
        return GUI.IntScale(value)
    end
    return math.floor(value)
end

local function GetScreenSize()
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

local function CreateRect(width, height, parent, anchor)
    local parentRect = parent ~= nil and parent.RectTransform or nil
    return GUI.RectTransform(Vector2(width, height), parentRect, anchor)
end

local function CreateCanvasRect(x, y, width, height)
    local rectTransform = GUI.RectTransform(
        Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))),
        nil,
        GUI.Anchor.TopLeft
    )
    rectTransform.AbsoluteOffset = Point(math.floor(x), math.floor(y))
    return rectTransform
end

local function Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function SendReady()
    local message = Networking.Start(NET_READY)
    Networking.Send(message)
end

local function RequestSnapshot(openMenu)
    local message = Networking.Start(NET_REQUEST)
    message.WriteBoolean(openMenu == true)
    Networking.Send(message)
end

local function GetCharacterById(characterId)
    characterId = tonumber(characterId)
    if characterId == nil or characterId <= 0 then return nil end

    for _, character in pairs(Character.CharacterList) do
        if character ~= nil and tonumber(character.ID) == characterId then
            return character
        end
    end

    return nil
end

local function GetJobIconData(jobIdentifier)
    if jobIdentifier == nil or jobIdentifier == "" then return nil, nil end

    local prefab = JobPrefab.Get(jobIdentifier)
    if prefab == nil then return nil, nil end

    local sprite = prefab.Icon or prefab.IconSmall
    if sprite == nil then return nil, nil end
    return sprite, prefab.UIColor or Color(255, 255, 255, 255)
end

local function GetIconData(target)
    local iconIdentifier = tostring(target.Icon or "")

    if string.sub(iconIdentifier, 1, 4) == "job:" then
        return GetJobIconData(string.sub(iconIdentifier, 5))
    end

    if iconIdentifier ~= "" and iconIdentifier ~= "character" then
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

    local character = GetCharacterById(target.CharacterId)
    if character ~= nil and character.AnimController ~= nil and character.AnimController.MainLimb ~= nil then
        local sprite = character.AnimController.MainLimb.ActiveSprite
        if sprite ~= nil then return sprite, Color(255, 255, 255, 255) end
    end

    return nil, nil
end

local function CreateIcon(parent, target)
    local box = GUI.Frame(CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    box.CanBeFocused = false
    box.RectTransform.IsFixedSize = true
    box.RectTransform.MinSize = Point(ICON_PIXELS, ICON_PIXELS)
    box.RectTransform.MaxSize = Point(ICON_PIXELS, ICON_PIXELS)

    local sprite, color = GetIconData(target)
    if sprite == nil then return box end

    local image = GUI.Image(CreateRect(0.82, 0.82, box, GUI.Anchor.Center), sprite, true)
    image.Color = color
    return box
end

local function CreateText(parent, width, height, anchor, value, alignment, scale, color, wrap)
    if wrap == nil then wrap = true end
    local block = GUI.TextBlock(CreateRect(width, height, parent, anchor), value or "", nil, nil, alignment or GUI.Alignment.Left, wrap)
    block.TextScale = scale or 1
    block.TextColor = color or Color(230, 230, 220, 255)
    return block
end

local function AddResizeHandles(panel)
    local topHandle = GUI.Frame(CreateRect(0.50, 0.024, panel, GUI.Anchor.TopCenter), nil)
    topHandle.Color = Color(0, 0, 0, 0)
    topHandle.CanBeFocused = true
    local topIndicator = GUI.Image(CreateRect(0.24, 0.80, topHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    topIndicator.CanBeFocused = false
    table.insert(resizeTopTargets, topHandle)

    local bottomHandle = GUI.Frame(CreateRect(0.50, 0.024, panel, GUI.Anchor.BottomCenter), nil)
    bottomHandle.Color = Color(0, 0, 0, 0)
    bottomHandle.CanBeFocused = true
    local bottomIndicator = GUI.Image(CreateRect(0.24, 0.80, bottomHandle, GUI.Anchor.Center), "GUIDragIndicatorHorizontal")
    bottomIndicator.CanBeFocused = false
    table.insert(resizeBottomTargets, bottomHandle)
end

local function SaveMenuGeometry()
    if currentMenu == nil then return end
    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuHeight = currentMenu.Rect.Height
    if targetList ~= nil then targetListScroll = targetList.BarScroll end
end

local function CloseMenu()
    if currentMenu == nil then return end

    SaveMenuGeometry()
    currentMenu:RemoveFromGUIUpdateList(true)
    currentMenu.Visible = false
    if currentMenu.RectTransform ~= nil then currentMenu.RectTransform.Parent = nil end
    currentMenu = nil
    targetList = nil
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil
    sharedState.CurrentMenu = nil
    sharedState.MenuRoot = nil
end

sharedState.CloseMenu = CloseMenu

local function AddMenuToUpdateList()
    if currentMenu ~= nil then currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER) end
end

local function AddButtonToUpdateList()
    if buttonRoot ~= nil then buttonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER) end
end

local function DestroyBottomButton()
    if buttonRoot == nil then return end
    buttonRoot:RemoveFromGUIUpdateList(true)
    buttonRoot.Visible = false
    if buttonRoot.RectTransform ~= nil then buttonRoot.RectTransform.Parent = nil end
    buttonRoot = nil
    bottomButton = nil
    sharedState.ButtonRoot = nil
end

local function ShouldShowBottomButton()
    if Game == nil or Game.Client == nil or Game.RoundStarted ~= true then return false end
    local character = Character.Controlled
    return character == nil or character.IsDead == true
end

local function ResizeBottomButtonToText()
    if bottomButton == nil or bottomButton.TextBlock == nil then return end

    local textWidth = bottomButton.TextBlock.TextSize.X * bottomButton.TextBlock.TextScale
    local width = math.max(1, math.ceil(textWidth + SafeIntScale(BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS)))
    bottomButton.RectTransform:Resize(Point(width, SafeIntScale(32)), true)
end

local function UpdateBottomButtonPosition()
    if bottomButton == nil then return end

    local ghostState = rawget(_G, GHOST_STATE_KEY)
    local ghostWidth = 0
    if ghostState ~= nil and ghostState.GetButtonWidth ~= nil then
        ghostWidth = tonumber(ghostState.GetButtonWidth()) or 0
    end

    local width = bottomButton.Rect.Width
    local offsetX = -math.floor((ghostWidth + width) / 2 + SafeIntScale(BOTTOM_BUTTON_GAP_PIXELS))
    bottomButton.RectTransform.AbsoluteOffset = Point(offsetX, SafeIntScale(BOTTOM_BUTTON_Y_PIXELS))
end

local function CreateBottomButton()
    DestroyBottomButton()

    local canvas = GUI.Canvas.Instance
    local rectTransform = GUI.RectTransform(Point(SafeIntScale(180), SafeIntScale(32)), canvas, GUI.Anchor.BottomCenter)
    bottomButton = GUI.Button(rectTransform, text.Button, GUI.Alignment.Center, "GUIButtonSmall")
    bottomButton.CanBeFocused = true

    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end
    UpdateBottomButtonPosition()

    bottomButton.OnClicked = function()
        RequestSnapshot(true)
        return true
    end

    buttonRoot = bottomButton
    sharedState.ButtonRoot = buttonRoot
    AddButtonToUpdateList()
end

local function EnsureBottomButton()
    if sharedState.Disabled or not ShouldShowBottomButton() then return end
    if buttonRoot == nil then CreateBottomButton() end
    UpdateBottomButtonPosition()
end

sharedState.EnsureBottomButton = EnsureBottomButton

local function UpdateBottomButton()
    if not ShouldShowBottomButton() then
        if buttonRoot ~= nil then buttonRoot.Visible = false end
        return
    end

    EnsureBottomButton()
    if bottomButton == nil then return end
    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.Text = text.Button
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end
    UpdateBottomButtonPosition()
    buttonRoot.Visible = not (GUI ~= nil and GUI.DisableHUD == true)
end

local function StartFollow(target)
    local ghostState = rawget(_G, GHOST_STATE_KEY)
    if ghostState == nil or ghostState.StartFollow == nil then
        error("VoidTraitor CameraTeleport: GhostRoles camera follow controller is unavailable.")
    end

    ghostState.StartFollow(
        target.CharacterId,
        Vector2(tonumber(target.WorldX) or 0, tonumber(target.WorldY) or 0)
    )
end

local function CreateTargetRow(list, target)
    local row = GUI.Frame(CreateRect(1, 0.12, list.Content, GUI.Anchor.TopLeft), nil)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false
    local rowHeight = SafeIntScale(ROW_HEIGHT_PIXELS)
    row.RectTransform.MinSize = Point(0, rowHeight)
    row.RectTransform.MaxSize = Point(100000, rowHeight)

    local selectButton = GUI.Button(CreateRect(1, 1, row, GUI.Anchor.TopCenter), "", GUI.Alignment.Center, "ListBoxElement")
    if selectButton.TextBlock ~= nil then selectButton.TextBlock.Text = "" end

    local iconHolder = GUI.Frame(CreateRect(0.18, 0.88, selectButton, GUI.Anchor.CenterLeft), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    CreateIcon(iconHolder, target)

    local content = GUI.Frame(CreateRect(0.78, 0.86, selectButton, GUI.Anchor.CenterRight), nil)
    content.Color = Color(0, 0, 0, 0)
    content.CanBeFocused = false

    local name = CreateText(content, 1, 0.52, GUI.Anchor.TopLeft, tostring(target.CharacterName or ""), GUI.Alignment.Left, 0.88, Color(235, 225, 190, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    CreateText(content, 1, 0.40, GUI.Anchor.BottomLeft, text.Player .. ": " .. tostring(target.PlayerName or ""), GUI.Alignment.Left, 1.28, Color(145, 205, 145, 255), false)

    local targetId = target.CharacterId
    selectButton.OnClicked = function()
        local currentTarget = targetById[targetId]
        if currentTarget ~= nil then
            StartFollow(currentTarget)
            CloseMenu()
            UpdateBottomButton()
        end
        return true
    end
end

local function BuildPanel(root)
    local panel = GUI.Frame(CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.003

    local header = GUI.Frame(CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.84, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.07, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = CreateText(dragArea, 0.90, 1, GUI.Anchor.CenterRight, text.Title, GUI.Alignment.Left, 1.00, Color(235, 205, 145, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    local close = GUI.Button(CreateRect(0.10, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.OnClicked = function()
        CloseMenu()
        UpdateBottomButton()
        return true
    end
    close.ToolTip = text.Close

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local listFrame = GUI.Frame(CreateRect(1, 0.91, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    if #targets == 0 then
        CreateText(listFrame, 0.90, 0.24, GUI.Anchor.Center, text.Empty, GUI.Alignment.Center, 0.88, Color(195, 195, 185, 255), true)
        targetList = nil
    else
        targetList = GUI.ListBox(CreateRect(1, 0.985, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
        targetList.Color = Color(0, 0, 0, 0)
        targetList.ContentBackground.Color = Color(0, 0, 0, 0)
        targetList.KeepSpaceForScrollBar = true

        for _, target in ipairs(targets) do CreateTargetRow(targetList, target) end
        targetList.BarScroll = targetListScroll
        targetList:RecalculateChildren()
        targetList:UpdateScrollBarSize()
    end

    AddResizeHandles(panel)
end

local function ShowMenu()
    if not canUse then
        CloseMenu()
        UpdateBottomButton()
        return
    end

    CloseMenu()

    local width = SafeIntScale(MENU_WIDTH_PIXELS)
    local height = menuHeight or SafeIntScale(DEFAULT_HEIGHT_PIXELS)
    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local maximumHeight = math.max(minimumHeight, screenHeight - (margin * 2))
    height = Clamp(height, minimumHeight, maximumHeight)
    menuHeight = height

    local x = menuX
    local y = menuY
    if x == nil then x = math.floor((screenWidth - width) / 2) end
    if y == nil then y = math.floor((screenHeight - height) / 2) end
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))
    menuX = x
    menuY = y

    currentMenu = GUI.Frame(CreateCanvasRect(x, y, width, height), nil)
    currentMenu.Color = Color(0, 0, 0, 0)
    currentMenu.CanBeFocused = false
    currentMenu.IgnoreLayoutGroups = true
    sharedState.CurrentMenu = currentMenu
    sharedState.MenuRoot = currentMenu

    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil

    BuildPanel(currentMenu)
    AddMenuToUpdateList()
    UpdateBottomButton()
end

local function ReadSnapshot(message)
    local openMenu = message.ReadBoolean()
    canUse = message.ReadBoolean()

    local newTargets = {}
    local newTargetById = {}
    local signatureParts = {}
    local count = message.ReadInt32()
    for _ = 1, count do
        local target = {
            CharacterId = message.ReadInt32(),
            CharacterName = message.ReadString(),
            PlayerName = message.ReadString(),
            WorldX = message.ReadSingle(),
            WorldY = message.ReadSingle(),
            Icon = message.ReadString(),
        }
        table.insert(newTargets, target)
        newTargetById[target.CharacterId] = target
        table.insert(signatureParts, tostring(target.CharacterId) .. ":" .. tostring(target.CharacterName) .. ":" .. tostring(target.PlayerName) .. ":" .. tostring(target.Icon))
    end

    local newSignature = table.concat(signatureParts, "|")
    local listChanged = newSignature ~= targetSignature
    targets = newTargets
    targetById = newTargetById
    targetSignature = newSignature

    local textCount = message.ReadInt32()
    for _ = 1, textCount do
        local key = message.ReadString()
        local value = message.ReadString()
        if key ~= nil and key ~= "" then text[key] = value or "" end
    end

    UpdateBottomButton()

    if not canUse then
        CloseMenu()
    elseif openMenu or (currentMenu ~= nil and listChanged) then
        ShowMenu()
    end
end

local function IsLocalCandidate()
    local character = Character.Controlled
    return character == nil or character.IsDead == true
end

local function IsRoundStarted()
    return Game ~= nil and Game.RoundStarted == true
end

local function IsConnected()
    return Game ~= nil and Game.Client ~= nil
end

local function ContainsMouse(component)
    return component ~= nil and component.Rect.Contains(PlayerInput.MousePosition)
end

local function GetResizeEdge()
    for _, target in ipairs(resizeTopTargets) do
        if ContainsMouse(target) then return "top" end
    end
    for _, target in ipairs(resizeBottomTargets) do
        if ContainsMouse(target) then return "bottom" end
    end
    return nil
end

local function UpdateMenuInteraction()
    if currentMenu == nil then
        resizeState = nil
        return
    end

    local mouseDown = PlayerInput.PrimaryMouseButtonDown()
    local mouseHeld = PlayerInput.PrimaryMouseButtonHeld()

    if mouseDown and resizeState == nil then
        local edge = GetResizeEdge()
        if edge ~= nil then
            local rectTransform = currentMenu.RectTransform
            resizeState = {
                Edge = edge,
                MouseY = PlayerInput.MousePosition.Y,
                Top = currentMenu.Rect.Y,
                Bottom = currentMenu.Rect.Bottom,
                Height = currentMenu.Rect.Height,
                NonScaledWidth = rectTransform.NonScaledSize.X,
                ScreenOffsetX = rectTransform.ScreenSpaceOffset.X,
                ScreenOffsetY = rectTransform.ScreenSpaceOffset.Y,
            }
        end
    end

    if not mouseHeld then
        resizeState = nil
        return
    end

    if resizeState ~= nil then
        local _, screenHeight = GetScreenSize()
        local margin = SafeIntScale(10)
        local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
        local dy = PlayerInput.MousePosition.Y - resizeState.MouseY
        local newHeight
        local newTop = resizeState.Top

        if resizeState.Edge == "top" then
            newTop = Clamp(resizeState.Top + dy, margin, resizeState.Bottom - minimumHeight)
            newHeight = resizeState.Bottom - newTop
        else
            local maximumHeight = math.max(minimumHeight, screenHeight - resizeState.Top - margin)
            newHeight = Clamp(resizeState.Height + dy, minimumHeight, maximumHeight)
        end

        local rectTransform = currentMenu.RectTransform
        local scaleY = rectTransform.Scale.Y
        local nonScaledHeight = math.max(1, math.floor(newHeight / scaleY + 0.5))
        rectTransform:Resize(Point(resizeState.NonScaledWidth, nonScaledHeight), true)

        if resizeState.Edge == "top" then
            rectTransform.ScreenSpaceOffset = Point(
                resizeState.ScreenOffsetX,
                resizeState.ScreenOffsetY + (newTop - resizeState.Top)
            )
        end

        menuX = currentMenu.Rect.X
        menuY = currentMenu.Rect.Y
        menuHeight = currentMenu.Rect.Height

        if targetList ~= nil then
            targetList:RecalculateChildren()
            targetList:UpdateScrollBarSize()
        end
    end
end

if not rawget(_G, GLOBAL_HUD_PATCH_KEY) then
    Hook.Patch("Barotrauma.GameSession", "AddToGUIUpdateList", function()
        local state = rawget(_G, GLOBAL_STATE_KEY)
        if state == nil or state.Disabled then return end
        if GUI ~= nil and GUI.DisableHUD then return end

        if state.MenuRoot ~= nil then
            state.MenuRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
        end
        if state.ButtonRoot ~= nil then
            state.ButtonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER)
        end
    end)
    _G[GLOBAL_HUD_PATCH_KEY] = true
end

if not rawget(_G, GLOBAL_PAUSE_PATCH_KEY) then
    Hook.Patch("Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, p)
        local state = rawget(_G, GLOBAL_STATE_KEY)
        if state ~= nil and not state.Disabled and state.CurrentMenu ~= nil then
            if state.CloseMenu ~= nil then state.CloseMenu() end
            if p ~= nil then p.PreventExecution = true end
            return false
        end
    end, Hook.HookMethodType.Before)
    _G[GLOBAL_PAUSE_PATCH_KEY] = true
end

Hook.Remove("think", "VoidTraitor.CameraTeleportGui.Think")
Hook.Add("think", "VoidTraitor.CameraTeleportGui.Think", function(deltaTime)
    if sharedState.Disabled then return end

    UpdateMenuInteraction()

    stateCheckTimer = stateCheckTimer + (tonumber(deltaTime) or 0)
    if stateCheckTimer < 0.1 then return end
    stateCheckTimer = 0

    local width, height = GetScreenSize()
    if width ~= lastResolutionX or height ~= lastResolutionY then
        lastResolutionX = width
        lastResolutionY = height
        DestroyBottomButton()
        if currentMenu ~= nil then ShowMenu() end
    end

    local refreshNeeded = false
    local candidate = IsLocalCandidate()
    if candidate ~= lastLocalCandidate then
        lastLocalCandidate = candidate
        refreshNeeded = true
    end

    local roundStarted = IsRoundStarted()
    if roundStarted ~= lastRoundStarted then
        lastRoundStarted = roundStarted
        refreshNeeded = true
    end

    local connected = IsConnected()
    if connected ~= lastConnected then
        lastConnected = connected
        if connected then
            refreshNeeded = true
        else
            CloseMenu()
        end
    end

    if refreshNeeded and connected then SendReady() end

    local showBottomButton = ShouldShowBottomButton()
    if showBottomButton then EnsureBottomButton() end
    if buttonRoot ~= nil then
        buttonRoot.Visible = showBottomButton and not (GUI ~= nil and GUI.DisableHUD == true)
        UpdateBottomButtonPosition()
    end

    if currentMenu ~= nil and connected then
        local now = Timer.GetTime()
        if now >= nextRefreshTime then
            nextRefreshTime = now + 1
            RequestSnapshot(false)
        end
    end
end)

Networking.Receive(NET_SNAPSHOT, function(message)
    if sharedState.Disabled then return end
    ReadSnapshot(message)
end)

UpdateBottomButton()
SendReady()
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 2000)
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 6000)
