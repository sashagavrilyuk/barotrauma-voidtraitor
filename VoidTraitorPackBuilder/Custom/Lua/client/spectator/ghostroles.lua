if SERVER then return end

local Common = select(2, ...)

local NET_READY = "VoidTraitor_GhostRolesGuiReady"
local NET_REQUEST = "VoidTraitor_GhostRolesRequest"
local NET_SNAPSHOT = "VoidTraitor_GhostRolesSnapshot"
local NET_TAKE = "VoidTraitor_GhostRolesTake"

local GLOBAL_STATE_KEY = "VoidTraitorGhostRolesGuiState"
local HUD_PATCH_ID = "VoidTraitor.GhostRolesGui.Hud"
local PAUSE_PATCH_ID = "VoidTraitor.GhostRolesGui.Pause"

local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
    if previousState.StopFollow ~= nil then previousState.StopFollow() end

    for _, key in ipairs({ "GuiRoot", "MenuRoot", "ButtonRoot" }) do
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
local bottomButtonAlert = false
local bottomButtonBaseColors = nil
local knownRoleIds = nil
local currentMenu = nil
local selectedRoleId = nil
local followCharacterId = nil
local followPosition = nil
local followCharacter = nil
local followLookupTimer = 0
local ApplyFollowPosition = nil
local canUse = false
local currentPoints = 0
local freeCount = 0
local roles = {}
local roleById = {}
local roleList = nil
local roleListScroll = 0
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
local stateCheckTimer = 0

local text = {
    Title = "GHOST ROLES",
    Button = "Ghost roles (%d)",
    Points = "Points",
    Price = "Price",
    Free = "AVAILABLE",
    Taken = "TAKEN",
    Dead = "DEAD",
    Take = "Request",
    Follow = "Follow",
    Close = "Close",
    Empty = "No ghost roles are registered right now.",
    SelectRole = "Select a role on the left to see its description.",
    FreePrice = "Free",
    NotEnoughPoints = "Not enough points",
}

local MENU_DRAW_ORDER = 122
local BUTTON_DRAW_ORDER = 121
local LIST_WIDTH_PIXELS = 370
local DETAILS_WIDTH_PIXELS = 280
local DEFAULT_HEIGHT_PIXELS = 420
local MIN_HEIGHT_PIXELS = 320
local PANEL_GAP_PIXELS = 8
local ROW_HEIGHT_PIXELS = 70
local ICON_PIXELS = 40
local DETAIL_ICON_PIXELS = 68
local BOTTOM_BUTTON_TEXT_SCALE = 0.90
local BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS = 22

local SafeIntScale = Common.SafeIntScale
local GetScreenSize = Common.GetScreenSize
local CreateRect = Common.CreateRect
local CreateCanvasRect = Common.CreateCanvasRect
local Clamp = Common.Clamp

local function SendReady()
    local msg = Networking.Start(NET_READY)
    Networking.Send(msg)
end

local function RequestSnapshot()
    local msg = Networking.Start(NET_REQUEST)
    Networking.Send(msg)
end

local function SendTake(roleId)
    local msg = Networking.Start(NET_TAKE)
    msg.WriteInt32(roleId)
    Networking.Send(msg)
end

local function Format(template, ...)
    return string.format(tostring(template or ""), ...)
end

local function GetRoleStateText(role)
    if role.State == "taken" then return text.Taken end
    if role.State == "dead" then return text.Dead end
    return text.Free
end

local function GetRoleStateColor(role)
    if role.State == "free" then return Color(145, 205, 145, 255) end
    if role.State == "dead" then return Color(185, 105, 105, 255) end
    return Color(160, 160, 160, 255)
end

local GetCharacterById = Common.GetCharacterById
local CreateText = Common.CreateText

local function CreateIcon(parent, role, pixelSize)
    return Common.CreateIcon(parent, role, pixelSize or ICON_PIXELS)
end

local function AddResizeHandles(panel)
    Common.AddResizeHandles(panel, resizeTopTargets, resizeBottomTargets)
end

