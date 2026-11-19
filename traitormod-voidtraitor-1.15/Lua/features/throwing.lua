-- Throwing and placing any item (client half: Void traitor pack-1.15 Lua/client/throwing.lua). Holding F winds up and
-- releasing it throws the item in hand, or the one under the cursor in the inventory; holding X reaches out with the
-- item in hand and releasing it lets the item go where the hand is. The server times the wind-up itself, aims along
-- the cursor direction the game already syncs and checks every request; nearby clients get a short start/stop message
-- and animate the arms themselves.
local NET_REQUEST = "VoidTraitor_Throw"
local NET_STATE = "VoidTraitor_ThrowState"

local ACTION_THROW, ACTION_PLACE, ACTION_RELEASE, ACTION_CANCEL = 0, 1, 2, 3

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
-- ServerLog.MessageType.ItemInteraction
local LOG_ITEM_INTERACTION = 1

local HANDS = {
    { Slot = InvSlotType.RightHand, Limb = LimbType.RightHand },
    { Slot = InvSlotType.LeftHand, Limb = LimbType.LeftHand },
}

-- client -> { Action, Character, Item, Start } between the key press and its release
local pending = {}
local lastStart = {}
-- thrown item -> the collisions it had before, restored once it comes to rest
local flying = {}
local watchingFlight = false

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

local function throwSpeed(character, item, charge)
    local massFactor = math.max(MIN_MASS_FACTOR, math.min(1, math.sqrt(LIGHT_MASS / item.body.Mass)))
    return MAX_SPEED * (MIN_CHARGE + (1 - MIN_CHARGE) * charge) * massFactor
        * (1 - ARM_DAMAGE_PENALTY * armDamage(character, item))
end

local function sendState(character, action, itemId)
    for _, client in pairs(Client.ClientList) do
        local viewer = client.Character
        if viewer == nil or viewer.IsDead
            or Vector2.Distance(viewer.WorldPosition, character.WorldPosition) < VIEW_DISTANCE then
            local message = Networking.Start(NET_STATE)
            message.WriteUInt16(character.ID)
            message.WriteByte(action)
            message.WriteUInt16(itemId)
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

-- Like Throwable: drop the item, then push it from the hand; until it comes to rest it flies through platforms.
local function throw(character, item, charge)
    local direction = character.CursorWorldPosition - character.WorldPosition
    if direction.LengthSquared() < 1 then
        direction = Vector2(0, 1)
    else
        direction = Vector2.Normalize(direction)
    end
    local speed = throwSpeed(character, item, charge)
    local hand = character.AnimController.GetLimb(LimbType.RightHand).SimPosition

    item.Drop(character)
    if item.ParentInventory ~= nil then return false end
    item.SetTransform(hand, 0)
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

local function start(client, action, itemId)
    local character = client.Character
    local now = Timer.GetTime()
    if not canAct(character) or now - (lastStart[client] or -COOLDOWN) < COOLDOWN then return end
    local item = Entity.FindEntityByID(itemId)
    if item == nil or not LuaUserData.IsTargetType(item, "Barotrauma.Item") or not ownsItem(character, item) then return end
    if action == ACTION_PLACE and not isHeld(character, item) then return end

    if pending[client] ~= nil then sendState(pending[client].Character, ACTION_CANCEL, 0) end
    lastStart[client] = now
    pending[client] = { Action = action, Character = character, Item = item, Start = now }
    sendState(character, action, item.ID)
end

local function release(client, state, point)
    local character, item = state.Character, state.Item
    local done = false
    if client.Character == character and canAct(character) and ownsItem(character, item) then
        if state.Action == ACTION_THROW then
            done = throw(character, item, math.min(1, (Timer.GetTime() - state.Start) / CHARGE_TIME))
        elseif isHeld(character, item) then
            done = place(character, item, point)
        end
    end
    if done and state.Action == ACTION_THROW then
        sendState(character, ACTION_RELEASE, item.ID)
    else
        sendState(character, done and ACTION_RELEASE or ACTION_CANCEL, 0)
    end
end

Networking.Receive(NET_REQUEST, function(message, client)
    if not Game.RoundStarted then return end
    local action = message.ReadByte()
    if action == ACTION_THROW or action == ACTION_PLACE then
        start(client, action, message.ReadUInt16())
        return
    end
    local state = pending[client]
    if state == nil then return end
    pending[client] = nil
    if action == ACTION_RELEASE then
        local point = state.Action == ACTION_PLACE and Vector2(message.ReadSingle(), message.ReadSingle()) or nil
        release(client, state, point)
    else
        sendState(state.Character, ACTION_CANCEL, 0)
    end
end)

Hook.Add("roundEnd", "Traitormod.Throwing.RoundEnd", function()
    pending = {}
    lastStart = {}
    flying = {}
end)

Hook.Add("client.disconnected", "Traitormod.Throwing.Disconnect", function(client)
    pending[client] = nil
    lastStart[client] = nil
end)
