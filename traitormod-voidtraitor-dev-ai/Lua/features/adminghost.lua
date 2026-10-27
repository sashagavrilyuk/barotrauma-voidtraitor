-- Admin ghost: an admin swaps spectating (or their body) for a hidden, unkillable body that flies through walls and
-- reaches items at any distance. The admin's client runs the same movement and reach code
-- (Void traitor pack: Lua/client/spectator/adminghost.lua) so its movement prediction matches the server.
-- Clients without client LuaCs only need the vt_adminghost affliction from the pack to keep the ghost invisible;
-- spectators with the pack's client script are told which characters are ghosts so they can still see them.
local adminGhost = {}

local AFFLICTION = "vt_adminghost"
local NET_PROBE = "VoidTraitor_AdminGhostProbe"
local NET_READY = "VoidTraitor_AdminGhostReady"
local NET_STATE = "VoidTraitor_AdminGhostState"
local NET_LIST = "VoidTraitor_AdminGhostList"
local NET_LIST_REQUEST = "VoidTraitor_AdminGhostListRequest"
local PATCH_ID = "Traitormod.AdminGhost"
local REACH_ARGS = { "Barotrauma.Item", "out System.Single", "System.Boolean", "System.Boolean" }
local UPDATE_ANIM_ARGS = { "System.Single" }
local UPDATE_RAGDOLL_ARGS = { "System.Single", "Barotrauma.Camera" }
local VOIP_ARGS = { "Barotrauma.Networking.Client", "Barotrauma.Networking.Client", "out System.Single", "out System.Boolean" }
local BODY_KINEMATIC, BODY_DYNAMIC = 1, 2 -- FarseerPhysics.BodyType
local WALK_SPEED, RUN_SPEED = 5, 15 -- sim units per second (100 display units each)
-- a carried character closes the gap to the ghost within about 1 / CATCH_UP seconds
local CATCH_UP = 10
local PROBE_TIMEOUT_MS = 2000

LuaUserData.RegisterType("Barotrauma.ContentXElement")
local contentElement = LuaUserData.CreateStatic("Barotrauma.ContentXElement")

-- ghost character -> { Client, Body, Info }
local ghosts = {}
-- clients asked whether their client mod can run the ghost
local probing = {}
-- clients whose pack script asked for the ghost list this round
local listeners = {}
-- ghost -> true while its selected character was picked with the health key: inspected, not carried
local inspecting = {}
-- ghost -> the character it carries
local carried = {}
local patched = false

-- While levitatingCollider is set, Ragdoll.UpdateRagdoll pulls a collider above a floor to standing height and
-- ragdolls an idle airborne one (Ragdoll.cs:1469-1508); the animation sets it every frame (HumanoidAnimController.cs:258,
-- FishAnimController.cs:146). collider and prevCollisionCategory are needed to give a carried character back its physics.
for _, animType in ipairs({ "Barotrauma.HumanoidAnimController", "Barotrauma.FishAnimController" }) do
    local descriptor = LuaUserData.RegisterType(animType)
    for _, field in ipairs({ "levitatingCollider", "collider", "prevCollisionCategory" }) do
        LuaUserData.MakeFieldAccessible(descriptor, field)
    end
end

function adminGhost.IsGhost(character)
    return ghosts[character] ~= nil
end

local function isGhostClient(client)
    return client.Character ~= nil and ghosts[client.Character] ~= nil
end

-- Moves a character whose collider controls its movement (Ragdoll.ColliderControlsMovement), as the ghost does.
local function fly(anim, velocity)
    -- a kinematic body ignores gravity, buoyancy, animation forces and the damping of a frozen remote player
    -- (Island.cs:121-129 in Farseer, Ragdoll.Frozen); set every frame because crouching switches to another collider
    -- (Ragdoll.ColliderIndex)
    anim.Collider.BodyType = BODY_KINEMATIC
    anim.Collider.LinearVelocity = velocity
    anim.levitatingCollider = false
    -- away from a floor the walking animation stops pulling the limbs to the collider
    anim.MainLimb.PullJointWorldAnchorB = anim.Collider.SimPosition
    anim.MainLimb.PullJointEnabled = true
end

-- A character that cannot move (unconscious, dead, a fish on dry land) is moved by its main limb, which its disabled
-- collider follows (Ragdoll.UpdateRagdollControlsMovement).
local function carry(ghost, target, ghostVelocity)
    local anim = target.AnimController
    local velocity = ghostVelocity + (ghost.WorldPosition - target.WorldPosition) * (CATCH_UP / 100)
    if anim.ColliderControlsMovement then
        fly(anim, velocity)
    else
        anim.MainLimb.body.LinearVelocity = velocity
    end
