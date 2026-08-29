if SERVER then return end

-- Void Traitor quick menu.
-- Client-side buttons only. Every action is validated and executed on the server.

local NET_READY = "VoidTraitor_ClientMenuGuiReady"
local NET_REQUEST = "VoidTraitor_ClientMenuRequest"
local NET_SNAPSHOT = "VoidTraitor_ClientMenuSnapshot"
local NET_RUN = "VoidTraitor_ClientMenuRun"
local NET_POINTSHOP_REQUEST = "VoidTraitor_PointshopRequest"
local NET_VOTE_READY = "VoidTraitor_LobbyVoteGuiReady"
local NET_VOTE_REQUEST = "VoidTraitor_LobbyVoteRequest"
local NET_VOTE_SNAPSHOT = "VoidTraitor_LobbyVoteSnapshot"
local NET_VOTE_START = "VoidTraitor_LobbyVoteStart"
local NET_VOTE_CAST = "VoidTraitor_LobbyVoteCast"

local GLOBAL_STATE_KEY = "VoidTraitorClientMenuState"
local HUD_PATCH_ID = "VoidTraitor.ClientMenu.Hud"
local PAUSE_PATCH_ID = "VoidTraitor.ClientMenu.Pause"

local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then pcall(previousState.CloseMenu) end
    if previousState.ButtonRoot ~= nil then
        pcall(function() previousState.ButtonRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            previousState.ButtonRoot.Visible = false
            if previousState.ButtonRoot.RectTransform ~= nil then
                previousState.ButtonRoot.RectTransform.Parent = nil
            end
        end)
    end
    if previousState.VoteButtonRoot ~= nil then
        pcall(function() previousState.VoteButtonRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            previousState.VoteButtonRoot.Visible = false
            if previousState.VoteButtonRoot.RectTransform ~= nil then
                previousState.VoteButtonRoot.RectTransform.Parent = nil
            end
        end)
    end
    if previousState.GuiRoot ~= nil then
        pcall(function() previousState.GuiRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            previousState.GuiRoot.Visible = false
            if previousState.GuiRoot.RectTransform ~= nil then
                previousState.GuiRoot.RectTransform.Parent = nil
            end
        end)
    end
end

local sharedState = { Disabled = false }
_G[GLOBAL_STATE_KEY] = sharedState

local buttonRoot = nil
local voteButtonRoot = nil
local voteButtonParent = nil
local guiRoot = nil
local currentMenu = nil
local currentMenuKind = ""
local activeVoteUi = nil
local lastResolutionX = -1
local lastResolutionY = -1
local escapeClosePending = false
local menuEntries = nil
local pendingMenuOpen = false
local voteSnapshot = nil
local pendingVoteMenuOpen = false
local lastActiveVoteId = ""
local lastShownActiveVoteId = ""
local lastVoteButtonResolutionX = -1
local lastVoteButtonResolutionY = -1
local uiStateCheckTimer = 0
local vtMenuList = nil
local vtMenuScroll = 0
local vtMenuX = nil
local vtMenuY = nil
local vtMenuWidth = nil
local vtMenuHeight = nil
local vtResizeTargets = {}
local vtResizeState = nil
local uiText = {
    Title = "VOID TRAITOR",
    ShopButton = "SHOP",
    MainButton = "VT",
    ShopTooltip = "Open Void Traitor Pointshop",
    MainTooltip = "Open Void Traitor command menu",
    NoCommands = "No commands were received from the server.",
    GenericCommand = "Command",
    DefaultConfirmTitle = "Confirmation",
    Cancel = "Cancel",
    Yes = "Yes",
    Ok = "OK",
}

local voteUiText = {
    Button = "Начать голосование",
    Tooltip = "Открыть меню голосования в лобби",
    StartTitle = "Vote",
    StartMode = "Start game mode vote",
    StartMap = "Start submarine vote",
    StartBlockedReason = "",
    Close = "Close",
    NoActive = "No active vote right now.",
    StartedBy = "Started by",
    Timer = "Time left",
    Votes = "votes",
}

local BUTTON_DRAW_ORDER = 100
local MENU_DRAW_ORDER = 125
local VT_MENU_DEFAULT_WIDTH_PIXELS = 460
local VT_MENU_DEFAULT_HEIGHT_PIXELS = 580
local VT_MENU_MIN_WIDTH_PIXELS = 360
local VT_MENU_MIN_HEIGHT_PIXELS = 340
local VT_MENU_MARGIN_PIXELS = 10
local VT_RESIZE_EDGE_PIXELS = 10
local VT_RESIZE_CORNER_PIXELS = 22
local VT_BUTTON_HEIGHT_PIXELS = 42
local VT_CATEGORY_HEIGHT_PIXELS = 30
local VT_DIVIDER_HEIGHT_PIXELS = 10
local VT_INPUT_LABEL_HEIGHT_PIXELS = 24
local VT_INPUT_ROW_HEIGHT_PIXELS = 40

local function SafeIntScale(value)
    local ok, result = pcall(function()
        if GUI ~= nil and GUI.IntScale ~= nil then
            return GUI.IntScale(value)
        end
        return nil
    end)

    if ok and tonumber(result) ~= nil then
        return tonumber(result)
    end

    local scale = 1
    pcall(function()
        if GUI ~= nil and GUI.Scale ~= nil then
            scale = tonumber(GUI.Scale) or 1
        end
    end)
    return math.floor(value * scale)
end

local function GetScreenSize()
    local width = 1920
    local height = 1080

    pcall(function()
        if GameMain ~= nil and GameMain.GraphicsWidth ~= nil then
            width = GameMain.GraphicsWidth
        end
        if GameMain ~= nil and GameMain.GraphicsHeight ~= nil then
            height = GameMain.GraphicsHeight
        end
    end)

    return width, height
end

local function Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function GetParentRect(parent)
    if parent == nil or parent == GUI.Canvas then
        return nil
    end

    local ok, rectTransform = pcall(function()
        return parent.RectTransform
    end)

    if ok and rectTransform ~= nil then
        return rectTransform
    end

    return parent
end

local function CreateRect(width, height, parent, anchor)
    return GUI.RectTransform(Vector2(width, height), GetParentRect(parent), anchor)
end

local function CreatePixelRect(width, height, parent, anchor)
    return GUI.RectTransform(Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))), GetParentRect(parent), anchor)
end

local function SetFixedHeight(component, pixels)
    if component == nil or component.RectTransform == nil then return end
    local height = SafeIntScale(pixels)
    component.RectTransform.MinSize = Point(0, height)
    component.RectTransform.MaxSize = Point(100000, height)
end

guiRoot = GUI.Frame(CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
guiRoot.Color = Color(0, 0, 0, 0)
guiRoot.CanBeFocused = false
guiRoot.IgnoreLayoutGroups = true
sharedState.GuiRoot = guiRoot
pcall(function() guiRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER) end)

