-- Station radio like Space Station 14's. A channel works only while a powered telecom server holds its key, and a
-- headset talks and listens on a channel while it holds the key too: the common key, a department key, or a blank key
-- set to a channel of its own. Unlike vanilla radios, which hear only the channel they are tuned to, a headset hears
-- all of its keys' channels at once. A player talks on a channel by tuning the headset to it, which the client's chat
-- mode list does (Void traitor pack-1.15: Lua/client/radio.lua); its tickboxes turn hearing a channel's voice or text
-- off. Admin ghosts hear every channel a server opens.
local radio = {}
Traitormod.StationRadio = radio

local config = Traitormod.Config.Radio
local NET_CHANNELS = "VoidTraitor_RadioChannels"
local NET_CHANNELS_REQUEST = "VoidTraitor_RadioChannelsRequest"
local NET_HEARING = "VoidTraitor_RadioHearing"
local NET_JAMMED = "VoidTraitor_RadioJammed"
local PATCH_ID = "Traitormod.StationRadio"
local DISTANCE_ARGS = { "System.String", "Barotrauma.Networking.ChatMessageType", "Barotrauma.Character", "Barotrauma.Character" }
local VOIP_ARGS = { "Barotrauma.Networking.Client", "Barotrauma.Networking.Client", "out System.Single", "out System.Boolean" }
local SPEAK_RANGE_VOIP = ChatMessage.SpeakRangeVOIP
local SERVER_TAG = "vt_telecomserver"
-- how many channels a player can turn off: the common one, the departments and the blank keys' ones
local MAX_MUTED = 32

local departmentById, channelByKey = {}, {}
channelByKey[config.CommonKey] = config.CommonChannel
for _, department in ipairs(config.Departments) do
    departmentById[department.Id] = department
    channelByKey[department.Key] = department.Channel
end
-- channels that only their own key opens; a blank key can't be set to one of them
local keyedChannels = {}
for _, channel in pairs(channelByKey) do keyedChannels[channel] = true end

local active = false
local patched = false
-- headsets that already got their job's keys
local keyedHeadsets = {}
-- client -> { Voice = { [channel] = true }, Text = { ... } }: channels the player turned off in the chat mode list
local muted = {}
-- telecom servers of the round, and the channels the powered ones open (read at most once a second)
local servers = {}
local openChannels, openSecond = {}, nil
-- channels a radiation storm jams
local jammed = {}
-- client -> its headset, read at most once a second: voice packets come every 20 ms for every listener, and reading
-- the headset and its keys on each of them cost about 35 microseconds per packet and listener (measured in the sandbox)
local voiceRadios = {}

local function chatRadio(character)
    local headset = character.Inventory ~= nil and character.Inventory.GetItemInLimbSlot(InvSlotType.Headset) or nil
    local wifi = headset ~= nil and headset.GetComponentString("WifiComponent") or nil
    if wifi == nil or not wifi.LinkToChat then return nil end
    return wifi
end

-- channels of the keys in a headset or a server
local function keyChannels(keys)
    local channels = {}
    if keys == nil then return channels end
    for key in keys.AllItems do
        local identifier = key.Prefab.Identifier.Value
        if identifier == config.BlankKey then
            local channel = key.GetComponentString("WifiComponent").Channel
            if not keyedChannels[channel] then channels[channel] = true end
        elseif channelByKey[identifier] ~= nil then
            channels[channelByKey[identifier]] = true
        end
    end
    return channels
end

local function serverChannels()
    local second = math.floor(os.time())
    if second == openSecond then return openChannels end
    openSecond = second
    openChannels = {}
    for server in pairs(servers) do
        if server.Removed then
            servers[server] = nil
        elseif server.GetComponentString("Powered").HasPower then
            for channel in pairs(keyChannels(server.OwnInventory)) do openChannels[channel] = true end
        end
    end
    return openChannels
end

-- What the radio checks need from a headset. The channel, jamming and position change often and are read by readLive.
-- An admin ghost has every key and hears the blank keys' channels the servers open.
local function radioState(wifi, character)
    local keys = keyChannels(wifi.Item.OwnInventory)
    if Traitormod.AdminGhost.IsGhost(character) then
        for channel in pairs(serverChannels()) do keys[channel] = true end
    end
    return { Wifi = wifi, Item = wifi.Item, Keys = keys, Team = wifi.TeamID, Cross = wifi.AllowCrossTeamCommunication, Range = wifi.Range }
end

local function readLive(state)
    state.Channel = state.Wifi.Channel
    state.Jam = state.Wifi.JamTimer
    state.Position = state.Item.WorldPosition
end

-- Whether a headset's channel goes out at all: a powered server opens it, it isn't jammed, the headset holds the key
-- of a keyed channel and isn't jammed itself.
local function transmits(sender)
    local channel = sender.Channel
    return serverChannels()[channel] and not jammed[channel] and (not keyedChannels[channel] or sender.Keys[channel])
        and sender.Jam <= 0
end

