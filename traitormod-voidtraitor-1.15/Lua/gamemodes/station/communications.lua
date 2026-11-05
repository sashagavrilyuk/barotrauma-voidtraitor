local console = {}
Traitormod.Communications = console
local json = require("json")
local config = Traitormod.Config.Communications
local terminals, sessions, broadcasters = {}, {}, {}
local codes = { "green", "blue", "violet", "yellow", "red" }
local announcementColor = Color(255, 215, 0, 255)
local announcementHeaderColor = Color(255, 255, 170, 255)
local active = false
local texts
local patchVoice

function console.Start()
    active, terminals, sessions, broadcasters = true, {}, {}, {}
    texts = {}
    for _, key in ipairs({ "Title", "Announce", "Voice", "Stop", "Busy", "Cooldown", "Code", "Close",
        "green", "blue", "violet", "yellow", "red", "delta", "gamma", "epsilon" }) do
        texts[key] = Traitormod.GetText("Comms" .. key)
    end
    for item in Item.ItemList do
        if item.Prefab.Identifier == "vt_communications_console" then
            terminals[item] = { NextAnnouncement = Timer.GetTime() + config.InitialDelay, NextVoice = 0 }
        end
    end
end

function console.Validate(client, item, readOnly)
    return active and Game.RoundStarted
        and client ~= nil and client.InGame and client.Character ~= nil and client.Character.IsHuman
        and not client.Character.IsDead and not client.Character.IsIncapacitated
        and item ~= nil and not item.Removed and terminals[item] ~= nil
        and item.Submarine == Submarine.MainSub and client.Character.Submarine == item.Submarine
        and client.Character.CanInteractWith(item)
        and item.CanClientAccess(client) and (readOnly == true or client.Character.SelectedItem == item)
end

function console.Snapshot(client, item, data)
    local now = Timer.GetTime()
    return { Text = texts, Alert = Traitormod.SelectedGamemode.AlertCode,
        Evacuation = Traitormod.SelectedGamemode:GetEvacuationStatus(),
        Powered = item.Condition > 0 and item.GetComponentString("Powered").HasPower,
        Voice = data.Speaker ~= nil, Mine = data.Speaker ~= nil and data.Speaker == client,
        Remaining = math.max(0, math.ceil((data.EndTime or 0) - now)),
        VoiceCooldown = math.max(0, math.ceil(data.NextVoice - now)),
        AnnouncementCooldown = math.max(0, math.ceil(data.NextAnnouncement - now)), MaxLength = ChatMessage.MaxLength }
end

function console.Send(client, item)
    local message = Networking.Start("VoidTraitor_CommunicationsSnapshot")
    message.WriteUInt16(UShort(item.ID))
    message.WriteString(json.encode(console.Snapshot(client, item, terminals[item])))
    Networking.Send(message, client.Connection)
end

function console.Stop(data)
    broadcasters[data.Speaker] = nil
    data.Speaker, data.EndTime = nil, nil
    data.NextVoice = Timer.GetTime() + config.VoiceCooldown
    Traitormod.SelectedGamemode:SendAlertMessage(Traitormod.GetText("CommsVoiceFinished"), announcementColor, announcementHeaderColor)
    Traitormod.SelectedGamemode:PlayAlertSound("green")
end

