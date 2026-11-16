if SERVER then return end

-- The vanilla chat mode list next to the chat input as the radio channel picker. In Station rounds it shows the
-- common channel and the departments whose keys are in the headset (traitormod Lua/gamemodes/station/radio.lua);
-- picking one tunes the headset to that channel, and the two tickboxes of a channel turn hearing its voice and
-- reading its messages on and off. The vanilla radio entry stays in the list, hidden, because the chat keys select it.
-- An admin ghost also gets "dead", which sends its chat to dead chat (traitormod Lua/features/adminghost.lua), and the
-- channels the telecom servers' blank keys open. Its local and dead entries get tickboxes too, which this client
-- applies itself: the server would need another patch on every voice packet to hold back local voice.
-- Players' chat messages are labelled with the radio channel or dead chat they were said in, and in Station the
-- speaker's name with the role on their ID card.
local Common = select(2, ...)
local text = Common.Language.Radio

local NET_CHANNELS = "VoidTraitor_RadioChannels"
local NET_CHANNELS_REQUEST = "VoidTraitor_RadioChannelsRequest"
local NET_HEARING = "VoidTraitor_RadioHearing"
local NET_JAMMED = "VoidTraitor_RadioJammed"
local NET_DEAD_CHAT = "VoidTraitor_AdminGhostDeadChat"
local STATE_KEY = "VoidTraitorRadioState"
local PATCH_ID = "VoidTraitor.Radio"
local SEND_ARGS = { "System.String", "Barotrauma.Networking.ChatMessageType" }
local LABEL_FORMAT = "[%s] %s"
local DEAD_CHAT_PREFIX = "d; "
local RADIO_CHAT_PREFIX = "r; "
local HEARING_KINDS = { "Voice", "Text" }
local DIVIDER_WIDTH = 2 -- width of the vanilla VerticalLine style
-- longer than any jamming: it ends with the server's message
local JAM_SECONDS = 3600

local chatBoxType = LuaUserData.RegisterType("Barotrauma.ChatBox")
LuaUserData.MakePropertyAccessible(chatBoxType, "ChatModeDropDown")
LuaUserData.MakeMethodAccessible(chatBoxType, "SetChannel")
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")

local commonChannel, commonKey = 0, nil
-- departments of the current Station round ({ Channel, Key, Name }); empty in other rounds
local departments = {}
-- channels the telecom servers' blank keys open; the server sends them only to admin ghosts
local blankChannels = {}
-- channels the player turned off, kept for the whole session
local muted = { Voice = {}, Text = {} }
-- "Local" and "Dead" when an admin ghost turned them off, kept for the whole session
local ghostMuted = { Voice = {}, Text = {} }
local inGhost = false
local voicePatched = false
-- character IDs of admin ghosts that talk to the dead (traitormod Lua/features/adminghost.lua)
local talkingToDead = {}
-- channels a radiation storm jams, and the headset whose jam timer this script runs
local jammed = {}
local jammedRadio = nil
local deadChat = false
local installedOn = nil
-- tickboxes in the open list; a click on one also selects its row, which must not change the chat target
local tickBoxes = {}
local reopen = false

local function chatBox()
    return Game.Client ~= nil and Game.Client.ChatBox or nil
end

local function headsetOf(character)
    local headset = character ~= nil and character.Inventory ~= nil and character.Inventory.GetItemInLimbSlot(InvSlotType.Headset) or nil
    return headset, headset ~= nil and headset.GetComponentString("WifiComponent") or nil
end

local function headsetRadio()
    return headsetOf(Character.Controlled)
end

-- The server blocks a jammed channel; the jam timer of a headset tuned to one only gives the game's warning in the
-- chat and the headset's static, since the server doesn't send its own timer. While it runs the game won't change
-- the channel, so the patches on SetChannel clear it first and set it again for the new channel; the channel arrows
-- and presets check it before SetChannel and stay locked, as on a jammed vanilla radio.
local function applyJam()
    if jammedRadio ~= nil then jammedRadio.JamTimer = 0 end
    local _, radio = headsetRadio()
    jammedRadio = radio ~= nil and jammed[radio.Channel] and radio or nil
    if jammedRadio ~= nil then jammedRadio.JamTimer = JAM_SECONDS end
