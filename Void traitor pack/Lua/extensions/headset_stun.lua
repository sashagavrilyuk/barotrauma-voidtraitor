local blockedHeadsets = {
    headset = true,
    autoinjectorheadset = true
}

local function isStunnedHeadset(wifi)
    if wifi == nil or wifi.Item == nil then return false end
    if not blockedHeadsets[wifi.Item.Prefab.Identifier.Value] then return false end

    local inventory = wifi.Item.ParentInventory
    if inventory == nil or inventory.Owner == nil then return false end
    if not LuaUserData.IsTargetType(inventory.Owner, "Barotrauma.Character") then return false end

    return inventory.Owner.Stun > 1
end

local function blockStunnedHeadset(wifi, parameters)
    if not isStunnedHeadset(wifi) then return end

    parameters.PreventExecution = true
    return false
end

Hook.Patch(
    "VoidTraitorPack.HeadsetStun.CanTransmit",
    "Barotrauma.Items.Components.WifiComponent",
    "CanTransmit",
    { "System.Boolean" },
    blockStunnedHeadset,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "VoidTraitorPack.HeadsetStun.CanTransmitFromWifi",
    "Barotrauma.Items.Components.WifiComponent",
    "CanTransmit",
    { "Barotrauma.Items.Components.WifiComponent" },
    blockStunnedHeadset,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "VoidTraitorPack.HeadsetStun.CanReceive",
    "Barotrauma.Items.Components.WifiComponent",
    "CanReceive",
    { "Barotrauma.Items.Components.WifiComponent" },
    blockStunnedHeadset,
    Hook.HookMethodType.Before
)
