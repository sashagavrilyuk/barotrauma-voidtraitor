-- devices are built from frames, as SS14's machine frames (pack items/assembly.xml). A frame holds a board and the parts
-- its device needs, and the frame's window turns it into the device; the devices below get a window that turns them back
-- into the frame with the board and parts, and a lamp back into its pack. Both windows are the game's CustomInterface
-- and need a screwdriver; the game shows a button only with an effect, a property or a wire, hence the empty effect
if CLIENT and not Game.IsMultiplayer then return end

-- board -> the device it builds, the frame it goes into and the parts it needs (identifier or tag -> amount)
local BOARDS = {
    vt_board_junctionbox = { Device = "junctionbox", Frame = "vt_frame_wall", Parts = { wire = 2, vt_capacitor = 1 } },
}
-- devices that come apart into a board's frame and parts besides the one the board builds
local ALSO_FROM_BOARD = { junctionboxswappable = "vt_board_junctionbox" }
-- devices that come apart into the pack they were hung from
local PACKS = { lamp = "vt_lamppack_lamp" }

local boardOf = {}
for board, recipe in pairs(BOARDS) do boardOf[recipe.Device] = board end
for device, board in pairs(ALSO_FROM_BOARD) do boardOf[device] = board end

local DISASSEMBLY = [[<CustomInterface canbeselected="true" allowuioverlap="true">
    <GuiFrame relativesize="0.12,0.07" anchor="Center" relativeoffset="0,0.1" style="ItemUI"/>
    <RequiredItem items="screwdriver" type="Equipped"/>
    <Button text="vt.assembly.disassemble">
        <StatusEffect type="OnUse" target="This"/>
    </Button>
</CustomInterface>]]

