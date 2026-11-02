if SERVER then return end

-- Client side of the admin ghost: the same movement and reach code as the server
-- (traitormod-voidtraitor-1.15: Lua/features/adminghost.lua), so prediction matches it.
-- Spectators and ghosts also see the ghosts that the vt_adminghost affliction hides.
local NET_PROBE = "VoidTraitor_AdminGhostProbe"
local NET_READY = "VoidTraitor_AdminGhostReady"
local NET_STATE = "VoidTraitor_AdminGhostState"
local NET_LIST = "VoidTraitor_AdminGhostList"
local NET_LIST_REQUEST = "VoidTraitor_AdminGhostListRequest"
local SHOW_ID = "VoidTraitor.AdminGhost.Show"
local PATCH_ID = "VoidTraitor.AdminGhost"
local REACH_ARGS = { "Barotrauma.Item", "out System.Single", "System.Boolean", "System.Boolean" }
local REACH_CHARACTER_ARGS = { "Barotrauma.Character", "System.Single", "System.Boolean", "System.Boolean" }
local UPDATE_ANIM_ARGS = { "System.Single" }
local UPDATE_RAGDOLL_ARGS = { "System.Single", "Barotrauma.Camera" }
local BODY_KINEMATIC = 1 -- FarseerPhysics.BodyType.Kinematic
local CURSOR_FOLLOW_MARGIN = 40 -- Character.cursorFollowMargin

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local direction = LuaUserData.CreateEnumTable("Barotrauma.Direction")
local ghostId, walkSpeed, runSpeed
local ghost
local patched = false
-- the character the server carries for this client's ghost
local carried
-- set while the ghost's focus search runs (see measureLimbDistance)
local searchingFocus = false
local cameraZoom, cameraTargetZoom
-- entity IDs of every ghost in the round
local listed = {}

-- levitatingCollider makes the ragdoll stand a character up on the floor or ragdoll it in the air;
-- prevCollisionCategory gives a carried character its collisions back
for _, animType in ipairs({ "Barotrauma.HumanoidAnimController", "Barotrauma.FishAnimController" }) do
    local descriptor = LuaUserData.RegisterType(animType)
    for _, field in ipairs({ "levitatingCollider", "prevCollisionCategory" }) do
        LuaUserData.MakeFieldAccessible(descriptor, field)
    end
end

local function release(target)
    if target == nil or target.Removed then return end
    for limb in target.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = false end
    target.AnimController.prevCollisionCategory = 0 -- FarseerPhysics.Dynamics.Category.None
end

-- The server carries the character; the client only lets its copy pass through walls so the server's position
-- updates can move it there. A character inspected with H is told apart by the open health window, because the
-- client also re-selects characters on its own when it syncs with the server.
local function updateCarried()
    local target = ghost.SelectedCharacter
    local window = CharacterHealth.OpenHealthWindow
    if (target ~= nil and target.Removed) or (window ~= nil and window.Character == target) then target = nil end
    if carried == target then return end
    release(carried)
    carried = target
    if target ~= nil then
        for limb in target.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end
    end
end

local function setVelocity()
    if ghost == nil or ghost.Removed then return end
    local x, y = 0, 0
    if ghost.IsKeyDown(InputType.Left) then x = x - 1 end
    if ghost.IsKeyDown(InputType.Right) then x = x + 1 end
    if ghost.IsKeyDown(InputType.Up) then y = y + 1 end
    if ghost.IsKeyDown(InputType.Down) then y = y - 1 end
    local velocity = Vector2.Zero
    if x ~= 0 or y ~= 0 then
        velocity = Vector2.Normalize(Vector2(x, y)) * (ghost.IsKeyDown(InputType.Run) and runSpeed or walkSpeed)
    end
    local anim = ghost.AnimController
    anim.Collider.BodyType = BODY_KINEMATIC
    anim.Collider.LinearVelocity = velocity
    anim.levitatingCollider = false
    anim.MainLimb.PullJointWorldAnchorB = anim.Collider.SimPosition
    anim.MainLimb.PullJointEnabled = true
    -- The game turns a character to the cursor only while it stands on the ground, so a flying ghost couldn't
    -- turn around to throw. The server takes the facing from this client.
    if not anim.OnGround and not anim.InWater and ghost.FollowCursor and not anim.IsUsingItem then
        local cursorOffset = ghost.CursorPosition.X - anim.Collider.Position.X
        if cursorOffset < -CURSOR_FOLLOW_MARGIN then
            anim.TargetDir = direction.Left
        elseif cursorOffset > CURSOR_FOLLOW_MARGIN then
            anim.TargetDir = direction.Right
        end
    end
    updateCarried()
