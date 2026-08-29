if SERVER then return end

local packPath = table.pack(...)[1]
local spectatorCommon = assert(loadfile(packPath .. "/Lua/client/spectator/common.lua"))(packPath)

assert(loadfile(packPath .. "/Lua/client/spectator/camera_teleport.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/spectator/ghostroles.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/pointshop/gui.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/lobby/menu.lua"))(packPath, spectatorCommon)
assert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath, spectatorCommon)

for _, patchIdentifier in ipairs({
    "VoidTraitor.ClientMenu.Hud",
    "VoidTraitor.PointshopGui.Hud",
    "VoidTraitor.CameraTeleportGui.Hud",
    "VoidTraitor.GhostRolesGui.Hud",
    "VoidTraitor.ClientRuntime.Hud",
}) do
    Hook.RemovePatch(patchIdentifier, "Barotrauma.GameSession", "AddToGUIUpdateList", Hook.HookMethodType.Before)
end

Hook.Patch("VoidTraitor.ClientRuntime.Hud", "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local lobby = rawget(_G, "VoidTraitorClientMenuState")
    if lobby ~= nil and not lobby.Disabled and not (GUI ~= nil and GUI.DisableHUD) then
        if lobby.CurrentMenu ~= nil and lobby.GuiRoot ~= nil then lobby.GuiRoot:AddToGUIUpdateList(false, 125) end
        if lobby.ButtonRoot ~= nil then lobby.ButtonRoot:AddToGUIUpdateList(false, 100) end
    end

    local pointshop = rawget(_G, "VoidTraitorPointshopGuiState")
    if pointshop ~= nil and pointshop.GuiRoot ~= nil then
        local pointshopOpen = not pointshop.Disabled and pointshop.CurrentMenu ~= nil
        pointshop.GuiRoot.CanBeFocused = pointshopOpen
        if pointshopOpen then pointshop.GuiRoot:AddToGUIUpdateList(false, 120) end
    end

    for _, stateKey in ipairs({ "VoidTraitorCameraTeleportGuiState", "VoidTraitorGhostRolesGuiState" }) do
        local state = rawget(_G, stateKey)
        if state ~= nil and not state.Disabled and not (GUI ~= nil and GUI.DisableHUD) then
            if state.MenuRoot ~= nil then state.MenuRoot:AddToGUIUpdateList(false, 122) end
            if state.ButtonRoot ~= nil then state.ButtonRoot:AddToGUIUpdateList(false, 121) end
        end
    end
end)

Hook.Patch("VoidTraitor.ClientRuntime.PointshopLockHud", "Barotrauma.Character", "ShouldLockHud", function(instance)
    local pointshop = rawget(_G, "VoidTraitorPointshopGuiState")
    if pointshop ~= nil and not pointshop.Disabled and pointshop.CurrentMenu ~= nil and instance == Character.Controlled then
        return true
    end
end, Hook.HookMethodType.After)
