-- Throwing and placing any item (client half: Void traitor pack-1.15 Lua/client/throwing.lua). F starts winding up the
-- item in hand, or the one under the cursor in the inventory, and the left mouse button throws it; X reaches out with
-- the item in hand and the left mouse button lets it go where the hand is. Grenades and other items the game throws
-- itself keep its controls, but the longer the player aims before throwing, the farther they fly. The server times
-- every wind-up itself, aims along the cursor direction the game already syncs and checks every request; nearby
-- clients get a short start/stop message and animate the arms themselves.
local NET_REQUEST = "VoidTraitor_Throw"
local NET_STATE = "VoidTraitor_ThrowState"

local ACTION_THROW, ACTION_PLACE, ACTION_RELEASE, ACTION_CANCEL = 0, 1, 2, 3
local ACTION_AIM, ACTION_AIM_THROW, ACTION_AIM_END = 4, 5, 6
-- one item per hand
local MAX_ITEMS = 2

local COOLDOWN = 0.4
-- the wind-up, the speed and the mass and arm penalties must match the trajectory the client draws
local CHARGE_TIME = 1
-- m/s of a light item at full wind-up: the speed the game gives a grenade (ThrowForce 3.5, impulse x3 in Throwable)
local MAX_SPEED = 10.5
-- share of the speed a throw gets without any wind-up
local MIN_CHARGE = 0.2
-- items up to the mass of a frag grenade fly at full speed; heavier ones lose speed with the square root of
-- their mass, so a crate (mass 7) still flies about half as fast
local LIGHT_MASS = 1.5
local MIN_MASS_FACTOR = 0.1
-- a fully injured throwing arm halves the speed; the game measures arm damage the same way for aim wobble
local ARM_DAMAGE_PENALTY = 0.5
-- NetConfig.MaxPhysicsBodyVelocity: the server reports an error for faster bodies when it syncs them
local MAX_BODY_VELOCITY = 64
-- Throwable.WaterDragCoefficient, used while a thrown item flies
local THROWN_WATER_DRAG = 0.5
-- slack for the hand position the client measured a moment ago, in world units
local REACH_TOLERANCE = 60
-- clients farther away than this cannot see the character and get no arm animation
local VIEW_DISTANCE = 3000
local FLIGHT_CHECK_MS = 100
local AIM_CHECK_MS = 100
-- after the click a grenade still finishes the game's swing before it leaves the hand
local GRENADE_SWING_TIME = 1
-- ServerLog.MessageType.ItemInteraction
local LOG_ITEM_INTERACTION = 1

local HANDS = {
    { Slot = InvSlotType.RightHand, Limb = LimbType.RightHand },
    { Slot = InvSlotType.LeftHand, Limb = LimbType.LeftHand },
}

-- client -> { Action, Character, Items, Start } between the key press and the click
local pending = {}
local lastStart = {}
-- thrown item -> the collisions it had before, restored once it comes to rest
local flying = {}
local watchingFlight = false
-- client -> { Character, Item, Throwable, BaseForce, Start, Charge, Thrown } while it aims a grenade
local aiming = {}
local watchingAim = false

local function canAct(character)
    return character ~= nil and not character.Removed and not character.IsDead and character.AllowInput
        and not character.IsKnockedDown and not character.LockHands and character.Inventory ~= nil
        and character.AnimController.GetLimb(LimbType.RightHand) ~= nil
end

local function ownsItem(character, item)
    return not item.Removed and item.body ~= nil and item.ParentInventory ~= nil and not item.ParentInventory.Locked
        and not item.IsStuckInHandSlot and item.GetRootInventoryOwner() == character
end

local function isHeld(character, item)
    for _, hand in ipairs(HANDS) do
        if character.Inventory.IsInLimbSlot(item, hand.Slot) then return true end
    end
    return false
end

local function armDamage(character, item)
    local health, anim = character.CharacterHealth, character.AnimController
    local damage, held = 0, false
    for _, hand in ipairs(HANDS) do
        if character.Inventory.IsInLimbSlot(item, hand.Slot) then
            held = true
            damage = damage + health.GetLimbDamage(anim.GetLimb(hand.Limb), AfflictionPrefab.DamageType)
        end
    end
    if not held then
        damage = health.GetLimbDamage(anim.GetLimb(LimbType.RightHand), AfflictionPrefab.DamageType)
    end
    return math.min(damage, 1)
end

local function windUp(charge)
    return MIN_CHARGE + (1 - MIN_CHARGE) * charge
end

