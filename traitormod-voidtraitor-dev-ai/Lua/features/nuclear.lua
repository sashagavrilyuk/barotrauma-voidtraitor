local nuclear = {}
Traitormod.Nuclear = nuclear
local config = Traitormod.Config.Nuclear
local json = require("json")
local bombs, sessions = {}, {}
local active = false
local texts
local statusLabels = { locked = "Locked", code = "AwaitCode", ready = "Ready", armed = "Armed", cooldown = "Cooldown", exploded = "Exploded" }
local componentEvent = LuaUserData.CreateStatic("Barotrauma.Item+ComponentStateEventData", true)
local terminalDescriptor = Descriptors["Barotrauma.Items.Components.Terminal"] or LuaUserData.RegisterType("Barotrauma.Items.Components.Terminal")
LuaUserData.MakePropertyAccessible(terminalDescriptor, "OutputValue")

function nuclear.Start()
    active, bombs, sessions = true, {}, {}
    texts = {}
    for _, key in ipairs({ "Title", "Locked", "AwaitDisk", "AwaitCode", "Ready", "Armed", "Cooldown", "Exploded",
        "Time", "Cooling", "Eject", "Insert", "Anchor", "Arm", "Disarm", "Close", "Disarming" }) do
        texts[key] = Traitormod.GetText("Nuke" .. key)
    end
    for item in Item.ItemList do
        if item.Prefab.Identifier == "vt_nuclear_bomb" then nuclear.Register(item) end
    end
end

function nuclear.Register(item)
    if not active or bombs[item] ~= nil then return end
    local code = ""
    for _ = 1, 6 do code = code .. tostring(math.random(0, 9)) end
    bombs[item] = { Code = code, Entered = "", Status = "locked", Remaining = config.Time, Cooldown = 0, LastAttempt = -1 }
end

function nuclear.Validate(client, item, readOnly)
    return active and Game.RoundStarted and not Traitormod.IsRoundFinalizing()
        and client ~= nil and client.Character ~= nil and client.Character.IsHuman
        and not client.Character.IsDead and not client.Character.IsIncapacitated
        and item ~= nil and not item.Removed and bombs[item] ~= nil and item.CanClientAccess(client)
        and (readOnly == true or client.Character.SelectedItem == item)
end

function nuclear.Snapshot(item, data)
    return { Status = data.Status, Remaining = math.ceil(data.Remaining), Cooldown = math.ceil(data.Cooldown),
        Entered = #data.Entered, Disk = item.OwnInventory.GetItemAt(0) ~= nil,
        Anchored = item.GetComponentString("Holdable").Attached,
        Disarming = data.Disarming ~= nil and math.floor(data.Disarming.Progress / config.DisarmTime * 100) or -1, Text = texts }
end

function nuclear.Send(client, item, payload)
    local message = Networking.Start("VoidTraitor_NuclearSnapshot")
    message.WriteUInt16(UShort(item.ID))
    message.WriteString(payload or json.encode(nuclear.Snapshot(item, bombs[item])))
    Networking.Send(message, client.Connection)
end

function nuclear.Update(item, data)
    local snapshot = nuclear.Snapshot(item, data)
    local first = snapshot.Text[statusLabels[data.Status]]
    local second = Traitormod.FormatText("NukeTime", snapshot.Remaining)
    if data.Status == "locked" then second = snapshot.Text.AwaitDisk
    elseif data.Status == "code" then second = string.rep("*", #data.Entered) .. string.rep("_", 6 - #data.Entered)
    elseif data.Status == "cooldown" then second = Traitormod.FormatText("NukeCooling", snapshot.Cooldown) end
    local body = first .. "\n" .. second
    if snapshot.Disarming >= 0 then body = body .. "\n" .. Traitormod.FormatText("NukeDisarming", snapshot.Disarming) end
    local terminal = item.GetComponentString("Terminal")
    if terminal.ShowMessage ~= body then
        terminal.ShowMessage = body
        -- The native Terminal packet is a single OutputValue string; SyncHistory would resend all previous countdown lines.
        terminal.OutputValue = body
        Networking.CreateEntityEvent(item, componentEvent.__new(terminal, nil))
    end
    local holdable = item.GetComponentString("Holdable")
    local canPick = data.Status ~= "exploded"
    if holdable.CanBePicked ~= canPick then
        holdable.CanBePicked = canPick
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(holdable.SerializableProperties[Identifier("CanBePicked")], holdable))
    end
    local light = item.GetComponentString("LightComponent")
    local armed = data.Status == "armed"
    if light.IsOn ~= armed then
        light.IsOn = armed
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(light.SerializableProperties[Identifier("IsOn")], light))
    end
    local payload
    for client, selected in pairs(sessions) do
        if selected == item then
            if nuclear.Validate(client, item) then
                payload = payload or json.encode(snapshot)
                nuclear.Send(client, item, payload)
            else
                sessions[client] = nil
            end
        end
    end
