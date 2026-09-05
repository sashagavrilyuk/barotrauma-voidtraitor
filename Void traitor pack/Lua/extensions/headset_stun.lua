local blockedHeadsets = {
    headset = true,
    autoinjectorheadset = true
}

local function isBlockedHeadset(item)
    return item ~= nil and blockedHeadsets[item.Prefab.Identifier.Value] == true
end

local function isEquipped(character, item)
    return character ~= nil and item ~= nil and character.HasEquippedItem(item)
end

local function findFallbackRadio(character, ignoreJamming)
    local bestRadio = nil

    for item in character.Inventory.AllItems do
        if not isBlockedHeadset(item) and isEquipped(character, item) then
            local wifi = item.GetComponentString("WifiComponent")
            if wifi ~= nil and wifi.LinkToChat and wifi.CanTransmit(ignoreJamming) then
                if bestRadio == nil or wifi.Range > bestRadio.Range then
                    bestRadio = wifi
                end
            end
        end
    end

    return bestRadio
end

Hook.Patch(
    "VoidTraitorPack.HeadsetStun.CanUseRadio",
    "Barotrauma.Networking.ChatMessage",
    "CanUseRadio",
    {
        "Barotrauma.Character",
        "out Barotrauma.Items.Components.WifiComponent",
        "System.Boolean"
    },
    function(_, p)
        local character = p["sender"]
        local radio = p["radio"]
        if character == nil or character.Stun <= 1 or radio == nil or not isBlockedHeadset(radio.Item) then return end

        local fallback = findFallbackRadio(character, p["ignoreJamming"])
        p["radio"] = fallback
        p.ReturnValue = fallback ~= nil
    end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "VoidTraitorPack.HeadsetStun.ApplyDistanceEffect",
    "Barotrauma.Networking.ChatMessage",
    "ApplyDistanceEffect",
    {
        "System.String",
        "Barotrauma.Networking.ChatMessageType",
        "Barotrauma.Character",
        "Barotrauma.Character"
    },
    function(_, p)
        local receiver = p["receiver"]
        if receiver == nil or receiver.Stun <= 1 or receiver.Inventory == nil or receiver.IsDead then return end

        local hasBlockedEquippedHeadset = false
        for item in receiver.Inventory.AllItems do
            if isBlockedHeadset(item) and isEquipped(receiver, item) then
                hasBlockedEquippedHeadset = true
                break
            end
        end
        if not hasBlockedEquippedHeadset then return end

        local messageType = p["type"]
        if messageType ~= ChatMessageType.Radio and messageType ~= ChatMessageType.Order then return end

        local sender = p["sender"]
        if sender == nil or sender.Inventory == nil then return end

        local message = p["message"]
        for receiverItem in receiver.Inventory.AllItems do
            if not isBlockedHeadset(receiverItem) and isEquipped(receiver, receiverItem) then
                local receiverRadio = receiverItem.GetComponentString("WifiComponent")
                if receiverRadio ~= nil and receiverRadio.LinkToChat then
                    for senderItem in sender.Inventory.AllItems do
                        if isEquipped(sender, senderItem) then
                            local senderRadio = senderItem.GetComponentString("WifiComponent")
                            if senderRadio ~= nil and senderRadio.LinkToChat and receiverRadio.CanReceive(senderRadio) then
                                local result = ChatMessage.ApplyDistanceEffect(receiverItem, senderItem, message, senderRadio.Range, 0)
                                if sender.SpeechImpediment > 0 then
                                    result = ChatMessage.ApplyDistanceEffect(result, sender.SpeechImpediment / 100)
                                end
                                p.ReturnValue = result
                                return
                            end
                        end
                    end
                end
            end
        end

        p.ReturnValue = ChatMessage.ApplyDistanceEffect(receiver, sender, message, ChatMessage.SpeakRange, 3)
    end,
    Hook.HookMethodType.After
)
