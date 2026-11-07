local event = {}

-- A short circuit knocks out one power controller of the station and burns through a wire running from it to a lamp,
-- a device or the power source. Engineers repair the controller and lay a new wire.
event.Name = "ShortCircuit"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local function workingControllers()
    local controllers = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("vt_powercontroller") and item.Condition > 0 then table.insert(controllers, item) end
    end
    return controllers
end

-- wires of the controller that can be laid again: the connection panels at both ends are open
local function replaceableWires(controller)
    local wires = {}
    local panel = controller.GetComponentString("ConnectionPanel")
    if panel == nil or panel.Locked then return wires end
    for connection in panel.Connections do
        for wire in connection.Wires do
            local other = wire.OtherConnection(connection)
            if other ~= nil and not other.ConnectionPanel.Locked then table.insert(wires, wire) end
        end
    end
    return wires
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #workingControllers() > 0
end

event.Start = function ()
    local controllers = workingControllers()
    local controller = controllers[math.random(#controllers)]
    -- the server sends a broken item to the clients at once
    controller.Condition = 0
    local wires = replaceableWires(controller)
    if #wires > 0 then Entity.Spawner.AddItemToRemoveQueue(wires[math.random(#wires)].Item) end

    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("ShortCircuit"), "green")
    event.End()
end

event.End = function ()

end

return event