end

local function requestChannels()
    Networking.Send(Networking.Start(NET_CHANNELS_REQUEST))
end

local function channelName(channel)
    if channel == commonChannel then return text.Common end
    for _, department in ipairs(departments) do
        if department.Channel == channel then return department.Name end
    end
    return string.format(text.Channel, channel)
end

-- What a character talks on over the radio: its channel in Station rounds, otherwise just the radio.
local function radioName(character)
    local _, radio = headsetOf(character)
    if #departments > 0 and radio ~= nil then return channelName(radio.Channel) end
    return tostring(TextManager.Get("chatmode.radio"))
end

-- Where a voice this client hears comes from: "Dead", "Radio" or "Local", and its name. The server tells only
-- whether a voice came over the radio; a ghost that talks to the dead does it over the radio too.
local function voiceSource(client)
    local character = client.Character
    if character == nil or character.IsDead or talkingToDead[character.ID] then return "Dead", text.Dead end
    if client.VoipSound ~= nil and client.VoipSound.UsingRadio then return "Radio", radioName(character) end
    return "Local", tostring(TextManager.Get("chatmode.local"))
end

-- An admin ghost's local and dead voice it turned off. The game sets the gain every frame before this.
local function muteVoice(instance)
    if not inGhost or instance.VoipSound == nil then return end
    if ghostMuted.Voice[voiceSource(instance)] then instance.VoipSound.Gain = 0 end
end

local function isOwn(message)
    local sender = message.SenderClient
    return message.SenderCharacter == Character.Controlled or (sender ~= nil and Game.Client ~= nil and sender.SessionId == Game.Client.SessionId)
end

-- A player's chat message gets the radio channel or dead chat it was said in; an admin ghost leaves out local and dead
-- chat it turned off, except its own. Messages from the server and items have no sender character and stay as they are.
local function labelMessage(instance, ptable)
    local message = ptable["message"]
    local type, sender = message.Type, message.SenderCharacter
    local kind
    if type == ChatMessageType.Dead then
        kind = "Dead"
    elseif sender ~= nil and type == ChatMessageType.Radio then
        kind = "Radio"
    elseif sender ~= nil and type == ChatMessageType.Default then
        kind = "Local"
    else
        return
    end
    if inGhost and ghostMuted.Text[kind] and not isOwn(message) then
        ptable.PreventExecution = true
        return
    end
    -- the living speak under the role on their ID card in Station
    local role = kind ~= "Dead" and Common.GetCardRole(sender) or nil
    if kind == "Local" and role == nil then return end
    local name = role ~= nil and role .. " " .. message.SenderName or message.SenderName
    local body = message.Text
    if kind ~= "Local" then body = string.format(LABEL_FORMAT, kind == "Dead" and text.Dead or radioName(sender), body) end
    -- the message's text can't be changed, so the chat gets a copy
    ptable["message"] = ChatMessage.Create(name, body, type, message.Sender, message.SenderClient)
end

local function setDeadChat(value)
    if deadChat == value then return end
    deadChat = value
    local message = Networking.Start(NET_DEAD_CHAT)
    message.WriteBoolean(value)
    Networking.Send(message)
end

