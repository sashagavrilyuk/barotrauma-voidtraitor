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
local REACH_ARGS = { "Barotrauma.Item", "out System.Single", "System.Boolean", "System.Boolean" }
local UPDATE_ANIM_ARGS = { "System.Single" }
local UPDATE_RAGDOLL_ARGS = { "System.Single", "Barotrauma.Camera" }
local BODY_KINEMATIC = 1 -- FarseerPhysics.BodyType.Kinematic

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local ghostId, walkSpeed, runSpeed
local ghost
local patched = false
-- entity IDs of every ghost in the round
local listed = {}

-- while it is set, Ragdoll.UpdateRagdoll pulls the collider to a floor or ragdolls it (Ragdoll.cs:1469-1508)
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.HumanoidAnimController"), "levitatingCollider")

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
end

local function clearCollisions()
    if ghost == nil or ghost.Removed then return end
    local anim = ghost.AnimController
    if anim.Collider.CollidesWith == 0 then return end
    anim.Collider.CollidesWith = 0
    for limb in anim.Limbs do limb.body.CollidesWith = 0 end
end

local function reach(instance, ptable)
    if instance ~= ghost then return end
    ptable.PreventExecution = true
    local item = ptable["item"]
    local allowHidden = ptable["allowHiddenItems"]
    -- a flying ghost never climbs: pressing up or down grabs the first ladder accepted here (Character.cs:3222-3260)
    if item.GetComponentString("Ladder") ~= nil then return false end
    if not instance.CanInteract or (item.IsHidden and not allowHidden) or not item.IsInteractable(instance, allowHidden) then return false end
    if item.ParentInventory ~= nil then return instance.CanAccessInventory(item.ParentInventory) end
    return item.InteractDistance > 0 or #item.Prefab.Triggers > 0
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
    for limb in ghost.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end
    -- taking control turns line of sight back on (CharacterNetworking.cs:386 in ClientSource)
    gameMain.LightManager.LosEnabled = false
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
