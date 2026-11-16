-- Admin overlay like Space Station 14's: an admin who turns it on (!aoverlay or the admin menu) sees above every living
-- human and every character a player controls who controls it, its job (a Station player's role) and its antagonist
-- role. The admin's client draws them with the name and health it knows itself (Void traitor pack-1.15:
-- Lua/client/adminoverlay.lua); roles are hidden information, so they go only to the admins who asked.
local overlay = {}

local NET_DATA = "VoidTraitor_AdminOverlay"
local REFRESH_MS = 2000

-- admin client -> what was sent to it last (false before the first send)
local viewers = {}
local running = false

local function snapshot()
    local players = {}
    for _, client in pairs(Client.ClientList) do
        if client.Character ~= nil then players[client.Character] = client.Name end
    end
    local entries = {}
    for character in Character.CharacterList do
        local player = players[character]
        if not character.Removed and not character.IsDead and (character.IsHuman or player ~= nil)
            and not Traitormod.AdminGhost.IsGhost(character) then
            local role = Traitormod.RoleManager.GetRole(character)
            entries[#entries + 1] = { Id = character.ID, Player = player or "",
                Job = character.Info ~= nil and character.Info.Job ~= nil and Traitormod.GetJobString(character) or "",
                Role = role ~= nil and role.IsAntagonist and role.Name or "" }
        end
    end
    return entries
end

local function signatureOf(entries)
    local parts = {}
    for _, entry in ipairs(entries) do parts[#parts + 1] = entry.Id .. "|" .. entry.Player .. "|" .. entry.Job .. "|" .. entry.Role end
    return table.concat(parts, ";")
end

local function send(client, entries)
    local message = Networking.Start(NET_DATA)
    message.WriteUInt16(#entries)
    for _, entry in ipairs(entries) do
        message.WriteUInt16(entry.Id)
        message.WriteString(entry.Player)
        message.WriteString(entry.Job)
        message.WriteString(entry.Role)
    end
    Networking.Send(message, client.Connection)
end

-- Every few seconds while someone watches; a viewer gets the list only when it changed.
local function refresh()
    if next(viewers) == nil or not Game.RoundStarted then
        running = false
        return
    end
    local entries = snapshot()
    local signature = signatureOf(entries)
    for client, sent in pairs(viewers) do
        if sent ~= signature then
            viewers[client] = signature
            send(client, entries)
        end
    end
    Timer.Wait(refresh, REFRESH_MS)
end

function overlay.Toggle(client)
    if viewers[client] ~= nil then
        viewers[client] = nil
        send(client, {})
        return
    end
    viewers[client] = false
    if not running then
        running = true
        refresh()
    end
end

Hook.Add("roundEnd", "Traitormod.AdminOverlay.RoundEnd", function()
    viewers = {}
end)

Hook.Add("client.disconnected", "Traitormod.AdminOverlay.Disconnect", function(client)
    viewers[client] = nil
end)

return overlay