local function sendHearing()
    local message = Networking.Start(NET_HEARING)
    for _, kind in ipairs(HEARING_KINDS) do
        local channels = {}
        for channel in pairs(muted[kind]) do channels[#channels + 1] = channel end
        message.WriteByte(#channels)
        for _, channel in ipairs(channels) do message.WriteUInt16(channel) end
    end
    Networking.Send(message)
end

-- The list button shows where chat goes: dead chat, local chat, or the channel the headset is tuned to.
local function showTarget(dropdown)
    local _, radio = headsetRadio()
    if deadChat then
        dropdown.Text = text.Dead
    elseif gameMain.ActiveChatMode ~= ChatMode.Radio then
        dropdown.Text = TextManager.Get("chatmode.local")
    elseif #departments > 0 and radio ~= nil then
        dropdown.Text = channelName(radio.Channel)
    else
        dropdown.Text = TextManager.Get("chatmode.radio")
    end
end

local function onTickBox()
    for _, tickBox in ipairs(tickBoxes) do
        if GUI.MouseOn == tickBox then return true end
    end
    return false
end

-- Vanilla entries carry ChatMode values, ours carry a table.
local function pick(dropdown, data)
    if onTickBox() then
        reopen = true
        showTarget(dropdown)
        return true
    end
    local box = chatBox()
    if type(data) == "table" then
        if data.Dead then
            gameMain.ActiveChatMode = ChatMode.Local
            setDeadChat(true)
        else
            setDeadChat(false)
            gameMain.ActiveChatMode = ChatMode.Radio
            box.SetChannel(data.Channel, true)
        end
        showTarget(dropdown)
        return true
    end
    -- opening the chat in dead mode makes the game select the local entry again; a click on it leaves dead mode
    if deadChat and data == ChatMode.Local and not dropdown.Dropped then
        showTarget(dropdown)
        return true
    end
    setDeadChat(false)
    gameMain.ActiveChatMode = data
    -- as in the original: local chat drops the radio prefix the radio chat key put into the input
    local input = box.InputBox
    if data == ChatMode.Local and input ~= nil and string.sub(input.Text, 1, #RADIO_CHAT_PREFIX) == RADIO_CHAT_PREFIX then
        input.Text = string.sub(input.Text, #RADIO_CHAT_PREFIX + 1)
    end
    showTarget(dropdown)
    return true
end

-- A fixed size: otherwise it stretches with the row when the list lays the rows out.
local function fixedRect(width, height, parent, x)
    local rect = GUI.RectTransform(Point(width, height), parent.RectTransform, GUI.Anchor.CenterLeft)
    rect.IsFixedSize = true
    rect.AbsoluteOffset = Point(x, 0)
    return rect
end

-- Voice and text tickboxes of a row, each followed by a divider line; they turn hearing `key` off in `store`, and
-- `changed` runs after each click. Returns where the name starts.
local function addTickBoxes(row, store, key, changed, name, size, gap)
    local x = gap
    for _, kind in ipairs(HEARING_KINDS) do
        local tickBox = GUI.TickBox(fixedRect(size, size, row, x), "")
        tickBox.Selected = not store[kind][key]
        -- the local entry's name is the game's LocalizedString, not a Lua string
        tickBox.ToolTip = string.format(text[kind .. "Tooltip"], tostring(name))
        tickBox.OnSelected = function(box)
            store[kind][key] = not box.Selected or nil
            if changed ~= nil then changed() end
            return true
        end
        tickBoxes[#tickBoxes + 1] = tickBox
        x = x + size + gap
        local divider = GUI.Image(fixedRect(DIVIDER_WIDTH, size, row, x), "VerticalLine")
        divider.CanBeFocused = false
        x = x + DIVIDER_WIDTH + gap
    end
    return x
end

-- Fills the list each time it opens, since keys go in and out of the headset.
local function fill(dropdown)
    local headset, radio = headsetRadio()
    local held = {}
    if headset ~= nil and headset.OwnInventory ~= nil then
        for key in headset.OwnInventory.AllItems do held[key.Prefab.Identifier.Value] = true end
    end
    local station = #departments > 0 and radio ~= nil
    local ghost = Common.IsAdminGhost()
    -- in order from the button up: local, common (the vanilla radio entry outside Station), dead, departments
    local entries = { { Text = TextManager.Get("chatmode.local"), Data = ChatMode.Local, Hearing = ghost and "Local" or nil } }
    -- hidden in Station, where it would only repeat one of the channels
    entries[#entries + 1] = { Text = TextManager.Get("chatmode.radio"), Data = ChatMode.Radio, Hidden = station }
    if station and held[commonKey] then
        entries[#entries + 1] = { Text = text.Common, Data = { Channel = commonChannel }, Channel = commonChannel }
    end
    if ghost then entries[#entries + 1] = { Text = text.Dead, Data = { Dead = true }, Hearing = "Dead" } end
    if station then
        for _, department in ipairs(departments) do
            if held[department.Key] then
                entries[#entries + 1] = { Text = department.Name, Data = { Channel = department.Channel }, Channel = department.Channel }
            end
        end
        if ghost then
            for _, channel in ipairs(blankChannels) do
                entries[#entries + 1] = { Text = channelName(channel), Data = { Channel = channel }, Channel = channel }
            end
        end
    end

    -- the game sized the list and the button for its two entries. Rows are as high as the button; the list is resized
    -- before the rows are added because they stretch with it.
    local rowHeight = dropdown.Rect.Height
    -- the vanilla tickbox style makes the box this size whatever size the tickbox is given
    local tickSize = Common.GetStyleHeight("GUITickBox")
    local gap = math.max(2, math.floor(rowHeight * 0.15))
    local tickArea = (station or ghost) and (#HEARING_KINDS * (tickSize + DIVIDER_WIDTH + 2 * gap) + gap) or 0
    local rows, longest = 0, 0
    for _, entry in ipairs(entries) do
        if not entry.Hidden then
            rows = rows + 1
            longest = math.max(longest, GUI.Style.Font.MeasureString(entry.Text).X)
        end
    end
    local icon = dropdown.DropDownIcon
    local buttonWidth = longest + dropdown.Padding.X
    if icon ~= nil then buttonWidth = buttonWidth + icon.RectTransform.NonScaledSize.X + icon.RectTransform.AbsoluteOffset.X * 2 end
    local minSize = dropdown.RectTransform.MinSize
    if buttonWidth > minSize.X then dropdown.RectTransform.MinSize = Point(math.ceil(buttonWidth), minSize.Y) end

    dropdown.ClearChildren()
    tickBoxes = {}
    local list = dropdown.ListBox
    -- the list's frame takes some height from its rows; without it the last row goes under a scrollbar
    local frameHeight = list.Rect.Height - list.Content.Rect.Height
    list.RectTransform.NonScaledSize = Point(math.max(dropdown.Rect.Width, math.ceil(tickArea + buttonWidth)), rowHeight * rows + frameHeight)
    -- grows to the right of the button instead of both ways, so it stays on screen
    list.RectTransform.SetPosition(GUI.Anchor.TopLeft, GUI.Pivot.BottomLeft)
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local row = dropdown.AddItem(entry.Text, entry.Data)
        row.Visible = not entry.Hidden
        if tickArea > 0 then
            local padding = row.Padding
            local nameStart = tickArea
            if entry.Channel ~= nil then
                nameStart = addTickBoxes(row, muted, entry.Channel, sendHearing, entry.Text, tickSize, gap)
            elseif entry.Hearing ~= nil then
                nameStart = addTickBoxes(row, ghostMuted, entry.Hearing, nil, entry.Text, tickSize, gap)
            end
            row.Padding = Vector4(nameStart, padding.Y, padding.Z, padding.W)
        end
    end
    showTarget(dropdown)
end

-- The chat box is created with the connection, so the list is taken over whenever a new one appears.
local function install()
    local box = chatBox()
    local dropdown = box ~= nil and box.ChatModeDropDown or nil
    if dropdown == nil or dropdown == installedOn then return end
    installedOn = dropdown
    dropdown.OnSelected = function(component, data) return pick(dropdown, data) end
    dropdown.OnDropped = function()
        fill(dropdown)
        -- servers get keys and power on and off; the answer fills the list again
        if Common.IsAdminGhost() then requestChannels() end
        return true
    end
    -- runs after the list closed itself on the click
    dropdown.AfterSelected = function()
        if reopen then
            reopen = false
            dropdown.Dropped = true
        end
        return true
    end
end

Hook.Patch(PATCH_ID, "Barotrauma.ChatBox", "SetChannel", function()
    if jammedRadio ~= nil then jammedRadio.JamTimer = 0 end
end, Hook.HookMethodType.Before)

-- Channel picked with the numbers or typed in: show its name.
Hook.Patch(PATCH_ID, "Barotrauma.ChatBox", "SetChannel", function(instance)
    applyJam()
    showTarget(instance.ChatModeDropDown)
end, Hook.HookMethodType.After)

Hook.Patch(PATCH_ID, "Barotrauma.ChatBox", "AddMessage", labelMessage, Hook.HookMethodType.Before)

-- In dead mode the ghost's chat goes out with the dead chat prefix; commands stay as they are.
Hook.Patch(PATCH_ID, "Barotrauma.Networking.GameClient", "SendChatMessage", SEND_ARGS, function(instance, ptable)
    local message = ptable["message"]
    if not deadChat or message == nil or string.find(message, "^%s*$") or string.sub(message, 1, 1) == "!" then return end
    ptable["message"] = DEAD_CHAT_PREFIX .. message
end, Hook.HookMethodType.Before)

Networking.Receive(NET_CHANNELS, function(message)
    commonChannel, commonKey = message.ReadUInt16(), message.ReadString()
    departments = {}
    for _ = 1, message.ReadByte() do
        departments[#departments + 1] = { Channel = message.ReadUInt16(), Key = message.ReadString(), Name = message.ReadString() }
    end
    blankChannels = {}
    for _ = 1, message.ReadByte() do blankChannels[#blankChannels + 1] = message.ReadUInt16() end
    install()
    if installedOn ~= nil and installedOn.Dropped then fill(installedOn) end
    -- the server forgets the player's choice when they reconnect
    if #departments > 0 then sendHearing() end
end)

Networking.Receive(NET_JAMMED, function(message)
    jammed = {}
    for _ = 1, message.ReadByte() do jammed[message.ReadUInt16()] = true end
    applyJam()
end)

-- Called by the admin ghost's client script: a new ghost starts in dead chat, as on the server.
-- The speaker list (Lua/client/speakers.lua) names voices with VoiceSource.
_G[STATE_KEY] = {
    EnterGhost = function()
        install()
        deadChat = true
        inGhost = true
        -- dead mode rides on local chat: the chat keys keep it there (see pick)
        gameMain.ActiveChatMode = ChatMode.Local
        if installedOn ~= nil then showTarget(installedOn) end
        requestChannels()
        -- added on first use and never removed, like the ghost's own patches; it returns right away outside a ghost
        if not voicePatched then
            voicePatched = true
            Hook.Patch(PATCH_ID, "Barotrauma.Networking.Client", "UpdateVoipSound", muteVoice, Hook.HookMethodType.After)
        end
    end,
    LeaveGhost = function()
        deadChat = false
        inGhost = false
        if installedOn ~= nil then showTarget(installedOn) end
    end,
    -- ids: { [character ID] = true } of the ghosts that talk to the dead
    SetTalkingToDead = function(ids)
        talkingToDead = ids
    end,
    VoiceSource = voiceSource,
    IsVoiceMuted = function(client)
        return inGhost and ghostMuted.Voice[voiceSource(client)] == true
    end,
}

Hook.Add("roundStart", PATCH_ID, function()
    install()
    requestChannels()
end)

Hook.Add("roundEnd", PATCH_ID, function()
    departments = {}
    blankChannels = {}
    jammed = {}
    jammedRadio = nil
    deadChat = false
    talkingToDead = {}
end)

if Game.RoundStarted then
    install()
    requestChannels()
end
