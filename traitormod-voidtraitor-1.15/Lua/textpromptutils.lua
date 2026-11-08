-- Server questions and notices, shown by the pack's client window (Lua/client/prompt.lua)
local c = {}

-- open prompts per client by id; an answer is the number of the chosen option
local openPrompts = {}
local nextId = 0

-- with an item the client closes the prompt once its character stops selecting that item
c.Prompt = function (message, options, client, callback, item)
    nextId = nextId % 65535 + 1
    local prompts = openPrompts[client] or {}
    openPrompts[client] = prompts
    if item ~= nil then
        -- the client has already closed the prompt of an item it selected before
        for id, prompt in pairs(prompts) do
            if prompt.Item ~= nil then prompts[id] = nil end
        end
    end
    prompts[nextId] = { Options = #options, Callback = callback, Item = item }

    local netMessage = Networking.Start("VoidTraitor_Prompt")
    netMessage.WriteUInt16(UShort(nextId))
    netMessage.WriteUInt16(UShort(item ~= nil and item.ID or 0))
    netMessage.WriteString(message)
    netMessage.WriteByte(Byte(#options))
    for _, option in ipairs(options) do
        netMessage.WriteString(option)
    end
    Networking.Send(netMessage, client.Connection, DeliveryMethod.Reliable)
end

Networking.Receive("VoidTraitor_PromptAnswer", function (message, client)
    local id, option = message.ReadUInt16(), message.ReadByte()
    local prompts = openPrompts[client]
    local prompt = prompts ~= nil and prompts[id] or nil
    if prompt == nil or option < 1 or option > prompt.Options then return end

    prompts[id] = nil
    prompt.Callback(option, client)
end)

-- item identifier -> function (client, item) that opens the prompt of that item; the client asks for it when it selects one
c.ItemPrompts = {}
local nextItemPromptTime = {}

Networking.Receive("VoidTraitor_ItemPrompt", function (message, client)
    local item = Entity.FindEntityByID(message.ReadUInt16())
    -- the request can arrive before the server sees the item selected, so only reach is checked here; answers need the selection
    if item == nil or not LuaUserData.IsTargetType(item, "Barotrauma.Item") or item.Removed
        or client.Character == nil or client.Character.IsDead or not item.CanClientAccess(client) then return end
    local open = c.ItemPrompts[item.Prefab.Identifier.Value]
    if open == nil or (nextItemPromptTime[client] or 0) > Timer.GetTime() then return end
    nextItemPromptTime[client] = Timer.GetTime() + 0.5
    open(client, item)
end)

Hook.Add("client.disconnected", "Traitormod.Prompt.Disconnect", function (client)
    openPrompts[client] = nil
    nextItemPromptTime[client] = nil
end)

Hook.Add("roundEnd", "Traitormod.Prompt.RoundEnd", function ()
    openPrompts = {}
end)

return c
