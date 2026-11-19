if SERVER then return end
-- Anomalies on the client (traitormod Lua/gamemodes/station/anomalies.lua): what pulses, bolts, a supercritical
-- anomaly and the vessel's beeping look and sound like, and the window of the anomaly scanner, the vessel and the
-- generator. The server writes the window's lines and buttons; this only shows them and sends the button pressed.
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorAnomalyGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
end
local UI = {}
_G.VoidTraitorAnomalyGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local SOUND_RANGE, SOUND_GAIN = 1500, 0.8
local TEXT_COLOR = Color(230, 230, 220, 255)
local LINE_COLORS = {
    good = Color(90, 200, 110, 255),
    warning = Color(225, 185, 80, 255),
    danger = Color(220, 60, 70, 255),
    unstable = Color(221, 160, 221, 255),
    transformation = Color(107, 117, 250, 255),
    error = Color(235, 60, 60, 255),
    muted = Color(160, 160, 150, 255),
}

-- The game loads a sound in the background and skips playing it until then, so all of them load with the module.
local function loadSound(file) return gameMain.SoundManager.LoadSound(file) end
local sounds = {
    pulse = loadSound("Content/Items/Alien/AlienCoil2.ogg"),
    supercritical = loadSound("Content/Items/Reactor/ReactorOverheatAlarm.ogg"),
    bolt = loadSound("Content/Items/Electricity/MACHINERY_zap1.ogg"),
    beep = loadSound(packPath .. "/Sounds/Anomalies/vessel_warning.ogg"),
    generate = loadSound(packPath .. "/Sounds/Anomalies/anomaly_generate.ogg"),
}

local function particle(name, position, velocity, size, color)
    local created = gameMain.ParticleManager.CreateParticle(name, position, velocity, 0, nil)
    if created == nil then return end
    created.Size = created.Size * size
    if color ~= nil then created.ColorMultiplier = Vector4(color.R / 255, color.G / 255, color.B / 255, 1) end
end

-- a ring of the anomaly's own colour, as SS14's pulse animation
local function burst(item, position, amount)
    local light = item ~= nil and not item.Removed and item.GetComponentString("LightComponent") or nil
    local color = light ~= nil and light.LightColor or nil
    for index = 1, amount do
        local angle = index / amount * math.pi * 2
        particle("anomaly", position, Vector2(math.cos(angle), math.sin(angle)) * math.random(200, 500), 0.08, color)
    end
end

-- sparks along the line of SS14's lightning bolt
local function bolt(from, to)
    local steps = math.max(1, math.floor(Vector2.Distance(from, to) / 60))
    for step = 0, steps do
        particle("ElectricShock", from + (to - from) * (step / steps), Vector2(0, 0), 0.15, nil)
    end
end

Networking.Receive("VoidTraitor_AnomalyFx", function(message)
    local item, kind = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    local position = Vector2(message.ReadSingle(), message.ReadSingle())
    local target = Vector2(message.ReadSingle(), message.ReadSingle())
    local range = message.ReadSingle()
    if kind == "explosion" then
        -- only the look: the server already dealt the damage
        Explosion(range, 0, 0, 0, 0, 0).Explode(position, nil)
        return
    end
    if sounds[kind] ~= nil then sounds[kind].Play(SOUND_GAIN, SOUND_RANGE, kind == "bolt" and target or position) end
    if kind == "pulse" then
        burst(item, position, 30)
    elseif kind == "supercritical" then
        burst(item, position, 60)
    elseif kind == "bolt" then
        bolt(position, target)
    end
end)

function UI.Send(action)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_AnomalyAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
    Networking.Send(message)
end

function UI.CloseMenu()
    UI.Send("close")
    local character = Character.Controlled
    if character ~= nil and character.SelectedItem ~= nil and character.SelectedItem.ID == UI.ItemId then
        character.EmulateInput(inputTypes.Deselect)
        character.SelectedItem = nil
    end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update, UI.SelectedItem = nil, nil, nil, nil, nil
end

local function showLines(group, lines)
    group.ClearChildren()
    for _, line in ipairs(lines) do
        local block = Common.CreateText(group, 1, 0, nil, line.Text, GUI.Alignment.TopLeft, 1, LINE_COLORS[line.Color] or TEXT_COLOR, true)
        block.CanBeFocused = false
        if line.Text == "" then Common.FitHeightToText(block) else
            block.CalculateHeightFromText()
            Common.SetFixedHeight(block, block.Rect.Height)
        end
    end
    group.ForceLayoutRecalculation()
end

-- the window fits its lines, up to most of the screen
local function fitHeight(root, group)
    local needed = 0
    for child in group.Children do needed = needed + child.Rect.Height + group.AbsoluteSpacing end
    local _, screenHeight = Common.GetScreenSize()
    local height = math.floor(math.min(screenHeight * 0.8, root.Rect.Height - group.Rect.Height + needed))
    if math.abs(height - root.Rect.Height) > 2 then
        root.RectTransform.NonScaledSize = Point(root.Rect.Width, height)
        root.ForceLayoutRecalculation()
    end
end

function UI.Show(itemId, panel)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(panel) return end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.ItemId = itemId
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(math.min(Common.SafeIntScale(480), screenWidth * 0.4))
    local root = GUI.Frame(GUI.RectTransform(Point(width, math.floor(screenHeight * 0.5)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, panel.Title, panel.Close, function()
        UI.CloseMenu()
        return true
    end)
    local group = GUI.LayoutGroup(Common.CreateRect(1, 1, layout))
    group.AbsoluteSpacing = math.floor(Common.GetGap() / 2)
    local buttons = {}
    if #panel.Buttons > 0 then
        local row = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
        row.Stretch = true
        row.AbsoluteSpacing = Common.GetGap()
        Common.SetFixedHeight(row, Common.GetStyleHeight("GUIButton"))
        for index, entry in ipairs(panel.Buttons) do
            local button = Common.CreateButton(row, 1 / #panel.Buttons, entry.Label)
            local action = entry.Action
            button.OnClicked = function() UI.Send(action) return true end
            buttons[index] = button
        end
    end
    local shown
    UI.Update = function(state)
        local text = json.serialize(state.Lines)
        if text ~= shown then
            shown = text
            showLines(group, state.Lines)
            fitHeight(root, group)
        end
        for index, button in ipairs(buttons) do
            if state.Buttons[index] ~= nil then button.Enabled = state.Buttons[index].Enabled end
        end
    end
    root.ForceLayoutRecalculation()
    UI.Update(panel)
end

Networking.Receive("VoidTraitor_AnomalyPanel", function(message)
    local itemId, panel = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.SelectedItem ~= nil and UI.SelectedItem.ID == itemId
        and character.SelectedItem == UI.SelectedItem then UI.Show(itemId, panel) end
end)
Common.AddWindowLayer(120, function()
    if not UI.Disabled and UI.MenuRoot ~= nil then UI.MenuRoot:AddToGUIUpdateList(false, 0) end
end)
Common.InstallPausePatch("VoidTraitor.Anomaly.Pause", "VoidTraitorAnomalyGuiState")
Hook.Add("roundEnd", "VoidTraitor.Anomaly.End", function() UI.CloseMenu() end)
Hook.Add("think", "VoidTraitor.Anomaly.Selection", function()
    -- the anomalies, the vessel and the generator share the tag
    Common.UpdateSelectedItemMenu(UI, "vt_anomaly_panel", function(selected)
        local message = Networking.Start("VoidTraitor_AnomalyOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
end)
