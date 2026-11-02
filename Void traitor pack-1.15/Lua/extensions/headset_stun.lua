local updateInterval = 0.25
local updateTimer = 0
local linkToChatPropertyId = Identifier("LinkToChat")
local blockedHeadsets = {}

local function setLinkToChat(item, enabled)
    local wifi = item.GetComponentString("WifiComponent")
    if wifi == nil or wifi.LinkToChat == enabled then return end

    wifi.LinkToChat = enabled
    local property = wifi.SerializableProperties[linkToChatPropertyId]
    if property ~= nil then
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(property, wifi))
    end
end

Hook.Add("think", "VoidTraitorPack.HeadsetStun", function(deltaTime)
    updateTimer = updateTimer + deltaTime
    if updateTimer < updateInterval then return end
    updateTimer = 0

    local stillBlocked = {}

    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and not character.Removed and not character.IsDead and character.Inventory ~= nil then
            local item = character.Inventory.GetItemInLimbSlot(InvSlotType.Headset)
            if item ~= nil and not item.Removed then
                local identifier = item.Prefab.Identifier
                if identifier == "headset" or identifier == "autoinjectorheadset" then
                    if character.Stun > 1 then
                        if blockedHeadsets[item] == nil then
                            local wifi = item.GetComponentString("WifiComponent")
                            if wifi ~= nil then
                                blockedHeadsets[item] = wifi.LinkToChat
                            end
                        end
                        stillBlocked[item] = true
                        setLinkToChat(item, false)
                    end
                end
            end
        end
    end

    for item, previousLinkToChat in pairs(blockedHeadsets) do
        if not stillBlocked[item] then
            if item ~= nil and not item.Removed then
                setLinkToChat(item, previousLinkToChat)
            end
            blockedHeadsets[item] = nil
        end
    end
end)