local function throwSpeed(character, item, charge)
    local massFactor = math.max(MIN_MASS_FACTOR, math.min(1, math.sqrt(LIGHT_MASS / item.body.Mass)))
    return MAX_SPEED * windUp(charge) * massFactor * (1 - ARM_DAMAGE_PENALTY * armDamage(character, item))
end

local function sendState(character, action, items)
    for _, client in pairs(Client.ClientList) do
        local viewer = client.Character
        if viewer == nil or viewer.IsDead
            or Vector2.Distance(viewer.WorldPosition, character.WorldPosition) < VIEW_DISTANCE then
            local message = Networking.Start(NET_STATE)
            message.WriteUInt16(character.ID)
            message.WriteByte(action)
            message.WriteByte(#items)
            for _, item in ipairs(items) do message.WriteUInt16(item.ID) end
            Networking.Send(message, client.Connection)
        end
    end
end

local function watchFlight()
    for item, collidesWith in pairs(flying) do
        if item.Removed or item.body == nil then
            flying[item] = nil
        elseif item.ParentInventory ~= nil or item.body.LinearVelocity.LengthSquared() < 0.01 then
            item.body.CollidesWith = collidesWith
            item.body.FarseerBody.IsBullet = false
            item.ResetWaterDragCoefficient()
            flying[item] = nil
        end
    end
    if next(flying) == nil then
        watchingFlight = false
        return
    end
    Timer.Wait(watchFlight, FLIGHT_CHECK_MS)
end

-- Like Throwable: drop the item and push it; until it comes to rest it flies through platforms. It starts from the
-- shoulder along the cursor angle the client sends (measured from the shoulder), the same start and direction as the
-- line the client draws: the server's own arm is not in the wind-up pose.
local function throw(character, item, charge)
    local anim = character.AnimController
    local direction = character.CursorWorldPosition - anim.AimSourceWorldPos
    if direction.LengthSquared() < 1 then
        direction = Vector2(0, 1)
    else
        direction = Vector2.Normalize(direction)
    end
    local speed = throwSpeed(character, item, charge)

    item.Drop(character)
    if item.ParentInventory ~= nil then return false end
    item.SetTransform(anim.AimSourceSimPos, 0)
    flying[item] = item.body.CollidesWith
    item.body.CollidesWith = bit32.bor(Physics.CollisionWall, Physics.CollisionLevel)
    item.body.FarseerBody.IsBullet = true
    item.WaterDragCoefficient = THROWN_WATER_DRAG
    item.body.ApplyLinearImpulse(direction * (speed * item.body.Mass), MAX_BODY_VELOCITY)
    Game.Log(character.Name .. " threw " .. item.Name, LOG_ITEM_INTERACTION)

    if not watchingFlight then
        watchingFlight = true
        Timer.Wait(watchFlight, FLIGHT_CHECK_MS)
    end
    return true
end

-- Lets the item go where the client saw it in the hand, if that is within arm's reach and no wall is in between.
local function place(character, item, point)
    local anim = character.AnimController
    local torso = anim.GetLimb(LimbType.Torso) or anim.MainLimb
    -- the held item's centre may stick out past the hand by half its length
    local reach = ConvertUnits.ToDisplayUnits(anim.ArmLength) + math.max(item.Rect.Width, item.Rect.Height) / 2
        + REACH_TOLERANCE
    -- written as "not <=" so that a NaN from the client is refused too
    if not (Vector2.Distance(point, torso.WorldPosition) <= reach) then return false end
    local target = ConvertUnits.ToSimUnits(point)
    if character.Submarine ~= nil then target = target - character.Submarine.SimPosition end
    if Submarine.PickBody(character.SimPosition, target, nil, Physics.CollisionWall) ~= nil then return false end

    item.Drop(character)
    if item.ParentInventory ~= nil then return false end
    item.SetTransform(target, 0)
    return true
end

local function start(client, action, ids)
    local character = client.Character
    local now = Timer.GetTime()
    if not canAct(character) or now - (lastStart[client] or -COOLDOWN) < COOLDOWN then return end
    local items = {}
    for _, id in ipairs(ids) do
        local item = Entity.FindEntityByID(id)
        if item == nil or not LuaUserData.IsTargetType(item, "Barotrauma.Item") or not ownsItem(character, item)
            or item == items[1] then
            return
        end
        -- only a single item comes straight from the inventory; placing and two items need them in the hands
        if (action == ACTION_PLACE or #ids > 1) and not isHeld(character, item) then return end
        -- the game throws grenades itself; F leaves them to it
        if action == ACTION_THROW and item.GetComponentString("Throwable") ~= nil then return end
        items[#items + 1] = item
    end

    if pending[client] ~= nil then sendState(pending[client].Character, ACTION_CANCEL, {}) end
    lastStart[client] = now
    pending[client] = { Action = action, Character = character, Items = items, Start = now }
    sendState(character, action, items)
end

-- Throws every item of the action, or lets each go at the point the client saw it in the hand (points in item order).
local function release(client, state, points)
    local character = state.Character
    local done = {}
    if client.Character == character and canAct(character) then
        local charge = math.min(1, (Timer.GetTime() - state.Start) / CHARGE_TIME)
        for index, item in ipairs(state.Items) do
            if ownsItem(character, item) then
                if state.Action == ACTION_THROW then
                    if throw(character, item, charge) then done[#done + 1] = item end
                elseif isHeld(character, item) and place(character, item, points[index]) then
                    done[#done + 1] = item
                end
            end
        end
    end
    if #done == 0 then
        sendState(character, ACTION_CANCEL, {})
    else
        -- clients make thrown items fly through platforms too
        sendState(character, ACTION_RELEASE, state.Action == ACTION_THROW and done or {})
    end
end

local function endAim(client)
    local state = aiming[client]
    if not state.Item.Removed then state.Throwable.ThrowForce = state.BaseForce end
    aiming[client] = nil
end

-- The game throws a grenade with the force it finds when the swing ends, so while the player aims it follows the
-- wind-up so far, until the click fixes it; once the grenade has left the hand it gets its own force back. The client
-- reports the aim itself: the game's aim input can reach the server after this message.
local function watchAim()
    local now = Timer.GetTime()
    for client, state in pairs(aiming) do
        local character = state.Character
        if state.Item.Removed or character.Removed or not isHeld(character, state.Item)
            or (state.Charge ~= nil and now - state.Thrown > GRENADE_SWING_TIME) then
            endAim(client)
        elseif state.Charge == nil then
            state.Throwable.ThrowForce = state.BaseForce * windUp(math.min(1, (now - state.Start) / CHARGE_TIME))
        end
    end
    if next(aiming) == nil then
        watchingAim = false
        return
    end
    Timer.Wait(watchAim, AIM_CHECK_MS)
end

local function startAim(client, itemId)
    local character = client.Character
    local item = Entity.FindEntityByID(itemId)
    if not canAct(character) or item == nil or not LuaUserData.IsTargetType(item, "Barotrauma.Item")
        or item.Removed or not isHeld(character, item) then
        return
    end
    local throwable = item.GetComponentString("Throwable")
    if throwable == nil then return end
    if aiming[client] ~= nil then endAim(client) end
    aiming[client] = { Character = character, Item = item, Throwable = throwable, BaseForce = throwable.ThrowForce,
        Start = Timer.GetTime() }
    throwable.ThrowForce = throwable.ThrowForce * windUp(0)
    if not watchingAim then
        watchingAim = true
        Timer.Wait(watchAim, AIM_CHECK_MS)
    end
end

local function aimThrow(client)
    local state = aiming[client]
    if state == nil or state.Charge ~= nil then return end
    local now = Timer.GetTime()
    state.Charge = math.min(1, (now - state.Start) / CHARGE_TIME)
    state.Thrown = now
    state.Throwable.ThrowForce = state.BaseForce * windUp(state.Charge)
end

Networking.Receive(NET_REQUEST, function(message, client)
    if not Game.RoundStarted then return end
    local action = message.ReadByte()
    if action == ACTION_THROW or action == ACTION_PLACE then
        local count = message.ReadByte()
        if count < 1 or count > MAX_ITEMS then return end
        local ids = {}
        for index = 1, count do ids[index] = message.ReadUInt16() end
        start(client, action, ids)
        return
    elseif action == ACTION_AIM then
        startAim(client, message.ReadUInt16())
        return
    elseif action == ACTION_AIM_THROW then
        aimThrow(client)
        return
    elseif action == ACTION_AIM_END then
        if aiming[client] ~= nil and aiming[client].Charge == nil then endAim(client) end
        return
    end
    local state = pending[client]
    if state == nil then return end
    pending[client] = nil
    if action == ACTION_RELEASE then
        local points = {}
        if state.Action == ACTION_PLACE then
            for index = 1, #state.Items do points[index] = Vector2(message.ReadSingle(), message.ReadSingle()) end
        end
        release(client, state, points)
    else
        sendState(state.Character, ACTION_CANCEL, {})
    end
end)

Hook.Add("roundEnd", "Traitormod.Throwing.RoundEnd", function()
    pending = {}
    lastStart = {}
    flying = {}
    aiming = {}
end)

Hook.Add("client.disconnected", "Traitormod.Throwing.Disconnect", function(client)
    pending[client] = nil
    lastStart[client] = nil
    if aiming[client] ~= nil then endAim(client) end
end)