end

-- Gives a carried character its own physics back: dynamic colliders, gravity, no leftover speed (a fast body that hits
-- a wall gets hurt) and the collisions the ragdoll restores once its category is reset (Ragdoll.cs:1227-1240, 2170-2177).
local function release(target)
    local anim = target.AnimController
    for body in anim.collider do
        body.BodyType = BODY_DYNAMIC
        body.ResetDynamics()
    end
    for limb in anim.Limbs do
        limb.body.FarseerBody.IgnoreGravity = false
        limb.body.ResetDynamics()
    end
    anim.prevCollisionCategory = 0 -- FarseerPhysics.Dynamics.Category.None
end

-- The ghost carries what it grabbed with G instead of dragging it, so nothing makes it let go
-- (see skipDrag) and the carried character passes through walls with it.
local function updateCarried(ghost, velocity)
    local target = ghost.SelectedCharacter
    if inspecting[ghost] or (target ~= nil and target.Removed) then target = nil end
    local previous = carried[ghost]
    if previous ~= target then
        if previous ~= nil and not previous.Removed then release(previous) end
        carried[ghost] = target
        -- limbs pulled along by a flying body lag far behind it under gravity
        if target ~= nil then
            for limb in target.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end
        end
    end
    if target ~= nil then carry(ghost, target, velocity) end
end

-- Runs after the animations, which set the collider velocity and levitatingCollider (GameScreen.cs:274),
-- and before Ragdoll.UpdateAll uses them.
local function setVelocities()
    for ghost in pairs(ghosts) do
        if not ghost.Removed then
            local x, y = 0, 0
            if ghost.IsKeyDown(InputType.Left) then x = x - 1 end
            if ghost.IsKeyDown(InputType.Right) then x = x + 1 end
            if ghost.IsKeyDown(InputType.Up) then y = y + 1 end
            if ghost.IsKeyDown(InputType.Down) then y = y - 1 end
            local velocity = Vector2.Zero
            if x ~= 0 or y ~= 0 then
                velocity = Vector2.Normalize(Vector2(x, y)) * (ghost.IsKeyDown(InputType.Run) and RUN_SPEED or WALK_SPEED)
            end
            fly(ghost.AnimController, velocity)
            updateCarried(ghost, velocity)
        end
    end
end

local function disableCollisions(anim)
    if anim.Collider.CollidesWith == 0 then return end
    anim.Collider.CollidesWith = 0
    -- the limbs the ragdoll leaves alone itself (Ragdoll.UpdateCollisionCategories)
    for limb in anim.Limbs do
        if not limb.IgnoreCollisions and not limb.IsSevered then limb.body.CollidesWith = 0 end
    end
end

-- Runs right before the physics step (GameScreen.cs:277-302). Ragdoll.UpdateCollisionCategories restores
-- collisions whenever the category changes, e.g. on leaving a submarine (Ragdoll.cs:1227-1240).
local function clearCollisions()
    for ghost in pairs(ghosts) do
        if not ghost.Removed then disableCollisions(ghost.AnimController) end
    end
    for _, target in pairs(carried) do
        if not target.Removed then disableCollisions(target.AnimController) end
    end
end

-- Same gates as Character.CanInteractWith(Item, out float, bool, bool) without the distance check.
local function reach(instance, ptable)
    if ghosts[instance] == nil then return end
    ptable.PreventExecution = true
    local item = ptable["item"]
    local allowHidden = ptable["allowHiddenItems"]
    -- a flying ghost never climbs: pressing up or down grabs the first ladder accepted here (Character.cs:3222-3260)
    if item.GetComponentString("Ladder") ~= nil then return false end
    if not instance.CanInteract or (item.IsHidden and not allowHidden) or not item.IsInteractable(instance, allowHidden) then return false end
    if item.ParentInventory ~= nil then return instance.CanAccessInventory(item.ParentInventory) end
    return item.InteractDistance > 0 or #item.Prefab.Triggers > 0
end

-- Dead and spectating players are heard only by each other (VoipServer.CanReceive, VoipServer.cs:87-94); ghosts
-- hear them too. Such a sender has no living character, so the ghost's client plays it without distance (VoipClient.cs:114).
local function hearSpectators(instance, ptable)
    local recipient = ptable["recipient"]
    if not isGhostClient(recipient) then return end
    local sender = ptable["sender"]
    if sender.Muted or (sender.Character ~= nil and not sender.Character.IsDead) then return end
    ptable.PreventExecution = true
    -- out parameters are not set when the original is skipped; Single converts to float (LuaTypes.cs:191)
    ptable["distanceFactor"] = Single(0)
    ptable["isRadio"] = false
    return true
end

