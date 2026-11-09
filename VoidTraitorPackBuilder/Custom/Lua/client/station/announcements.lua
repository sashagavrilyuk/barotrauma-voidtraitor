if SERVER then return end

-- Station announcements and alert sounds (traitormod Lua/gamemodes/station/station.lua). An announcement goes into the
-- chat with its header as the sender line, drawn in the bold heading font and the header colour.
local packPath = ...
local chatBoxDescriptor = LuaUserData.RegisterType("Barotrauma.ChatBox")
LuaUserData.MakeFieldAccessible(chatBoxDescriptor, "chatBox")
LuaUserData.MakeFieldAccessible(chatBoxDescriptor, "popupMessages")
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")

local HEADER_TO_TEXT_SIZE = 14 / 12
-- the game plays no sound louder than full volume after the sound slider, so like vanilla sounds with volume 2 these
-- are at full volume from half the slider up
local SOUND_GAIN = 2
local SOUND_FILES = {
    green = "green_announce.ogg",
    yellow = "notice1.ogg",
    blue = "bluealert.ogg",
    violet = "notice1.ogg",
    red = "redalert.ogg",
    delta = "delta.ogg",
    gamma = "siren.ogg",
    epsilon = "epsilon.ogg",
    biohazard = "outbreak7.ogg",
    announcement = "announce_generic.ogg",
    evacCalled = "shuttlecalled.ogg",
    evacRecalled = "shuttlerecalled.ogg",
    evacDocked = "shuttle_dock.ogg",
    evacLaunching = "notice1.ogg",
    evacDeparted = "green_announce.ogg",
    attack = "aliens.ogg",
    commsBlackout = "comms_blackout.ogg",
    powerOff = "power_off.ogg",
    powerOn = "power_on.ogg",
    intercept = "intercept.ogg",
    attention = "attention.ogg",
}

-- The game loads a sound in the background and stops every channel of it that started before the loading finished
-- (OggSound in Barotrauma 1.15), so a sound loaded on first use is never heard that first time. All of them are loaded
-- when the client starts and freed when its Lua stops.
local loadedSounds = {}
for _, file in pairs(SOUND_FILES) do
    if loadedSounds[file] == nil then
        loadedSounds[file] = gameMain.SoundManager.LoadSound(packPath .. "/Sounds/Station/" .. file)
    end
end

Hook.Add("stop", "VoidTraitor.StationAnnouncements", function()
    for _, sound in pairs(loadedSounds) do sound.Dispose() end
end)

local function readColor(message)
    return Color(message.ReadByte(), message.ReadByte(), message.ReadByte(), 255)
end

local function getChildren(component)
    local children = {}
    for child in component.Children do children[#children + 1] = child end
    return children
end

-- Wrap is a plain field, so it goes before the font, whose setter lays the text out again. Like SS14 announcements
-- (14 pt bold header over 12 pt text) the header is scaled to that ratio of the chat text font, which the game sizes
-- for the resolution and the text scale setting.
local function setHeaderFont(textBlock, color)
    textBlock.Wrap = true
    textBlock.Font = GUI.Style.SubHeadingFont
    textBlock.TextScale = GUI.Style.SmallFont.Size * HEADER_TO_TEXT_SIZE / GUI.Style.SubHeadingFont.Size
    textBlock.OverrideTextColor(color)
end

-- TextSize is measured before TextScale is applied
local function getTextHeight(textBlock)
    return math.ceil(textBlock.TextSize.Y * textBlock.TextScale)
end

-- ChatBox.AddMessage puts the sender button inside the timestamp row and the text right below that row
local function styleChatHeader(entry, color)
    local rows = getChildren(entry)
    local timestamp, text = rows[1], rows[2]
    local sender = getChildren(timestamp)[1]
    setHeaderFont(sender.TextBlock, color)
    -- the header wraps in the rest of the row after the timestamp
    sender.RectTransform.NonScaledSize = Point(timestamp.Rect.Width - sender.RectTransform.AbsoluteOffset.X, sender.Rect.Height)

    local function fitRowToHeader()
        local height = getTextHeight(sender.TextBlock)
        if height == timestamp.RectTransform.MinSize.Y then return end
        timestamp.RectTransform.MinSize = Point(0, height)
        -- the button height is relative to the row, so it is set after the row has grown
        sender.RectTransform.NonScaledSize = Point(sender.Rect.Width, height)
        text.RectTransform.AbsoluteOffset = Point(text.RectTransform.AbsoluteOffset.X, height)
        -- a resize makes the chat box sum up the row heights of the message again
        entry.RectTransform.Resize(entry.RectTransform.NonScaledSize, false)
    end
    fitRowToHeader()
    -- the header wraps again whenever the chat gets narrower or wider, e.g. when its scroll bar shows up
    sender.TextBlock.RectTransform.SizeChanged.add(fitRowToHeader)
end

-- the popup shown while the chat is closed keeps its width; its height is worked out like in ChatBox.AddMessage
local function stylePopupHeader(popup, color)
    local content = getChildren(popup)[1]
    local rows = getChildren(content)
    local sender, text = rows[1], rows[2]
    setHeaderFont(sender, color)
    -- the layout group sizes the header relative to itself, so its height is pinned
    local height = getTextHeight(sender)
    sender.RectTransform.MinSize = Point(0, height)
    sender.RectTransform.MaxSize = Point(sender.RectTransform.MaxSize.X, height)
    local relativeHeight = content.RectTransform.RelativeSize.Y
    popup.RectTransform.Resize(Point(popup.Rect.Width, math.floor((sender.Rect.Height + text.Rect.Height) / relativeHeight)))
    content.Recalculate()
end

local function getLastPopup(chatBox)
    local last
    for popup in chatBox.popupMessages do last = popup end
    return last
end

Networking.Receive("VoidTraitor_StationAnnouncement", function(message)
    local header, text = message.ReadString(), message.ReadString()
    local color, headerColor = readColor(message), readColor(message)
    local chatBox = Game.Client.ChatBox
    local previousPopup = getLastPopup(chatBox)

    local chatMessage = ChatMessage.Create(header, text, ChatMessageType.Default, nil, nil)
    chatMessage.Color = color
    Game.Client.AddChatMessage(chatMessage)

    local entries = getChildren(chatBox.chatBox.Content)
    styleChatHeader(entries[#entries], headerColor)
    local popup = getLastPopup(chatBox)
    if popup ~= previousPopup then stylePopupHeader(popup, headerColor) end
end)

Networking.Receive("VoidTraitor_StationAlertSound", function(message)
    loadedSounds[SOUND_FILES[message.ReadString()]].Play(SOUND_GAIN)
end)