end

local function disableCollisions(anim)
    if anim.Collider.CollidesWith == 0 then return end
    anim.Collider.CollidesWith = 0
    -- the same limbs the game updates in Ragdoll.UpdateCollisionCategories
    for limb in anim.Limbs do
        if not limb.IgnoreCollisions and not limb.IsSevered then limb.body.CollidesWith = 0 end
    end
end

local function clearCollisions()
    if ghost == nil or ghost.Removed then return end
    disableCollisions(ghost.AnimController)
    if carried ~= nil and not carried.Removed then disableCollisions(carried.AnimController) end
end

local function reach(instance, ptable)
    if instance ~= ghost then return end
    ptable.PreventExecution = true
    local item = ptable["item"]
    local allowHidden = ptable["allowHiddenItems"]
    -- skip ladders: pressing up or down would grab the first one in reach and the ghost would start climbing
    if item.GetComponentString("Ladder") ~= nil then return false end
    if not instance.CanInteract or (item.IsHidden and not allowHidden) or not item.IsInteractable(instance, allowHidden) then return false end
    if item.ParentInventory ~= nil then return instance.CanAccessInventory(item.ParentInventory) end
    return item.InteractDistance > 0 or #item.Prefab.Triggers > 0
end

local function reachCharacter(instance, ptable)
    if instance ~= ghost then return end
    ptable.PreventExecution = true
    local c = ptable["c"]
    return c ~= instance and c.Enabled and c.CanBeSelected and c.InvisibleTimer <= 0
end