-- Grabbing (G) and the health window (H) need an incapacitated or cuffed target, a pet or a bot of the same team
-- (Character.CanBeDraggedBy, Character.cs:2746-2750); a ghost may take anyone.
local function canBeDragged(instance, ptable)
    if ghosts[ptable["character"]] == nil then return end
    ptable.PreventExecution = true
    return instance.IsDraggable
end

-- Another character's inventory opens under the same conditions (Character.IsInventoryAccessibleTo, Character.cs:2755);
-- a ghost opens any.
local function inventoryAccessible(instance, ptable)
    if ghosts[ptable["character"]] == nil then return end
    ptable.PreventExecution = true
    return not instance.Removed and instance.Inventory ~= nil
end

-- G and H both select the character (Character.cs:3276-3310); a ghost carries only what it grabbed with G.
local function rememberSelection(instance)
    if ghosts[instance] == nil then return end
    inspecting[instance] = instance.IsKeyHit(InputType.Health)
end

-- A selected character is dragged every frame (HumanoidAnimController.UpdateAnim), and dragging lets go of it behind a wall
-- or when it is conscious and walks away (HumanoidAnimController.cs:1458-1478, 1569-1576); a ghost carries it instead.
local function skipDrag(instance, ptable)
    if ghosts[instance.Character] ~= nil then ptable.PreventExecution = true end
end

-- Status effects with RemoveCharacter (e.g. a singularity), deconstructors and console commands remove characters
-- through the spawner, which also takes the client off the character at once (EntitySpawner.cs:358-376).
-- removeGhost forgets the ghost before removing it.
local function keepGhost(instance, ptable)
    if ghosts[ptable["entity"]] ~= nil then ptable.PreventExecution = true end
end

-- Installed on first use and kept: Hook.RemovePatch cannot remove them, because LuaCs passes the class name as the
-- patch identifier (EventService.RemovePatch, EventService.cs:391-399). Without ghosts they return at once.
local function ensurePatches()
    if patched then return end
    patched = true
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanInteractWith", REACH_ARGS, reach, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "UpdateAnimAll", UPDATE_ANIM_ARGS, setVelocities, Hook.HookMethodType.After)
    Hook.Patch(PATCH_ID, "Barotrauma.Ragdoll", "UpdateAll", UPDATE_RAGDOLL_ARGS, clearCollisions, Hook.HookMethodType.After)
    Hook.Patch(PATCH_ID, "Barotrauma.Networking.VoipServer", "CanReceive", VOIP_ARGS, hearSpectators, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "CanBeDraggedBy", canBeDragged, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "IsInventoryAccessibleTo", inventoryAccessible, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.Character", "SelectCharacter", rememberSelection, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.HumanoidAnimController", "DragCharacter", skipDrag, Hook.HookMethodType.Before)
    Hook.Patch(PATCH_ID, "Barotrauma.EntitySpawner", "AddEntityToRemoveQueue", keepGhost, Hook.HookMethodType.Before)
end

local function sendList(connection)
    local message = Networking.Start(NET_LIST)
    local count = 0
    for _ in pairs(ghosts) do count = count + 1 end
    message.WriteByte(count)
    for ghost in pairs(ghosts) do message.WriteUInt16(ghost.ID) end
    Networking.Send(message, connection)
end

local function sendListToListeners()
    for client in pairs(listeners) do sendList(client.Connection) end
end

local function sendState(client, ghost, active)
    local message = Networking.Start(NET_STATE)
    message.WriteUInt16(ghost.ID)
    message.WriteBoolean(active)
    if active then
        message.WriteSingle(WALK_SPEED)
        message.WriteSingle(RUN_SPEED)
    end
    Networking.Send(message, client.Connection)
end

