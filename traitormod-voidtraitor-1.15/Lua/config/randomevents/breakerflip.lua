local event = {}

-- Station's take on the SS14 breaker flip: a short circuit knocks out one junction box of the station and burns through
-- a wire running from it to a lamp, a device or the power source. Engineers repair the box and lay a new wire.
event.Name = "BreakerFlip"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local function workingJunctionBoxes()
    local boxes = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("junctionbox") and item.Condition > 0 then table.insert(boxes, item) end
    end
    return boxes
end

-- wires of the box that can be laid again: the connection panels at both ends are open
local function replaceableWires(box)
    local wires = {}
    local panel = box.GetComponentString("ConnectionPanel")
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
    return mode ~= nil and mode.Name == "Station" and #workingJunctionBoxes() > 0
end

event.Start = function ()
    local boxes = workingJunctionBoxes()
    local box = boxes[math.random(#boxes)]
    -- the server sends a broken item to the clients at once
    box.Condition = 0
    local wires = replaceableWires(box)
    if #wires > 0 then Entity.Spawner.AddItemToRemoveQueue(wires[math.random(#wires)].Item) end

    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("BreakerFlip"), "green")
    event.End()
end

event.End = function ()

end

return event
