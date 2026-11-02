local P = ...
local S = P.State

Hook.Add("think", "VoidTraitor.PointshopGui.CooldownClock", function()
    if S.sharedState.Disabled or S.currentMenu == nil then return end
    if #S.cooldownTextBlocks.shop == 0 and #S.cooldownTextBlocks.cart == 0 then return end

    local now = P.GetClientTime()
    if now < S.nextCooldownTextUpdateTime then return end
    S.nextCooldownTextUpdateTime = now + 1

    P.UpdateCooldownTextBlocks()
end)

Networking.Receive(P.NET_PROBE, function(message)
    if S.sharedState.Disabled then return end
    P.SendReady()
    P.RequestSnapshot()
end)

Networking.Receive(P.NET_PURCHASE_SOUND, function(message)
    if S.sharedState.Disabled then return end
    SoundPlayer.PlayUISound(GUI.SoundType.ConfirmTransaction)
end)

Networking.Receive(P.NET_CLOSE_LOCK, function(message)
    if S.sharedState.Disabled then return end
    S.sharedState.CloseLocked = message.ReadBoolean()
end)

Networking.Receive(P.NET_CLASS_LIMITS, function(message)
    if S.sharedState.Disabled then return end

    local count = message.ReadInt32()
    S.classLimitValues = {}
    for i = 1, count do
        local categoryIdentifier = message.ReadString()
        local pathIdentifiers = message.ReadString()
        local limitText = message.ReadString()
        S.classLimitValues[P.GetClassLimitKey(categoryIdentifier, pathIdentifiers)] = limitText or ""
    end

    P.UpdateClassLimitTextBlocks()
end)

Networking.Receive(P.NET_SNAPSHOT, function(message)
    if S.sharedState.Disabled then return end
    P.ReadSnapshot(message)
    if S.closeMenuAfterSnapshot then
        P.CloseMenu()
        return
    end
    P.ShowMenu()
end)

Networking.Receive(P.NET_STATE, function(message)
    if S.sharedState.Disabled then return end
    if not P.ReadState(message) then
        P.RequestSnapshot()
        return
    end
    if S.closeMenuAfterSnapshot then
        P.CloseMenu()
        return
    end
    P.ShowMenu()
end)

Networking.Receive(P.NET_BALANCE, function(message)
    if S.sharedState.Disabled then return end
    S.currentPoints = message.ReadInt32()
    P.ReconcileProductState(false)
    if S.currentMenu ~= nil then
        if S.rebuildProductList ~= nil and S.selectedFilter == "affordable" then
            S.rebuildProductList(false)
        else
            P.RefreshProductRows()
        end
        P.RefreshCartOnly()
    end
end)

Networking.Receive(P.NET_PRODUCT_STATE, function(message)
    if S.sharedState.Disabled then return end
    local count = message.ReadInt32()
    local complete = true
    local rebuildRows = false
    for i = 1, count do
        local ok, needsRebuild = P.ReadProductState(message)
        if not ok then
            complete = false
        elseif needsRebuild then
            rebuildRows = true
        end
    end
    if not complete then
        P.RequestSnapshot()
        return
    end
    P.ReconcileProductState(false)
    if S.currentMenu ~= nil then
        if S.rebuildProductList ~= nil and rebuildRows then
            S.rebuildProductList(false)
        else
            P.RefreshProductRows()
        end
        P.RefreshCartOnly()
    end
end)
