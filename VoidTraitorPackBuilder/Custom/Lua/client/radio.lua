if SERVER then return end

-- The vanilla chat mode list next to the chat input as the radio channel picker. In Station rounds it shows the
-- common channel and the departments whose keys are in the headset (traitormod Lua/gamemodes/station/radio.lua);
-- picking one tunes the headset to that channel, and the two tickboxes of a channel turn hearing its voice and
-- reading its messages on and off. The vanilla radio entry stays in the list, hidden, because the chat keys select it.
-- An admin ghost also gets "dead", which sends its chat to dead chat (traitormod Lua/features/adminghost.lua), and the
-- channels the telecom servers' blank keys open.
local Common = select(2, ...)
local text = Common.Language.Radio

local NET_CHANNELS = "VoidTraitor_RadioChannels"
local NET_CHANNELS_REQUEST = "VoidTraitor_RadioChannelsRequest"
local NET_HEARING = "VoidTraitor_RadioHearing"
local NET_DEAD_CHAT = "VoidTraitor_AdminGhostDeadChat"
local STATE_KEY = "VoidTraitorRadioState"
local PATCH_ID = "VoidTraitor.Radio"
local SEND_ARGS = { "System.String", "Barotrauma.Networking.ChatMessageType" }
local DEAD_CHAT_PREFIX = "d; "
local RADIO_CHAT_PREFIX = "r; "
local HEARING_KINDS = { "Voice", "Text" }
local DIVIDER_WIDTH = 2 -- width of the vanilla VerticalLine style

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
local deadChat = false
local installedOn = nil
-- tickboxes in the open list; a click on one also selects its row, which must not change the chat target
local tickBoxes = {}
local reopen = false

local function chatBox()
    return Game.Client ~= nil and Game.Client.ChatBox or nil
end

local function headsetRadio()
    local character = Character.Controlled
    local headset = character ~= nil and character.Inventory ~= nil and character.Inventory.GetItemInLimbSlot(InvSlotType.Headset) or nil
    return headset, headset ~= nil and headset.GetComponentString("WifiComponent") or nil
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

-- Voice and text tickboxes of a channel row, each followed by a divider line; returns where the name starts.
local function addTickBoxes(row, channel, name, size, gap)
    local x = gap
    for _, kind in ipairs(HEARING_KINDS) do
        local tickBox = GUI.TickBox(fixedRect(size, size, row, x), "")
        tickBox.Selected = not muted[kind][channel]
        tickBox.ToolTip = string.format(text[kind .. "Tooltip"], name)
        tickBox.OnSelected = function(box)
            muted[kind][channel] = not box.Selected or nil
            sendHearing()
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
    -- in order from the button up: local, common (the vanilla radio entry outside Station), dead, departments
    local entries = { { Text = TextManager.Get("chatmode.local"), Data = ChatMode.Local } }
    -- hidden in Station, where it would only repeat one of the channels
    entries[#entries + 1] = { Text = TextManager.Get("chatmode.radio"), Data = ChatMode.Radio, Hidden = station }
    if station and held[commonKey] then
        entries[#entries + 1] = { Text = text.Common, Data = { Channel = commonChannel }, Channel = commonChannel }
    end
    local ghost = Common.IsAdminGhost()
    if ghost then entries[#entries + 1] = { Text = text.Dead, Data = { Dead = true } } end
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
    local tickArea = station and (#HEARING_KINDS * (tickSize + DIVIDER_WIDTH + 2 * gap) + gap) or 0
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
    list.RectTransform.NonScaledSize = Point(math.max(dropdown.Rect.Width, math.ceil(tickArea + buttonWidth)), rowHeight * rows)
    -- grows to the right of the button instead of both ways, so it stays on screen
    list.RectTransform.SetPosition(GUI.Anchor.TopLeft, GUI.Pivot.BottomLeft)
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local row = dropdown.AddItem(entry.Text, entry.Data)
        row.Visible = not entry.Hidden
        if tickArea > 0 then
            local padding = row.Padding
            local nameStart = entry.Channel ~= nil and addTickBoxes(row, entry.Channel, entry.Text, tickSize, gap) or tickArea
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

-- Channel picked with the numbers or typed in: show its name.
Hook.Patch(PATCH_ID, "Barotrauma.ChatBox", "SetChannel", function(instance)
    showTarget(instance.ChatModeDropDown)
end, Hook.HookMethodType.After)

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

-- Called by the admin ghost's client script: a new ghost starts in dead chat, as on the server.
_G[STATE_KEY] = {
    EnterGhost = function()
        install()
        deadChat = true
        -- dead mode rides on local chat: the chat keys keep it there (see pick)
        gameMain.ActiveChatMode = ChatMode.Local
        if installedOn ~= nil then showTarget(installedOn) end
        requestChannels()
    end,
    LeaveGhost = function()
        deadChat = false
        if installedOn ~= nil then showTarget(installedOn) end
    end,
}

Hook.Add("roundStart", PATCH_ID, function()
    install()
    requestChannels()
end)

Hook.Add("roundEnd", PATCH_ID, function()
    departments = {}
    blankChannels = {}
    deadChat = false
end)

if Game.RoundStarted then
    install()
    requestChannels()
end
