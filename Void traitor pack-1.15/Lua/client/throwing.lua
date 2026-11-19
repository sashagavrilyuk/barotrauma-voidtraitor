if SERVER then return end

-- Client half of throwing and placing (traitormod Lua/features/throwing.lua). F starts winding up the items in the
-- hands, or the one under the cursor in the inventory, and the left mouse button throws them; X reaches out with the
-- items in the hands and the left mouse button lets them go where they are. F, X or the right mouse button cancels.
-- Grenades and other items the game throws itself keep its controls, but the longer the player aims before throwing,
-- the farther they fly. The server decides what happens; this file sends the keys, draws the own trajectories and moves
-- the arms of every nearby character the server reports.
local NET_REQUEST = "VoidTraitor_Throw"
local NET_STATE = "VoidTraitor_ThrowState"
local THINK_HOOK = "VoidTraitor.Throwing"
local PATCH_ID = "VoidTraitor.Throwing.Draw"
local POSE_PATCH_ID = "VoidTraitor.Throwing.Pose"
local INPUT_PATCH_ID = "VoidTraitor.Throwing.Input"

local ACTION_THROW, ACTION_PLACE, ACTION_RELEASE, ACTION_CANCEL = 0, 1, 2, 3
local ACTION_AIM, ACTION_AIM_THROW, ACTION_AIM_END = 4, 5, 6
local THROW_KEY, PLACE_KEY = Keys.F, Keys.X

-- the cooldown, the wind-up, the speed and the mass and arm penalties must match the server
local COOLDOWN = 0.4
local CHARGE_TIME = 1
local MAX_SPEED = 10.5
local MIN_CHARGE = 0.2
local LIGHT_MASS = 1.5
local MIN_MASS_FACTOR = 0.1
local ARM_DAMAGE_PENALTY = 0.5

-- the arm swings the item around the shoulder as in the game's grenade throw: from pointing down to straight up while
-- winding up, then forward on release
local WINDUP_START_ANGLE = -math.pi / 2
local WINDUP_END_ANGLE = math.pi / 2
local SWING_TIME = 0.2
local SWING_END_ANGLE = math.rad(-20)
-- where the hand holds the item relative to the shoulder, in sim units: Throwable's default aim position
local HOLD_OFFSET = Vector2(0.45, 0.1)
-- the arm speed limit the game's hold pose uses
local MAX_ARM_SPIN = 15
-- a thrown item counts as landed once it is this slow, as in the server's check
local REST_SPEED_SQUARED = 0.01
-- the drop reaches this client separately from the throw message: wait a moment before checking whether it is held
local FLIGHT_MIN_TIME = 0.3
-- after the click a grenade still finishes the game's swing before it leaves the hand
local GRENADE_SWING_TIME = 1
-- Throwable: the impulse is the throw force times 3 per unit of mass, and up to 70% weaker when aiming down
local GRENADE_IMPULSE = 3
local GRENADE_DOWN_PENALTY = 0.7
-- the server rebuilds a client's cursor this far from the shoulder along the aim angle it gets (CharacterNetworking)
local SYNCED_CURSOR_DISTANCE = 500
local TRAJECTORY_STEP = 0.05
local TRAJECTORY_TIME = 2.5
local GRAVITY = -9.82
local TRAJECTORY_COLOR = Color(255, 255, 255, 150)
local LANDING_SIZE = 8

local HANDS = {
    { Slot = InvSlotType.RightHand, Limb = LimbType.RightHand },
    { Slot = InvSlotType.LeftHand, Limb = LimbType.LeftHand },
}

local inventory = LuaUserData.CreateStatic("Barotrauma.Inventory")
-- each component type has its own Lua descriptor, so the field is opened on both types that hold items this way
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.Items.Components.Holdable"), "scaledHandlePos")
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.Items.Components.MeleeWeapon"), "handlePos")
local zero = Vector2(0, 0)
local flightCollisions = bit32.bor(Physics.CollisionWall, Physics.CollisionLevel)