local function CreateButtonAreaRect(buttonWidth, buttonHeight, buttonCount, padding)
    buttonCount = buttonCount or 2
    padding = padding or SafeIntScale(11)

    local ok, rect = pcall(function()
        local buttonArea = HUDLayoutSettings.ButtonAreaTop
        local x = buttonArea.X + ((buttonWidth + padding) * 3)
        local y = buttonArea.Center.Y - math.floor(buttonHeight / 2)
        local width = (buttonWidth * buttonCount) + (padding * math.max(buttonCount - 1, 0))
        return HUDLayoutSettings.ToRectTransform(Rectangle(x, y, width, buttonHeight), GUI.Canvas)
    end)

    if ok and rect ~= nil then
        return rect
    end

    local rectTransform = GUI.RectTransform(Point((buttonWidth * buttonCount) + padding, buttonHeight), nil, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(SafeIntScale(11) + ((buttonWidth + padding) * 3), SafeIntScale(11))
    return rectTransform
end

local function GetTopButtonSize()
    local buttonHeight = SafeIntScale(40)
    local buttonWidth = math.floor(buttonHeight * 1.72)

    pcall(function()
        local style = GUIStyle.GetComponentStyle("CrewListToggleButton")
        if style == nil then return end
        local sprite = style:GetDefaultSprite()
        if sprite == nil or sprite.size == nil then return end

        local spriteSize = sprite.size
        local spriteWidth = tonumber(spriteSize.X) or tonumber(spriteSize.x) or 0
        local spriteHeight = tonumber(spriteSize.Y) or tonumber(spriteSize.y) or 0
        if spriteWidth > 0 and spriteHeight > 0 then
            buttonWidth = math.floor((buttonHeight / spriteHeight) * spriteWidth)
        end
    end)

    return buttonWidth, buttonHeight
end

local function GetTopButtonSpacing()
    local spacing = SafeIntScale(11)
    pcall(function()
        if HUDLayoutSettings ~= nil and HUDLayoutSettings.Padding ~= nil then
            spacing = HUDLayoutSettings.Padding
        end
    end)
    return spacing
end

local function SendNetMessage(identifier, writer)
    local ok, err = pcall(function()
        local msg = Networking.Start(identifier)
        if writer ~= nil then writer(msg) end
        Networking.Send(msg)
    end)

    if not ok then
        print("[VoidTraitor.ClientMenu] Failed to send " .. tostring(identifier) .. ": " .. tostring(err))
    end
end

local function GetTime()
    local ok, result = pcall(function()
        if Timer ~= nil and Timer.GetTime ~= nil then
            return Timer.GetTime()
        end
        return 0
    end)

    if ok and tonumber(result) ~= nil then
        return tonumber(result)
    end

    return 0
end

local function SendReady()
    SendNetMessage(NET_READY)
end

local function SendCommand(command, input)
    SendNetMessage(NET_RUN, function(msg)
        msg.WriteString(command or "")
        msg.WriteString(tostring(input or ""))
    end)
end

local function RequestPointshop()
    SendNetMessage(NET_POINTSHOP_REQUEST)
end

local function RequestMenuSnapshot(openAfterResponse)
    pendingMenuOpen = openAfterResponse == true
    SendNetMessage(NET_REQUEST)
end

local function SendVoteReady()
    SendNetMessage(NET_VOTE_READY)
end

local function RequestVoteSnapshot(openAfterResponse)
    pendingVoteMenuOpen = openAfterResponse == true
    SendNetMessage(NET_VOTE_REQUEST)
end

local function SendVoteStart(voteType)
    SendNetMessage(NET_VOTE_START, function(msg)
        msg.WriteString(tostring(voteType or ""))
    end)
end

local function SendVoteCast(optionId)
    SendNetMessage(NET_VOTE_CAST, function(msg)
        msg.WriteInt32(tonumber(optionId or 0) or 0)
    end)
end

local function SaveVoidTraitorMenuGeometry()
    if currentMenu == nil or currentMenuKind ~= "vt" then return end

    local rect = currentMenu.Rect
    vtMenuX = rect.X
    vtMenuY = rect.Y
    vtMenuWidth = rect.Width
    vtMenuHeight = rect.Height
    if vtMenuList ~= nil then vtMenuScroll = vtMenuList.BarScroll end
end

local CloseMenu

CloseMenu = function()
    SaveVoidTraitorMenuGeometry()

    if currentMenu ~= nil then
        pcall(function() currentMenu:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            if currentMenu.RectTransform ~= nil then
                currentMenu.RectTransform.Parent = nil
            end
            currentMenu.Visible = false
        end)
    end

    currentMenu = nil
    currentMenuKind = ""
    activeVoteUi = nil
    vtMenuList = nil
    vtResizeTargets = {}
    vtResizeState = nil
    sharedState.CurrentMenu = nil
    sharedState.CurrentMenuKind = ""
    escapeClosePending = false
end

sharedState.CloseMenu = CloseMenu

local function IsEscapeHit()
    local ok, hit = pcall(function()
        if Keys ~= nil and Keys.Escape ~= nil then
            return PlayerInput.KeyHit(Keys.Escape)
        end
        return false
    end)
    if ok and hit then return true end

    ok, hit = pcall(function()
        return PlayerInput.KeyHit(Microsoft.Xna.Framework.Input.Keys.Escape)
    end)
    return ok and hit == true
end

local function RequestEscapeClose()
    if currentMenu == nil or escapeClosePending then return end

    if currentMenuKind == "voteactive" then
        return
    end

    escapeClosePending = true
    sharedState.BlockPauseMenu = true
    CloseMenu()
    Timer.Wait(function()
        sharedState.BlockPauseMenu = false
    end, 250)
end

local function CreateText(parent, width, height, anchor, label, alignment, scale, color, wrap)
    if wrap == nil then wrap = true end
    local block = GUI.TextBlock(CreateRect(width, height, parent, anchor), label or "", nil, nil, alignment or GUI.Alignment.Left, wrap)
    block.TextColor = color or Color(230, 230, 220, 255)
    block.TextScale = scale or 1
    return block
end

local function SetButtonTextScale(button, scale)
    if button == nil then return end
    pcall(function()
        if button.TextBlock ~= nil then
            button.TextBlock.TextScale = scale
            button.TextBlock.AutoScaleHorizontal = true
        end
    end)
end

local function ResolveGuiSoundType(name)
    local candidates = {
        function() if GUI ~= nil and GUI.SoundType ~= nil then return GUI.SoundType[name] end end,
        function() if GUISoundType ~= nil then return GUISoundType[name] end end,
        function() if Barotrauma ~= nil and Barotrauma.GUISoundType ~= nil then return Barotrauma.GUISoundType[name] end end,
    }

    for _, getter in ipairs(candidates) do
        local ok, value = pcall(getter)
        if ok and value ~= nil then return value end
    end

    return nil
end

local function TryPlaySoundTag(soundTag, volume)
    if soundTag == nil or soundTag == "" then return false end

    local attempts = {
        function() return SoundPlayer.PlaySound(soundTag, volume or 1.0) end,
        function() return Barotrauma.SoundPlayer.PlaySound(soundTag, volume or 1.0) end,
    }

    for _, attempt in ipairs(attempts) do
        local ok, channel = pcall(attempt)
        if ok and channel ~= nil then return true end
    end

    return false
end

local function PlayVoteSound()
    if TryPlaySoundTag("voteding", 1.0) then return end

    local soundType = ResolveGuiSoundType("Cart") or ResolveGuiSoundType("Select")
    if soundType == nil then return end

    local attempts = {
        function() SoundPlayer.PlayUISound(soundType) end,
        function() Barotrauma.SoundPlayer.PlayUISound(soundType) end,
        function() GUI.AddMessage(" ", Color(255, 255, 255, 1), Vector2(0, 0), Vector2(0, 0), 0.10, true, soundType, -1) end,
    }

    for _, attempt in ipairs(attempts) do
        if pcall(attempt) then return end
    end
end

local function CreateMenuButton(parent, label, enabled)
    local button = GUI.Button(CreateRect(1, 0.10, parent, nil), label or "", GUI.Alignment.Center, "GUIButton")
    SetFixedHeight(button, VT_BUTTON_HEIGHT_PIXELS)
    button.Enabled = enabled ~= false
    SetButtonTextScale(button, 0.92)
    return button
end

local function CreateDivider(parent)
    local frame = GUI.Frame(CreateRect(1, 0.02, parent, nil), nil)
    SetFixedHeight(frame, VT_DIVIDER_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)
    pcall(function()
        GUI.Image(CreateRect(1, 0.50, frame, GUI.Anchor.Center), "HorizontalLine")
    end)
end

local function CreateCategoryHeader(parent, label)
    local frame = GUI.Frame(CreateRect(1, 0.06, parent, nil), nil)
    SetFixedHeight(frame, VT_CATEGORY_HEIGHT_PIXELS)
    frame.Color = Color(0, 0, 0, 0)

    local text = CreateText(frame, 1, 0.82, GUI.Anchor.BottomLeft, string.upper(tostring(label or "")), GUI.Alignment.Left, 0.88, Color(205, 220, 200, 255), false)
    pcall(function() text.Font = GUI.Style.SubHeadingFont end)
    return frame
end

local function CreateTextInputRow(parent, label, placeholder, action, clearAfterSend)
    local labelBlock = CreateText(parent, 1, 0.05, nil, label, GUI.Alignment.Left, 0.86, Color(210, 220, 200, 255), false)
    SetFixedHeight(labelBlock, VT_INPUT_LABEL_HEIGHT_PIXELS)
    pcall(function() labelBlock.Font = GUI.Style.SubHeadingFont end)

    local row = GUI.LayoutGroup(CreateRect(1, 0.09, parent, nil), true, GUI.Anchor.CenterLeft)
    SetFixedHeight(row, VT_INPUT_ROW_HEIGHT_PIXELS)
    row.Stretch = true
    pcall(function() row.RelativeSpacing = 0.010 end)

    local input = GUI.TextBox(CreateRect(0.66, 1, row, nil), placeholder or "")
    pcall(function()
        if input.TextBlock ~= nil then
            input.TextBlock.TextScale = 0.86
        end
    end)

    local sendButton = GUI.Button(CreateRect(0.32, 1, row, nil), uiText.Ok, GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(sendButton, 0.90)
    sendButton.OnClicked = function()
        local value = ""
        pcall(function() value = input.Text or "" end)
        SendCommand(action, value)
        if clearAfterSend then
            pcall(function() input.Text = "" end)
        end
        return true
    end

    return input
end

local function AddVoidTraitorResizeHandle(panel, edge, width, height, anchor)
    local handle = GUI.Frame(CreateRect(width, height, panel, anchor), nil)
    handle.Color = Color(0, 0, 0, 0)
    handle.CanBeFocused = true
    table.insert(vtResizeTargets, { Component = handle, Edge = edge })
    return handle
end

local function AddVoidTraitorResizeHandles(panel)
    vtResizeTargets = {}

    local cornerScaleX = SafeIntScale(VT_RESIZE_CORNER_PIXELS) / math.max(panel.Rect.Width, 1)
    local cornerScaleY = SafeIntScale(VT_RESIZE_CORNER_PIXELS) / math.max(panel.Rect.Height, 1)
    local edgeScaleX = SafeIntScale(VT_RESIZE_EDGE_PIXELS) / math.max(panel.Rect.Width, 1)
    local edgeScaleY = SafeIntScale(VT_RESIZE_EDGE_PIXELS) / math.max(panel.Rect.Height, 1)

    AddVoidTraitorResizeHandle(panel, "topleft", cornerScaleX, cornerScaleY, GUI.Anchor.TopLeft)
    AddVoidTraitorResizeHandle(panel, "topright", cornerScaleX, cornerScaleY, GUI.Anchor.TopRight)
    AddVoidTraitorResizeHandle(panel, "bottomleft", cornerScaleX, cornerScaleY, GUI.Anchor.BottomLeft)
    AddVoidTraitorResizeHandle(panel, "bottomright", cornerScaleX, cornerScaleY, GUI.Anchor.BottomRight)

    local top = AddVoidTraitorResizeHandle(panel, "top", 0.72, edgeScaleY, GUI.Anchor.TopCenter)
    local bottom = AddVoidTraitorResizeHandle(panel, "bottom", 0.72, edgeScaleY, GUI.Anchor.BottomCenter)
    local left = AddVoidTraitorResizeHandle(panel, "left", edgeScaleX, 0.72, GUI.Anchor.CenterLeft)
    local right = AddVoidTraitorResizeHandle(panel, "right", edgeScaleX, 0.72, GUI.Anchor.CenterRight)

    GUI.Image(CreateRect(0.20, 0.75, top, GUI.Anchor.Center), "GUIDragIndicatorHorizontal").CanBeFocused = false
    GUI.Image(CreateRect(0.20, 0.75, bottom, GUI.Anchor.Center), "GUIDragIndicatorHorizontal").CanBeFocused = false
    GUI.Image(CreateRect(0.80, 0.08, left, GUI.Anchor.Center), "GUIDragIndicator").CanBeFocused = false
    GUI.Image(CreateRect(0.80, 0.08, right, GUI.Anchor.Center), "GUIDragIndicator").CanBeFocused = false
end

local function GetVoidTraitorResizeEdge()
    local mousePosition = PlayerInput.MousePosition
    for _, target in ipairs(vtResizeTargets) do
        if target.Component ~= nil and target.Component.Rect.Contains(mousePosition) then
            return target.Edge
        end
    end
    return nil
end

local function FitVoidTraitorMenuToScreen()
    if currentMenu == nil or currentMenuKind ~= "vt" or vtResizeState ~= nil then return end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(VT_MENU_MARGIN_PIXELS)
    local minWidth = SafeIntScale(VT_MENU_MIN_WIDTH_PIXELS)
    local minHeight = SafeIntScale(VT_MENU_MIN_HEIGHT_PIXELS)
    local maxWidth = math.max(minWidth, screenWidth - margin * 2)
    local maxHeight = math.max(minHeight, screenHeight - margin * 2)
    local rect = currentMenu.Rect
    local width = Clamp(rect.Width, minWidth, maxWidth)
    local height = Clamp(rect.Height, minHeight, maxHeight)
    local rectTransform = currentMenu.RectTransform

    if width ~= rect.Width or height ~= rect.Height then
        local scaleX = math.max(tonumber(rectTransform.Scale.X) or 1, 0.0001)
        local scaleY = math.max(tonumber(rectTransform.Scale.Y) or 1, 0.0001)
        rectTransform:Resize(Point(math.max(1, math.floor(width / scaleX + 0.5)), math.max(1, math.floor(height / scaleY + 0.5))), true)
        rect = currentMenu.Rect
    end

    local dx = 0
    local dy = 0
    if rect.X < margin then
        dx = margin - rect.X
    elseif rect.Right > screenWidth - margin then
        dx = (screenWidth - margin) - rect.Right
    end
    if rect.Y < margin then
        dy = margin - rect.Y
    elseif rect.Bottom > screenHeight - margin then
        dy = (screenHeight - margin) - rect.Bottom
    end

    if dx ~= 0 or dy ~= 0 then
        rectTransform.ScreenSpaceOffset = Point(rectTransform.ScreenSpaceOffset.X + dx, rectTransform.ScreenSpaceOffset.Y + dy)
    end

    SaveVoidTraitorMenuGeometry()
end

local function UpdateVoidTraitorMenuInteraction()
    if currentMenu == nil or currentMenuKind ~= "vt" then
        vtResizeState = nil
        return
    end

    local mouseDown = PlayerInput.PrimaryMouseButtonDown()
    local mouseHeld = PlayerInput.PrimaryMouseButtonHeld()

    if mouseDown and vtResizeState == nil then
        local edge = GetVoidTraitorResizeEdge()
        if edge ~= nil then
            local rect = currentMenu.Rect
            local rectTransform = currentMenu.RectTransform
            vtResizeState = {
                Edge = edge,
                MouseX = PlayerInput.MousePosition.X,
                MouseY = PlayerInput.MousePosition.Y,
                Left = rect.X,
                Top = rect.Y,
                Right = rect.Right,
                Bottom = rect.Bottom,
                ScreenOffsetX = rectTransform.ScreenSpaceOffset.X,
                ScreenOffsetY = rectTransform.ScreenSpaceOffset.Y,
            }
        end
    end

    if not mouseHeld then
        vtResizeState = nil
        FitVoidTraitorMenuToScreen()
        return
    end

    if vtResizeState == nil then
        FitVoidTraitorMenuToScreen()
        return
    end

    local state = vtResizeState
    local edge = state.Edge
    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(VT_MENU_MARGIN_PIXELS)
    local minWidth = SafeIntScale(VT_MENU_MIN_WIDTH_PIXELS)
    local minHeight = SafeIntScale(VT_MENU_MIN_HEIGHT_PIXELS)
    local dx = PlayerInput.MousePosition.X - state.MouseX
    local dy = PlayerInput.MousePosition.Y - state.MouseY
    local left = state.Left
    local top = state.Top
    local right = state.Right
    local bottom = state.Bottom

    if edge == "left" or edge == "topleft" or edge == "bottomleft" then
        left = Clamp(state.Left + dx, margin, state.Right - minWidth)
    elseif edge == "right" or edge == "topright" or edge == "bottomright" then
        right = Clamp(state.Right + dx, state.Left + minWidth, screenWidth - margin)
    end

    if edge == "top" or edge == "topleft" or edge == "topright" then
        top = Clamp(state.Top + dy, margin, state.Bottom - minHeight)
    elseif edge == "bottom" or edge == "bottomleft" or edge == "bottomright" then
        bottom = Clamp(state.Bottom + dy, state.Top + minHeight, screenHeight - margin)
    end

    local width = math.max(minWidth, right - left)
    local height = math.max(minHeight, bottom - top)
    local rectTransform = currentMenu.RectTransform
    local scaleX = math.max(tonumber(rectTransform.Scale.X) or 1, 0.0001)
    local scaleY = math.max(tonumber(rectTransform.Scale.Y) or 1, 0.0001)
    rectTransform:Resize(Point(math.max(1, math.floor(width / scaleX + 0.5)), math.max(1, math.floor(height / scaleY + 0.5))), true)
    rectTransform.ScreenSpaceOffset = Point(state.ScreenOffsetX + (left - state.Left), state.ScreenOffsetY + (top - state.Top))

    if vtMenuList ~= nil then
        vtMenuList:RecalculateChildren()
        vtMenuList:UpdateScrollBarSize()
    end

    SaveVoidTraitorMenuGeometry()
end

local function ShowConfirm(title, text, action)
    SaveVoidTraitorMenuGeometry()
    if currentMenu ~= nil then
        pcall(function()
            currentMenu:RemoveFromGUIUpdateList(true)
            if currentMenu.RectTransform ~= nil then currentMenu.RectTransform.Parent = nil end
        end)
    end

    local overlay = GUI.Frame(CreateRect(1, 1, guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 110)
    overlay.CanBeFocused = true
    overlay.IgnoreLayoutGroups = true
    currentMenu = overlay
    currentMenuKind = "confirm"
    sharedState.CurrentMenu = overlay
    sharedState.CurrentMenuKind = currentMenuKind

    local box = GUI.Frame(CreateRect(0.20, 0.165, overlay, GUI.Anchor.Center), "GUIFrame")
    box.CanBeFocused = true

    local content = GUI.LayoutGroup(CreateRect(0.84, 0.55, box, GUI.Anchor.TopCenter), false, GUI.Anchor.TopCenter)
    content.Stretch = true
    pcall(function() content.RelativeSpacing = 0.035 end)

    local titleBlock = CreateText(content, 1, 0.40, nil, title, GUI.Alignment.Center, 1.02, Color(255, 235, 170, 255), false)
    pcall(function() titleBlock.Font = GUI.Style.LargeFont end)
    CreateText(content, 1, 0.45, nil, text, GUI.Alignment.Center, 0.82, Color(230, 230, 220, 255), true)

    -- Компактное окно подтверждения: кнопки держим в отдельной нижней строке
    -- и оставляем обычный ванильный GUIButton-стиль. Проблема была не в текстуре,
    -- а в прежнем растягивании кнопок на всю строку.
    local buttons = GUI.LayoutGroup(CreateRect(0.76, 0.20, box, GUI.Anchor.BottomCenter), true, GUI.Anchor.Center)
    buttons.Stretch = false
    pcall(function() buttons.RelativeSpacing = 0 end)
    pcall(function() buttons.AbsoluteSpacing = SafeIntScale(10) end)

    local cancel = GUI.Button(CreateRect(0.46, 0.92, buttons, nil), uiText.Cancel, GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(cancel, 0.84)
    cancel.OnClicked = function()
        CloseMenu()
        return true
    end

    local confirm = GUI.Button(CreateRect(0.46, 0.92, buttons, nil), uiText.Yes, GUI.Alignment.Center, "GUIButton")
    SetButtonTextScale(confirm, 0.84)
    confirm.OnClicked = function()
        SendCommand(action)
        CloseMenu()
        return true
    end
end

local function ShowVoidTraitorMenu()
    if currentMenu ~= nil then
        CloseMenu()
        return
    end

    if menuEntries == nil then
        RequestMenuSnapshot(true)
        return
    end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(VT_MENU_MARGIN_PIXELS)
    local minWidth = SafeIntScale(VT_MENU_MIN_WIDTH_PIXELS)
    local minHeight = SafeIntScale(VT_MENU_MIN_HEIGHT_PIXELS)
    local maxWidth = math.max(minWidth, screenWidth - margin * 2)
    local maxHeight = math.max(minHeight, screenHeight - margin * 2)
    local width = Clamp(vtMenuWidth or SafeIntScale(VT_MENU_DEFAULT_WIDTH_PIXELS), minWidth, maxWidth)
    local height = Clamp(vtMenuHeight or SafeIntScale(VT_MENU_DEFAULT_HEIGHT_PIXELS), minHeight, maxHeight)
    local x = vtMenuX or math.floor((screenWidth - width) / 2)
    local y = vtMenuY or math.floor((screenHeight - height) / 2)
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))

    local rootRect = CreatePixelRect(width, height, guiRoot, GUI.Anchor.TopLeft)
    rootRect.AbsoluteOffset = Point(x, y)
    local root = GUI.Frame(rootRect, nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    currentMenu = root
    currentMenuKind = "vt"
    sharedState.CurrentMenu = root
    sharedState.CurrentMenuKind = currentMenuKind

    local panel = GUI.Frame(CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.003

    local header = GUI.Frame(CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(CreateRect(0.86, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(CreateRect(0.07, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = CreateText(dragArea, 0.90, 1, GUI.Anchor.CenterRight, uiText.Title, GUI.Alignment.Left, 1.00, Color(235, 205, 145, 255), false)
    pcall(function() title.Font = GUI.Style.SubHeadingFont end)

    local close = GUI.Button(CreateRect(0.10, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.ToolTip = uiText.Cancel
    close.OnClicked = function()
        CloseMenu()
        return true
    end

    GUI.Image(CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local listFrame = GUI.Frame(CreateRect(1, 0.91, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false
    vtMenuList = GUI.ListBox(CreateRect(1, 0.985, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    vtMenuList.Color = Color(0, 0, 0, 0)
    pcall(function()
        if vtMenuList.ContentBackground ~= nil then
            vtMenuList.ContentBackground.Color = Color(0, 0, 0, 0)
        end
    end)
    pcall(function() vtMenuList.KeepSpaceForScrollBar = true end)

    local entries = menuEntries or {}
    if #entries == 0 then
        CreateText(listFrame, 0.90, 0.24, GUI.Anchor.Center, uiText.NoCommands, GUI.Alignment.Center, 0.90, Color(195, 195, 185, 255), true)
    end

    local lastCategory = nil
    for _, entry in ipairs(entries) do
        local category = tostring(entry.Category or "")
        if category ~= "" and category ~= lastCategory then
            if lastCategory ~= nil then
                CreateDivider(vtMenuList.Content)
            end
            CreateCategoryHeader(vtMenuList.Content, category)
            lastCategory = category
        end

        local inputType = tostring(entry.InputType or "")
        if inputType ~= "" then
            CreateTextInputRow(vtMenuList.Content, entry.Label or entry.Command or uiText.GenericCommand, entry.InputHint or "", entry.Command or "", true)
        else
            local button = CreateMenuButton(vtMenuList.Content, entry.Label or entry.Command or uiText.GenericCommand, true)
            button.ToolTip = entry.Hint or ""
            button.OnClicked = function()
                if tostring(entry.ConfirmText or "") ~= "" then
                    ShowConfirm(entry.ConfirmTitle ~= "" and entry.ConfirmTitle or uiText.DefaultConfirmTitle, entry.ConfirmText, entry.Command)
                else
                    SendCommand(entry.Command)
                end
                return true
            end
        end
    end

    vtMenuList.BarScroll = vtMenuScroll
    vtMenuList:RecalculateChildren()
    vtMenuList:UpdateScrollBarSize()
    AddVoidTraitorResizeHandles(panel)
    SaveVoidTraitorMenuGeometry()
end

local function GetNetLobbyScreen()
    local candidates = {
        function()
            if GameMain ~= nil and GameMain.NetLobbyScreen ~= nil then return GameMain.NetLobbyScreen end
            return nil
        end,
        function()
            if Game ~= nil and Game.NetLobbyScreen ~= nil then return Game.NetLobbyScreen end
            return nil
        end,
    }

    for _, getter in ipairs(candidates) do
        local ok, screen = pcall(getter)
        if ok and screen ~= nil then return screen end
    end

    return nil
end

local function IsLobbyScreenAvailable()
    local screen = GetNetLobbyScreen()
    if screen == nil then return false end

    local ok, selected = pcall(function()
        return GUI ~= nil and GUI.Screen ~= nil and GUI.Screen.Selected == screen
    end)
    if ok and selected then return true end

    ok, selected = pcall(function()
        return Screen ~= nil and Screen.Selected == screen
    end)
    if ok and selected then return true end

    return false
end

local function GetLobbyGuiFrame()
    local screen = GetNetLobbyScreen()
    if screen == nil then return nil end

    local ok, frame = pcall(function() return screen.Frame end)
    if ok and frame ~= nil and frame.RectTransform ~= nil then
        return frame
    end

    return nil
end

local function SafeSetAsLastChild(component)
    if component == nil or component.RectTransform == nil then return end

    local hasParent = false
    pcall(function() hasParent = component.RectTransform.Parent ~= nil end)
    if not hasParent then return end

    pcall(function() component.RectTransform.SetAsLastChild() end)
end

local function ReadRectValue(rect, key, fallbackKey, fallback)
    if rect == nil then return fallback or 0 end
    local value = nil
    pcall(function() value = rect[key] end)
    if tonumber(value) ~= nil then return tonumber(value) end
    if fallbackKey ~= nil then
        pcall(function() value = rect[fallbackKey] end)
        if tonumber(value) ~= nil then return tonumber(value) end
    end
    return fallback or 0
end

local function GetComponentRect(component)
    if component == nil then return nil end
    local ok, rect = pcall(function() return component.Rect end)
    if ok and rect ~= nil then return rect end
    return nil
end

local function GetLobbyComponent(name)
    local screen = GetNetLobbyScreen()
    if screen == nil then return nil end

    local ok, component = pcall(function() return screen[name] end)
    if ok and component ~= nil then return component end

    return nil
end

local function GetLobbyComponentRect(name)
    return GetComponentRect(GetLobbyComponent(name))
end

local function GetComponentText(component)
    if component == nil then return "" end

    local text = ""
    pcall(function()
        if component.TextBlock ~= nil and component.TextBlock.Text ~= nil then
            text = tostring(component.TextBlock.Text)
        elseif component.Text ~= nil then
            text = tostring(component.Text)
        end
    end)

    return text or ""
end

local function IsRespawnTabText(text)
    local respawnText = ""
    local ok = pcall(function()
        respawnText = tostring(TextManager.Get("respawnsettings"))
    end)

    return ok and respawnText ~= "" and tostring(text or "") == respawnText
end

local function FindRespawnTabButtonRect()
    local direct = GetComponentRect(GetLobbyComponent("respawnTabButton"))
    if direct ~= nil then return direct end

    local lobbyFrame = GetLobbyGuiFrame()
    if lobbyFrame == nil then return nil end

    local found = nil
    pcall(function()
        for child in lobbyFrame.GetAllChildren() do
            if child ~= nil then
                local hasTextBlock = false
                pcall(function() hasTextBlock = child.TextBlock ~= nil end)
                if hasTextBlock then
                    local text = GetComponentText(child)
                    if IsRespawnTabText(text) then
                        local rect = GetComponentRect(child)
                        if rect ~= nil then
                            local width = ReadRectValue(rect, "Width", "width", 0)
                            local height = ReadRectValue(rect, "Height", "height", 0)
                            if width >= SafeIntScale(120) and height >= SafeIntScale(20) then
                                found = rect
                                return
                            end
                        end
                    end
                end
            end
        end
    end)

    return found
end

local function GetVoteButtonParent()
    return GetLobbyGuiFrame()
end

local function GetVoteButtonAnchorRect()
    local respawnRect = FindRespawnTabButtonRect()
    if respawnRect ~= nil then
        local x = ReadRectValue(respawnRect, "X", "x", 0)
        local y = ReadRectValue(respawnRect, "Y", "y", 0)
        local width = ReadRectValue(respawnRect, "Width", "width", 0)
        local height = ReadRectValue(respawnRect, "Height", "height", 0)
        if width > 0 and height > 0 then
            local buttonWidth = math.max(SafeIntScale(170), math.min(SafeIntScale(245), math.floor(width * 0.82)))
            local gap = SafeIntScale(8)
            return {
                X = x - buttonWidth - gap,
                Y = y,
                Width = buttonWidth,
                Height = height,
            }
        end
    end

    local subRect = GetLobbyComponentRect("SubList")
    local modeRect = GetLobbyComponentRect("ModeList")
    local anchorRect = subRect or modeRect
    if anchorRect == nil then return nil end

    local x = ReadRectValue(anchorRect, "X", "x", 0)
    local y = ReadRectValue(anchorRect, "Y", "y", 0)
    local width = ReadRectValue(anchorRect, "Width", "width", 0)
    local height = ReadRectValue(anchorRect, "Height", "height", 0)
    if width <= 0 or height <= 0 then return nil end

    local buttonWidth = math.max(SafeIntScale(170), math.min(SafeIntScale(245), math.floor(width * 0.324)))
    local buttonHeight = SafeIntScale(32)

    return {
        X = x + width - buttonWidth - SafeIntScale(6),
        Y = y + height + SafeIntScale(6),
        Width = buttonWidth,
        Height = buttonHeight,
    }
end
local function GetVoteButtonMetrics()
    local anchor = GetVoteButtonAnchorRect()
    if anchor ~= nil then
        return math.max(1, math.floor(anchor.Width)), math.max(SafeIntScale(22), math.floor(anchor.Height)), SafeIntScale(2)
    end

    return SafeIntScale(190), SafeIntScale(26), SafeIntScale(2)
end

local function GetVoteStartOptionMetrics()
    local width, height, gap = GetVoteButtonMetrics()
    local optionHeight = math.max(SafeIntScale(18), math.floor(height * 0.48))
    return width, optionHeight, SafeIntScale(1), gap
end

local function CreateLobbyAbsoluteRect(x, y, width, height)
    local lobbyFrame = GetLobbyGuiFrame()
    if lobbyFrame == nil or lobbyFrame.RectTransform == nil then return nil end

    local frameRect = GetComponentRect(lobbyFrame)
    local frameX = ReadRectValue(frameRect, "X", "x", 0)
    local frameY = ReadRectValue(frameRect, "Y", "y", 0)

    local rectTransform = GUI.RectTransform(Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))), lobbyFrame.RectTransform, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(math.floor(x - frameX), math.floor(y - frameY))
    return rectTransform
end

local function GetVoteButtonRect(parent)
    local anchor = GetVoteButtonAnchorRect()
    if anchor ~= nil then
        local rect = CreateLobbyAbsoluteRect(anchor.X, anchor.Y, anchor.Width, anchor.Height)
        if rect ~= nil then return rect end
    end

    local width, height = GetVoteButtonMetrics()
    return GUI.RectTransform(Point(width, height), GetParentRect(parent), GUI.Anchor.TopLeft)
end

local function GetVoteStartPanelRect(parent)
    local width, optionHeight, spacing, gap = GetVoteStartOptionMetrics()

    local buttonRect = GetComponentRect(parent)
    if buttonRect ~= nil then
        local x = ReadRectValue(buttonRect, "X", "x", 0)
        local y = ReadRectValue(buttonRect, "Y", "y", 0) + ReadRectValue(buttonRect, "Height", "height", optionHeight) + gap
        local rect = CreateLobbyAbsoluteRect(x, y, width, optionHeight * 2 + spacing)
        if rect ~= nil then return rect end
    end

    local rectTransform = GUI.RectTransform(Point(width, optionHeight * 2 + spacing), GetParentRect(parent), GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(0, optionHeight + gap)
    return rectTransform
end

local function GetVoteTargetComponent(voteType)
    if tostring(voteType or "") == "map" then
        return GetLobbyComponent("SubList")
    end

    return GetLobbyComponent("ModeList")
end

local function DestroyVoteButton()
    if voteButtonRoot ~= nil then
        pcall(function() voteButtonRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            voteButtonRoot.Visible = false
            if voteButtonRoot.RectTransform ~= nil then
                voteButtonRoot.RectTransform.Parent = nil
            end
        end)
    end

    voteButtonRoot = nil
    voteButtonParent = nil
    sharedState.VoteButtonRoot = nil
end

local function AttachVoteGuiRoot()
    if not IsLobbyScreenAvailable() or guiRoot == nil or guiRoot.RectTransform == nil then return false end

    local lobbyFrame = GetLobbyGuiFrame()
    if lobbyFrame == nil then return false end

    pcall(function() guiRoot:RemoveFromGUIUpdateList(true) end)
    pcall(function()
        guiRoot.Visible = true
        guiRoot.RectTransform.Parent = lobbyFrame.RectTransform
        guiRoot.RectTransform.RelativeSize = Vector2(1, 1)
        guiRoot.RectTransform.AbsoluteOffset = Point(0, 0)
    end)
    SafeSetAsLastChild(guiRoot)

    return true
end

local function GetVoteProgress(active)
    if active == nil then return 0 end
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local remaining = math.max(0, tonumber(active.Remaining or 0) or 0)
    return math.max(0, math.min(1, remaining / duration))
end

local function GetVoteTimeText(active)
    local remaining = 0
    if active ~= nil then remaining = math.max(0, tonumber(active.Remaining or 0) or 0) end
    return string.format("%s: %s", voteUiText.Timer, tostring(math.floor(remaining)))
end

local CreateVoteButton
local IsWelcomeMenuOpen

local function ShowVoteStartMenu()
    if IsWelcomeMenuOpen ~= nil and IsWelcomeMenuOpen() then return end
    if not IsLobbyScreenAvailable() then return end
    if voteButtonRoot == nil then CreateVoteButton() end
    if voteButtonRoot == nil then return end

    local panel = GUI.Frame(GetVoteStartPanelRect(voteButtonRoot), "GUIFrame")
    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    currentMenu = panel
    currentMenuKind = "votestart"
    sharedState.CurrentMenu = panel
    sharedState.CurrentMenuKind = currentMenuKind
    SafeSetAsLastChild(panel)

    local width, optionHeight, spacing = GetVoteStartOptionMetrics()
    local canStart = voteSnapshot == nil or voteSnapshot.CanStart ~= false

    local modeRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    modeRect.AbsoluteOffset = Point(0, 0)
    local modeButton = GUI.Button(modeRect, voteUiText.StartMode, GUI.Alignment.Center, "GUIButtonSmall")
    modeButton.Enabled = canStart
    SetButtonTextScale(modeButton, 0.70)
    modeButton.OnClicked = function()
        SendVoteStart("game")
        CloseMenu()
        return true
    end

    local mapRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    mapRect.AbsoluteOffset = Point(0, optionHeight + spacing)
    local mapButton = GUI.Button(mapRect, voteUiText.StartMap, GUI.Alignment.Center, "GUIButtonSmall")
    mapButton.Enabled = canStart
    SetButtonTextScale(mapButton, 0.70)
    mapButton.OnClicked = function()
        SendVoteStart("map")
        CloseMenu()
        return true
    end
end

local function GetActiveVoteRemaining(active)
    if active == nil then return 0 end
    if active.LocalEndTime ~= nil then
        return math.max(0, math.ceil((tonumber(active.LocalEndTime) or 0) - GetTime()))
    end
    return math.max(0, tonumber(active.Remaining or 0) or 0)
end

local function FormatVoteOptionLabel(option)
    local selectedPrefix = option.Selected and "✓ " or ""
    return string.format("%s%s — %s %s", selectedPrefix, tostring(option.Text or ""), tostring(option.Votes or 0), voteUiText.Votes)
end

local function CreateVoteOverlayOnComponent(target)
    if target == nil or target.RectTransform == nil then return nil end

    local overlayRect = nil
    pcall(function()
        if target.RectTransform.Parent ~= nil then
            overlayRect = target.RectTransform.Parent.Rect
        end
    end)
    if overlayRect == nil then
        overlayRect = GetComponentRect(target)
    end
    if overlayRect == nil then return nil end

    local x = ReadRectValue(overlayRect, "X", "x", 0)
    local y = ReadRectValue(overlayRect, "Y", "y", 0)
    local width = ReadRectValue(overlayRect, "Width", "width", 0)
    local height = ReadRectValue(overlayRect, "Height", "height", 0)
    if width <= 0 or height <= 0 then return nil end

    -- В NetLobbyScreen верхние блоки режима/подлодки создаются как одинаковые
    -- Stretch-панели внутри mainPanelTopLayout, поэтому активное голосование
    -- выравниваем по фактическим границам этих соседних lobby-блоков, а не по
    -- ручному большому запасу вниз.
    local topY = y
    local bottomY = y + height

    local function includeTopVotePanelBounds(componentName)
        local component = GetLobbyComponent(componentName)
        if component == nil or component.RectTransform == nil then return end

        local siblingRect = nil
        pcall(function()
            if component.RectTransform.Parent ~= nil then
                siblingRect = component.RectTransform.Parent.Rect
            end
        end)
        if siblingRect == nil then return end

        local siblingY = ReadRectValue(siblingRect, "Y", "y", topY)
        local siblingHeight = ReadRectValue(siblingRect, "Height", "height", 0)
        if siblingHeight <= 0 then return end

        topY = math.min(topY, siblingY)
        bottomY = math.max(bottomY, siblingY + siblingHeight)
    end

    includeTopVotePanelBounds("ModeList")
    includeTopVotePanelBounds("SubList")

    y = topY + 1
    height = math.max(1, bottomY - topY)

    -- Ванильный NetLobbyScreen использует PanelSpacing = 0.005f. Берём такой же
    -- масштабируемый небольшой нахлёст только на нижний шов, чтобы не было видно
    -- нижнюю линию родного блока, но без прежнего завышенного SafeIntScale(6).
    local seamCover = math.max(SafeIntScale(2), math.floor(height * 0.005 + 0.5))
    height = height + seamCover

    local rectTransform = CreateLobbyAbsoluteRect(x, y, width, height)
    if rectTransform == nil then return nil end

    local panel = GUI.Frame(rectTransform, "GUIFrame")
    panel.Color = Color(255, 255, 255, 255)
    panel.IgnoreLayoutGroups = true
    return panel
end


local function RefreshActiveVoteUi()
    if currentMenuKind ~= "voteactive" or activeVoteUi == nil then return end
    local active = voteSnapshot and voteSnapshot.Active or nil
    if active == nil then return end

    local remaining = GetActiveVoteRemaining(active)
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local progress = math.max(0, math.min(1, remaining / duration))

    if activeVoteUi.TimerText ~= nil then
        pcall(function() activeVoteUi.TimerText.Text = string.format("%s: %s", voteUiText.Timer, tostring(math.floor(remaining))) end)
    end
    if activeVoteUi.ProgressFill ~= nil and activeVoteUi.ProgressFill.RectTransform ~= nil then
        pcall(function() activeVoteUi.ProgressFill.RectTransform.RelativeSize = Vector2(progress, 1) end)
    end

    local buttons = activeVoteUi.OptionButtons or {}
    for _, option in ipairs(active.Options or {}) do
        local button = buttons[option.Index]
        if button ~= nil then
            local label = FormatVoteOptionLabel(option)
            pcall(function() button.TextBlock.Text = label end)
        end
    end
end

local function ShowActiveVoteMenu()
    if IsWelcomeMenuOpen ~= nil and IsWelcomeMenuOpen() then return end

    local active = voteSnapshot and voteSnapshot.Active or nil
    if active == nil then
        ShowVoteStartMenu()
        return
    end

    if not IsLobbyScreenAvailable() then return end

    local target = GetVoteTargetComponent(active.Type)
    local panel = CreateVoteOverlayOnComponent(target)
    if panel == nil then
        if not AttachVoteGuiRoot() then return end
        panel = GUI.Frame(CreateRect(0.36, 0.30, guiRoot, GUI.Anchor.Center), "GUIFrame")
        panel.Color = Color(255, 255, 255, 255)
    end

    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    currentMenu = panel
    currentMenuKind = "voteactive"
    sharedState.CurrentMenu = panel
    sharedState.CurrentMenuKind = currentMenuKind
    SafeSetAsLastChild(panel)

    activeVoteUi = { Panel = panel, ActiveId = tostring(active.Id or ""), OptionButtons = {} }

    local content = GUI.LayoutGroup(CreateRect(0.985, 0.985, panel, GUI.Anchor.Center), false, GUI.Anchor.TopCenter)
    content.Stretch = true
    pcall(function() content.RelativeSpacing = 0.008 end)

    local header = GUI.LayoutGroup(CreateRect(1, 0.10, content, nil), true, GUI.Anchor.CenterLeft)
    header.Stretch = true
    pcall(function() header.RelativeSpacing = 0.012 end)

    local title = CreateText(header, 0.70, 1, nil, active.Title or voteUiText.StartTitle, GUI.Alignment.Left, 0.95, Color(255, 235, 170, 255), false)
    pcall(function() title.Font = GUI.Style.SubHeadingFont end)

    activeVoteUi.TimerText = CreateText(header, 0.30, 1, nil, GetVoteTimeText(active), GUI.Alignment.CenterRight, 1.125, Color(210, 220, 200, 255), false)

    local progressFrame = GUI.Frame(CreateRect(1, 0.035, content, nil), "GUIFrame")
    progressFrame.Color = Color(25, 35, 30, 230)
    activeVoteUi.ProgressFill = GUI.Frame(CreateRect(GetVoteProgress(active), 1, progressFrame, GUI.Anchor.CenterLeft), nil)
    activeVoteUi.ProgressFill.Color = Color(120, 170, 130, 230)

    local listArea = GUI.Frame(CreateRect(1, 0.855, content, nil), nil)
    listArea.Color = Color(0, 0, 0, 0)
    listArea.CanBeFocused = false

    -- Слои списка не должны перекрашивать ванильную рамку.
    -- Чёрный фон лежит под GUIFrameListBox, сама зелёная рамка остаётся родной,
    -- а ListBox внутри прозрачный и только держит кнопки вариантов.
    local listBackground = GUI.Frame(CreateRect(0.984, 0.944, listArea, GUI.Anchor.Center), nil)
    listBackground.Color = Color(0, 0, 0, 255)
    listBackground.CanBeFocused = false

    local listFrame = GUI.Frame(CreateRect(1, 1, listArea, GUI.Anchor.Center), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(0.984, 0.944, listFrame, GUI.Anchor.Center), false, Color(0, 0, 0, 0), nil)
    list.Color = Color(0, 0, 0, 0)
    pcall(function()
        if list.ContentBackground ~= nil then
            list.ContentBackground.Color = Color(0, 0, 0, 0)
        end
    end)
    pcall(function() list.KeepSpaceForScrollBar = false end)

    for _, option in ipairs(active.Options or {}) do
        local label = FormatVoteOptionLabel(option)
        local button = GUI.Button(CreateRect(1, 0.105, list.Content, nil), label, GUI.Alignment.Center, "GUIButtonSmall")
        SetButtonTextScale(button, 0.73)
        activeVoteUi.OptionButtons[option.Index] = button
        button.OnClicked = function()
            SendVoteCast(option.Index)
            if voteSnapshot ~= nil and voteSnapshot.Active ~= nil then
                for _, localOption in ipairs(voteSnapshot.Active.Options or {}) do
                    localOption.Selected = localOption.Index == option.Index
                end
                RefreshActiveVoteUi()
            end
            return true
        end
    end

    RefreshActiveVoteUi()
end

CreateVoteButton = function()
    DestroyVoteButton()

    if not IsLobbyScreenAvailable() then return end

    local parent = GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then return end

    local root = GUI.Frame(GetVoteButtonRect(parent), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = true
    root.IgnoreLayoutGroups = true
    voteButtonRoot = root
    voteButtonParent = parent
    sharedState.VoteButtonRoot = voteButtonRoot

    SafeSetAsLastChild(root)

    local button = GUI.Button(CreateRect(1, 1, root, GUI.Anchor.Center), voteUiText.Button, GUI.Alignment.Center, "GUITabButton")
    button.CanBeFocused = true
    button.ToolTip = voteUiText.Tooltip
    SetButtonTextScale(button, 1.0)
    button.OnClicked = function()
        if currentMenuKind == "votestart" then
            CloseMenu()
            return true
        end
        RequestVoteSnapshot(true)
        return true
    end
end

IsWelcomeMenuOpen = function()
    local welcomeRoot = rawget(_G, "VoidTraitorWelcomeMenuRoot")
    if welcomeRoot == nil or welcomeRoot.RectTransform == nil then
        return rawget(_G, "VoidTraitorWelcomeMenuOpen") == true
    end

    local hasParent = false
    pcall(function() hasParent = welcomeRoot.RectTransform.Parent ~= nil end)
    if not hasParent then
        _G.VoidTraitorWelcomeMenuOpen = false
    end
    return hasParent
end

local function EnsureVoteButton()
    if sharedState.Disabled then return end

    if IsWelcomeMenuOpen() then
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
        return
    end

    if not IsLobbyScreenAvailable() then
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
        return
    end

    local parent = GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then
        DestroyVoteButton()
        return
    end

    local width, height = GetScreenSize()
    if voteButtonRoot == nil or voteButtonParent ~= parent or width ~= lastVoteButtonResolutionX or height ~= lastVoteButtonResolutionY then
        lastVoteButtonResolutionX = width
        lastVoteButtonResolutionY = height
        CreateVoteButton()
    end
end

sharedState.EnsureVoteButton = EnsureVoteButton

local function CreateTopButtons()
    if buttonRoot ~= nil then
        pcall(function() buttonRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            if buttonRoot.RectTransform ~= nil then
                buttonRoot.RectTransform.Parent = nil
            end
        end)
        buttonRoot = nil
    end

    local buttonWidth, buttonHeight = GetTopButtonSize()
    local padding = GetTopButtonSpacing()

    local root = GUI.LayoutGroup(CreateButtonAreaRect(buttonWidth, buttonHeight, 2, padding), true, GUI.Anchor.CenterLeft)
    root.AbsoluteSpacing = padding
    root.Stretch = false
    root.CanBeFocused = true
    buttonRoot = root
    sharedState.ButtonRoot = buttonRoot

    local shop = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), uiText.ShopButton, GUI.Alignment.Center, "GUIButtonSmall")
    shop.CanBeFocused = true
    shop.ToolTip = uiText.ShopTooltip
    SetButtonTextScale(shop, 0.74)
    shop.OnClicked = function(button, userData)
        if currentMenu ~= nil then CloseMenu() end
        RequestPointshop()
        return true
    end

    local vt = GUI.Button(GUI.RectTransform(Point(buttonWidth, buttonHeight), root.RectTransform), uiText.MainButton, GUI.Alignment.Center, "GUIButtonSmall")
    vt.CanBeFocused = true
    vt.ToolTip = uiText.MainTooltip
    SetButtonTextScale(vt, 0.88)
    vt.OnClicked = function(button, userData)
        if currentMenu ~= nil then
            CloseMenu()
        else
            RequestMenuSnapshot(true)
        end
        return true
    end

end

local function EnsureTopButtons()
    if sharedState.Disabled then return end

    local width, height = GetScreenSize()
    if buttonRoot == nil or width ~= lastResolutionX or height ~= lastResolutionY then
        lastResolutionX = width
        lastResolutionY = height
        CreateTopButtons()
    end
end

sharedState.EnsureTopButtons = EnsureTopButtons

Networking.Receive(NET_SNAPSHOT, function(message)
    if sharedState.Disabled then return end

    uiText.Title = message.ReadString()
    uiText.ShopButton = message.ReadString()
    uiText.MainButton = message.ReadString()
    uiText.ShopTooltip = message.ReadString()
    uiText.MainTooltip = message.ReadString()
    uiText.NoCommands = message.ReadString()
    uiText.GenericCommand = message.ReadString()
    uiText.DefaultConfirmTitle = message.ReadString()
    uiText.Cancel = message.ReadString()
    uiText.Yes = message.ReadString()
    uiText.Ok = message.ReadString()
    local count = message.ReadInt32()
    local entries = {}
    for i = 1, count do
        table.insert(entries, {
            Command = message.ReadString(),
            Label = message.ReadString(),
            Hint = message.ReadString(),
            Category = message.ReadString(),
            InputType = message.ReadString(),
            InputHint = message.ReadString(),
            ConfirmTitle = message.ReadString(),
            ConfirmText = message.ReadString(),
        })
    end

    menuEntries = entries
    if buttonRoot ~= nil then
        CreateTopButtons()
    end
    if pendingMenuOpen then
        pendingMenuOpen = false
        ShowVoidTraitorMenu()
    end
end)

Networking.Receive(NET_VOTE_SNAPSHOT, function(message)
    if sharedState.Disabled then return end

    voteUiText.Button = message.ReadString()
    voteUiText.Tooltip = message.ReadString()
    voteUiText.StartTitle = message.ReadString()
    voteUiText.StartMode = message.ReadString()
    voteUiText.StartMap = message.ReadString()
    voteUiText.StartBlockedReason = message.ReadString()
    voteUiText.Close = message.ReadString()
    voteUiText.NoActive = message.ReadString()
    voteUiText.StartedBy = message.ReadString()
    voteUiText.Timer = message.ReadString()
    voteUiText.Votes = message.ReadString()

    local canStart = message.ReadBoolean()
    local hasActive = message.ReadBoolean()
    local snapshot = { CanStart = canStart, Active = nil }

    if hasActive then
        local active = {
            Id = message.ReadString(),
            Type = message.ReadString(),
            Title = message.ReadString(),
            StartedBy = message.ReadString(),
            Remaining = message.ReadInt32(),
            Duration = message.ReadInt32(),
            Options = {},
        }
        active.LocalEndTime = GetTime() + math.max(0, tonumber(active.Remaining or 0) or 0)

        local count = message.ReadInt32()
        for i = 1, count do
            table.insert(active.Options, {
                Index = message.ReadInt32(),
                Text = message.ReadString(),
                Votes = message.ReadInt32(),
                Selected = message.ReadBoolean(),
            })
        end

        snapshot.Active = active
        if active.Id ~= "" and active.Id ~= lastActiveVoteId then
            lastActiveVoteId = active.Id
            PlayVoteSound()
        end
    else
        lastActiveVoteId = ""
        lastShownActiveVoteId = ""
    end

    voteSnapshot = snapshot

    if voteButtonRoot ~= nil and IsLobbyScreenAvailable() and currentMenuKind ~= "votestart" and currentMenuKind ~= "voteactive" then
        CreateVoteButton()
    end

    if pendingVoteMenuOpen then
        pendingVoteMenuOpen = false
        if currentMenu ~= nil then CloseMenu() end
        if voteSnapshot.Active ~= nil then
            lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
            ShowActiveVoteMenu()
        else
            ShowVoteStartMenu()
        end
    elseif currentMenu ~= nil and currentMenuKind == "voteactive" then
        if voteSnapshot.Active == nil then
            CloseMenu()
        elseif activeVoteUi ~= nil and tostring(voteSnapshot.Active.Id or "") == tostring(activeVoteUi.ActiveId or "") then
            RefreshActiveVoteUi()
        else
            CloseMenu()
            lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
            ShowActiveVoteMenu()
        end
    elseif currentMenu ~= nil and currentMenuKind == "votestart" and voteSnapshot.Active ~= nil then
        CloseMenu()
        lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
        ShowActiveVoteMenu()
    elseif voteSnapshot.Active ~= nil and tostring(voteSnapshot.Active.Id or "") ~= "" and tostring(voteSnapshot.Active.Id or "") ~= lastShownActiveVoteId then
        lastShownActiveVoteId = tostring(voteSnapshot.Active.Id or "")
        ShowActiveVoteMenu()
    end
end)

SendReady()
SendVoteReady()
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 2000)
Timer.Wait(function() if not sharedState.Disabled then SendVoteReady() end end, 2500)
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 6000)
Timer.Wait(function() if not sharedState.Disabled then SendVoteReady() end end, 6500)

Hook.Patch(HUD_PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state == nil or state.Disabled then return end
    if GUI ~= nil and GUI.DisableHUD then return end

    if state.GuiRoot ~= nil then
        state.GuiRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
    end
    if state.ButtonRoot == nil and state.EnsureTopButtons ~= nil then
        state.EnsureTopButtons()
    end
    if state.ButtonRoot ~= nil then
        state.ButtonRoot:AddToGUIUpdateList(false, BUTTON_DRAW_ORDER)
    end
end)

Hook.Patch(PAUSE_PATCH_ID, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, params)
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
        if state.CurrentMenuKind == "voteactive" and state.BlockPauseMenu ~= true then
            return
        end
        if state.CurrentMenu ~= nil and state.CloseMenu ~= nil then
            state.CloseMenu()
        end
        if params ~= nil then params.PreventExecution = true end
        return false
    end
end, Hook.HookMethodType.Before)

Hook.Remove("keyUpdate", "VoidTraitor.ClientMenu.PauseGuard")
Hook.Remove("think", "VoidTraitor.ClientMenu.KeepPauseBlocked")
Hook.Remove("think", "VoidTraitor.ClientMenu.UiState")

Hook.Add("keyUpdate", "VoidTraitor.ClientMenu.PauseGuard", function()
    if sharedState.Disabled then return end
    if currentMenu ~= nil and IsEscapeHit() then
        RequestEscapeClose()
    end
end)

Hook.Add("think", "VoidTraitor.ClientMenu.UiState", function(deltaTime)
    if sharedState.Disabled then return end

    UpdateVoidTraitorMenuInteraction()

    uiStateCheckTimer = uiStateCheckTimer + (tonumber(deltaTime) or 0)
    if uiStateCheckTimer < 0.1 then return end
    uiStateCheckTimer = 0

    EnsureTopButtons()

    if IsLobbyScreenAvailable() then
        EnsureVoteButton()
        RefreshActiveVoteUi()
    else
        if currentMenuKind == "votestart" or currentMenuKind == "voteactive" then CloseMenu() end
        DestroyVoteButton()
    end
end)
