local patches, receivers, prompts, queue, removals, messages = {}, {}, {}, {}, {}, {}
Hook = { Add = function() end, Patch = function(id, _, _, callback) patches[id] = callback end, HookMethodType = { Before = 1 } }
Networking = { Receive = function(id, callback) receivers[id] = callback end, Start = function()
    return { WriteUInt16 = function() end, WriteString = function() end }
end, Send = function() end }
DeliveryMethod, UShort = { Reliable = 1 }, function(value) return value end
require = function(name)
    if name == 'json' then return { encode = function(value) for _, order in ipairs(value.Orders) do assert(order.Manager == nil) end return '{}' end } end
    return { Prompt = function(_, options, _, callback) prompts.Options, prompts.Callback = options, callback end }
end
local function vector(x, y)
    return setmetatable({ X = x, Y = y }, { __sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y) end })
end
local function iterable(values)
    local index = 0
    return function() index = index + 1 return values[index] end
end
local prefabs = {}
for _, id in ipairs({ 'bandage', 'batterycell', 'lamp', 'morphine', 'metalcrate', 'console', 'port', 'vt_cargo_package' }) do
    prefabs[id] = { Identifier = { Value = id }, Name = { Value = id }, DefaultPrice = { Price = 100 } }
end
ItemPrefab = { GetItemPrefab = function(id) return prefabs[id] end }
local function inventory(capacity)
    local inv = { Capacity = capacity, Slots = {} }
    inv.GetItemAt = function(slot) return inv.Slots[slot] end
    inv.CanBePutInSlot = function(_, slot) return inv.Slots[slot] == nil end
    inv.TryPutItem = function(item, slot)
        if inv.Reject or inv.Slots[slot] ~= nil then return false end
        inv.Slots[slot], item.ParentInventory = item, inv return true
    end
    inv.IsEmpty = function() return next(inv.Slots) == nil end
    inv.AllItems = function(_, previous)
        for slot = 0, capacity - 1 do if inv.Slots[slot] ~= nil and (previous == nil or slot > previous.Slot) then inv.Slots[slot].Slot = slot return inv.Slots[slot] end end
    end
    return inv