-- The focus search compares the cursor (relative to the ghost's submarine) with limbs relative to each character's
-- own submarine, so a ghost outside that submarine could not focus on the character. While the ghost searches, give
-- each character the cursor in its own coordinates. Otherwise keep a selected character at any distance.
local function measureLimbDistance(instance, ptable)
    if ghost == nil then return end
    if searchingFocus then
        local cursor = ghost.CursorWorldPosition
        if instance.Submarine ~= nil then cursor = cursor - instance.Submarine.Position end
        ptable["simPos"] = cursor / 100
    elseif instance.SelectedBy == ghost then
        ptable.PreventExecution = true
        return 0
    end
end

local function startFocusSearch(instance)
    searchingFocus = instance == ghost
end

local function endFocusSearch()
    searchingFocus = false
end

-- Focusing on a character needs line of sight; the ghost sees through walls like a spectator,
-- which also shows the names of characters behind walls.
local function seeThroughWalls(instance, ptable)
    if instance ~= ghost then return end
    ptable.PreventExecution = true
    return true
end

local function canBeDragged(instance, ptable)
    if ptable["character"] ~= ghost then return end
    ptable.PreventExecution = true
    return instance.IsDraggable
end

local function inventoryAccessible(instance, ptable)
    if ptable["character"] ~= ghost then return end
    ptable.PreventExecution = true
    return not instance.Removed and instance.Inventory ~= nil
end

-- the server carries what the ghost grabbed instead of dragging it
local function skipDrag(instance, ptable)
    if instance.Character == ghost then ptable.PreventExecution = true end
end

-- A camera that follows a character zooms by cursor distance; the ghost's camera zooms with the mouse wheel
-- like the free camera. With Alt held the wheel is left to items that use it (e.g. sprayer spray size).
local function zoomCamera(instance, ptable)
    if ghost == nil or instance ~= gameMain.GameScreen.Cam then return end
    if ptable["allowZoom"] and not PlayerInput.KeyDown(Keys.LeftAlt) and not PlayerInput.KeyDown(Keys.RightAlt) then
        cameraTargetZoom = math.max(instance.MinZoom, math.min(instance.MaxZoom,
            cameraTargetZoom + PlayerInput.ScrollWheelSpeed / 1000 * cameraZoom))
    end
    cameraZoom = cameraZoom + (cameraTargetZoom - cameraZoom) * math.min(ptable["deltaTime"] * 10, 1)
    instance.Zoom = cameraZoom
end

-- Added on first use and never removed: Hook.RemovePatch can't remove them because LuaCs uses the class name
-- as the patch id. Without a ghost they return right away.
local function ensurePatches()
    if patched then return end
    patched = true
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanInteractWith", REACH_ARGS, reach, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "UpdateAnimAll", UPDATE_ANIM_ARGS, setVelocity, Hook.HookMethodType.After)
    Hook.Patch(PATCH_ID, "Barotrauma.Ragdoll", "UpdateAll", UPDATE_RAGDOLL_ARGS, clearCollisions, Hook.HookMethodType.After)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanBeDraggedBy", canBeDragged, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "IsInventoryAccessibleTo", inventoryAccessible, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.HumanoidAnimController", "DragCharacter", skipDrag, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanInteractWith", REACH_CHARACTER_ARGS, reachCharacter, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "GetDistanceToClosestLimb", measureLimbDistance, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "FindCharacterAtPosition", startFocusSearch, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "FindCharacterAtPosition", endFocusSearch, Hook.HookMethodType.After)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanSeeTarget", seeThroughWalls, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Camera", "MoveCamera", zoomCamera, Hook.HookMethodType.After)
end

-- Runs after the affliction sets InvisibleTimer and before the frame is drawn.
local function showGhosts()
    local controlled = Character.Controlled
    if controlled ~= nil and not controlled.IsDead and controlled ~= ghost then return end
    for id in pairs(listed) do
        local character = Entity.FindEntityByID(id)
        if character ~= nil then character.InvisibleTimer = 0 end
    end
end

local function stop()
    release(carried)
    carried = nil
    ghostId = nil
    ghost = nil
    Hook.Remove("think", PATCH_ID)
end

-- the ghost's spawn can arrive after the state message, so it is picked up once this client controls it
local function watchControl()
    local controlled = Character.Controlled
    if controlled == nil or controlled.ID ~= ghostId then return end
    Hook.Remove("think", PATCH_ID)
    ghost = controlled
    -- Unkillable isn't synced, so local damage would knock the ghost down until the server corrects it
    ghost.Unkillable = true
    for limb in ghost.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end
    -- taking control of a character turns line of sight back on
    gameMain.LightManager.LosEnabled = false
    cameraZoom = gameMain.GameScreen.Cam.Zoom
    cameraTargetZoom = cameraZoom
    ensurePatches()
end

Networking.Receive(NET_PROBE, function()
    Networking.Send(Networking.Start(NET_READY))
end)

Networking.Receive(NET_STATE, function(message)
    local id, active = message.ReadUInt16(), message.ReadBoolean()
    if active then
        stop()
        ghostId = id
        walkSpeed, runSpeed = message.ReadSingle(), message.ReadSingle()
        Hook.Add("think", PATCH_ID, watchControl)
    elseif id == ghostId then
        stop()
    end
end)

Networking.Receive(NET_LIST, function(message)
    listed = {}
    local count = message.ReadByte()
    for _ = 1, count do listed[message.ReadUInt16()] = true end
    if count > 0 then
        Hook.Add("think", SHOW_ID, showGhosts)
    else
        Hook.Remove("think", SHOW_ID)
    end
end)

Hook.Add("roundStart", PATCH_ID, function()
    Networking.Send(Networking.Start(NET_LIST_REQUEST))
end)

Hook.Add("roundEnd", PATCH_ID, function()
    stop()
    listed = {}
    Hook.Remove("think", SHOW_ID)
end)
