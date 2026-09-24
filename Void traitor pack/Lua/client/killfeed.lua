if SERVER then return end

local _, Common = ...
local NET_KILLFEED = "VoidTraitor_KillFeed"
local STATE_KEY = "VoidTraitorKillFeedState"
local HUD_PATCH_ID = "VoidTraitor.KillFeed.Hud"

local previousState = rawget(_G, STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.Clear ~= nil then previousState.Clear() end
    if previousState.Root ~= nil then Common.RemoveGuiComponent(previousState.Root) end
end

local state = {
    Disabled = false,
    Rows = {},
    Root = nil,
    ScreenWidth = 0,
    ScreenHeight = 0,
}
_G[STATE_KEY] = state

local ROW_LIFETIME = 15
local MAX_ROWS = 6
local ROW_HEIGHT = Common.SafeIntScale(40)
local ROW_SPACING = Common.SafeIntScale(4)
local TOP_OFFSET = Common.SafeIntScale(150)
local RIGHT_OFFSET = Common.SafeIntScale(10)
local MAX_ROW_WIDTH = Common.SafeIntScale(900)

local function getTeamColor(team)
    if team == tostring(CharacterTeamType.Team1) then
        return Color(144, 238, 144, 255)
    elseif team == tostring(CharacterTeamType.Team2) then
        return Color(255, 200, 150, 255)
    elseif team == tostring(CharacterTeamType.FriendlyNPC) then
        return Color(173, 216, 230, 255)
    elseif team == tostring(CharacterTeamType.None) then
        return Color(255, 100, 100, 255)
    end

    return Color(255, 255, 255, 255)
end

local function getItemData(identifier)
    if identifier == nil or identifier == "" then return nil, nil, "" end

    local prefab = ItemPrefab.GetItemPrefab(identifier)
    if prefab == nil then return nil, nil, identifier end

    local sprite = prefab.InventoryIcon or prefab.Sprite
    local color = prefab.InventoryIcon ~= nil and prefab.InventoryIconColor or prefab.SpriteColor
    return sprite, color, prefab.Name.Value
end

local function addIcon(parent, sprite, color)
    if sprite == nil then return false end

    local box = GUI.Frame(Common.CreateRect(0.18, 0.84, parent, nil), nil)
    box.Color = Color(0, 0, 0, 0)
    box.CanBeFocused = false

    local image = GUI.Image(Common.CreateRect(1, 1, box, GUI.Anchor.Center), sprite, true)
    image.Color = color or Color(255, 255, 255, 255)
    image.CanBeFocused = false
    return true
end

local function addActor(parent, width, actor)
    local holder = GUI.Frame(Common.CreateRect(width, 1, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local layout = GUI.LayoutGroup(Common.CreateRect(1, 1, holder, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    layout.Stretch = true
    layout.RelativeSpacing = 0.02

    local sprite, color = Common.GetPrefabIconData(actor.Job ~= "" and ("job:" .. actor.Job) or "")
    local hasIcon = addIcon(layout, sprite, color)

    local text = Common.CreateText(
        layout,
        hasIcon and 0.80 or 1,
        1,
        nil,
        actor.Name,
        GUI.Alignment.Left,
        1,
        getTeamColor(actor.Team),
        false
    )
    text.Font = GUI.Style.Font
end

local function addWeapon(parent, width, identifier)
    local holder = GUI.Frame(Common.CreateRect(width, 1, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local layout = GUI.LayoutGroup(Common.CreateRect(1, 1, holder, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    layout.Stretch = true
    layout.RelativeSpacing = 0.02

    local sprite, color, name = getItemData(identifier)
    local hasIcon = addIcon(layout, sprite, color)

    local text = Common.CreateText(
        layout,
        hasIcon and 0.80 or 1,
        1,
        nil,
        name,
        GUI.Alignment.Left,
        0.88,
        Color(215, 215, 215, 255),
        false
    )
    text.Font = GUI.Style.SmallFont
end

local function addArrow(parent, width)
    local text = Common.CreateText(
        parent,
        width,
        1,
        nil,
        "→",
        GUI.Alignment.Center,
        1,
        Color(235, 235, 235, 255),
        false
    )
    text.Font = GUI.Style.Font
end

local function ensureRoot()
    local width, height = Common.GetScreenSize()

    if state.Root == nil then
        state.Root = GUI.Frame(Common.CreateCanvasRect(0, 0, width, height), nil)
        state.Root.Color = Color(0, 0, 0, 0)
        state.Root.CanBeFocused = false
        state.MenuRoot = state.Root
    elseif width ~= state.ScreenWidth or height ~= state.ScreenHeight then
        state.Root.RectTransform:Resize(Point(width, height), true)
    end

    state.ScreenWidth = width
    state.ScreenHeight = height
end

local function relayoutRows()
    ensureRoot()

    local rowWidth = math.max(1, math.min(MAX_ROW_WIDTH, state.ScreenWidth - RIGHT_OFFSET * 2))
    for index, row in ipairs(state.Rows) do
        row.Root.RectTransform:Resize(Point(rowWidth, ROW_HEIGHT), true)
        row.Root.RectTransform.AbsoluteOffset = Point(
            state.ScreenWidth - rowWidth - RIGHT_OFFSET,
            TOP_OFFSET + (index - 1) * (ROW_HEIGHT + ROW_SPACING)
        )
    end
end

local function removeRow(index)
    local row = state.Rows[index]
    if row ~= nil and row.Root ~= nil then
        Common.RemoveGuiComponent(row.Root)
    end
    table.remove(state.Rows, index)
end

local function clearRows()
    for index = #state.Rows, 1, -1 do
        removeRow(index)
    end
end

state.Clear = clearRows

local function readActor(message)
    return {
        Name = message.ReadString(),
        Team = message.ReadString(),
        Job = message.ReadString(),
    }
end

local function addRow(killer, victim, weaponIdentifier)
    ensureRoot()

    local row = GUI.Frame(
        GUI.RectTransform(Point(MAX_ROW_WIDTH, ROW_HEIGHT), state.Root.RectTransform, GUI.Anchor.TopLeft),
        "GUIToolTip"
    )
    row.Color = Color(0, 0, 0, 170)
    row.CanBeFocused = false

    local content = GUI.LayoutGroup(Common.CreateRect(0.97, 0.88, row, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.01

    if killer ~= nil then
        if weaponIdentifier ~= "" then
            addActor(content, 0.28, killer)
            addWeapon(content, 0.30, weaponIdentifier)
            addArrow(content, 0.06)
            addActor(content, 0.28, victim)
        else
            addActor(content, 0.42, killer)
            addArrow(content, 0.08)
            addActor(content, 0.42, victim)
        end
    else
        addActor(content, 0.50, victim)
        local died = Common.CreateText(
            content,
            0.40,
            1,
            nil,
            Common.Language.KillFeed.Died,
            GUI.Alignment.Left,
            0.9,
            Color(200, 200, 200, 255),
            false
        )
        died.Font = GUI.Style.SmallFont
    end

    local timeBar = GUI.Frame(Common.CreateRect(1, 0.055, row, GUI.Anchor.BottomRight), nil)
    timeBar.Color = Color(225, 225, 225, 180)
    timeBar.CanBeFocused = false

    table.insert(state.Rows, {
        Root = row,
        TimeBar = timeBar,
        Remaining = ROW_LIFETIME,
    })

    while #state.Rows > MAX_ROWS do
        removeRow(1)
    end

    relayoutRows()
end

Networking.Receive(NET_KILLFEED, function(message)
    local killer = nil
    if message.ReadBoolean() then
        killer = readActor(message)
    end

    local victim = readActor(message)
    local weaponIdentifier = message.ReadString()
    addRow(killer, victim, weaponIdentifier)
end)

Hook.Add("think", "VoidTraitor.KillFeed.Think", function(deltaTime)
    if state.Disabled or #state.Rows == 0 then return end

    local width, height = Common.GetScreenSize()
    if width ~= state.ScreenWidth or height ~= state.ScreenHeight then
        relayoutRows()
    end

    local mousePosition = PlayerInput.MousePosition
    for index = #state.Rows, 1, -1 do
        local row = state.Rows[index]
        local hovered = row.Root.Rect.Contains(mousePosition)

        if not hovered then
            row.Remaining = row.Remaining - deltaTime
        end

        if row.Remaining <= 0 then
            removeRow(index)
        else
            row.TimeBar.RectTransform.RelativeSize = Vector2(math.max(0, row.Remaining / ROW_LIFETIME), 0.055)
        end
    end

    if #state.Rows > 0 then
        relayoutRows()
    end
end)

Hook.Add("roundEnd", "VoidTraitor.KillFeed.RoundEnd", clearRows)

Common.InstallHudPatch(HUD_PATCH_ID, STATE_KEY, 130, 130)
