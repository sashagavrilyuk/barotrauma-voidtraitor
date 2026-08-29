if SERVER then return end

local function IsPointshopOpen()
    local state = rawget(_G, "VoidTraitorPointshopGuiState")
    return state ~= nil and not state.Disabled and state.CurrentMenu ~= nil
end

Hook.RemovePatch("VoidTraitor.ClientRuntime.PointshopLockHud", "Barotrauma.Character", "ShouldLockHud", Hook.HookMethodType.After)
Hook.RemovePatch("VoidTraitor.ClientRuntime.PointshopLockInventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, Hook.HookMethodType.After)
Hook.RemovePatch("VoidTraitor.ClientRuntime.PointshopInventoryMouse", "Barotrauma.Inventory", "get_IsMouseOnInventory", {}, Hook.HookMethodType.After)

Hook.Patch("VoidTraitor.PointshopGui.LockInventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, p)
    if IsPointshopOpen() and p["character"] == Character.Controlled then
        return true
    end
end, Hook.HookMethodType.After)

Hook.Patch("VoidTraitor.PointshopGui.InventoryMouse", "Barotrauma.Inventory", "get_IsMouseOnInventory", {}, function()
    if IsPointshopOpen() then
        return false
    end
end, Hook.HookMethodType.After)