-- The vanilla radio checks (team, jamming, range) plus the servers, keys and jammed channels, without the
-- single-channel rule.
local function reaches(sender, receiver)
    if not transmits(sender) then return false end
    local channel = sender.Channel
    if keyedChannels[channel] then
        if not receiver.Keys[channel] then return false end
    elseif receiver.Channel ~= channel and not receiver.Keys[channel] then
        return false
    end
    if sender.Team ~= receiver.Team and not receiver.Cross then return false end
    if receiver.Jam > 0 then return false end
    return Vector2.DistanceSquared(sender.Position, receiver.Position) <= sender.Range * sender.Range
end

local function hears(client, channel, kind)
    local channels = client ~= nil and muted[client] ~= nil and muted[client][kind] or nil
    return channels == nil or not channels[channel]
end

-- nil when the client has no living character that can speak through a headset
local function voiceRadio(client)
    local second = math.floor(os.time())
    local entry = voiceRadios[client]
    if entry ~= nil and entry.Second == second then return entry.State end
    local character = client.Character
    local wifi = character ~= nil and not character.IsDead and character.SpeechImpediment < 100 and chatRadio(character) or nil
    entry = { Second = second, State = wifi ~= nil and radioState(wifi, character) or nil }
    if entry.State ~= nil then entry.State.Character = character end
    voiceRadios[client] = entry
    return entry.State
end

-- Who reads a radio message (and an order); called for every living player the message could reach.
local function routeText(instance, ptable)
    if not active then return end
    local type = ptable["type"]
    if type ~= ChatMessageType.Radio and type ~= ChatMessageType.Order then return end
    local sender, receiver = ptable["sender"], ptable["receiver"]
    if sender == nil or receiver == nil or receiver.IsDead then return end
    local senderWifi, receiverWifi = chatRadio(sender), chatRadio(receiver)
    if senderWifi == nil or receiverWifi == nil then return end
    ptable.PreventExecution = true
    local message = ptable["message"]
    local senderRadio, receiverRadio = radioState(senderWifi, sender), radioState(receiverWifi, receiver)
    readLive(senderRadio)
    readLive(receiverRadio)
    if not reaches(senderRadio, receiverRadio)
        or (next(muted) ~= nil and not hears(Traitormod.FindClientCharacter(receiver), senderRadio.Channel, "Text")) then
        -- off the radio it is heard only as speech nearby, as in the original
        return ChatMessage.ApplyDistanceEffect(receiver, sender, message, ChatMessage.SpeakRange, 3)
    end
    local text = ChatMessage.ApplyDistanceEffect(receiverWifi.Item, senderWifi.Item, message, senderWifi.Range, 0)
    if sender.SpeechImpediment > 0 then text = ChatMessage.ApplyDistanceEffect(text, sender.SpeechImpediment / 100) end
    return text
end

-- Who hears a voice on the radio, by the same rules. Local voice and players without a headset keep the original
-- rules; spectators too, unless the speaker's channel doesn't go out. The original is skipped, so the out parameters
-- have to be set here.
local function routeVoice(instance, ptable)
    if not active then return end
    local sender, recipient = ptable["sender"], ptable["recipient"]
    local speaker = voiceRadio(sender)
    if speaker == nil or sender.Muted or sender.VoipQueue.ForceLocal
        or (Traitormod.AdminGhost.IsGhost(speaker.Character) and Traitormod.AdminGhost.TalksToDead(sender)) then return end
    local listener = voiceRadio(recipient)
    if listener == nil and recipient.Character ~= nil and not recipient.Character.IsDead then return end
    readLive(speaker)
    if listener == nil then
        if transmits(speaker) then return end
        -- spectators hear it as speech nearby, the same way the original does without a radio
        ptable.PreventExecution = true
        ptable["isRadio"] = false
        local position = recipient.SpectatePos
        if position == nil then
            ptable["distanceFactor"] = Single(0)
            return true
        end
        local distance = math.min(Vector2.Distance(speaker.Character.WorldPosition, position) / SPEAK_RANGE_VOIP, 1)
        ptable["distanceFactor"] = Single(distance)
        return distance < 1
    end
    readLive(listener)
    ptable.PreventExecution = true
    if reaches(speaker, listener) and hears(recipient, speaker.Channel, "Voice") then
        ptable["isRadio"] = true
        ptable["distanceFactor"] = Single(math.min(Vector2.Distance(speaker.Position, listener.Position) / speaker.Range, 1))
        return true
    end
    local garble = ChatMessage.GetGarbleAmount(listener.Character, speaker.Character, SPEAK_RANGE_VOIP)
    ptable["isRadio"] = false
    ptable["distanceFactor"] = Single(garble)
    return garble < 1
end