end

function nuclear.Disarm(item, data)
    if data.Status ~= "armed" then return end
    data.Status, data.Cooldown, data.Disarming = "cooldown", config.Cooldown, nil
    data.Remaining = math.max(data.Remaining, config.MinimumTime)
    item.OwnInventory.Locked = false
    Traitormod.SendMessageEveryone(Traitormod.GetText("NukeDisarmedAnnouncement"))
    Traitormod.SelectedGamemode:SetAlertCode("green")
end

function nuclear.BeginDisarm(character, item)
    local data = bombs[item]
    if not active or not Game.RoundStarted or Traitormod.IsRoundFinalizing() or data == nil or data.Status ~= "armed"
        or data.Disarming ~= nil or character == nil or character.IsDead or character.IsIncapacitated
        or not character.IsHuman or character.LockHands or not character.CanInteractWith(item) then return false end
    data.Disarming = { Character = character, Position = character.WorldPosition, Progress = 0 }
    nuclear.Update(item, data)
    return true
end

function nuclear.Action(client, item, action, value)
    if action == "close" then
        if sessions[client] == item then sessions[client] = nil end
        return true
    end
    if not nuclear.Validate(client, item) then return false end
    local data = bombs[item]
    local disk = item.OwnInventory.GetItemAt(0)
    local holdable = item.GetComponentString("Holdable")
    if action == "insert" and disk == nil and data.Status ~= "armed" then
        for held in client.Character.Inventory.AllItems do
            if held.Prefab.Identifier == "vt_nuclear_disk" then
                if item.OwnInventory.TryPutItem(held, 0, false, false, client.Character, true) then break end
            end
        end
    elseif action == "eject" and disk ~= nil and data.Status ~= "armed" and holdable.Attached then
        if not client.Character.Inventory.TryPutItem(disk, client.Character, disk.GetComponentString("Pickable").AllowedSlots, true, false, true) then disk.Drop(client.Character, true) end
        if data.Status ~= "cooldown" then data.Status = "locked" end
        data.Entered = ""
    elseif action == "digit" and data.Status == "code" and type(value) == "string" and value:match("^%d$") and #data.Entered < 6 then
        data.Entered = data.Entered .. value
    elseif action == "clear" and data.Status == "code" then data.Entered = ""
    elseif action == "enter" and data.Status == "code" and Timer.GetTime() - data.LastAttempt >= 1 then
        data.LastAttempt = Timer.GetTime()
        if data.Entered == data.Code then
            data.Status, data.Remaining = "ready", config.Time
        else data.Entered = "" end
    elseif action == "code" and data.Status == "code" and type(value) == "string" and value:match("^%d%d%d%d%d%d$") then
        if Timer.GetTime() - data.LastAttempt < 1 then return false end
        data.Entered = value
        return nuclear.Action(client, item, "enter")
    elseif action == "anchor" and data.Status ~= "armed" and item.ParentInventory == nil then
        if holdable.Attached then
            holdable.Drop(nil, false)
            Networking.CreateEntityEvent(item, componentEvent.__new(holdable, nil))
        else
            local position = item.WorldPosition
            local hull = Hull.FindHull(position, item.CurrentHull)
            local safe = hull ~= nil and hull.Submarine == Submarine.MainSub
            if safe then
                for _, offset in ipairs({ Vector2(80, 0), Vector2(-80, 0), Vector2(0, 80), Vector2(0, -80) }) do
                    local nearby = Hull.FindHull(position + offset, hull)
                    if nearby == nil or nearby.Submarine ~= Submarine.MainSub then safe = false break end
                end
            end
            if not safe then
                Traitormod.SendChatMessage(client, Traitormod.GetText("NukeUnsafePlacement"))
                return false
            end
            if not holdable.CanBeAttached(nil) then return false end
            holdable.AttachToWall()
            Networking.CreateEntityEvent(item, componentEvent.__new(holdable, nil))
        end
    elseif action == "arm" and data.Status == "ready" and disk ~= nil and holdable.Attached then
        data.Status = "armed"
        item.OwnInventory.Locked = true
        Traitormod.SelectedGamemode:SetAlertCode("delta")
        local hull = Hull.FindHull(item.WorldPosition, item.CurrentHull)
        local room = hull ~= nil and tostring(hull.DisplayName) or Traitormod.GetText("NukeUnknownRoom")
        local station = Submarine.MainSub
        local borders = station.GetDockedBorders()
        local middle = station.WorldPosition + Vector2(borders.X + borders.Width / 2, borders.Y - borders.Height / 2)
        local offset = item.WorldPosition - middle
        local vertical = offset.Y >= 0 and "North" or "South"
        local horizontal = offset.X >= 0 and "East" or "West"
        local direction = math.abs(offset.X) < 50 and math.abs(offset.Y) < 50 and "Center"
            or math.abs(offset.X) > math.abs(offset.Y) * 2 and horizontal
            or math.abs(offset.Y) > math.abs(offset.X) * 2 and vertical or vertical .. horizontal
        local text = Traitormod.FormatText("NukeArmedAnnouncement", room,
            Traitormod.GetText("NukeDirection" .. direction), math.ceil(data.Remaining))
        for _, player in pairs(Client.ClientList) do
            local message = ChatMessage.Create(Traitormod.GetText("NukeAnnouncementSender"), text, ChatMessageType.Default, nil, nil)
            message.Color = Color(255, 0, 0, 255)
            Game.SendDirectChatMessage(message, player)
        end
    elseif action == "disarm" then return nuclear.BeginDisarm(client.Character, item)
    else return false end
    if data.Status == "locked" and item.OwnInventory.GetItemAt(0) ~= nil then data.Status = "code" end
    nuclear.Update(item, data)
    return true