-- the window goes last, after what the detachable devices add, in the same order on the server and every client
local added = {}
local function addWindow(identifier)
    local element = XElement.Parse(DISASSEMBLY)
    ItemPrefab.Prefabs[identifier].ConfigElement.Element.Add(element)
    added[#added + 1] = element
end
for device in pairs(boardOf) do addWindow(device) end
for device in pairs(PACKS) do addWindow(device) end

Hook.Add("stop", "VoidTraitorPack.DeviceAssembly", function()
    for _, element in ipairs(added) do element.Remove() end
    added = {}
end)

-- the board in a frame and the other items in it
local function contents(frame)
    local board, items = nil, {}
    for item in frame.OwnInventory.AllItems do
        if BOARDS[item.Prefab.Identifier.Value] ~= nil then board = item else items[#items + 1] = item end
    end
    return board, items
end

local function matches(item, part)
    return item.Prefab.Identifier.Value == part or item.HasTag(part)
end

-- part -> how many more the board needs; empty once the frame is complete
local function shortage(recipe, items)
    local need = {}
    for part, amount in pairs(recipe.Parts) do
        local have = 0
        for _, item in ipairs(items) do
            if matches(item, part) then have = have + 1 end
        end
        if have < amount then need[part] = amount - have end
    end
    return need
end

if SERVER then
    local componentEvent = LuaUserData.CreateStatic("Barotrauma.Item+ComponentStateEventData", true)
    -- ServerLog.MessageType.ItemInteraction
    local LOG_ITEM_INTERACTION = 1
    -- items already turning into something else, so a second click does nothing
    local busy = {}

    -- a created item is loose, so it is hung where the old one hung and the clients are told
    local function hangInPlace(identifier, at, onHung)
        local function hang(item)
            local holdable = item.GetComponentString("Holdable")
            holdable.AttachToWall()
            Networking.CreateEntityEvent(item, componentEvent.__new(holdable, nil))
            if onHung ~= nil then onHung(item) end
        end
        local prefab = ItemPrefab.Prefabs[identifier]
        if at.Submarine ~= nil then
            Entity.Spawner.AddItemToSpawnQueue(prefab, at.Position, at.Submarine, nil, nil, hang)
        else
            Entity.Spawner.AddItemToSpawnQueue(prefab, at.WorldPosition, nil, nil, hang)
        end
    end

    local function assemble(frame, user)
        local board, items = contents(frame)
        local recipe = board ~= nil and BOARDS[board.Prefab.Identifier.Value] or nil
        if recipe == nil or recipe.Frame ~= frame.Prefab.Identifier.Value or next(shortage(recipe, items)) ~= nil
            or not frame.GetComponentString("Holdable").Attached then
            return
        end
        busy[frame] = true
        -- the device takes what its board needs; anything else falls out, the rest goes with the frame
        local left = {}
        for part, amount in pairs(recipe.Parts) do left[part] = amount end
        for _, item in ipairs(items) do
            local taken = false
            for part, amount in pairs(left) do
                if not taken and amount > 0 and matches(item, part) then
                    left[part] = amount - 1
                    taken = true
                end
            end
            if not taken then item.Drop(user) end
        end
        hangInPlace(recipe.Device, frame)
        Entity.Spawner.AddEntityToRemoveQueue(frame)
        Game.Log(user.Name .. " assembled " .. ItemPrefab.Prefabs[recipe.Device].Name.Value, LOG_ITEM_INTERACTION)
    end

    local function disassemble(device, user)
        local holdable = device.GetComponentString("Holdable")
        -- what keeps a device from coming off keeps it from coming apart: wires, links, fuel, a locked panel
        if holdable == nil or not holdable.Attached or not holdable.CanBeDeattached() then return end
        busy[device] = true
        for component in device.Components do
            if LuaUserData.IsTargetType(component, "Barotrauma.Items.Components.ItemContainer") then
                for item in component.Inventory.AllItems do item.Drop(user) end
            end
        end
        local identifier = device.Prefab.Identifier.Value
        if PACKS[identifier] ~= nil then
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[PACKS[identifier]], user.Inventory, nil, nil, nil)
        else
            local board = boardOf[identifier]
            local recipe = BOARDS[board]
            hangInPlace(recipe.Frame, device, function(frame)
                Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[board], frame.OwnInventory, nil, nil, nil)
                for part, amount in pairs(recipe.Parts) do
                    for _ = 1, amount do
                        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[part], frame.OwnInventory, nil, nil, nil)
                    end
                end
            end)
        end
        Entity.Spawner.AddEntityToRemoveQueue(device)
        Game.Log(user.Name .. " took apart " .. device.Name, LOG_ITEM_INTERACTION)
    end

    local function lastComponent(item)
        local last
        for component in item.Components do last = component end
        return last
    end

    -- the game has checked that the client can reach the item; the screwdriver and the rest are checked here
    Hook.Patch("VoidTraitorPack.DeviceAssembly.Button", "Barotrauma.Items.Components.CustomInterface", "ButtonClicked",
        function(interface, ptable)
            local item, user = interface.Item, ptable["user"]
            if busy[item] or item.Removed or user == nil or user.IsDead or user.IsIncapacitated
                or not interface.HasRequiredItems(user, false) then
                return
            end
            local identifier = item.Prefab.Identifier.Value
            if item.HasTag("vt_frame") then
                assemble(item, user)
            elseif (boardOf[identifier] ~= nil or PACKS[identifier] ~= nil) and interface == lastComponent(item) then
                disassemble(item, user)
            end
        end, Hook.HookMethodType.After)

    Hook.Add("roundEnd", "VoidTraitorPack.DeviceAssembly", function()
        busy = {}
    end)
    return
end

-- the hint over a frame says what it still needs
local needBoard = TextManager.Get("vt.assembly.needboard")
local ready = TextManager.Get("vt.assembly.ready")
local need = TextManager.Get("vt.assembly.need")

Hook.Patch("VoidTraitorPack.DeviceAssembly.Hint", "Barotrauma.Item", "GetHUDTexts", function(item, ptable)
    if not ptable["recreateHudTexts"] or not item.HasTag("vt_frame") then return end
    local container = item.GetComponentString("ItemContainer")
    local board, items = contents(item)
    local recipe = board ~= nil and BOARDS[board.Prefab.Identifier.Value] or nil
    if recipe == nil then
        container.DisplayMsg = needBoard
        return
    end
    local parts = {}
    for part, amount in pairs(shortage(recipe, items)) do
        parts[#parts + 1] = amount .. " × " .. ItemPrefab.Prefabs[part].Name.Value
    end
    if #parts == 0 then
        container.DisplayMsg = ready
    else
        container.DisplayMsg = RawLString((string.gsub(need.Value, "%[parts%]", table.concat(parts, ", "))))
    end
end, Hook.HookMethodType.Before)