local function enable(client)
    local body = client.Character
    local position = body ~= nil and not body.IsDead and body.WorldPosition or client.SpectatePos
    -- the ghost copies the appearance, name and job of the admin's character, the way station cloning copies a body
    -- (gamemodes/station/cloning.lua)
    local source = body ~= nil and body.IsHuman and body.Info or client.CharacterInfo
    local info
    if source ~= nil then
        info = CharacterInfo(contentElement.__new(nil, source.Save(nil)))
        info.PermanentlyDead = false
    else
        info = CharacterInfo("human", client.Name)
    end
    info.Name = string.format(Traitormod.Language.AdminGhostName, info.Name)
    local ghost = Character.Create(info, position, info.Name, 0, true, true)
    -- friendly to every team (Character.IsOnFriendlyTeam, Character.cs:6183-6196): bots do not treat the ghost as an
    -- intruder (team None made every bot's AI update several times slower), and clients leave it out of the crew list
    ghost.TeamID = CharacterTeamType.FriendlyNPC
    -- unlike GodMode, Unkillable still updates afflictions (CharacterHealth.cs:919) and lets buffs through (:479)
    ghost.Unkillable = true
    ghost.CharacterHealth.ApplyAffliction(nil, AfflictionPrefab.Prefabs[AFFLICTION].Instantiate(1))
    -- nothing in the game resets IgnoreGravity on limbs; the collider is kept kinematic in setVelocities
    for limb in ghost.AnimController.Limbs do limb.body.FarseerBody.IgnoreGravity = true end

    ghosts[ghost] = { Client = client, Body = body, Info = client.CharacterInfo }
    client.SetClientCharacter(ghost)
    ensurePatches()
    sendState(client, ghost, true)
    sendListToListeners()
end

-- returnControl is false when the round ends or the admin disconnects
local function removeGhost(ghost, returnControl)
    local state = ghosts[ghost]
    ghosts[ghost] = nil
    inspecting[ghost] = nil
    if carried[ghost] ~= nil and not carried[ghost].Removed then release(carried[ghost]) end
    carried[ghost] = nil

    -- Character.Remove drops held items into the world (Character.cs:5401-5404); the ghost's items go with it
    for item in ghost.Inventory.AllItems do
        Entity.Spawner.AddItemToRemoveQueue(item)
    end

    local client = state.Client
    if returnControl then
        local body = state.Body
        client.SetClientCharacter(body ~= nil and not body.Removed and not body.IsDead and body or nil)
        sendState(client, ghost, false)
    end
    -- SetClientCharacter gave the client the ghost's CharacterInfo, which would otherwise be used for the next spawn
    client.CharacterInfo = state.Info
    Entity.Spawner.AddEntityToRemoveQueue(ghost)
    sendListToListeners()
end

function adminGhost.Toggle(client)
    for ghost, state in pairs(ghosts) do
        if state.Client == client then
            removeGhost(ghost, true)
            return
        end
    end
    if probing[client] then return end

    -- the movement prediction needs the pack's client script, which answers this probe
    probing[client] = true
    Networking.Send(Networking.Start(NET_PROBE), client.Connection)
    Timer.Wait(function()
        if not probing[client] then return end
        probing[client] = nil
        Traitormod.SendMessage(client, Traitormod.Language.CMDAdminGhostNoClientLua)
    end, PROBE_TIMEOUT_MS)
end

Networking.Receive(NET_LIST_REQUEST, function(message, client)
    listeners[client] = true
    sendList(client.Connection)
end)

Networking.Receive(NET_READY, function(message, client)
    if not probing[client] then return end
    probing[client] = nil
    if Game.RoundStarted then enable(client) end
end)

-- A ghost's "d;" message: the server drops dead chat from a living character (GameServer.cs:3963-3968) and resolves the
-- sender's character from its client (:3904-3906), so it is delivered here to everyone who reads dead chat.
Hook.Add("chatMessage", "Traitormod.AdminGhost.DeadChat", function(message, client)
    if client == nil or not isGhostClient(client) then return end
    local command, text = ChatMessage.GetChatMessageCommand(message)
    command = string.lower(command)
    if command ~= "d" and command ~= "dead" then return end

    for _, recipient in pairs(Client.ClientList) do
        if recipient.Character == nil or recipient.Character.IsDead or isGhostClient(recipient) then
            Game.SendDirectChatMessage(ChatMessage.Create(client.Character.Name, text, ChatMessageType.Dead, nil, client), recipient)
        end
    end
    Game.Server.AddChatMessage(text, ChatMessageType.Dead, client.Character.Name, client)
    return true
end)

-- Dead chat goes only to clients without a living character (GameServer.cs:4013-4015); ghosts get a copy.
Hook.Add("modifyChatMessage", "Traitormod.AdminGhost.DeadChatCopy", function(message)
    if message.Type ~= ChatMessageType.Dead then return end
    for _, state in pairs(ghosts) do
        if state.Client ~= message.SenderClient then
            Game.SendDirectChatMessage(ChatMessage.Create(message.SenderName, message.Text, ChatMessageType.Dead, nil, message.SenderClient), state.Client)
        end
    end
end)

Hook.Add("roundEnd", "Traitormod.AdminGhost.RoundEnd", function()
    for ghost in pairs(ghosts) do removeGhost(ghost, false) end
    probing = {}
    listeners = {}
end)

Hook.Add("client.disconnected", "Traitormod.AdminGhost.Disconnect", function(client)
    probing[client] = nil
    listeners[client] = nil
    for ghost, state in pairs(ghosts) do
        if state.Client == client then removeGhost(ghost, false) end
    end
end)

return adminGhost
