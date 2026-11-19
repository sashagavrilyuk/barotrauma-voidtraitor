-- devices on maps can be pried off with a crowbar, carried in both hands and attached elsewhere, like the game's own
-- attachable items. their vanilla XML gets a body and a Holdable in memory, so game updates still reach them; the server
-- and every client add exactly the same, since network events address components by index.
-- a device comes off only once no wire is connected, nothing is linked to it and a reactor holds no fuel
if CLIENT and not Game.IsMultiplayer then return end

local NET_SYNC = "VoidTraitor_DetachableSync"

-- components that make an installed item something players use
local INTERACTIVE = {
    itemcontainer = true, lightcomponent = true, controller = true, pump = true, powercontainer = true,
    powertransfer = true, terminal = true, custominterface = true, sonar = true, sonartransducer = true, minimap = true,
    engine = true, electricaldischarger = true, fabricator = true, deconstructor = true, steering = true,
    oxygengenerator = true, reactor = true, planter = true,
}
-- vanilla uses bare ones for invisible emitters; only a selectable one is a console
local SELECTABLE_ONLY = { itemcomponent = true, powered = true }
-- items that already move or must stay: doors keep their gaps, turrets their loaders, and a trigger would stay behind
-- when its item is moved (TriggerComponent.Move)
local EXCLUDED = {
    body = true, staticbody = true, holdable = true, pickable = true, wearable = true, throwable = true,
    meleeweapon = true, rangedweapon = true, door = true, ladder = true, dockingport = true, wire = true,
    levelresource = true, projectile = true, turret = true, triggercomponent = true,
}
-- in alien ruins only the decor comes off: buttons, terminals, pumps, chests and vents are the ruin's puzzles and traps
local ALIEN_MECHANISMS = { buttonterminal = true, vent = true }
local EXCLUDED_CATEGORIES = { "legacy", "thalamus" }
-- in display units: the reactor (2.6 m) and the shuttle engine are carried, the main engines (3.3 and 8 m) are not
local MAX_SIZE = 300
-- by sprite area in square metres: seconds to pry off and speed while carrying; a reactor is always the heaviest
local CLASSES = {
    { MinArea = 6, Time = 60, Speed = 0.15 },
    { MinArea = 3, Time = 20, Speed = 0.25 },
    { MinArea = 0.6, Time = 10, Speed = 0.5 },
    { MinArea = 0, Time = 5, Speed = 0.75 },
}
local HOLDABLE = [[<Holdable selectkey="Select" pickkey="Use" slots="RightHand+LeftHand" msg="vt.detach.crowbar"
    MsgWhenDropped="ItemMsgPickupSelect" PickingTime="%d" aimpos="65,-10" handle1="0,0" attachable="true"
    attachedbydefault="true" aimable="true" AllowAttachInsideDoors="false">
    <RequiredItem items="crowbar" type="Equipped"/>
    <StatusEffect type="OnActive" target="Character" SpeedMultiplier="%s" setvalue="true"/>
</Holdable>]]

-- prefab identifier -> the elements added to its XML
local added = {}

local function isDevice(prefab)
    local config = prefab.ConfigElement
    local category = string.lower(config.GetAttributeString("category", ""))
    for _, excluded in ipairs(EXCLUDED_CATEGORIES) do
        if string.find(category, excluded, 1, true) then return false end
    end
    local alien = string.find(category, "alien", 1, true)
        or string.find(string.lower(config.GetAttributeString("tags", "")), "alien", 1, true)
    local interactive = false
    for element in config.Elements() do
        local name = string.lower(element.Name.LocalName)
        if EXCLUDED[name] then return false end
        local part = INTERACTIVE[name] or (SELECTABLE_ONLY[name] and element.GetAttributeBool("canbeselected", false))
        if alien and name ~= "lightcomponent" and (part or SELECTABLE_ONLY[name] or ALIEN_MECHANISMS[name]) then
            return false
        end
        interactive = interactive or part
    end
    local width, height = prefab.Size.X * prefab.Scale, prefab.Size.Y * prefab.Scale
    return interactive and width >= 1 and height >= 1 and math.max(width, height) <= MAX_SIZE
end

local function classOf(prefab)
    if prefab.ConfigElement.GetChildElement("Reactor") ~= nil then return CLASSES[1] end
    local area = prefab.Size.X * prefab.Scale * prefab.Size.Y * prefab.Scale / 10000
    for _, class in ipairs(CLASSES) do
        if area >= class.MinArea then return class end
    end
end

for prefab in ItemPrefab.Prefabs do
    if isDevice(prefab) then
        local class = classOf(prefab)
        local root = prefab.ConfigElement.Element
        local body = XElement.Parse(string.format('<Body width="%d" height="%d" density="30"/>',
            math.floor(prefab.Size.X), math.floor(prefab.Size.Y)))
        local holdable = XElement.Parse(string.format(HOLDABLE, class.Time, class.Speed))
        -- Holdable takes the body that exists when it is created, so the body goes first
        root.AddFirst(body)
        root.Add(holdable)
        added[prefab.Identifier.Value] = { body, holdable }
    end
end

-- a client leaves this server for the menu, singleplayer or another server with vanilla items again
Hook.Add("stop", "VoidTraitorPack.DetachableDevices", function()
    for _, elements in pairs(added) do
        for _, element in ipairs(elements) do element.Remove() end
    end
    added = {}
end)