local function SaveMenuGeometry()
    if currentMenu == nil then return end
    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuHeight = currentMenu.Rect.Height
end

local function CloseMenu()
    if roleList ~= nil then
        roleListScroll = roleList.BarScroll
    end
    roleList = nil
    SaveMenuGeometry()
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil

    if currentMenu ~= nil then
        currentMenu:RemoveFromGUIUpdateList(true)
        currentMenu.Visible = false
        if currentMenu.RectTransform ~= nil then currentMenu.RectTransform.Parent = nil end
    end

    currentMenu = nil
    sharedState.CurrentMenu = nil
    sharedState.MenuRoot = nil
end

sharedState.CloseMenu = CloseMenu

local function AddMenuToUpdateList()
    if currentMenu == nil then return end
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
end

local function AddButtonToUpdateList()
    if buttonRoot == nil then return end
    buttonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER)
end

local function DestroyBottomButton()
    if buttonRoot == nil then return end
    buttonRoot:RemoveFromGUIUpdateList(true)
    buttonRoot.Visible = false
    if buttonRoot.RectTransform ~= nil then buttonRoot.RectTransform.Parent = nil end
    buttonRoot = nil
    bottomButton = nil
    bottomButtonBaseColors = nil
    sharedState.ButtonRoot = nil
end

local ShouldShowBottomButton = Common.ShouldShowBottomButton

local function ResizeBottomButtonToText()
    Common.ResizeButtonToText(bottomButton, BOTTOM_BUTTON_HORIZONTAL_PADDING_PIXELS, 32)
end

local function ApplyBottomButtonAlertStyle(flash)
    if bottomButton == nil or bottomButtonBaseColors == nil then return end

    if bottomButtonAlert then
        bottomButton.Color = Color(150, 45, 45, 255)
        bottomButton.HoverColor = Color(185, 55, 55, 255)
        bottomButton.SelectedColor = Color(205, 65, 65, 255)
        bottomButton.PressedColor = Color(205, 65, 65, 255)
        if flash then
            bottomButton:Flash(Color(245, 105, 105, 255), 1.5, true)
        end
    else
        bottomButton.Color = bottomButtonBaseColors.Color
        bottomButton.HoverColor = bottomButtonBaseColors.HoverColor
        bottomButton.SelectedColor = bottomButtonBaseColors.SelectedColor
        bottomButton.PressedColor = bottomButtonBaseColors.PressedColor
    end
end

local function ClearBottomButtonAlert()
    if not bottomButtonAlert then return end
    bottomButtonAlert = false
    ApplyBottomButtonAlertStyle(false)
end

local function CreateBottomButton()
    DestroyBottomButton()

    local height = SafeIntScale(32)
    local canvas = GUI.Canvas.Instance
    local rectTransform = GUI.RectTransform(Point(SafeIntScale(190), height), canvas, GUI.Anchor.BottomCenter)
    rectTransform.AbsoluteOffset = Point(0, SafeIntScale(18))

    bottomButton = GUI.Button(rectTransform, Format(text.Button, freeCount), GUI.Alignment.Center, "GUIButtonSmall")
    bottomButton.CanBeFocused = true
    bottomButtonBaseColors = {
        Color = bottomButton.Color,
        HoverColor = bottomButton.HoverColor,
        SelectedColor = bottomButton.SelectedColor,
        PressedColor = bottomButton.PressedColor,
    }
    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end
    ApplyBottomButtonAlertStyle(false)
    bottomButton.OnClicked = function()
        ClearBottomButtonAlert()
        RequestSnapshot()
        return true
    end

    buttonRoot = bottomButton
    sharedState.ButtonRoot = buttonRoot
    AddButtonToUpdateList()
    return true
end

local function EnsureBottomButton()
    if sharedState.Disabled or not ShouldShowBottomButton() then return end
    if buttonRoot == nil then CreateBottomButton() end
end

sharedState.EnsureBottomButton = EnsureBottomButton
sharedState.GetButtonWidth = function()
    if bottomButton == nil then return 0 end
    return bottomButton.Rect.Width
