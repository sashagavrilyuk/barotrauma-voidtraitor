-- The power controller (Void traitor pack items/powercontroller.xml) is a power distributor with a power switch. Switched
-- off it passes no power, whatever its supply ratios are, and the ratios stay as players set them.
-- Every machine simulates power itself, so the server and each client switch the box off the same way: the distributor
-- counts as broken and may not transfer power, and only allowing it to transfer again lets it clear that
-- (PowerTransfer.Update). The switch is the tickbox of the item's custom interface, which the game sends to every client,
-- also to those who join later; the client half is Void traitor pack Lua/client/station/powercontroller.lua.
local powerController = {}
Traitormod.PowerController = powerController
local config = Traitormod.Config.PowerController
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.Items.Components.PowerDistributor"), "isBroken")

-- set by the power grid check: nobody may switch controllers while it runs
powerController.Locked = false

local function switchOf(item)
    return item.GetComponentString("CustomInterface").customInterfaceElementList[1]
end

function powerController.IsOn(item)
    return switchOf(item).State
end

local function applySwitch(item, on)
    local distributor = item.GetComponentString("PowerDistributor")
    if on then
        distributor.CanTransfer = true
    else
        distributor.isBroken = true
        distributor.CanTransfer = false
    end
    -- the first two lights are the status strip; the game sends their state to the clients by itself
    local strip = 0
    for component in item.Components do
        if strip < 2 and LuaUserData.IsTargetType(component, "Barotrauma.Items.Components.LightComponent") then
            strip = strip + 1
            component.IsOn = (strip == 1) == on
        end
    end
end

function powerController.SetOn(item, on)
    local interface = item.GetComponentString("CustomInterface")
    interface.customInterfaceElementList[1].State = on
    item.CreateServerEvent(interface, interface)
    applySwitch(item, on)
end

-- the station's controllers, optionally only those that are on
function powerController.Find(onlyOn)
    local controllers = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("vt_powercontroller") and (not onlyOn or powerController.IsOn(item)) then
            table.insert(controllers, item)
        end
    end
    return controllers
end

local function hasAccess(character)
    for slot = 0, character.Inventory.Capacity - 1 do
        local card = character.Inventory.GetItemAt(slot)
        if card ~= nil and card.GetComponentString("IdCard") ~= nil and card.HasTag(config.AccessTag) then return true end
    end
    return false
end

Hook.Patch("Traitormod.PowerController.Switch", "Barotrauma.Items.Components.CustomInterface", "ServerEventRead", function (instance, parameters)
    local item = instance.Item
    if not item.HasTag("vt_powercontroller") then return end
    local wanted = parameters["msg"].ReadBoolean()
    parameters.PreventExecution = true

    local client = parameters["c"]
    local character = client.Character
    if wanted == powerController.IsOn(item) or character == nil or character.IsDead or character.IsIncapacitated
        or not item.CanClientAccess(client) or powerController.Locked or not hasAccess(character) then
        -- the client already shows its own click: send everyone the real state back
        item.CreateServerEvent(instance, instance)
        return
    end
    powerController.SetOn(item, wanted)
end, Hook.HookMethodType.Before)

-- While a player has a controller's panel open, their client asks every second why they may not use its switch; an
-- empty reason means they may. The client greys the switch out and shows the reason on hover.
local answeredAt = {}
Networking.Receive("VoidTraitor_PowerControllerOpen", function (message, client)
    local item, now = Entity.FindEntityByID(message.ReadUInt16()), Timer.GetTime()
    if client.Character == nil or now - (answeredAt[client.SessionId] or -1) < 0.5 or item == nil
        or not LuaUserData.IsTargetType(item, "Barotrauma.Item") or not item.HasTag("vt_powercontroller")
        or not item.CanClientAccess(client) then return end
    answeredAt[client.SessionId] = now

    local reason = ""
    if powerController.Locked then
        reason = Traitormod.GetText("PowerControllerLocked")
    elseif not hasAccess(client.Character) then
        reason = Traitormod.GetText("PowerControllerNoAccess")
    end
    local reply = Networking.Start("VoidTraitor_PowerControllerSnapshot")
    reply.WriteString(reason)
    Networking.Send(reply, client.Connection)
end)

Hook.Add("roundEnd", "Traitormod.PowerController.End", function () powerController.Locked = false end)

return powerController