end

function nuclear.Think(deltaTime)
    if not active or not Game.RoundStarted or Traitormod.IsRoundFinalizing() then return end
    for item, data in pairs(bombs) do
        if item.Removed then bombs[item] = nil
        else
            -- OnSpawn runs inside the Item constructor, before its network spawn event. Initialize on the next Think.
            if not data.Initialized then
                data.Initialized = true
                nuclear.Update(item, data)
            end
            local previous = data.Status .. ":" .. math.ceil(data.Remaining) .. ":" .. math.ceil(data.Cooldown)
            local disk = item.OwnInventory.GetItemAt(0)
            if disk == nil then
                if data.Status == "armed" then nuclear.Disarm(item, data) end
                if data.Status ~= "cooldown" and data.Status ~= "exploded" then data.Status, data.Entered = "locked", "" end
            elseif data.Status == "locked" then data.Status = "code" end
            if data.Status == "cooldown" then
                data.Cooldown = math.max(0, data.Cooldown - deltaTime)
                if data.Cooldown == 0 then data.Status = disk ~= nil and "ready" or "locked" end
            elseif data.Status == "armed" then
                data.Remaining = math.max(0, data.Remaining - deltaTime)
                local job = data.Disarming
                if job ~= nil then
                    local character = job.Character
                    if character.Removed or character.IsDead or character.IsIncapacitated or character.LockHands
                        or not character.CanInteractWith(item)
                        or Vector2.DistanceSquared(character.WorldPosition, job.Position) > 100 then
                        data.Disarming = nil
                        nuclear.Update(item, data)
                    else
                        character.AnimController.UpdateUseItem(false, item.WorldPosition)
                        job.Progress = job.Progress + deltaTime
                        if job.Progress >= config.DisarmTime then nuclear.Disarm(item, data) end
                    end
                end
                if data.Remaining == 0 and data.Status == "armed" then
                    data.Status, data.Disarming = "exploded", nil
                    nuclear.Update(item, data)
                    local position = item.WorldPosition
                    Explosion(config.ExplosionRange, 100, 10000, 10000, 10000, 1).Explode(position, item)
                    if Vector2.Distance(position, Submarine.MainSub.WorldPosition) <= config.ExplosionRange then
                        Traitormod.SelectedGamemode:BeginEnding("traitors")
                    end
                    Entity.Spawner.AddEntityToRemoveQueue(item)
                end
            end
            if previous ~= data.Status .. ":" .. math.ceil(data.Remaining) .. ":" .. math.ceil(data.Cooldown) then nuclear.Update(item, data) end
        end
    end
end

