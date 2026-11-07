if SERVER then return end

-- Client half of the power controller (traitormod Lua/gamemodes/station/powercontroller.lua). The client simulates power
-- itself, so when the server's state of the power switch arrives, the box is switched off here the same way as on the
-- server. The state is read from the message before the game handles it: for a second after the player's own click the
-- game holds the server's answer back and keeps showing the clicked state.
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.Items.Components.PowerDistributor"), "isBroken")
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.Items.Components.CustomInterface"), "uiElements")

Hook.Patch("VoidTraitor.PowerController.Switch", "Barotrauma.Items.Components.CustomInterface", "ClientEventRead", function (instance, parameters)
    local item = instance.Item
    if not item.HasTag("vt_powercontroller") then return end
    local msg = parameters["msg"]
    local start = msg.BitPosition
    local on = msg.ReadBoolean()
    msg.BitPosition = start
    local distributor = item.GetComponentString("PowerDistributor")
    if on then
        distributor.CanTransfer = true
    else
        distributor.isBroken = true
        distributor.CanTransfer = false
    end
end, Hook.HookMethodType.Before)

-- While a controller's panel is open the client asks the server every second why its player may not use the switch
-- (an empty reason means they may). Until the server allows it, the switch is greyed out with the reason on hover.
local reason, shown
local requestTimer = 0

Networking.Receive("VoidTraitor_PowerControllerSnapshot", function (message)
    reason = message.ReadString()
    if shown ~= nil then shown.ToolTip = reason end
end)

Hook.Patch("VoidTraitor.PowerController.Hud", "Barotrauma.Items.Components.CustomInterface", "UpdateHUDComponentSpecific", function (instance, parameters)
    local item = instance.Item
    if not item.HasTag("vt_powercontroller") then return end
    local switch = instance.uiElements[1]
    if switch ~= shown then
        shown, requestTimer = switch, 0
        switch.ToolTip = reason or ""
    end
    requestTimer = requestTimer - parameters["deltaTime"]
    if requestTimer <= 0 then
        requestTimer = 1
        local message = Networking.Start("VoidTraitor_PowerControllerOpen")
        message.WriteUInt16(UShort(item.ID))
        Networking.Send(message)
    end
    -- the game enables every element of the panel each frame just before this
    switch.Enabled = reason == ""
end, Hook.HookMethodType.After)