-- vanilla drops a device's wires when it is picked up; here they have to be disconnected first
local function blockedBy(item)
    for component in item.Components do
        if LuaUserData.IsTargetType(component, "Barotrauma.Items.Components.ConnectionPanel") then
            for connection in component.Connections do
                for _ in connection.Wires do return "wires" end
            end
        end
    end
    -- picking an item up breaks its links (Pickable.OnPicked), and they cannot be made again in the game
    for _ in item.linkedTo do return "linked" end
    if item.GetComponentString("Reactor") ~= nil then
        for _ in item.OwnInventory.AllItems do return "fuel" end
    end
end

Hook.Patch("VoidTraitorPack.DetachableDevices.Block", "Barotrauma.Items.Components.Holdable", "CanBeDeattached",
    function(holdable, ptable)
        if ptable.ReturnValue and holdable.Attached and added[holdable.Item.Prefab.Identifier.Value] ~= nil
            and blockedBy(holdable.Item) ~= nil then
            ptable.ReturnValue = false
        end
    end, Hook.HookMethodType.After)

-- a player who joins mid-round gets every device at its map spot, and the game ignores the attach position for an item
-- that is already attached (Holdable.ClientEventRead), so the server tells them where moved devices hang
if SERVER then
    local moved, answered = {}, {}

    Hook.Patch("VoidTraitorPack.DetachableDevices.Attached", "Barotrauma.Items.Components.Holdable", "ServerEventRead",
        function(holdable)
            if holdable.Attached and added[holdable.Item.Prefab.Identifier.Value] ~= nil then
                moved[holdable.Item] = true
            end
        end, Hook.HookMethodType.After)

    Networking.Receive(NET_SYNC, function(_, client)
        if answered[client] or not Game.RoundStarted then return end
        answered[client] = true
        local devices = {}
        for item in pairs(moved) do
            if item.Removed then
                moved[item] = nil
            elseif item.GetComponentString("Holdable").Attached then
                devices[#devices + 1] = item
            end
        end
        if #devices == 0 then return end
        local message = Networking.Start(NET_SYNC)
        message.WriteUInt16(#devices)
        for _, item in ipairs(devices) do
            message.WriteUInt16(item.ID)
            message.WriteSingle(item.SimPosition.X)
            message.WriteSingle(item.SimPosition.Y)
            message.WriteUInt16(item.Submarine ~= nil and item.Submarine.ID or 0)
        end
        Networking.Send(message, client.Connection)
    end)

    Hook.Add("roundEnd", "VoidTraitorPack.DetachableDevices", function()
        moved, answered = {}, {}
    end)
    Hook.Add("client.disconnected", "VoidTraitorPack.DetachableDevices", function(client)
        answered[client] = nil
    end)
    return
end

Hook.Add("roundStart", "VoidTraitorPack.DetachableDevices", function()
    Networking.Send(Networking.Start(NET_SYNC))
end)

Networking.Receive(NET_SYNC, function(message)
    for _ = 1, message.ReadUInt16() do
        local item = Entity.FindEntityByID(message.ReadUInt16())
        local position = Vector2(message.ReadSingle(), message.ReadSingle())
        local submarine = Entity.FindEntityByID(message.ReadUInt16())
        local holdable = item ~= nil and item.GetComponentString("Holdable") or nil
        if holdable ~= nil and holdable.Attached then
            item.SetTransform(position, 0, true, true, submarine)
            holdable.AttachToWall()
        end
    end
end)

-- the game plays pick sounds only for the picker, so everyone nearby hears the tear when the device detaches:
-- the sound of a door forced open with a crowbar
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local tearSound = gameMain.SoundManager.LoadSound("Content/Items/Tools/Crowbar.ogg")
local TEAR_RANGE = 2000
local wasAttached = false

Hook.Patch("VoidTraitorPack.DetachableDevices.Read", "Barotrauma.Items.Components.Holdable", "ClientEventRead",
    function(holdable)
        wasAttached = holdable.Attached
    end, Hook.HookMethodType.Before)

Hook.Patch("VoidTraitorPack.DetachableDevices.Tear", "Barotrauma.Items.Components.Holdable", "ClientEventRead",
    function(holdable)
        if wasAttached and not holdable.Attached and added[holdable.Item.Prefab.Identifier.Value] ~= nil then
            tearSound.Play(1, TEAR_RANGE, holdable.Item.WorldPosition)
        end
    end, Hook.HookMethodType.After)

-- the interaction hint says why a device does not come off instead of offering the crowbar
local detachText = TextManager.ParseInputTypes(TextManager.Get("vt.detach.crowbar"))
local blockedTexts = { wires = TextManager.Get("vt.detach.wires"), fuel = TextManager.Get("vt.detach.fuel") }
local fixedText = TextManager.Get("vt.detach.fixed")

Hook.Patch("VoidTraitorPack.DetachableDevices.Hint", "Barotrauma.Item", "GetHUDTexts", function(item, ptable)
    if not ptable["recreateHudTexts"] or added[item.Prefab.Identifier.Value] == nil then return end
    local holdable = item.GetComponentString("Holdable")
    if not holdable.Attached then return end
    if holdable.CanBeDeattached() then
        holdable.DisplayMsg = detachText
    else
        holdable.DisplayMsg = blockedTexts[blockedBy(item)] or fixedText
    end
end, Hook.HookMethodType.Before)
