if not Game.IsMultiplayer or (Game.IsMultiplayer and CLIENT) then return end

LuaUserData.RegisterType("Barotrauma.Networking.FileSender")

local luaConfirmed = {}
local clientTrackers = {}

local WAIT_AFTER_DOWNLOAD = 20 

local function getWelcomeText()
    if Traitormod and Traitormod.GetText then
        return Traitormod.GetText("WelcomeMessage")
    end
    return ""
end

local function getServerSenderText()
    if Traitormod and Traitormod.GetText then
        return Traitormod.GetText("ChatSenderServer")
    end
    return ""
end

local function IsDownloading(client)
    if not Game.Server or not Game.Server.FileSender then return false end
    for key, value in pairs(Game.Server.FileSender.ActiveTransfers) do
        if value.Connection == client.Connection then return true end
    end
    return false
end

Networking.Receive("VoidTraitor_LuaCheck", function(message, client)
    luaConfirmed[client] = true
end)

Hook.Add("client.connected", "Welcome_Connect", function(client)
    clientTrackers[client] = { timer = 0, sent = false }
end)

Hook.Add("client.disconnected", "Welcome_Disconnect", function(client)
    clientTrackers[client] = nil
    luaConfirmed[client] = nil
end)

Hook.Add("think", "Welcome_Logic", function()
    for client, data in pairs(clientTrackers) do
        if not data.sent then
            if luaConfirmed[client] then
                data.sent = true 
            elseif IsDownloading(client) then
                data.timer = 0
            else
                data.timer = data.timer + 0.0166 
                if data.timer > WAIT_AFTER_DOWNLOAD then
                    if not luaConfirmed[client] then
                        local ok, err = pcall(function()
                            local chatMessage = ChatMessage.Create(getServerSenderText(), getWelcomeText(), ChatMessageType.ServerMessageBox, nil, nil)
                            Game.SendDirectChatMessage(chatMessage, client)
                        end)

                        if not ok then
                            data.timer = 0
                            Traitormod.Error("Failed to send welcome message to " .. Traitormod.ClientLogName(client) .. ": " .. tostring(err))
                        else
                            data.sent = true
                        end
                    else
                        data.sent = true
                    end
                end
            end
        end
    end
end)