end

local function UpdateBottomButton()
    if not ShouldShowBottomButton() then
        if buttonRoot ~= nil then buttonRoot.Visible = false end
        return
    end

    EnsureBottomButton()
    if bottomButton == nil or buttonRoot == nil then return end

    if bottomButton.TextBlock ~= nil then
        bottomButton.TextBlock.Text = Format(text.Button, freeCount)
        bottomButton.TextBlock.TextScale = BOTTOM_BUTTON_TEXT_SCALE
        ResizeBottomButtonToText()
    end

    ApplyBottomButtonAlertStyle(false)
    buttonRoot.Visible = not (GUI ~= nil and GUI.DisableHUD == true)
end

local function StartFollow(characterId, position)
    characterId = tonumber(characterId)
    if characterId == nil or characterId <= 0 or position == nil then return false end

    followCharacterId = characterId
    followPosition = position
    followCharacter = GetCharacterById(characterId)
    followLookupTimer = 0
    return ApplyFollowPosition(followPosition)
end

sharedState.StartFollow = StartFollow

local function CanTake(role)
    return role ~= nil and role.CanTake == true
end

local function CanFollow(role)
    return role ~= nil and role.State ~= "dead" and role.CharacterId ~= nil and role.CharacterId > 0
end

local function SelectRole(roleId)
    selectedRoleId = roleId
end

local ShowMenu