function console.Action(client, item, action, value)
    if action == "close" then sessions[client] = nil return end
    if not console.Validate(client, item) then return end
    local data = terminals[item]
    local snapshot = console.Snapshot(client, item, data)
    if not snapshot.Powered then return end
    local now = Timer.GetTime()
    if action == "announce" then
        if #value > ChatMessage.MaxLength or #value == 0 or not value:find("%S") or now < data.NextAnnouncement then return end
        local speaker = client.Character
        local job = speaker.Info ~= nil and speaker.Info.Job
        local title = job ~= nil and job.Prefab.Name.Value or Traitormod.GetText("CommsVoiceUnknownTitle")
        local announcement = value .. "\n" .. Traitormod.FormatText("CommsAnnouncementSentBy", speaker.Name, title)
        Traitormod.SelectedGamemode:SendAlertMessage(announcement, announcementColor, announcementHeaderColor)
        Traitormod.SelectedGamemode:PlayAlertSound("announcement")
        data.NextAnnouncement = now + config.AnnouncementCooldown
    elseif action == "voice" then
        if data.Speaker == client then console.Stop(data)
        elseif data.Speaker == nil and broadcasters[client] == nil and now >= data.NextVoice then
            data.Speaker, data.EndTime = client, now + config.VoiceDuration
            broadcasters[client] = item
            patchVoice()
            local speaker = client.Character
            local job = speaker.Info ~= nil and speaker.Info.Job
            local title = job ~= nil and job.Prefab.Name.Value or Traitormod.GetText("CommsVoiceUnknownTitle")
            Traitormod.SelectedGamemode:SendAlertMessage(Traitormod.FormatText("CommsVoiceStarted", speaker.Name, title), announcementColor, announcementHeaderColor)
            Traitormod.SelectedGamemode:PlayAlertSound("green")
        end
    elseif action == "evacuation" then
        Traitormod.SelectedGamemode:ToggleEvacuation()
    elseif action == "code" then
        local selectable, currentSelectable = false, false
        for _, code in ipairs(codes) do
            if value == code then selectable = true end
            if snapshot.Alert == code then currentSelectable = true end
        end
        if selectable and currentSelectable then Traitormod.SelectedGamemode:SetAlertCode(value) end
    end
    data.Revision = nil
end

function console.Think()
    if not active then return end
    for item, data in pairs(terminals) do
        if data.Speaker ~= nil and (not console.Validate(data.Speaker, item, true)
            or Timer.GetTime() >= data.EndTime or item.Condition <= 0 or not item.GetComponentString("Powered").HasPower) then
            console.Stop(data)
        end
        if item.Removed then terminals[item] = nil
        elseif next(sessions) ~= nil then
            local revision = json.encode(console.Snapshot(nil, item, data))
            if data.Revision ~= revision then
                data.Revision = revision
                for client, selected in pairs(sessions) do
                    if selected == item then
                        if console.Validate(client, item, true) then console.Send(client, item)
                        else sessions[client] = nil end
                    end
                end
            end
        end
    end
end

function console.End()
    active, terminals, sessions, broadcasters = false, {}, {}, {}
end

Networking.Receive("VoidTraitor_CommunicationsOpen", function(message, client)
    local item = Entity.FindEntityByID(message.ReadUInt16())
    if console.Validate(client, item, true) then sessions[client] = item console.Send(client, item) end
end)
Networking.Receive("VoidTraitor_CommunicationsAction", function(message, client)
    local item, action, value = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString(), message.ReadString()
    if #action <= 16 and #value <= ChatMessage.MaxLength then console.Action(client, item, action, value) end
end)
Hook.Add("client.disconnected", "Traitormod.Communications.Disconnect", function(client) sessions[client] = nil end)
-- Patched only on the first broadcast: the patch then runs for every speaker and listener for the rest of the session.
local voicePatched = false
function patchVoice()
    if voicePatched then return end
    voicePatched = true
    Hook.Patch("Traitormod.Communications.Voice", "Barotrauma.Networking.VoipServer", "CanReceive", function(_, parameters)
        local sender, recipient = parameters["sender"], parameters["recipient"]
        local item = broadcasters[sender]
        if item == nil or not console.Validate(sender, item, true) or sender.Muted or sender.Character.SpeechImpediment >= 100 then return end
        local data = terminals[item]
        if Timer.GetTime() >= data.EndTime or item.Condition <= 0 or not item.GetComponentString("Powered").HasPower then return end
        if recipient.Character == nil or recipient.Character.IsDead or recipient.Character.Submarine ~= item.Submarine then return end
        parameters["distanceFactor"], parameters["isRadio"] = Single(0), true
        return true
    end, Hook.HookMethodType.After)
end
return console