-- character -> { Action, Items, Start, Charge, Swing } for every character whose arms move, the own one included
local posers = {}
-- the own action between the key press and the click
local own = nil
local lastStart = -COOLDOWN
-- the click that threw or placed keeps away from the game until the button is released
local holdingClick = false
-- the own grenade while aiming: { Item, Throwable, BaseForce, Start, Charge, Thrown }; Charge is fixed by the click
local aim = nil
-- thrown item -> { CollidesWith, Since }
local flying = {}

local function canAct(character)
    return character ~= nil and not character.Removed and not character.IsDead and character.AllowInput
        and not character.IsKnockedDown and not character.LockHands and character.Inventory ~= nil
        and character.AnimController.GetLimb(LimbType.RightHand) ~= nil
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

-- The aim as the server knows it: the game sends only the cursor's angle from the shoulder (Character.AimRefPosition).
local function aimDirection(character)
    local direction = character.CursorWorldPosition - character.AnimController.AimSourceWorldPos
    if direction.LengthSquared() < 1 then return Vector2(0, 1) end
    return Vector2.Normalize(direction)
end

-- The speed the game's own throw gives a grenade with this force: from the body's centre towards the cursor the server
-- rebuilt from the aim angle, weaker when aiming down (Throwable.Update).
local function grenadeVelocity(character, force)
    local cursor = character.AnimController.AimSourceWorldPos + aimDirection(character) * SYNCED_CURSOR_DISTANCE
    local direction = Vector2.Normalize(cursor - character.WorldPosition)
    if direction.Y < 0 then force = force * (1 + direction.Y * GRENADE_DOWN_PENALTY) end
    return direction * (force * GRENADE_IMPULSE)
end

-- Where the game's swing lets a grenade go: its aim position in front of the shoulder.
local function grenadeStart(character, throwable)
    local anim = character.AnimController
    return anim.AimSourceWorldPos + Vector2(anim.Dir * throwable.AimPos.X, throwable.AimPos.Y)
end

local function chargeOf(state, now)
    return math.min(1, (now - state.Start) / CHARGE_TIME)
end

local function send(action, item)
    local message = Networking.Start(NET_REQUEST)
    message.WriteByte(action)
    if item ~= nil then message.WriteUInt16(item.ID) end
    Networking.Send(message)
end

