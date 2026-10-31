if SERVER then return end

-- Movement and reach of the admin ghost this client controls. The server runs the same code
-- (traitormod-voidtraitor-dev-ai: Lua/features/adminghost.lua), so the client's movement prediction matches it.
-- While spectating (or being a ghost), this client also shows the ghosts that the vt_adminghost affliction hides.
local NET_PROBE = "VoidTraitor_AdminGhostProbe"
local NET_READY = "VoidTraitor_AdminGhostReady"
local NET_STATE = "VoidTraitor_AdminGhostState"
local NET_LIST = "VoidTraitor_AdminGhostList"
local NET_LIST_REQUEST = "VoidTraitor_AdminGhostListRequest"
local SHOW_ID = "VoidTraitor.AdminGhost.Show"
local PATCH_ID = "VoidTraitor.AdminGhost"
local REACH_ARGS = { "Barotrauma.Item", "out System.Single", "System.Boolean" }
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

-- while levitatingCollider is set, Ragdoll.UpdateRagdoll pulls the collider to a floor or ragdolls it
-- (Ragdoll.cs:1469-1508); prevCollisionCategory gives a carried character its collisions back
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

-- The server carries the character; this client only lets its own copy of it pass through walls, so the server's
-- corrections can move it there (a remote ragdoll is teleported only beyond about 3 m, ClientSource Ragdoll.cs:109-150).
-- An inspected (H) character has its health window open; the selection alone does not tell, because the client also
-- selects again without a key when it follows the server's state (ClientSource Ragdoll.cs:205-215).
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
    -- Facing follows the cursor only on the ground and out of water (Character.cs:2289-2312), so a flying ghost could
    -- not turn to throw; the server takes the facing from this client's input (:2322-2331).
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
    -- the limbs the ragdoll leaves alone itself (Ragdoll.UpdateCollisionCategories)
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
    -- a flying ghost never climbs: pressing up or down grabs the first ladder accepted here (Character.cs:3222-3260)
    if item.GetComponentString("Ladder") ~= nil then return false end
    if not instance.CanInteract or item.IsHidden or not item.IsInteractable(instance) then return false end
    if item.ParentInventory ~= nil then return instance.CanAccessInventory(item.ParentInventory) end
    return item.InteractDistance > 0 or #item.Prefab.Triggers > 0
end

local function reachCharacter(instance, ptable)
    if instance ~= ghost then return end
    ptable.PreventExecution = true
    local c = ptable["c"]
    return c ~= instance and c.Enabled and c.CanBeSelected and c.InvisibleTimer <= 0
end

-- The focus search measures from the cursor, kept relative to the controlled character's submarine (UpdateLocalCursor,
-- ClientSource Character.cs:524-531), to limbs relative to each character's own submarine (Character.cs:3914-3925),
-- so a ghost outside a character's submarine missed it; while the ghost searches, each character gets the cursor in its
-- own frame. Outside the search this only runs to let go of a selection beyond MaxDragDistance (Character.cs:2548-2556).
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

-- Focusing on a character needs line of sight (Character.cs:3174-3175); the ghost sees through walls like a spectator,
-- which also shows it the names of characters behind walls (hudInfoVisible, ClientSource Character.cs:879-890).
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

-- The camera following a character zooms with the cursor's distance from it (Camera.MoveCamera, Camera.cs:338-366);
-- the ghost's camera zooms with the wheel within the free camera's limits (:303-320). With Alt held the wheel is left
-- to the items that read it while aiming (a sprayer's spray size, Sprayer.cs:56-82).
local function zoomCamera(instance, ptable)
    if ghost == nil or instance ~= gameMain.GameScreen.Cam then return end
    if ptable["allowZoom"] and not PlayerInput.KeyDown(Keys.LeftAlt) and not PlayerInput.KeyDown(Keys.RightAlt) then
        cameraTargetZoom = math.max(instance.MinZoom, math.min(instance.MaxZoom,
            cameraTargetZoom + PlayerInput.ScrollWheelSpeed / 1000 * cameraZoom))
    end
    cameraZoom = cameraZoom + (cameraTargetZoom - cameraZoom) * math.min(ptable["deltaTime"] * 10, 1)
    instance.Zoom = cameraZoom
end

-- Installed on first use and kept: Hook.RemovePatch cannot remove them, because LuaCs passes the class name as the
-- patch identifier (EventService.RemovePatch, EventService.cs:391-399). Without a ghost they return at once.
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

-- Runs after the characters' updates, where the affliction sets InvisibleTimer, and before drawing (GameMain.Update).
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
    -- the server's Unkillable is not synced, so local damage would knock the ghost down until the server corrects it
    ghost.Unkillable = true
    for limb in ghost.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end
    -- taking control turns line of sight back on (CharacterNetworking.cs:386 in ClientSource)
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
