if SERVER then return end

local _, Common = ...
local NET_KILLFEED = "VoidTraitor_KillFeed"
local STATE_KEY = "VoidTraitorKillFeedState"
local GUI_PATCH_ID = "VoidTraitor.KillFeed.GUIUpdate"

local previousState = rawget(_G, STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.Clear ~= nil then previousState.Clear() end
    if previousState.Root ~= nil then Common.RemoveGuiComponent(previousState.Root) end
end

local state = {
    Disabled = false,
    Root = nil,
    List = nil,
    ListWidth = 0,
    Rows = {},
}
_G[STATE_KEY] = state

local ROW_LIFETIME = 15
local MAX_ROWS = 6
local ROW_HEIGHT = 40
local ICON_SIZE = 35
local ENTER_ANIM_DURATION = 1
local EXIT_ANIM_DURATION = 1
local ENTER_START_OFFSET_X = 300
local ROW_SPACING = 4
local TIME_BAR_STYLE = "MsCookieSKillFeed_TimeBar"
local TIME_BAR_STOP_STYLE = "MsCookieSKillFeed_TimeBar_Stop"

local BAR_FILL_COLOR = Color(255, 255, 255, 200)
local BAR_STOP_COLOR = Color(180, 180, 180, 255)
local ITEM_TEXT_COLOR = Color(211, 211, 211, 255)
local FATAL_WOUND_COLOR = Color(255, 180, 100, 255)
local DEAD_TEXT_COLOR = Color(200, 200, 200, 255)
local ARROW_COLOR = Color(255, 255, 0, 255)
local WHITE = Color(255, 255, 255, 255)
local TRANSPARENT = Color(0, 0, 0, 0)

local crewManagerDescriptor = Descriptors["Barotrauma.CrewManager"] or LuaUserData.RegisterType("Barotrauma.CrewManager")
LuaUserData.MakeFieldAccessible(crewManagerDescriptor, "guiFrame")

local function textWidth(text, font, maximum)
    if text == nil or text == "" then return 0 end
    return math.min(math.ceil(font.MeasureString(text).X) + 4, maximum)
end

local function getTeamColor(team)
    if team == tostring(CharacterTeamType.Team1) then return Color(144, 238, 144, 255) end
    if team == tostring(CharacterTeamType.Team2) then return Color(255, 200, 150, 255) end
    if team == tostring(CharacterTeamType.FriendlyNPC) then return Color(173, 216, 230, 255) end
    if team == tostring(CharacterTeamType.None) then return Color(255, 100, 100, 255) end
    return WHITE
end

local function getJobPrefab(actor)
    if actor == nil or actor.Job == "" then return nil end
    return JobPrefab.Get(actor.Job)
end

local function getItemPrefab(identifier)
    if identifier == nil or identifier == "" then return nil end
    return ItemPrefab.GetItemPrefab(identifier)
end

local function getAfflictionPrefab(identifier)
    if identifier == nil or identifier == "" then return nil end
    return AfflictionPrefab.Prefabs[identifier]
end

local function applyAlpha(component, alpha)
    if component == nil then return end

    local a = math.floor(math.max(0, math.min(255, 255 * alpha)))
    local color = component.Color
    local newColor = Color(color.R, color.G, color.B, a)
    component.Color = newColor
    component.HoverColor = newColor
    component.PressedColor = newColor
    component.SelectedColor = newColor

    for child in component.Children do
        applyAlpha(child, alpha)
    end
end

local function ensureUI()
    if state.Root ~= nil and state.Root.RectTransform.Parent ~= nil then return true end

    local crewManager = Game.GameSession ~= nil and Game.GameSession.CrewManager or nil
    if crewManager == nil or crewManager.guiFrame == nil then return false end

    state.Root = GUI.Frame(GUI.RectTransform(Vector2(1, 1), crewManager.guiFrame.RectTransform), nil)
    state.Root.CanBeFocused = false
    state.Root.Color = TRANSPARENT

    local screenWidth = Common.GetScreenSize()
    local listWidth = math.min(1000, screenWidth - 40)
    local listX = screenWidth - listWidth - 10
    state.ListWidth = listWidth

    state.List = GUI.Frame(GUI.RectTransform(Point(listWidth, 500), state.Root.RectTransform, GUI.Anchor.TopLeft), nil)
    state.List.RectTransform.AbsoluteOffset = Point(listX, 150)
    state.List.CanBeFocused = false
    state.List.Color = TRANSPARENT
    return true
end

local function removeRow(index)
    local row = state.Rows[index]
    if row ~= nil and row.Root ~= nil and row.Root.RectTransform.Parent ~= nil then
        row.Root.RectTransform.Parent = nil
    end
    table.remove(state.Rows, index)
end

local function clearRows()
    for index = #state.Rows, 1, -1 do
        removeRow(index)
    end
end
state.Clear = clearRows

local function relayoutRows()
    local y = 0
    for _, row in ipairs(state.Rows) do
        row.BaseY = y
        local currentX = row.Root.RectTransform.AbsoluteOffset.X
        row.Root.RectTransform.AbsoluteOffset = Point(currentX, y)
        y = y + ROW_HEIGHT + ROW_SPACING
    end
end

local function measureActor(actor, iconGap)
    local jobPrefab = getJobPrefab(actor)
    local hasIcon = jobPrefab ~= nil and jobPrefab.Icon ~= nil
    local width = textWidth(actor.Name, GUI.Style.Font, 200)
    if width < 20 then width = 20 end
    return (hasIcon and (ICON_SIZE + iconGap) or 0) + width
end

local function placeActor(row, actor, x, width, iconGap)
    local currentX = x
    local jobPrefab = getJobPrefab(actor)
    local hasIcon = jobPrefab ~= nil and jobPrefab.Icon ~= nil

    if hasIcon then
        local iconBox = GUI.Frame(GUI.RectTransform(Point(ICON_SIZE, ICON_SIZE), row.RectTransform, GUI.Anchor.TopLeft), nil)
        iconBox.RectTransform.AbsoluteOffset = Point(currentX, math.floor((ROW_HEIGHT - ICON_SIZE) / 2))
        iconBox.CanBeFocused = false
        iconBox.Color = TRANSPARENT

        local image = GUI.Image(GUI.RectTransform(Vector2(1, 1), iconBox.RectTransform), jobPrefab.Icon, true)
        image.CanBeFocused = false
        image.Color = jobPrefab.UIColor
        currentX = currentX + ICON_SIZE + iconGap
    end

    local nameWidth = width - (hasIcon and (ICON_SIZE + iconGap) or 0)
    if nameWidth < 10 then nameWidth = 10 end

    local text = GUI.TextBlock(
        GUI.RectTransform(Point(nameWidth, ROW_HEIGHT), row.RectTransform, GUI.Anchor.TopLeft),
        actor.Name,
        nil,
        GUI.Style.Font,
        GUI.Alignment.CenterLeft,
        false
    )
    text.RectTransform.AbsoluteOffset = Point(currentX, 0)
    text.CanBeFocused = false
    text.TextColor = getTeamColor(actor.Team)
    text.OutlineColor = Color.Black
    text.Shadow = true
end

local function measureItem(prefab, iconGap)
    if prefab == nil then return 0 end
    local sprite = prefab.InventoryIcon or prefab.Sprite
    local hasIcon = sprite ~= nil
    local name = prefab.Name ~= nil and prefab.Name.Value or ""
    local width = textWidth(name, GUI.Style.SmallFont, 180)
    if width < 20 then width = 20 end
    return (hasIcon and (ICON_SIZE + iconGap) or 0) + width
end

local function placeItem(row, prefab, x, width, iconGap)
    local currentX = x
    local sprite = prefab.InventoryIcon or prefab.Sprite
    local hasIcon = sprite ~= nil

    if hasIcon then
        local iconBox = GUI.Frame(GUI.RectTransform(Point(ICON_SIZE, ICON_SIZE), row.RectTransform, GUI.Anchor.TopLeft), nil)
        iconBox.RectTransform.AbsoluteOffset = Point(currentX, math.floor((ROW_HEIGHT - ICON_SIZE) / 2))
        iconBox.CanBeFocused = false
        iconBox.Color = TRANSPARENT

        local image = GUI.Image(GUI.RectTransform(Vector2(1, 1), iconBox.RectTransform), sprite, true)
        image.CanBeFocused = false
        currentX = currentX + ICON_SIZE + iconGap
    end

    local nameWidth = width - (hasIcon and (ICON_SIZE + iconGap) or 0)
    if nameWidth < 10 then nameWidth = 10 end

    local name = prefab.Name ~= nil and prefab.Name.Value or ""
    local text = GUI.TextBlock(
        GUI.RectTransform(Point(nameWidth, ROW_HEIGHT), row.RectTransform, GUI.Anchor.TopLeft),
        name,
        nil,
        GUI.Style.SmallFont,
        GUI.Alignment.CenterLeft,
        false
    )
    text.RectTransform.AbsoluteOffset = Point(currentX, 0)
    text.CanBeFocused = false
    text.TextColor = ITEM_TEXT_COLOR
    text.OutlineColor = Color.Black
    text.Shadow = true
end

local function measureAffliction(affliction, iconGap)
    if affliction == nil then return 0 end
    local hasIcon = affliction.Icon ~= nil
    local name = affliction.Name ~= nil and affliction.Name.Value or ""
    local width = textWidth(name, GUI.Style.SmallFont, 180)
    if width < 20 then width = 20 end
    return (hasIcon and (ICON_SIZE + iconGap) or 0) + width
end

local function placeAffliction(row, affliction, x, width, iconGap)
    local currentX = x
    local hasIcon = affliction.Icon ~= nil

    if hasIcon then
        local iconBox = GUI.Frame(GUI.RectTransform(Point(ICON_SIZE, ICON_SIZE), row.RectTransform, GUI.Anchor.TopLeft), nil)
        iconBox.RectTransform.AbsoluteOffset = Point(currentX, math.floor((ROW_HEIGHT - ICON_SIZE) / 2))
        iconBox.CanBeFocused = false
        iconBox.Color = TRANSPARENT

        local image = GUI.Image(GUI.RectTransform(Vector2(1, 1), iconBox.RectTransform), affliction.Icon, true)
        image.CanBeFocused = false
        image.Color = WHITE
        currentX = currentX + ICON_SIZE + iconGap
    end

    local nameWidth = width - (hasIcon and (ICON_SIZE + iconGap) or 0)
    if nameWidth < 10 then nameWidth = 10 end

    local name = affliction.Name ~= nil and affliction.Name.Value or ""
    local text = GUI.TextBlock(
        GUI.RectTransform(Point(nameWidth, ROW_HEIGHT), row.RectTransform, GUI.Anchor.TopLeft),
        name,
        nil,
        GUI.Style.SmallFont,
        GUI.Alignment.CenterLeft,
        false
    )
    text.RectTransform.AbsoluteOffset = Point(currentX, 0)
    text.CanBeFocused = false
    text.TextColor = FATAL_WOUND_COLOR
    text.OutlineColor = Color.Black
    text.Shadow = true
end

local function placeArrow(row, x, width)
    local text = GUI.TextBlock(
        GUI.RectTransform(Point(width, ROW_HEIGHT), row.RectTransform, GUI.Anchor.TopLeft),
        "→",
        nil,
        GUI.Style.SubHeadingFont,
        GUI.Alignment.Center,
        false
    )
    text.RectTransform.AbsoluteOffset = Point(x, 0)
    text.CanBeFocused = false
    text.TextColor = ARROW_COLOR
    text.OutlineColor = Color.Black
    text.Shadow = true
end

local function placeText(row, value, x, width, font, color)
    local text = GUI.TextBlock(
        GUI.RectTransform(Point(width, ROW_HEIGHT), row.RectTransform, GUI.Anchor.TopLeft),
        value,
        nil,
        font,
        GUI.Alignment.CenterLeft,
        false
    )
    text.RectTransform.AbsoluteOffset = Point(x, 0)
    text.CanBeFocused = false
    text.TextColor = color
    text.OutlineColor = Color.Black
    text.Shadow = true
end

local function addKillRow(attacker, victim, weaponIdentifier, afflictionIdentifier)
    if victim == nil or not ensureUI() then return end

    local itemPrefab = getItemPrefab(weaponIdentifier)
    local affliction = getAfflictionPrefab(afflictionIdentifier)
    local spacing = 10
    local arrowWidth = 26
    local padH = 8
    local iconGap = 4
    local parts = {}

    local function addPart(width, draw)
        table.insert(parts, { Width = width, Draw = draw })
    end

    if attacker ~= nil then
        local attackerWidth = measureActor(attacker, iconGap)
        addPart(attackerWidth, function(row, x) placeActor(row, attacker, x, attackerWidth, iconGap) end)

        if itemPrefab ~= nil then
            local itemWidth = measureItem(itemPrefab, iconGap)
            if itemWidth > 0 then
                addPart(itemWidth, function(row, x) placeItem(row, itemPrefab, x, itemWidth, iconGap) end)
            end
        end

        addPart(arrowWidth, function(row, x) placeArrow(row, x, arrowWidth) end)

        local victimWidth = measureActor(victim, iconGap)
        addPart(victimWidth, function(row, x) placeActor(row, victim, x, victimWidth, iconGap) end)

        if affliction ~= nil then
            local prefix = Common.Language.KillFeed.FatalWound
            local prefixWidth = textWidth(prefix, GUI.Style.SmallFont, 100)
            if prefixWidth > 0 then
                addPart(prefixWidth, function(row, x) placeText(row, prefix, x, prefixWidth, GUI.Style.SmallFont, FATAL_WOUND_COLOR) end)
            end

            local afflictionWidth = measureAffliction(affliction, iconGap)
            if afflictionWidth > 0 then
                addPart(afflictionWidth, function(row, x) placeAffliction(row, affliction, x, afflictionWidth, iconGap) end)
            end
        end
    else
        local victimWidth = measureActor(victim, iconGap)
        addPart(victimWidth, function(row, x) placeActor(row, victim, x, victimWidth, iconGap) end)

        local description = nil
        if affliction ~= nil and affliction.CauseOfDeathDescription ~= nil then
            local value = affliction.CauseOfDeathDescription.Value
            if value ~= nil and value ~= "" then description = value end
        end
        if description == nil then description = Common.Language.KillFeed.Died end

        local descriptionWidth = textWidth(description, GUI.Style.SmallFont, 400)
        if descriptionWidth < 20 then descriptionWidth = 20 end
        addPart(descriptionWidth, function(row, x) placeText(row, description, x, descriptionWidth, GUI.Style.SmallFont, DEAD_TEXT_COLOR) end)
    end

    local contentWidth = 0
    for index, part in ipairs(parts) do
        contentWidth = contentWidth + part.Width
        if index < #parts then contentWidth = contentWidth + spacing end
    end

    local actualWidth = padH * 2 + contentWidth
    local maxWidth = state.ListWidth - 20
    if actualWidth > maxWidth then actualWidth = maxWidth end

    local row = GUI.Frame(GUI.RectTransform(Point(actualWidth, ROW_HEIGHT), state.List.RectTransform, GUI.Anchor.TopLeft), "GUIToolTip")
    row.RectTransform.AbsoluteOffset = Point(0, 0)
    row.CanBeFocused = false
    row.Color = Color(0, 0, 0, 166)

    local fillStyle = GUI.Style.GetComponentStyle(TIME_BAR_STYLE) ~= nil and TIME_BAR_STYLE or nil
    local stopStyle = GUI.Style.GetComponentStyle(TIME_BAR_STOP_STYLE) ~= nil and TIME_BAR_STOP_STYLE or nil

    local barFill = GUI.Frame(GUI.RectTransform(Vector2(1, 1), row.RectTransform, GUI.Anchor.CenterRight), fillStyle)
    barFill.CanBeFocused = false
    barFill.Color = fillStyle ~= nil and BAR_FILL_COLOR or TRANSPARENT
    barFill:SetAsFirstChild()

    local barStop = GUI.Frame(GUI.RectTransform(Vector2(1, 1), row.RectTransform, GUI.Anchor.CenterLeft), stopStyle)
    barStop.CanBeFocused = false
    barStop.Visible = false
    barStop.Color = stopStyle ~= nil and BAR_STOP_COLOR or TRANSPARENT
    barStop:SetAsFirstChild()

    local currentX = padH
    for index, part in ipairs(parts) do
        part.Draw(row, currentX)
        currentX = currentX + part.Width
        if index < #parts then currentX = currentX + spacing end
    end

    table.insert(state.Rows, {
        Root = row,
        TimeBarFill = barFill,
        TimeBarStop = barStop,
        Remaining = ROW_LIFETIME,
        EnterTimer = 0,
        ExitTimer = -1,
        Exiting = false,
        Hovered = false,
        BaseX = state.ListWidth - actualWidth - 10,
        BaseY = 0,
        Width = actualWidth,
    })

    while #state.Rows > MAX_ROWS do
        removeRow(1)
    end

    relayoutRows()
end

local function readActor(message)
    return {
        Name = message.ReadString(),
        Team = message.ReadString(),
        Job = message.ReadString(),
    }
end

local function tick(deltaTime)
    if #state.Rows == 0 then return end

    if state.Root ~= nil and state.Root.RectTransform.Parent == nil then
        state.Root = nil
        state.List = nil
        state.Rows = {}
        return
    end

    local mousePosition = PlayerInput.MousePosition
    local mousePoint = Point(math.floor(mousePosition.X), math.floor(mousePosition.Y))

    for index = #state.Rows, 1, -1 do
        local row = state.Rows[index]
        local hovered = row.Root.Rect.Contains(mousePoint)
        row.Hovered = hovered

        local enterOffsetX = 0
        if row.EnterTimer < 1 then
            row.EnterTimer = math.min(1, row.EnterTimer + deltaTime / ENTER_ANIM_DURATION)
            local t = row.EnterTimer
            local eased = 1 - (1 - t) * (1 - t)
            enterOffsetX = math.floor(ENTER_START_OFFSET_X * (1 - eased))
        end
        row.Root.RectTransform.AbsoluteOffset = Point(row.BaseX + enterOffsetX, row.BaseY)

        if row.Exiting then
            row.ExitTimer = row.ExitTimer + deltaTime
            local t = math.max(0, math.min(1, row.ExitTimer / EXIT_ANIM_DURATION))
            local newHeight = math.floor(ROW_HEIGHT + (1 - ROW_HEIGHT) * t)
            row.Root.RectTransform:Resize(Point(row.Width, math.max(1, newHeight)), true)
            applyAlpha(row.Root, 1 - t)

            if t >= 1 then
                removeRow(index)
                relayoutRows()
            end
        else
            row.TimeBarFill.Visible = true
            row.TimeBarStop.Visible = hovered

            if not hovered and not Game.Paused then
                row.Remaining = math.max(0, row.Remaining - deltaTime)
            end

            if not hovered then
                local progress = math.max(0, math.min(1, row.Remaining / ROW_LIFETIME))
                row.TimeBarFill.RectTransform.RelativeSize = Vector2(progress, 1)
            end

            if row.Remaining <= 0 then
                row.Exiting = true
                row.ExitTimer = 0
            end
        end
    end
end

Networking.Receive(NET_KILLFEED, function(message)
    if state.Disabled or GUI.DisableHUD or GUI.Screen.Selected ~= Game.GameScreen then return end

    local attacker = nil
    if message.ReadBoolean() then attacker = readActor(message) end
    local victim = readActor(message)
    local weaponIdentifier = message.ReadString()
    local afflictionIdentifier = message.ReadString()
    addKillRow(attacker, victim, weaponIdentifier, afflictionIdentifier)
end)

Hook.Patch(GUI_PATCH_ID, "Barotrauma.CrewManager", "AddToGUIUpdateList", function()
    if state.Disabled then return end
    if state.Root ~= nil and state.Root.RectTransform.Parent ~= nil then
        state.Root:AddToGUIUpdateList()
    end
end, Hook.HookMethodType.After)

Hook.Add("think", "VoidTraitor.KillFeed.Think", function(deltaTime)
    if state.Disabled then return end
    tick(deltaTime)
end)

Hook.Add("roundEnd", "VoidTraitor.KillFeed.RoundEnd", clearRows)