Networking.Receive("VoidTraitor_NuclearOpen", function(message, client)
    local item = Entity.FindEntityByID(message.ReadUInt16())
    if nuclear.Validate(client, item, true) then sessions[client] = item nuclear.Send(client, item) end
end)
Networking.Receive("VoidTraitor_NuclearAction", function(message, client)
    local item, action, value = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString(), message.ReadString()
    if #action <= 16 and #value <= 6 then nuclear.Action(client, item, action, value) end
end)

Hook.Patch("Traitormod.Nuclear.Terminal", "Barotrauma.Items.Components.Terminal", "ServerEventRead", function(instance, parameters)
    if instance.Item.Prefab.Identifier ~= "vt_nuclear_bomb" then return end
    local value = parameters["msg"].ReadString()
    parameters.PreventExecution = true
    if #value <= 6 then nuclear.Action(parameters["c"], instance.Item, "code", value) end
end, Hook.HookMethodType.Before)
Hook.Patch("Traitormod.Nuclear.Buttons", "Barotrauma.Items.Components.CustomInterface", "ServerEventRead", function(instance, parameters)
    if instance.Item.Prefab.Identifier ~= "vt_nuclear_bomb" then return end
    local message = parameters["msg"]
    local insert, eject, anchor, arm = message.ReadBoolean(), message.ReadBoolean(), message.ReadBoolean(), message.ReadBoolean()
    parameters.PreventExecution = true
    if insert then nuclear.Action(parameters["c"], instance.Item, "insert")
    elseif eject then nuclear.Action(parameters["c"], instance.Item, "eject")
    elseif anchor then nuclear.Action(parameters["c"], instance.Item, "anchor")
    elseif arm then nuclear.Action(parameters["c"], instance.Item, "arm") end
end, Hook.HookMethodType.Before)
-- Native picking cancels as soon as a terminal on the same item is selected. Start the SS14 do-after on E instead.
Hook.Patch("Traitormod.Nuclear.Interact", "Barotrauma.Items.Components.Holdable", "Pick", function(instance, parameters)
    if instance.Item.Prefab.Identifier ~= "vt_nuclear_bomb" then return end
    local data = bombs[instance.Item]
    if not active or data == nil or data.Status == "exploded" then parameters.PreventExecution = true return false end
    if data.Status == "armed" then
        nuclear.BeginDisarm(parameters["picker"], instance.Item)
        parameters.PreventExecution = true
        return false
    end
end, Hook.HookMethodType.Before)
Hook.Patch("Traitormod.Nuclear.DamageBefore", "Barotrauma.CharacterHealth", "ApplyDamage", function(instance)
    for _, data in pairs(bombs) do
        local job = data.Disarming
        if job ~= nil and job.Character == instance.Character then job.DamageVitality = instance.Vitality end
    end
end, Hook.HookMethodType.Before)
Hook.Patch("Traitormod.Nuclear.DamageAfter", "Barotrauma.CharacterHealth", "ApplyDamage", function(instance)
    for item, data in pairs(bombs) do
        local job = data.Disarming
        if job ~= nil and job.Character == instance.Character and job.DamageVitality ~= nil then
            if job.DamageVitality - instance.Vitality >= 1 then data.Disarming = nil nuclear.Update(item, data)
            else job.DamageVitality = nil end
        end
    end
end, Hook.HookMethodType.After)
Hook.Patch("Traitormod.Nuclear.Detach", "Barotrauma.Items.Components.Holdable", "CanBeDeattached", function(instance, parameters)
    local data = bombs[instance.Item]
    if data ~= nil and data.Status == "armed" then parameters.PreventExecution = true return false end
end, Hook.HookMethodType.Before)
Hook.Add("vt_nuclear_spawn", "Traitormod.Nuclear.Spawn", function(effect, deltaTime, item)
    if active and item.Prefab.Identifier == "vt_nuclear_bomb" then nuclear.Register(item) end
end)
Hook.Add("think", "Traitormod.Nuclear.Think", nuclear.Think)
Hook.Add("roundEnd", "Traitormod.Nuclear.End", function() active, bombs, sessions = false, {}, {} end)
Hook.Add("client.disconnected", "Traitormod.Nuclear.Disconnect", function(client) sessions[client] = nil end)

Traitormod.AddCommand("!nukecode", function(client)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return true end
    for item, data in pairs(bombs) do
        if not item.Removed then Traitormod.SendChatMessage(client, Traitormod.FormatText("NukeAdminCode", item.ID, data.Code)) end
    end
    return true
end)
return nuclear
