if SERVER then return end

-- Speaker list after the SpeakerList mod (Workshop 3642060355), rewritten in Lua: on the right, everyone this client
-- hears right now with a loudness bar and where the voice comes from (dead chat, local, the radio channel; the names
-- come from Lua/client/radio.lua). A click on a row opens the vanilla player panel with its volume slider and mute.
-- The look, the position and the volumes set there are kept between sessions in a file next to the game's saves.
-- Only voices the server sends to this client show up.
local _, Common = ...
local text = Common.Language.Speakers

local STATE_KEY = "VoidTraitorSpeakersState"
local RADIO_STATE_KEY = "VoidTraitorRadioState"
local PATCH_ID = "VoidTraitor.Speakers"
local MENU_DRAW_ORDER, HUD_DRAW_ORDER = 124, 4
local SETTINGS_FILE = "VoidTraitorSpeakers.txt"
-- loudness (amplitude × gain × the player's volume) from which a client counts as speaking, as in the original
local SPEAKING_THRESHOLD = 0.01
-- how long a row stays after the voice stops, per look
local FADE_SECONDS = { Basic = 0.9, Detailed = 2.1 }
local LOOKS = { "Basic", "Detailed" }
-- sizes in 1920x1080 pixels, as in the original
local BAR_WIDTH, BAR_HEIGHT, ROW_GAP, MARGIN, TOP, ICON_SIZE, BUTTON_SIZE = 150, 20, 25, 10, 100, 16, 16
local OUTLINE = Color(128, 145, 153)
local SHADOW = Color(0, 0, 0)
-- vanilla chat colours (ChatMessage.MessageColor): local, radio, dead
local SOURCE_COLORS = { Local = Color(190, 198, 205), Radio = Color(238, 208, 0), Dead = Color(136, 177, 255) }

local previous = rawget(_G, STATE_KEY)
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
    Common.RemoveGuiComponent(previous.ButtonRoot)
end
local UI = { Disabled = false }
_G[STATE_KEY] = UI

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local radioState = rawget(_G, RADIO_STATE_KEY)

-- Look, and the list's top left corner (where the bars start) as a fraction of the screen; nil until moved.
local settings = { Look = "Detailed", X = nil, Y = nil }
-- account id -> voice volume the player set for them
local volumes = {}
local saveQueued = false
-- rows in the order they appeared: { Client, Name, Fade, Amplitude }
local rows = {}
local rowOf = {}
-- clients whose voice arrived since the last update
local heard = {}
-- clients whose saved volume was applied this session
local applied = {}
-- nil, "waiting" for the mouse button, or { Mouse, X, Y } (where the drag started) while the list is dragged
local moving = nil
-- the think hook runs only while rows are shown or the list is moved
local updating = false
local lastUpdate = 0
local spectateIcon = nil
local rowButtons = {}
local settingsButton, dragArea

-- the save folder is one of the few places client Lua may write to
local function settingsPath()
    return Game.SaveFolder .. "/" .. SETTINGS_FILE
end

local function save()
    local lines = { "look " .. settings.Look }
    if settings.X ~= nil then lines[#lines + 1] = string.format("position %.4f %.4f", settings.X, settings.Y) end
    for id, volume in pairs(volumes) do lines[#lines + 1] = string.format("volume %s %.2f", id, volume) end
    File.Write(settingsPath(), table.concat(lines, "\n"))
end

-- the volume slider moves the value many times a second
local function queueSave()
    if saveQueued then return end
    saveQueued = true
    Timer.Wait(function()
        saveQueued = false
        save()
    end, 1000)
end

local function load()
    local path = settingsPath()
    if not File.Exists(path) then return end
    for line in string.gmatch(File.Read(path), "[^\r\n]+") do
        local key, first, second = string.match(line, "^(%S+) (%S+) ?(%S*)$")
        if key == "look" and FADE_SECONDS[first] ~= nil then
            settings.Look = first
        elseif key == "position" then
            settings.X, settings.Y = tonumber(first), tonumber(second)
        elseif key == "volume" and tonumber(second) ~= nil then
            volumes[first] = tonumber(second)
        end
    end
end

local function accountKey(client)
    local account = client.AccountId
    return account ~= nil and account.StringRepresentation or nil
end

local function applyVolume(client)
    if applied[client] then return end
    applied[client] = true
    local key = accountKey(client)
    if key ~= nil and volumes[key] ~= nil then client.VoiceVolume = volumes[key] end
end

local function size(value)
    return Common.SafeIntScale(value)
end

local function screenSize()
    return gameMain.GraphicsWidth, gameMain.GraphicsHeight
end

local function rowHeight()
    return size(BAR_HEIGHT) + size(ROW_GAP)
end

-- the list's top left corner in pixels, kept on screen
local function origin()
    local width, height = screenSize()
    local x, y = width - size(BAR_WIDTH) - size(MARGIN), size(TOP)
    if settings.X ~= nil then x, y = settings.X * width, settings.Y * height end
    x = Common.Clamp(x, 0, math.max(0, width - size(BAR_WIDTH) - size(BUTTON_SIZE)))
    y = Common.Clamp(y, size(BUTTON_SIZE), math.max(0, height - size(BAR_HEIGHT)))
    return math.floor(x), math.floor(y)
end

local function isSpeaking(client)
    local sound = client.VoipSound
    if sound == nil or not sound.IsPlaying or client.Muted or client.MutedLocally or radioState.IsVoiceMuted(client) then return false end
    return sound.CurrentAmplitude * sound.Gain * client.VoiceVolume > SPEAKING_THRESHOLD
end

local function fade(color, alpha)
    return Color(math.floor(color.R * alpha), math.floor(color.G * alpha), math.floor(color.B * alpha), math.floor(255 * alpha))
end

local function drawText(spriteBatch, x, y, value, color, alpha)
    local font = GUI.Style.SmallFont
    GUI.DrawString(spriteBatch, Vector2(x + 1, y + 1), value, fade(SHADOW, alpha * 0.8), nil, 0, font)
    GUI.DrawString(spriteBatch, Vector2(x, y), value, fade(color, alpha), nil, 0, font)
end

-- job icon and name colour in the detailed look; spectators and the dead get the spectator icon
local function identity(client)
    local character = client.Character
    local job = character ~= nil and not character.IsDead and character.Info ~= nil and character.Info.Job or nil
    if job ~= nil then return job.Prefab.IconSmall, job.Prefab.UIColor end
    if spectateIcon == nil then spectateIcon = GUI.Style.GetComponentStyle("SpectateIcon").GetDefaultSprite() end
    return spectateIcon, SOURCE_COLORS.Dead
end

-- the client's name, after the role on its ID card while it lives in Station; taken when its row appears
local function speakerName(client)
    local character = client.Character
    local role = character ~= nil and not character.IsDead and Common.GetCardRole(character) or nil
    return role ~= nil and role .. " " .. client.Name or client.Name
end

-- Where the row's name starts on the left, for the click area.
local function nameLeft(row, x)
    local font = GUI.Style.SmallFont
    local left = x - size(5) - font.MeasureString(row.Name).X
    if settings.Look == "Detailed" then left = left - size(ICON_SIZE) - size(3) end
    return math.floor(left)
end

local function drawRow(spriteBatch, row, x, y)
    local alpha = math.min(row.Fade / FADE_SECONDS[settings.Look], 1)
    local font = GUI.Style.SmallFont
    local barWidth, barHeight = size(BAR_WIDTH), size(BAR_HEIGHT)
    local source, sourceName = radioState.VoiceSource(row.Client)
    local nameColor, barColor = Color(255, 255, 255), GUI.Style.Green.Value
    local textY = y + (barHeight - font.LineHeight) / 2
    if settings.Look == "Detailed" then
        local icon, color = identity(row.Client)
        nameColor, barColor = color, SOURCE_COLORS[source]
        if icon ~= nil then
            local iconSize = size(ICON_SIZE)
            local scale = math.min(1, iconSize / math.max(1, icon.SourceRect.Width, icon.SourceRect.Height))
            local center = Vector2(nameLeft(row, x) + iconSize / 2, y + barHeight / 2)
            icon.Draw(spriteBatch, center + Vector2(1.5, 1.5), fade(SHADOW, alpha * 0.85), 0, scale)
            icon.Draw(spriteBatch, center, fade(nameColor, alpha), 0, scale)
        end
    end
    local name = row.Name
    drawText(spriteBatch, x - size(5) - font.MeasureString(name).X, textY, name, nameColor, alpha)
    GUI.DrawRectangle(spriteBatch, Vector2(x, y), Vector2(barWidth * row.Amplitude, barHeight), fade(barColor, alpha * 0.85), true)
    GUI.DrawRectangle(spriteBatch, Vector2(x, y), Vector2(barWidth, barHeight), fade(OUTLINE, alpha), false)
    drawText(spriteBatch, x + size(4), textY, sourceName, Color(255, 255, 255), alpha)
end

local function draw(spriteBatch)
    local x, y = origin()
    for _, row in ipairs(rows) do
        if row.Fade > 0 then
            drawRow(spriteBatch, row, x, y)
            y = y + rowHeight()
        end
    end
    if moving ~= nil then
        local hint = moving == "waiting" and text.MoveHint or text.MovingHint
        local font = GUI.Style.SmallFont
        local hintX, hintY = origin()
        -- ends where the bars end, so it stays on screen at the right edge
        hintX = math.max(0, hintX + size(BAR_WIDTH) - font.MeasureString(hint).X)
        drawText(spriteBatch, hintX, hintY - size(BUTTON_SIZE) - font.LineHeight, hint, Color(224, 224, 224), 1)
    end
end

local function placeButton(button, x, y, width, height)
    button.RectTransform.NonScaledSize = Point(math.max(1, width), math.max(1, height))
    button.RectTransform.AbsoluteOffset = Point(x, y)
    button.Visible = true
end

local function transparentButton(parent)
    local button = GUI.Button(GUI.RectTransform(Point(1, 1), parent.RectTransform, GUI.Anchor.TopLeft), "", GUI.Alignment.Center, nil)
    local clear = Color(0, 0, 0, 0)
    button.Color, button.HoverColor, button.PressedColor, button.SelectedColor = clear, clear, clear, clear
    button.Visible = false
    return button
end

-- Click areas follow the rows; the settings button sits above the first row on the right, as in the original.
local function placeButtons()
    local x, y = origin()
    local shown = 0
    for _, row in ipairs(rows) do
        if row.Fade > 0 then
            shown = shown + 1
            local button = rowButtons[shown]
            if button == nil then
                button = transparentButton(UI.ButtonRoot)
                button.OnClicked = function()
                    if gameMain.NetLobbyScreen ~= nil then gameMain.NetLobbyScreen.SelectPlayer(button.UserData) end
                    return true
                end
                rowButtons[shown] = button
            end
            button.UserData = row.Client
            local left = nameLeft(row, x)
            placeButton(button, left, y, x + size(BAR_WIDTH) - left, size(BAR_HEIGHT))
            y = y + rowHeight()
        end
    end
    for index = shown + 1, #rowButtons do rowButtons[index].Visible = false end
    local buttonSize = size(BUTTON_SIZE)
    local originX, originY = origin()
    placeButton(settingsButton, originX + size(BAR_WIDTH) - buttonSize, originY - buttonSize - size(4), buttonSize, buttonSize)
    settingsButton.Visible = shown > 0 and moving == nil
    dragArea.Visible = moving ~= nil
    if moving ~= nil then
        local width, height = screenSize()
        placeButton(dragArea, 0, 0, width, height)
    end
end

-- While moving, a full-screen area takes the mouse so the drag doesn't reach the game.
local function updateMove()
    if moving == nil then return end
    local mouse = PlayerInput.MousePosition
    if moving == "waiting" then
        if PlayerInput.PrimaryMouseButtonHeld() then
            local x, y = origin()
            moving = { Mouse = mouse, X = x, Y = y }
        end
        return
    end
    local width, height = screenSize()
    settings.X = (moving.X + mouse.X - moving.Mouse.X) / width
    settings.Y = (moving.Y + mouse.Y - moving.Mouse.Y) / height
    if not PlayerInput.PrimaryMouseButtonHeld() then
        local x, y = origin()
        settings.X, settings.Y = x / width, y / height
        moving = nil
        save()
    end
end

local function update()
    local now = Timer.GetTime()
    local delta = math.min(now - lastUpdate, 0.1)
    lastUpdate = now
    for client in pairs(heard) do
        if rowOf[client] == nil and isSpeaking(client) then
            local row = { Client = client, Name = speakerName(client), Fade = 0, Amplitude = 0 }
            rows[#rows + 1] = row
            rowOf[client] = row
        end
        heard[client] = nil
    end
    for index = #rows, 1, -1 do
        local row = rows[index]
        if isSpeaking(row.Client) then
            row.Fade = FADE_SECONDS[settings.Look]
            row.Amplitude = math.min(row.Client.VoipSound.CurrentAmplitude * 2, 1)
        else
            row.Fade = row.Fade - delta
            if row.Fade <= 0 then
                table.remove(rows, index)
                rowOf[row.Client] = nil
            end
        end
    end
    updateMove()
    placeButtons()
    if #rows == 0 and moving == nil then
        updating = false
        Hook.Remove("think", PATCH_ID)
    end
end

local function startUpdates()
    if updating then return end
    updating = true
    lastUpdate = Timer.GetTime()
    Hook.Add("think", PATCH_ID, update)
end

function UI.CloseMenu()
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot = nil
    UI.CurrentMenu = nil
    UI.Picker = nil
end

local function openSettings()
    UI.CloseMenu()
    local _, screenHeight = Common.GetScreenSize()
    local width = Common.FitWindowWidth(Common.SafeIntScale(380), 300, Common.GetGap())
    local root = GUI.Frame(GUI.RectTransform(Point(width, Common.SafeIntScale(200)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot = root
    UI.CurrentMenu = root
    local layout, frame = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, text.Title, nil, function() UI.CloseMenu() return true end)
    local look = Common.CreateText(layout, 1, 1, nil, text.Look, GUI.Alignment.Left, 1, nil, false)
    Common.FitHeightToText(look)
    local picker = GUI.DropDown(Common.CreateRect(1, 1, layout), "", #LOOKS)
    Common.SetFixedHeight(picker, Common.GetStyleHeight("GUIDropDown"))
    for _, name in ipairs(LOOKS) do picker.AddItem(text[name], name) end
    picker.SelectItem(settings.Look)
    picker.OnSelected = function(_, name)
        settings.Look = name
        for _, row in ipairs(rows) do row.Fade = math.min(row.Fade, FADE_SECONDS[name]) end
        save()
        return true
    end
    UI.Picker = picker
    local move = Common.CreateButton(layout, 1, text.Move)
    Common.SetFixedHeight(move, Common.GetStyleHeight("GUIButton"))
    move.ToolTip = text.MoveTooltip
    move.OnClicked = function()
        UI.CloseMenu()
        moving = "waiting"
        startUpdates()
        return true
    end
    root.RectTransform:Resize(Point(root.Rect.Width, math.min(Common.GetMinimumHeight(frame), screenHeight)), true)
end

local function build()
    local root = GUI.Frame(GUI.RectTransform(Vector2(1, 1), nil, GUI.Anchor.TopLeft), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    UI.ButtonRoot = root
    local canvas = GUI.CustomComponent(GUI.RectTransform(Vector2(1, 1), root.RectTransform, GUI.Anchor.TopLeft), function(spriteBatch) draw(spriteBatch) end)
    canvas.CanBeFocused = false
    dragArea = transparentButton(root)
    settingsButton = GUI.Button(GUI.RectTransform(Point(1, 1), root.RectTransform, GUI.Anchor.TopLeft), "", GUI.Alignment.Center, "GUIButtonInfo")
    settingsButton.ToolTip = text.SettingsTooltip
    settingsButton.Visible = false
    settingsButton.OnClicked = function()
        openSettings()
        return true
    end
end

Hook.Patch(PATCH_ID, "Barotrauma.NetLobbyScreen", "SetPlayerSpeaking", function(instance, ptable)
    if UI.Disabled then return end
    local client = ptable["client"]
    if Game.Client == nil or client.SessionId == Game.Client.SessionId then return end
    applyVolume(client)
    heard[client] = true
    startUpdates()
end, Hook.HookMethodType.After)

-- volumes set in the vanilla player panel
Hook.Patch(PATCH_ID, "Barotrauma.Networking.Client", "set_VoiceVolume", function(instance)
    if UI.Disabled then return end
    local key = accountKey(instance)
    if key == nil then return end
    local volume = instance.VoiceVolume
    if volume == 1 then volume = nil end
    if volumes[key] == volume then return end
    volumes[key] = volume
    queueSave()
end, Hook.HookMethodType.After)

Hook.Patch(PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if UI.Disabled or GUI.DisableHUD then return end
    UI.ButtonRoot:AddToGUIUpdateList(false, HUD_DRAW_ORDER)
    if UI.MenuRoot ~= nil then
        UI.MenuRoot:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
        if UI.Picker.Dropped then UI.Picker.ListBox:AddToGUIUpdateList(false, MENU_DRAW_ORDER + 1) end
    end
end)
Common.InstallPausePatch(PATCH_ID .. ".Pause", STATE_KEY)

Hook.Add("roundStart", PATCH_ID, function()
    if Game.Client == nil then return end
    for client in Game.Client.ConnectedClients do applyVolume(client) end
end)

Hook.Add("roundEnd", PATCH_ID, function()
    rows, rowOf, heard, applied = {}, {}, {}, {}
    moving = nil
    updating = false
    Hook.Remove("think", PATCH_ID)
    UI.CloseMenu()
end)

load()
build()