local function sendStart(action, items)
    local message = Networking.Start(NET_REQUEST)
    message.WriteByte(action)
    message.WriteByte(#items)
    for _, item in ipairs(items) do message.WriteUInt16(item.ID) end
    Networking.Send(message)
end

-- A placement sends where each item was, in the order the start named them.
local function sendRelease(points)
    local message = Networking.Start(NET_REQUEST)
    message.WriteByte(ACTION_RELEASE)
    for _, point in ipairs(points) do
        message.WriteSingle(point.X)
        message.WriteSingle(point.Y)
    end
    Networking.Send(message)
end

local function windUpAngle(charge)
    return WINDUP_START_ANGLE + (WINDUP_END_ANGLE - WINDUP_START_ANGLE) * charge
end

-- The arm angle from facing forward: towards the cursor when placing, along the wind-up and the swing when throwing.
local function poseAngle(character, state, now)
    if state.Action == ACTION_PLACE then
        local direction = aimDirection(character)
        local angle = math.atan2(direction.Y, direction.X * character.AnimController.Dir)
        return math.max(WINDUP_START_ANGLE, math.min(WINDUP_END_ANGLE, angle))
    end
    if state.Swing ~= nil then
        local from = windUpAngle(state.Charge)
        return from + (SWING_END_ANGLE - from) * math.min(1, (now - state.Swing) / SWING_TIME)
    end
    return windUpAngle(chargeOf(state, now))
end

local function holdableOf(item)
    for component in item.Components do
        if LuaUserData.IsTargetType(component, "Barotrauma.Items.Components.Holdable") then return component end
    end
    return nil
end

-- A held item is posed through the game's own hold pose, as a grenade is while it is thrown: its hands stay on its
-- handles. An empty hand (an item thrown from the inventory) is moved along the same arc.
local function pose(character, state, angle, deltaTime)
    local anim = character.AnimController
    for _, item in ipairs(state.Items) do
        local holdable = not item.Removed and isHeld(character, item) and holdableOf(item) or nil
        -- an item that follows the hand's rotation gets no arm pose from the game, so its hand is moved below
        if holdable ~= nil and not holdable.UseHandRotationForHoldAngle then
            -- a melee weapon holds the item by its unscaled handles and never fills the scaled ones
            -- (MeleeWeapon.Update)
            local handles = LuaUserData.IsTargetType(holdable, "Barotrauma.Items.Components.MeleeWeapon")
                and holdable.handlePos or holdable.scaledHandlePos
            anim.HoldItem(deltaTime, item, handles, HOLD_OFFSET, false, angle)
        else
            local leftOnly = character.Inventory.IsInLimbSlot(item, InvSlotType.LeftHand)
                and not character.Inventory.IsInLimbSlot(item, InvSlotType.RightHand)
            local params = anim.CurrentAnimationParams
            anim.HandIK(anim.GetLimb(leftOnly and LimbType.LeftHand or LimbType.RightHand),
                anim.AimSourceSimPos + Vector2(anim.Dir * math.cos(angle), math.sin(angle)) * anim.ArmLength,
                params.ArmIKStrength, params.HandIKStrength, MAX_ARM_SPIN)
        end
    end
end

-- The items in the hands; one held in both hands counts once.
local function heldItems(character)
    local items = {}
    for _, hand in ipairs(HANDS) do
        local item = character.Inventory.GetItemInLimbSlot(hand.Slot)
        if item ~= nil and item ~= items[1] then items[#items + 1] = item end
    end
    return items
end

local function hoveredItem(character)
    local slot = inventory.SelectedSlot
    local item = slot ~= nil and slot.Item or nil
    if item ~= nil and item.GetRootInventoryOwner() == character then return item end
    return nil
end

local function heldThrowable(character)
    for _, hand in ipairs(HANDS) do
        local item = character.Inventory.GetItemInLimbSlot(hand.Slot)
        local throwable = item ~= nil and item.GetComponentString("Throwable") or nil
        if throwable ~= nil then return item, throwable end
    end
    return nil, nil
end

local function begin(character, action, candidates, now)
    local items = {}
    for _, item in ipairs(candidates) do
        -- the game throws grenades itself; F leaves them to it
        if item.body ~= nil and not (action == ACTION_THROW and item.GetComponentString("Throwable") ~= nil) then
            items[#items + 1] = item
        end
    end
    if #items == 0 then return end
    lastStart = now
    own = { Action = action, Items = items, Start = now, Character = character }
    posers[character] = own
    sendStart(action, items)
end

local function finish(character, now)
    if own.Action == ACTION_THROW then
        own.Charge = chargeOf(own, now)
        own.Swing = now
        sendRelease({})
    else
        posers[character] = nil
        local points = {}
        for index, item in ipairs(own.Items) do points[index] = item.WorldPosition end
        sendRelease(points)
    end
    own = nil
    holdingClick = true
end

local function cancel(character)
    posers[character] = nil
    own = nil
    send(ACTION_CANCEL)
end

local function lostItem(character, items)
    for _, item in ipairs(items) do
        if item.Removed or item.GetRootInventoryOwner() ~= character then return true end
    end
    return false
end

local function updateKeys(character, now)
    local typing = GUI.KeyboardDispatcher.Subscriber ~= nil
    if own == nil then
        if typing or not canAct(character) or now - lastStart < COOLDOWN then return end
        if PlayerInput.KeyHit(THROW_KEY) then
            local hovered = hoveredItem(character)
            begin(character, ACTION_THROW, hovered ~= nil and { hovered } or heldItems(character), now)
        elseif PlayerInput.KeyHit(PLACE_KEY) then
            begin(character, ACTION_PLACE, heldItems(character), now)
        end
        return
    end
    if not canAct(character) or lostItem(character, own.Items) or PlayerInput.SecondaryMouseButtonDown()
        or (not typing and (PlayerInput.KeyHit(THROW_KEY) or PlayerInput.KeyHit(PLACE_KEY))) then
        cancel(character)
    elseif PlayerInput.PrimaryMouseButtonDown() and GUI.MouseOn == nil and not inventory.IsMouseOnInventory then
        finish(character, now)
    end
end

local function updateFlying(now)
    for item, flight in pairs(flying) do
        if item.Removed or item.body == nil then
            flying[item] = nil
        elseif now - flight.Since > FLIGHT_MIN_TIME
            and (item.ParentInventory ~= nil or item.body.LinearVelocity.LengthSquared() < REST_SPEED_SQUARED) then
            item.body.CollidesWith = flight.CollidesWith
            item.body.FarseerBody.IsBullet = false
            flying[item] = nil
        end
    end
end

local function endAim()
    if not aim.Item.Removed then aim.Throwable.ThrowForce = aim.BaseForce end
    aim = nil
end

-- While the player aims a grenade, the game's own throw gets the force of the wind-up so far and the click fixes it.
-- Setting it here keeps the own client's copy of the throw in step with the server.
local function updateAim(character, now)
    if aim == nil then
        if not character.IsKeyDown(InputType.Aim) or not character.CanAim then return end
        local item, throwable = heldThrowable(character)
        if item == nil then return end
        aim = { Item = item, Throwable = throwable, BaseForce = throwable.ThrowForce, Start = now }
        send(ACTION_AIM, item)
        return
    end
    if aim.Item.Removed or not isHeld(character, aim.Item) then
        endAim()
    elseif aim.Charge ~= nil then
        if now - aim.Thrown > GRENADE_SWING_TIME then endAim() end
    elseif not character.IsKeyDown(InputType.Aim) then
        endAim()
        send(ACTION_AIM_END)
    else
        local charge = chargeOf(aim, now)
        if character.IsKeyDown(InputType.Shoot) then
            aim.Charge, aim.Thrown = charge, now
            send(ACTION_AIM_THROW)
        end
        aim.Throwable.ThrowForce = aim.BaseForce * windUp(charge)
    end
end

local function think()
    local now = Timer.GetTime()
    local character = Character.Controlled
    if own ~= nil and character ~= own.Character then cancel(own.Character) end
    if holdingClick and not PlayerInput.PrimaryMouseButtonHeld() then holdingClick = false end
    if character ~= nil then
        updateKeys(character, now)
        updateAim(character, now)
    elseif aim ~= nil then
        endAim()
    end
    if next(flying) ~= nil then updateFlying(now) end
end

-- While a throw or a placement waits for the click, the click must not shoot, use or select anything too. The game
-- resets the same inputs itself while the cursor is over the inventory (Character.ControlLocalPlayer).
Hook.Patch(INPUT_PATCH_ID, "Barotrauma.Character", "ControlLocalPlayer", function(instance)
    if own == nil and not holdingClick then return end
    instance.ClearInput(InputType.Shoot)
    instance.ClearInput(InputType.Use)
    instance.ClearInput(InputType.Select)
end, Hook.HookMethodType.After)

-- Items queue their hold pose while they update and the game applies it after the physics step; queuing the throw
-- pose here, once every item has updated, replaces theirs for the characters that are throwing or placing.
Hook.Patch(POSE_PATCH_ID, "Barotrauma.Character", "UpdateAnimAll", function(instance, ptable)
    if next(posers) == nil then return end
    local now = Timer.GetTime()
    for character, state in pairs(posers) do
        if character.Removed or character.IsDead or (state.Swing ~= nil and now - state.Swing > SWING_TIME) then
            posers[character] = nil
        else
            pose(character, state, poseAngle(character, state, now), ptable["deltaTime"])
        end
    end
end, Hook.HookMethodType.After)

-- The flight every throw takes: from the start along the velocity (in m/s), through platforms, until the first wall.
local function drawTrajectory(spriteBatch, cam, character, start, velocity)
    velocity = ConvertUnits.ToDisplayUnits(velocity)
    local gravity = ConvertUnits.ToDisplayUnits(GRAVITY)
    local offset = character.Submarine ~= nil and character.Submarine.SimPosition or zero
    local previous = start
    for step = 1, math.floor(TRAJECTORY_TIME / TRAJECTORY_STEP) do
        local t = step * TRAJECTORY_STEP
        local point = start + velocity * t + Vector2(0, gravity * t * t / 2)
        if Submarine.PickBody(ConvertUnits.ToSimUnits(previous) - offset, ConvertUnits.ToSimUnits(point) - offset,
            nil, flightCollisions) ~= nil then
            point = ConvertUnits.ToDisplayUnits(Submarine.LastPickedPosition + offset)
            GUI.DrawLine(spriteBatch, cam.WorldToScreen(previous), cam.WorldToScreen(point), TRAJECTORY_COLOR, 0, 2)
            local landing = cam.WorldToScreen(point)
            GUI.DrawRectangle(spriteBatch, landing - Vector2(LANDING_SIZE / 2, LANDING_SIZE / 2),
                Vector2(LANDING_SIZE, LANDING_SIZE), TRAJECTORY_COLOR, true)
            return
        end
        GUI.DrawLine(spriteBatch, cam.WorldToScreen(previous), cam.WorldToScreen(point), TRAJECTORY_COLOR, 0, 2)
        previous = point
    end
end

-- An item thrown straight from the inventory is not in the hand, so it is drawn there while the arm winds up.
local function drawItemsInHand(spriteBatch, cam)
    for character, state in pairs(posers) do
        if state.Action == ACTION_THROW and state.Swing == nil then
            for _, item in ipairs(state.Items) do
                if item.Sprite ~= nil and not isHeld(character, item) then
                    local hand = character.AnimController.GetLimb(LimbType.RightHand)
                    item.Sprite.Draw(spriteBatch, cam.WorldToScreen(hand.DrawPosition), item.SpriteColor,
                        -hand.Rotation, item.Scale * cam.Zoom)
                end
            end
        end
    end
end

-- Runs before the HUD, so the drawing covers the world but not the interface. Thrown items start from the shoulder,
-- where the server lets them go.
Hook.Patch(PATCH_ID, "Barotrauma.CharacterHUD", "Draw", function (instance, ptable)
    local aiming = aim ~= nil and aim.Charge == nil
    if next(posers) == nil and not aiming then return end
    local spriteBatch, cam, character = ptable["spriteBatch"], ptable["cam"], ptable["character"]
    drawItemsInHand(spriteBatch, cam)
    if own ~= nil and own.Action == ACTION_THROW and own.Character == character then
        local charge = chargeOf(own, Timer.GetTime())
        for _, item in ipairs(own.Items) do
            drawTrajectory(spriteBatch, cam, character, character.AnimController.AimSourceWorldPos,
                aimDirection(character) * throwSpeed(character, item, charge))
        end
    elseif aiming then
        drawTrajectory(spriteBatch, cam, character, grenadeStart(character, aim.Throwable),
            grenadeVelocity(character, aim.Throwable.ThrowForce))
    end
end, Hook.HookMethodType.Before)

Networking.Receive(NET_STATE, function(message)
    local character = Entity.FindEntityByID(message.ReadUInt16())
    local action = message.ReadByte()
    local items = {}
    for _ = 1, message.ReadByte() do
        local item = Entity.FindEntityByID(message.ReadUInt16())
        if item ~= nil then items[#items + 1] = item end
    end
    local now = Timer.GetTime()
    if action == ACTION_RELEASE then
        for _, item in ipairs(items) do
            if item.body ~= nil then
                flying[item] = { CollidesWith = item.body.CollidesWith, Since = now }
                item.body.CollidesWith = flightCollisions
                item.body.FarseerBody.IsBullet = true
            end
        end
    end
    if character == nil or character == Character.Controlled then return end
    if action == ACTION_THROW or action == ACTION_PLACE then
        if #items > 0 then posers[character] = { Action = action, Items = items, Start = now } end
    elseif action == ACTION_RELEASE and posers[character] ~= nil and posers[character].Action == ACTION_THROW then
        posers[character].Charge = chargeOf(posers[character], now)
        posers[character].Swing = now
    else
        posers[character] = nil
    end
end)

local function stop()
    Hook.Remove("think", THINK_HOOK)
    posers = {}
    own = nil
    holdingClick = false
    aim = nil
    flying = {}
end

Hook.Add("roundStart", THINK_HOOK, function()
    stop()
    Hook.Add("think", THINK_HOOK, think)
end)
Hook.Add("roundEnd", THINK_HOOK, stop)
if Game.RoundStarted then Hook.Add("think", THINK_HOOK, think) end