local function CreateRoleRow(list, role)
    local row = GUI.Frame(CreateRect(1, 0.12, list.Content, GUI.Anchor.TopLeft), nil)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false
    local rowHeight = SafeIntScale(ROW_HEIGHT_PIXELS)
    row.RectTransform.MinSize = Point(0, rowHeight)
    row.RectTransform.MaxSize = Point(100000, rowHeight)

    local selectButton = GUI.Button(CreateRect(1, 0.64, row, GUI.Anchor.TopCenter), "", GUI.Alignment.Center, "ListBoxElement")
    selectButton.Selected = selectedRoleId == role.Id
    if selectButton.TextBlock ~= nil then selectButton.TextBlock.Text = "" end
    selectButton.OnClicked = function()
        SelectRole(role.Id)
        ShowMenu()
        return true
    end

    local iconHolder = GUI.Frame(CreateRect(0.18, 0.88, selectButton, GUI.Anchor.CenterLeft), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    CreateIcon(iconHolder, role, ICON_PIXELS)

    local content = GUI.Frame(CreateRect(0.78, 0.86, selectButton, GUI.Anchor.CenterRight), nil)
    content.Color = Color(0, 0, 0, 0)
    content.CanBeFocused = false

    local name = CreateText(content, 1, 0.52, GUI.Anchor.TopLeft, tostring(role.Name or ""), GUI.Alignment.Left, 0.88, Color(235, 225, 190, 255), true)
    name.Font = GUI.Style.SubHeadingFont

    local priceText = role.Price > 0 and (tostring(role.Price) .. " pt") or text.FreePrice
    CreateText(content, 1, 0.40, GUI.Anchor.BottomLeft, GetRoleStateText(role) .. "  |  " .. priceText, GUI.Alignment.Left, 1.28, GetRoleStateColor(role), false)

    local actions = GUI.Frame(CreateRect(0.78, 0.31, row, GUI.Anchor.BottomRight), nil)
    actions.Color = Color(0, 0, 0, 0)
    actions.CanBeFocused = false

    local take = GUI.Button(CreateRect(0.485, 1, actions, GUI.Anchor.BottomLeft), text.Take, GUI.Alignment.Center, "GUIButtonSmall")
    take.Enabled = CanTake(role)
    take.ToolTip = (role.State == "free" and not role.CanTake) and text.NotEnoughPoints or ""
    take.OnClicked = function()
        if CanTake(role) then SendTake(role.Id) end
        return true
    end

    local follow = GUI.Button(CreateRect(0.485, 1, actions, GUI.Anchor.BottomRight), text.Follow, GUI.Alignment.Center, "GUIButtonSmall")
    follow.Enabled = CanFollow(role)
    follow.OnClicked = function()
        if CanFollow(role) then
            StartFollow(role.CharacterId, Vector2(tonumber(role.WorldX) or 0, tonumber(role.WorldY) or 0))
            CloseMenu()
            UpdateBottomButton()
        end
        return true
    end
end

local function BuildListPanel(root, groupWidth, listWidth)
    local panelRect = GUI.RectTransform(Vector2(listWidth / groupWidth, 1), root.RectTransform, GUI.Anchor.TopLeft)
    local panel = GUI.Frame(panelRect, "GUIFrame")
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

    CreateText(content, 1, 0.034, nil, text.Points .. ": " .. tostring(currentPoints), GUI.Alignment.Left, 0.76, Color(225, 220, 195, 255), false)
    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local listFrame = GUI.Frame(CreateRect(1, 0.875, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    if #roles == 0 then
        CreateText(listFrame, 0.90, 0.24, GUI.Anchor.Center, text.Empty, GUI.Alignment.Center, 0.88, Color(195, 195, 185, 255), true)
        roleList = nil
    else
        roleList = GUI.ListBox(CreateRect(1, 0.985, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
        roleList.Color = Color(0, 0, 0, 0)
        roleList.ContentBackground.Color = Color(0, 0, 0, 0)
        roleList.KeepSpaceForScrollBar = true

        for _, role in ipairs(roles) do CreateRoleRow(roleList, role) end
        roleList.BarScroll = roleListScroll
        roleList:RecalculateChildren()
        roleList:UpdateScrollBarSize()
    end

    AddResizeHandles(panel)
    return panel
end

local function BuildDetailsPanel(root, role, groupWidth, listWidth, gapWidth, detailsWidth)
    if role == nil then return nil end

    local panelRect = GUI.RectTransform(Vector2(detailsWidth / groupWidth, 1), root.RectTransform, GUI.Anchor.TopLeft)
    panelRect.RelativeOffset = Vector2((listWidth + gapWidth) / groupWidth, 0)
    local panel = GUI.Frame(panelRect, "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.92, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.004

    local header = GUI.Frame(CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.82, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.09, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = CreateText(dragArea, 0.88, 1, GUI.Anchor.CenterRight, tostring(role.Name or ""), GUI.Alignment.Left, 0.96, Color(235, 205, 145, 255), true)
    title.Font = GUI.Style.SubHeadingFont

    local close = GUI.Button(CreateRect(0.12, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.ToolTip = text.Close
    close.OnClicked = function()
        selectedRoleId = nil
        ShowMenu()
        return true
    end

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local summary = GUI.LayoutGroup(CreateRect(1, 0.175, content, nil), true, GUI.Anchor.CenterLeft)
    summary.Stretch = true
    summary.RelativeSpacing = 0.012

    local iconHolder = GUI.Frame(CreateRect(0.30, 1, summary, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    CreateIcon(iconHolder, role, DETAIL_ICON_PIXELS)

    local summaryText = GUI.Frame(CreateRect(0.67, 0.88, summary, nil), nil)
    summaryText.Color = Color(0, 0, 0, 0)
    summaryText.CanBeFocused = false

    CreateText(summaryText, 1, 0.42, GUI.Anchor.TopLeft, GetRoleStateText(role), GUI.Alignment.Left, 0.80, GetRoleStateColor(role), false)
    local priceText = role.Price > 0 and (text.Price .. ": " .. tostring(role.Price) .. " pt") or text.FreePrice
    CreateText(summaryText, 1, 0.38, GUI.Anchor.BottomLeft, priceText, GUI.Alignment.Left, 0.76, Color(220, 215, 195, 255), false)

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local descriptionFrame = GUI.Frame(CreateRect(1, 0.735, content, nil), "GUIFrameListBox")
    descriptionFrame.CanBeFocused = false
    local descriptionList = GUI.ListBox(CreateRect(0.95, 0.95, descriptionFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    descriptionList.Color = Color(0, 0, 0, 0)
    descriptionList.ContentBackground.Color = Color(0, 0, 0, 0)
    descriptionList.KeepSpaceForScrollBar = true

    local description = CreateText(descriptionList.Content, 1, 0.2, GUI.Anchor.TopLeft, tostring(role.Description or ""), GUI.Alignment.TopLeft, 0.84, Color(220, 220, 210, 255), true)
    description.CalculateHeightFromText()
    descriptionList:RecalculateChildren()
    descriptionList:UpdateScrollBarSize()

    AddResizeHandles(panel)
    return panel
end

local function GetMenuDimensions(hasDetails)
    local listWidth = SafeIntScale(LIST_WIDTH_PIXELS)
    local detailsWidth = SafeIntScale(DETAILS_WIDTH_PIXELS)
    local gapWidth = SafeIntScale(PANEL_GAP_PIXELS)
    local height = menuHeight or SafeIntScale(DEFAULT_HEIGHT_PIXELS)
    local groupWidth = listWidth
    if hasDetails then groupWidth = groupWidth + gapWidth + detailsWidth end
    return groupWidth, height, listWidth, detailsWidth, gapWidth
end

ShowMenu = function()
    if not canUse then
        CloseMenu()
        UpdateBottomButton()
        return
    end

    ClearBottomButtonAlert()

    if selectedRoleId ~= nil and roleById[selectedRoleId] == nil then
        selectedRoleId = nil
    end

    CloseMenu()

    local selectedRole = roleById[selectedRoleId]
    local groupWidth, height, listWidth, detailsWidth, gapWidth = GetMenuDimensions(selectedRole ~= nil)
    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local maximumHeight = math.max(minimumHeight, screenHeight - (margin * 2))
    height = Clamp(height, minimumHeight, maximumHeight)
    menuHeight = height

    local x = menuX
    local y = menuY
    if x == nil then x = math.floor((screenWidth - groupWidth) / 2) end
    if y == nil then y = math.floor((screenHeight - height) / 2) end
    x = Clamp(x, margin, math.max(margin, screenWidth - groupWidth - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))
    menuX = x
    menuY = y

    local menuRect = CreateCanvasRect(x, y, groupWidth, height)
    if menuRect == nil then return end

    currentMenu = GUI.Frame(menuRect, nil)
    currentMenu.Color = Color(0, 0, 0, 0)
    currentMenu.CanBeFocused = false
    currentMenu.IgnoreLayoutGroups = true
    sharedState.CurrentMenu = currentMenu
    sharedState.MenuRoot = currentMenu

    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeState = nil

    BuildListPanel(currentMenu, groupWidth, listWidth)
    if selectedRole ~= nil then
        BuildDetailsPanel(currentMenu, selectedRole, groupWidth, listWidth, gapWidth, detailsWidth)
    end

    AddMenuToUpdateList()
    UpdateBottomButton()
end

local function ReadSnapshot(message)
    local openMenu = message.ReadBoolean()
    canUse = message.ReadBoolean()
    currentPoints = message.ReadInt32()
    freeCount = message.ReadInt32()

    local count = message.ReadInt32()
    local newRoleIds = {}
    roles = {}
    roleById = {}

    for _ = 1, count do
        local role = {
            Id = message.ReadInt32(),
            Name = message.ReadString(),
            Description = message.ReadString(),
            Price = message.ReadInt32(),
            State = message.ReadString(),
            CharacterId = message.ReadInt32(),
            WorldX = message.ReadSingle(),
            WorldY = message.ReadSingle(),
            Icon = message.ReadString(),
            CanTake = message.ReadBoolean(),
        }
        table.insert(roles, role)
        roleById[role.Id] = role
        newRoleIds[role.Id] = true
    end

    local hasNewRole = false
    if knownRoleIds ~= nil then
        for roleId in pairs(newRoleIds) do
            if knownRoleIds[roleId] ~= true then
                hasNewRole = true
                break
            end
        end
    end
    knownRoleIds = newRoleIds

    if hasNewRole and currentMenu == nil then
        bottomButtonAlert = true
    end

    local textCount = message.ReadInt32()
    for _ = 1, textCount do
        local key = message.ReadString()
        local value = message.ReadString()
        if key ~= nil and key ~= "" then text[key] = value or "" end
    end

    UpdateBottomButton()
    if hasNewRole and currentMenu == nil then
        ApplyBottomButtonAlertStyle(true)
    end

    if not canUse then
        CloseMenu()
    elseif openMenu or currentMenu ~= nil then
        ShowMenu()
    end
end

local IsLocalCandidate = Common.IsLocalCandidate
local IsRoundStarted = Common.IsRoundStarted
local IsConnected = Common.IsConnected

local function StopFollow()
    followCharacterId = nil
    followPosition = nil
    followCharacter = nil
    followLookupTimer = 0

    local gameScreen = Game ~= nil and Game.GameScreen or nil
    local camera = gameScreen ~= nil and gameScreen.Cam or nil
    if camera ~= nil then
        camera.TargetPos = Vector2.Zero
        camera:StopMovement()
    end
end

sharedState.StopFollow = StopFollow

ApplyFollowPosition = function(position)
    local gameScreen = Game ~= nil and Game.GameScreen or nil
    local camera = gameScreen ~= nil and gameScreen.Cam or nil
    if camera == nil or position == nil then return false end

    camera.Position = position
    camera.TargetPos = position
    camera:StopMovement()
    return true
end

local function IsMovementDown()
    local bindings = GameSettings.CurrentConfig.KeyMap.Bindings
    return bindings[InputType.Left].IsDown()
        or bindings[InputType.Right].IsDown()
        or bindings[InputType.Up].IsDown()
        or bindings[InputType.Down].IsDown()
end

local function UpdateFollow(deltaTime)
    if followCharacterId == nil or followPosition == nil then return end

    if not IsLocalCandidate() or IsMovementDown() then
        StopFollow()
        return
    end

    if followCharacter == nil then
        followLookupTimer = followLookupTimer + (tonumber(deltaTime) or 0)
        if followLookupTimer >= 0.5 then
            followLookupTimer = 0
            followCharacter = GetCharacterById(followCharacterId)
        end
    end

    if followCharacter ~= nil then
        if followCharacter.Removed or followCharacter.IsDead then
            StopFollow()
            return
        end
        followPosition = followCharacter.WorldPosition
    end

    ApplyFollowPosition(followPosition)
end

local function UpdateMenuInteraction()
    resizeState, menuX, menuY, menuHeight = Common.UpdateMenuInteraction(
        currentMenu, resizeState, resizeTopTargets, resizeBottomTargets,
        MIN_HEIGHT_PIXELS, roleList, menuX, menuY, menuHeight
    )
end

Common.InstallHudPatch(HUD_PATCH_ID, GLOBAL_STATE_KEY, MENU_DRAW_ORDER, BUTTON_DRAW_ORDER)
Common.InstallPausePatch(PAUSE_PATCH_ID, GLOBAL_STATE_KEY)

Hook.Remove("think", "VoidTraitor.GhostRolesGui.Think")
Hook.Add("think", "VoidTraitor.GhostRolesGui.Think", function(deltaTime)
    if sharedState.Disabled then return end

    UpdateMenuInteraction()
    UpdateFollow(deltaTime)

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
        if not roundStarted then
            knownRoleIds = nil
            bottomButtonAlert = false
        end
    end

    local connected = IsConnected()
    if connected ~= lastConnected then
        lastConnected = connected
        if connected then
            refreshNeeded = true
        else
            knownRoleIds = nil
            bottomButtonAlert = false
            CloseMenu()
            StopFollow()
        end
    end

    if refreshNeeded and connected then SendReady() end

    local showBottomButton = ShouldShowBottomButton()
    if showBottomButton then
        EnsureBottomButton()
    end

    if buttonRoot ~= nil then
        buttonRoot.Visible = showBottomButton and not (GUI ~= nil and GUI.DisableHUD == true)
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
