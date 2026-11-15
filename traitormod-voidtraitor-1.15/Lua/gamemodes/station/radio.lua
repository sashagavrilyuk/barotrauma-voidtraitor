-- Station radio by department, like SS14. Every headset talks and listens on the common channel; a department
-- channel needs the department's key inside the headset. Unlike vanilla radios, which hear only the channel they
-- are tuned to, a headset hears the common channel and all of its keys' channels at once. A player talks on a
-- channel by tuning the headset to it, which the client's chat mode list does (Void traitor pack-1.15:
-- Lua/client/radio.lua); its tickboxes turn hearing a channel's voice or text off.
local radio = {}
Traitormod.StationRadio = radio

local config = Traitormod.Config.Radio
local NET_CHANNELS = "VoidTraitor_RadioChannels"
local NET_CHANNELS_REQUEST = "VoidTraitor_RadioChannelsRequest"
local NET_HEARING = "VoidTraitor_RadioHearing"
local PATCH_ID = "Traitormod.StationRadio"
local DISTANCE_ARGS = { "System.String", "Barotrauma.Networking.ChatMessageType", "Barotrauma.Character", "Barotrauma.Character" }
local VOIP_ARGS = { "Barotrauma.Networking.Client", "Barotrauma.Networking.Client", "out System.Single", "out System.Boolean" }
local SPEAK_RANGE_VOIP = ChatMessage.SpeakRangeVOIP

local departmentById, departmentByChannel, departmentByKey = {}, {}, {}
for _, department in ipairs(config.Departments) do
    departmentById[department.Id] = department
    departmentByChannel[department.Channel] = department
    departmentByKey[department.Key] = department
end

local active = false
local patched = false
-- headsets that already got their job's keys
local keyedHeadsets = {}
-- client -> { Voice = { [channel] = true }, Text = { ... } }: channels the player turned off in the chat mode list
local muted = {}
-- client -> its headset, read at most once a second: voice packets come every 20 ms for every listener, and reading
-- the headset and its keys on each of them cost about 35 microseconds per packet and listener (measured in the sandbox)
local voiceRadios = {}

local function chatRadio(character)
    local headset = character.Inventory ~= nil and character.Inventory.GetItemInLimbSlot(InvSlotType.Headset) or nil
    local wifi = headset ~= nil and headset.GetComponentString("WifiComponent") or nil
    if wifi == nil or not wifi.LinkToChat then return nil end
    return wifi
end

-- department channels of the keys in the headset
local function keyChannels(wifi)
    local channels = {}
    local keys = wifi.Item.OwnInventory
    if keys == nil then return channels end
    for key in keys.AllItems do
        local department = departmentByKey[key.Prefab.Identifier.Value]
        if department ~= nil then channels[department.Channel] = true end
    end
    return channels
end

-- What the radio checks need from a headset. The channel, jamming and position change often and are read by readLive.
local function radioState(wifi)
    return { Wifi = wifi, Item = wifi.Item, Keys = keyChannels(wifi), Team = wifi.TeamID,
        Cross = wifi.AllowCrossTeamCommunication, Range = wifi.Range }
end

local function readLive(state)
    state.Channel = state.Wifi.Channel
    state.Jam = state.Wifi.JamTimer
    state.Position = state.Item.WorldPosition
end

-- The vanilla radio checks (team, jamming, range) without the single-channel rule.
local function reaches(sender, receiver)
    local channel = sender.Channel
    if departmentByChannel[channel] ~= nil then
        if not sender.Keys[channel] or not receiver.Keys[channel] then return false end
    elseif channel ~= config.CommonChannel and receiver.Channel ~= channel then
        return false
    end
    if sender.Team ~= receiver.Team and not receiver.Cross then return false end
    if sender.Jam > 0 or receiver.Jam > 0 then return false end
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
    entry = { Second = second, State = wifi ~= nil and radioState(wifi) or nil }
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
    local senderRadio, receiverRadio = radioState(senderWifi), radioState(receiverWifi)
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

-- Who hears a voice on the radio, by the same rules. Spectators, local voice and players without a headset keep
-- the original rules. The original is skipped, so the out parameters have to be set here.
local function routeVoice(instance, ptable)
    if not active then return end
    local sender, recipient = ptable["sender"], ptable["recipient"]
    local speaker, listener = voiceRadio(sender), voiceRadio(recipient)
    if speaker == nil or listener == nil or sender.Muted or sender.VoipQueue.ForceLocal
        or (Traitormod.AdminGhost.IsGhost(speaker.Character) and Traitormod.AdminGhost.TalksToDead(sender)) then return end
    readLive(speaker)
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

local function sendChannels(connection)
    local message = Networking.Start(NET_CHANNELS)
    local departments = active and config.Departments or {}
    message.WriteUInt16(config.CommonChannel)
    message.WriteByte(#departments)
    for _, department in ipairs(departments) do
        message.WriteUInt16(department.Channel)
        message.WriteString(department.Key)
        message.WriteString(Traitormod.GetText(department.Name))
    end
    Networking.Send(message, connection)
end

-- Puts the keys of the character's job into its headset, once per headset.
function radio.InitializeHeadset(character, passenger)
    local headset = character.Inventory.GetItemInLimbSlot(InvSlotType.Headset)
    if passenger or headset == nil or headset.OwnInventory == nil or keyedHeadsets[headset] then return end
    keyedHeadsets[headset] = true
    local job = character.Info ~= nil and character.Info.Job ~= nil and character.Info.Job.Prefab.Identifier.Value or ""
    for _, id in ipairs(config.JobKeys[job] or {}) do
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[departmentById[id].Key], headset.OwnInventory)
    end
end

-- Added on the first Station round and never removed (Hook.RemovePatch can't remove them);
-- outside Station rounds they return right away.
function radio.Start()
    active = true
    if not patched then
        patched = true
        Hook.Patch(PATCH_ID, "Barotrauma.Networking.ChatMessage", "ApplyDistanceEffect", DISTANCE_ARGS, routeText, Hook.HookMethodType.Before)
        Hook.Patch(PATCH_ID, "Barotrauma.Networking.VoipServer", "CanReceive", VOIP_ARGS, routeVoice, Hook.HookMethodType.Before)
    end
    sendChannels(nil)
end

Networking.Receive(NET_CHANNELS_REQUEST, function(message, client)
    sendChannels(client.Connection)
end)

-- Only the common and department channels can be turned off; other channels are ignored, and a longer list than
-- there are channels rejects the message.
local function readChannels(message)
    local count = message.ReadByte()
    if count > #config.Departments + 1 then return nil end
    local channels = {}
    for _ = 1, count do
        local channel = message.ReadUInt16()
        if channel == config.CommonChannel or departmentByChannel[channel] ~= nil then channels[channel] = true end
    end
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
end)

return radio