-- Radio chat that can't go out (no headset, or its channel doesn't transmit) is said nearby instead, the way the
-- original turns the chat of someone who can't speak into dead chat, so everyone sees it as normal speech.
-- Only player chat comes here without a type; the original picks it from the r; command or the chat mode.
-- It is sent again as local chat: an enum argument can't be changed from Lua (Lua numbers don't cast to ChatMode).
local function sayOffAirNearby(instance, ptable)
    if not active or ptable["type"] ~= nil then return end
    local client = ptable["senderClient"]
    local character = client ~= nil and client.Character or nil
    if character == nil or character.IsDead then return end
    local command, text = ChatMessage.GetChatMessageCommand(ptable["message"])
    command = string.lower(command)
    if command ~= "r" and command ~= "radio" and (command ~= "" or ptable["chatMode"] ~= ChatMode.Radio) then return end
    local wifi = chatRadio(character)
    if wifi ~= nil then
        local state = radioState(wifi, character)
        readLive(state)
        if transmits(state) then return end
    end
    ptable.PreventExecution = true
    Game.Server.SendChatMessage(text, ChatMessageType.Default, client)
end

-- The blank keys' channels go only to admin ghosts: players find them by tuning in.
local function sendChannels(connection, ghost)
    local message = Networking.Start(NET_CHANNELS)
    local departments = active and config.Departments or {}
    message.WriteUInt16(config.CommonChannel)
    message.WriteString(config.CommonKey)
    message.WriteByte(#departments)
    for _, department in ipairs(departments) do
        message.WriteUInt16(department.Channel)
        message.WriteString(department.Key)
        message.WriteString(Traitormod.GetText(department.Name))
    end
    local channels = {}
    if active and ghost then
        for channel in pairs(serverChannels()) do
            if not keyedChannels[channel] then channels[#channels + 1] = channel end
        end
        table.sort(channels)
    end
    message.WriteByte(#channels)
    for _, channel in ipairs(channels) do message.WriteUInt16(channel) end
    Networking.Send(message, connection)
end

-- The game's jam timer isn't sent to clients, so they run it themselves on a headset tuned to a jammed channel to get
-- the game's warning in the chat and the headset's static.
local function sendJammed(connection)
    local message = Networking.Start(NET_JAMMED)
    local channels = {}
    for channel in pairs(jammed) do channels[#channels + 1] = channel end
    message.WriteByte(#channels)
    for _, channel in ipairs(channels) do message.WriteUInt16(channel) end
    Networking.Send(message, connection)
end

local function trackServer(item)
    if item.HasTag(SERVER_TAG) then servers[item] = true end
end

-- Puts the common key and the keys of the character's job into its headset, once per headset;
-- passengers get only the common key.
function radio.InitializeHeadset(character, passenger)
    local headset = character.Inventory.GetItemInLimbSlot(InvSlotType.Headset)
    if headset == nil or headset.OwnInventory == nil or keyedHeadsets[headset] then return end
    keyedHeadsets[headset] = true
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[config.CommonKey], headset.OwnInventory)
    if passenger then return end
    local job = character.Info ~= nil and character.Info.Job ~= nil and character.Info.Job.Prefab.Identifier.Value or ""
    for _, id in ipairs(config.JobKeys[job] or {}) do
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[departmentById[id].Key], headset.OwnInventory)
    end
end

-- Added on the first Station round and never removed (Hook.RemovePatch can't remove them);
-- outside Station rounds they return right away.
function radio.Start()
    active = true
    for item in Item.ItemList do trackServer(item) end
    Hook.Add("item.created", "Traitormod.StationRadio.Servers", trackServer)
    if not patched then
        patched = true
        Hook.Patch(PATCH_ID, "Barotrauma.Networking.ChatMessage", "ApplyDistanceEffect", DISTANCE_ARGS, routeText, Hook.HookMethodType.Before)
        Hook.Patch(PATCH_ID, "Barotrauma.Networking.VoipServer", "CanReceive", VOIP_ARGS, routeVoice, Hook.HookMethodType.Before)
        Hook.Patch(PATCH_ID, "Barotrauma.Networking.GameServer", "SendChatMessage", sayOffAirNearby, Hook.HookMethodType.Before)
    end
    sendChannels(nil, false)
end

-- channels: { [channel] = true }; an empty table ends the jamming
function radio.Jam(channels)
    jammed = channels
    sendJammed(nil)
end

Networking.Receive(NET_CHANNELS_REQUEST, function(message, client)
    sendChannels(client.Connection, Traitormod.AdminGhost.IsGhost(client.Character))
    sendJammed(client.Connection)
end)

-- A list longer than a player can turn off rejects the message.
local function readChannels(message)
    local count = message.ReadByte()
    if count > MAX_MUTED then return nil end
    local channels = {}
    for _ = 1, count do channels[message.ReadUInt16()] = true end
    return channels
end

Networking.Receive(NET_HEARING, function(message, client)
    local voice = readChannels(message)
    local text = voice ~= nil and readChannels(message) or nil
    if text == nil then return end
    muted[client] = { Voice = voice, Text = text }
end)

Hook.Add("client.disconnected", "Traitormod.StationRadio.Disconnect", function(client)
    muted[client] = nil
    voiceRadios[client] = nil
end)

Hook.Add("roundEnd", "Traitormod.StationRadio.End", function()
    active = false
    keyedHeadsets = {}
    voiceRadios = {}
    servers = {}
    openChannels, openSecond = {}, nil
    jammed = {}
    Hook.Remove("item.created", "Traitormod.StationRadio.Servers")
end)

return radio