end
local main = { Position = vector(0, 0) }
local submarine = { Position = vector(10, 20), Velocity = vector(0, 0) }
Submarine = { MainSub = main }
local itemList = {}
Item = { ItemList = function(_, previous) local index = previous ~= nil and previous.Index + 1 or 1 return itemList[index] end }
local function item(id, tag, sub, x)
    local value = { ID = #itemList + 1, Index = #itemList + 1, Submarine = sub, WorldPosition = vector(x or 0, 0), Prefab = prefabs[id], Tags = tag or '', ConditionPercentage = 100 }
    value.HasTag = function(t) return value.Tags == t end
    value.Components = {}
    value.GetComponentString = function(t) return value.Components[t] end
    value.CanClientAccess = function() return true end
    itemList[#itemList + 1] = value
    return value
end
local helm = item('console', 'vt_cargo_helm', submarine)
local home = item('port', 'vt_cargo_home', main)
home.Components.DockingPort = { Item = home }
local port = item('port', 'vt_cargo_port', submarine)
port.Components.DockingPort = { Item = port, Docked = true, DockingTarget = home.Components.DockingPort }
local crate = item('metalcrate', 'vt_cargo_crate', submarine)
crate.OwnInventory = inventory(3)
local marker = item('console', 'vt_cargo_large', submarine, 500)
local console = item('console', '', main)
console.Prefab = { Identifier = 'vt_cargo_console' }
console.CanClientAccess = function() return true end
console.Components.Terminal = { SyncHistory = function() end }
local client = { Name = 'Buyer', InGame = true, Character = { Inventory = inventory(1), IsHuman = true, SelectedItem = console, Submarine = main } }
client.Character.AnimController = { GetLimb = function() return { WorldPosition = vector(40, 50) } end }
local manager = { Name = 'Cargo', Character = { IsHuman = true, SelectedItem = console, Inventory = inventory(1) } }
manager.Character.Inventory.Slots[0] = { HasTag = function(tag) return tag == 'vt_access_cargo' end, GetComponentString = function(name) return name == 'IdCard' and {} or nil end }
local categories = { { Identifier = 'medical', Products = {
    { Identifier = 'bandage', Items = { 'bandage', 'morphine' }, Price = 300, Limit = 3 },
    { Identifier = 'batterycell', Items = { { Identifier = 'batterycell', Condition = 9 } }, Price = 100, Limit = 2 },
    { Identifier = 'lamp', Items = { { Identifier = 'lamp', IsInstallation = true } }, Price = 200, Limit = 3,
        Action = function(_, _, items) items[1].Lit = true end },
    { Identifier = 'invalid', Items = { 'missing' }, Price = 1 },
} } }
Traitormod = { Config = { PointShopConfig = { ItemCategories = categories }, Cargo = { Budget = 10000, Categories = { 'medical' }, AccessTag = 'vt_access_cargo', MaxOrders = 100,
        MaxQuantity = 20, SaleMultiplier = 0.5, SaleExcluded = {}, LargeAreaSize = 200, DeliveredHistorySeconds = 150 } },
    Language = { PointshopCannotBeUsed = 'Denied' }, IsRoundFinalizing = function() return false end,
    GetClientAccountKey = function(c) return c.Name end, GetText = function(key) return key end,
    FormatText = function(_, text) return text end,
    SendChatMessage = function(_, text) messages[#messages + 1] = text end,
    SendMessage = function(_, text) messages[#messages + 1] = text end, Error = function() end }
local ps = dofile(modpath .. '/Lua/pointshop.lua')
Traitormod.Pointshop = ps
ps.GetGuiProduct = function(_, category, product, id)
    return { Id = id, Name = product.Identifier, Price = product.Price, IconIdentifier = product.Identifier, Description = '', Category = category.Identifier }
end
LimbType, InvSlotType = { Torso = 1 }, { Any = 1 }
Entity = { Spawner = { AddItemToSpawnQueue = function(prefab, where, sub, condition, _, callback)
    if where == client.Character.Inventory then callback = _ condition = sub end
    queue[#queue + 1] = function()
        local obj = item(prefab.Identifier.Value, '', submarine)
        if where.X ~= nil then obj.WorldPosition = vector(where.X + submarine.Position.X, where.Y + submarine.Position.Y) end
        obj.Condition = condition
        obj.Components.PowerContainer = { Capacity = 10, Charge = 0 }
        obj.Components.ElectricalDischarger = { OutdoorsOnly = true }
        callback(obj)
        return obj
    end
end, AddEntityToRemoveQueue = function(obj) removals[#removals + 1] = obj end } }
Game, Level = { RoundStarted = true }, { Loaded = { EndOutpost = {} } }
local cargo = dofile(modpath .. '/Lua/features/cargo.lua')
cargo.Start()
local state, ship = cargo.State, cargo.State.Ship
assert(#state.Products == 3 and ship.Home == home.Components.DockingPort)
local snap = cargo.Snapshot(client)
assert(not snap.CanManage and snap.Products[1].Currency == 'кр' and snap.Ship.SlotsTotal == 3)
assert(cargo.Snapshot(manager).CanManage)
local function submit(id, count)
    return cargo.Submit(client, { Entries = { { Id = 'medical:' .. id, Quantity = count or 1 } }, Reason = 'Infirmary' })
end
assert(not submit(1, 0) and not submit(1, 1.5))
assert(not cargo.Submit(client, { Entries = { { Id = 'medical:1', Quantity = 1 }, { Id = 'bad', Quantity = 1 } }, Reason = 'test' }))
assert(#state.Orders == 0, 'partial invalid basket was accepted')
assert(submit(1) and state.Orders[1].Price == 300 and state.Budget == 10000 and state.Reserved == 0)
assert(not cargo.Decide(client, 'approve', 1), 'role/title bypassed cargo card')
state.Budget = 250
assert(not cargo.Decide(manager, 'approve', 1))
state.Budget = 500
assert(cargo.Decide(manager, 'approve', 1) and state.Reserved == 300 and state.Used['medical:1'] == 1)
assert(not cargo.Decide(manager, 'approve', 1), 'approval spent twice')
assert(submit(1) and not cargo.Decide(manager, 'approve', 2), 'overspent shared budget')
assert(cargo.Decide(manager, 'reject', 1) and state.Reserved == 0 and state.Used['medical:1'] == 0)
assert(cargo.Decide(manager, 'approve', 2))
port.Components.DockingPort.Docked = false
cargo.Think(0.5)
assert(state.Orders[2].Status == 'Outbound' and #queue == 0)
assert(not cargo.Decide(manager, 'reject', 2), 'changed active manifest')
port.Components.DockingPort.Docked = true
cargo.Think(0.5)
assert(state.Orders[2].Status == 'Accepted', 'aborted trip lost order')
port.Components.DockingPort.Docked = false
cargo.Think(0.5)
submarine.AtEndExit = true
local sale = item('bandage', '', submarine)
crate.OwnInventory.Slots[0], sale.ParentInventory = sale, crate.OwnInventory
cargo.Think(0.5)
assert(#removals == 1 and removals[1] == sale and #queue == 0, 'loaded before sale removal')
sale.Removed, crate.OwnInventory.Slots[0] = true, nil
cargo.Think(0.5)
assert(state.Budget == 550 and #queue == 2 and state.Reserved == 300)
for _, callback in ipairs(queue) do local spawned = callback() assert(spawned.Components.PowerContainer.Charge == 100 and not spawned.Components.ElectricalDischarger.OutdoorsOnly) end
queue = {}
assert(state.Budget == 250 and state.Reserved == 0 and state.Orders[2].Status == 'Loaded')
cargo.Think(0.5) cargo.Think(0.5)
assert(ship.State == 'Returning' and ship.LastSale == 50 and state.Budget == 250, 'duplicate sale or load')
submarine.AtEndExit = false port.Components.DockingPort.Docked = true
cargo.Think(0.5)
assert(state.Orders[2].Status == 'Delivered' and ship.State == 'Home')
state.Budget = 1000
assert(submit(1) and cargo.Decide(manager, 'approve', 3))
port.Components.DockingPort.Docked = false cargo.Think(0.5)
-- Goods without a native price are retained and occupy real capacity.
for obj in crate.OwnInventory.AllItems do obj.Prefab = { Identifier = { Value = 'unpriced' } } end
crate.OwnInventory.Slots[2] = item('bandage', '', submarine)
crate.OwnInventory.Slots[2].Prefab = { Identifier = { Value = 'unpriced' } }
submarine.AtEndExit = true cargo.Think(0.5)
assert(state.Orders[3].Status == 'Accepted' and state.Reserved == 300 and #queue == 0, 'partial oversized order loaded')
cargo.Think(0.5)
assert(ship.State == 'Returning')
submarine.AtEndExit = false port.Components.DockingPort.Docked = true cargo.Think(0.5)
assert(cargo.Decide(manager, 'reject', 3) and state.Reserved == 0)
assert(submit(3) and cargo.Decide(manager, 'approve', 4))
port.Components.DockingPort.Docked = false cargo.Think(0.5)
submarine.AtEndExit = true cargo.Think(0.5)
assert(#queue == 1)
local large = queue[1]() queue = {}
assert(large.Prefab == prefabs.vt_cargo_package and state.Orders[4].Status == 'Loaded' and #select(2, cargo.Capacity()) == 0, 'large package not delivered')
local saleGoods = cargo.SaleGoods()
assert(#saleGoods == 1 and saleGoods[1].Item == large, 'sold fixed shuttle equipment or unpriced goods')
client.Character.SelectedItem = large
client.Character.Submarine = submarine
assert(not cargo.Unpack(client, large), 'unpacked permanent equipment on shuttle')
client.Character.Submarine = main
assert(cargo.Unpack(client, large) and not cargo.Unpack(client, large), 'package unpack was not single-use')
local unpacked = queue[1]() queue = {}
assert(unpacked.Prefab == prefabs.lamp and unpacked.Lit and cargo.State.Packages[large] == nil, 'original installation action lost during unpack')
client.Character.SelectedItem = console
cargo.Open(manager, console, true)
manager.Character.SelectedItem = nil
assert(not cargo.Action(manager, console, 'reject', { OrderId = 4 }), 'distant/unselected write allowed')
manager.Character.SelectedItem = console
cargo.Open(client, console, false)
cargo.Action(client, console, 'product', { Id = 'medical:2' })
cargo.Action(client, console, 'close', {})
local values = { '1', 'native reason', false, true }
local index = 0
local params = { c = client, msg = { ReadString = function() index = index + 1 return values[index] end, ReadBoolean = function() index = index + 1 return values[index] end } }
patches['Traitormod.Cargo.Native']({ Item = console }, params)
assert(params.PreventExecution and state.Orders[5].Product == 'medical:2', 'native terminal/menu submit failed')
-- Ordinary pointshop still uses its original inventory destination and spawn effects.
local delivered
ps.SpawnItem(client, { Identifier = 'batterycell', Condition = 9 }, function(obj) delivered = obj end)
queue[1]()
assert(delivered.Condition == 9 and delivered.Components.PowerContainer.Capacity == 100)
-- Lost/sold sibling packages must not strand the original installation callback.
local firstPackage, lostPackage = item('vt_cargo_package', '', submarine), item('vt_cargo_package', '', submarine)
local lamp = item('lamp', '', main)
local batch = { Items = { firstPackage, lostPackage }, Waiting = 2, Manager = client, Price = 400,
    Product = { Action = function(_, _, items) assert(#items == 1 and items[1] == lamp) lamp.Lit = true end } }
state.Packages[firstPackage] = { Batch = batch, Index = 1 }
state.Packages[lostPackage] = { Batch = batch, Index = 2 }
cargo.ResolvePackage(firstPackage, lamp, client)
lostPackage.Removed = true
cargo.Think(0.5)
assert(lamp.Lit and batch.Waiting == 0, 'lost sibling stranded installation callback')
for _ = 1, 120 do
    assert(submit(2))
    local order = state.Orders[#state.Orders]
    assert(cargo.Decide(manager, 'reject', order.Id))
end
assert(#state.Orders <= Traitormod.Config.Cargo.MaxOrders and state.NextOrderId == 125, 'terminal history disabled future requests or reused IDs')
assert(submit(2) and cargo.Decide(manager, 'approve', state.NextOrderId), 'order after pruned history could not be approved')
local deliveredId = state.NextOrderId + 1
state.Orders[#state.Orders + 1] = { Id = deliveredId, Status = 'Delivered', DeliveredAt = state.Time }
cargo.Think(149.5)
assert(cargo.FindOrder(deliveredId) ~= nil, 'delivered history expired prematurely')
cargo.Think(0.5)
assert(cargo.FindOrder(deliveredId) == nil, 'delivered history persisted beyond 150 seconds')
return 'PASS cargo: card authority, atomic cart, shared reservations/stock, real capacity, sale removal, physical arrival/return, large callback, native submit, original shop spawn'
