-- Station xenoarchaeology, as SS14's before its 2025 rework (SS14 e9d13ea Content.Server/Xenoarchaeology/XenoArtifacts;
-- config/station.lua Xenoarch; pack Lua/extensions/artifacts.lua and Lua/client/station/xenoarch.lua). An artifact has a
-- tree of nodes, each with a trigger and an effect. It sits on one node; when that node's trigger happens, the effect
-- fires and the artifact moves to a neighbouring node, most often one not seen yet. A big artifact's own effects sleep
-- but on nodes of its own. The analyzer reads the node an artifact sits on, and its console turns what was explored into
-- research points.
local xenoarch = {}
Traitormod.Xenoarch = xenoarch
local effects = dofile(Traitormod.Path .. "/Lua/gamemodes/station/xenoarch_effects.lua")
local json = require("json")

local config, artifacts, damageTypes
-- artifacts that appeared since the last frame; their trees are made on the next one, as SS14 makes them on spawn,
-- once the item has reached the clients the node's effects may tell. Only the station's: the level's ruins hold a
-- hundred more, which get their trees when someone handles them (stateOf in the triggers and the analyzer).
local pending = {}
local consoles, sessions = {}, {}
local consoleTexts = { "XenoarchTitle", "XenoarchClose", "XenoarchNoAnalyzer", "XenoarchNoArtifact", "XenoarchNoPower",
    "XenoarchScan", "XenoarchScanning", "XenoarchNode", "XenoarchDepth", "XenoarchEdges", "XenoarchTriggered",
    "XenoarchUntriggered", "XenoarchTrigger", "XenoarchEffect", "XenoarchPoints", "XenoarchExtract", "XenoarchNotScanned",
    "XenoarchUnknown", "XenoarchCurrent", "XenoarchBiasUp", "XenoarchBiasDown" }

-- prefab identifier -> "big", "trinket" or "" for any other item (pack Lua/extensions/artifacts.lua)
local kinds = {}
local function artifactKind(item)
    local id = item.Prefab.Identifier.Value
    if kinds[id] == nil then kinds[id] = item.Prefab.ConfigElement.GetAttributeString("vtartifact", "") end
    return kinds[id]
end

local prefabDescriptor = Descriptors["Barotrauma.ItemPrefab"] or LuaUserData.RegisterType("Barotrauma.ItemPrefab")
LuaUserData.MakePropertyAccessible(prefabDescriptor, "DamagedByProjectiles")
LuaUserData.MakePropertyAccessible(prefabDescriptor, "DamagedByMeleeWeapons")
-- artifact prefab -> whether shots and blows reached it before the round
local damageable = {}

local function entryOf(list, id)
    for _, entry in ipairs(list) do
        if entry.Id == id then return entry end
    end
end

-- SS14 weights each depth by how close it is to the node's (Nodes.cs GetDepthWeights), then picks an entry of it
local function pickByDepth(list, nodeDepth)
    local weights, total = {}, 0
    for _, entry in ipairs(list) do
        if weights[entry.Depth] == nil then
            weights[entry.Depth] = 10 / (0.75 * math.sqrt(2 * math.pi)) * math.exp(-((entry.Depth - nodeDepth) / 0.75) ^ 2)
            total = total + weights[entry.Depth]
        end
    end
    local roll, chosen = math.random() * total, nil
    for depth, weight in pairs(weights) do
        chosen = depth
        roll = roll - weight
        if roll <= 0 then break end
    end
    local candidates = {}
    for _, entry in ipairs(list) do
        if entry.Depth == chosen then candidates[#candidates + 1] = entry end
    end
    return candidates[math.random(#candidates)]
end

-- SS14's GenerateArtifactNodeTree: from the root down, each node gets one or two children until the count is reached.
-- Below the root a big artifact's node is now and then its own, with the tier of its family the node's depth gives.
local function generateTree(tiers)
    local count, used = math.random(config.NodesMin, config.NodesMax), {}
    local function newId()
        local id
        repeat id = math.random(100, 999) until not used[id]
        used[id] = true
        return id
    end
    local root = { Id = newId(), Depth = 0, Edges = {} }
    local nodes, queue, created = {}, { root }, 1
    while #queue > 0 do
        local node = table.remove(queue, 1)
        node.Trigger = pickByDepth(config.Triggers, node.Depth).Id
        if tiers > 0 and node.Depth > 0 and math.random() < config.OwnNodeChance then
            node.Effect, node.Tier = "Own", math.min(node.Depth, tiers)
        else
            node.Effect = pickByDepth(config.Effects, node.Depth).Id
        end
        for _ = 1, math.random(1, 2) do
            if created >= count then break end
            local child = { Id = newId(), Depth = node.Depth + 1, Edges = { node.Id } }
            node.Edges[#node.Edges + 1] = child.Id
            queue[#queue + 1] = child
            created = created + 1
        end
        nodes[node.Id] = node
    end
    return nodes, root.Id
end

-- SS14 checks its triggers every frame. Here the game watches heat, water and power itself (pack extensions/artifacts.lua)
-- and calls back only while the artifact carries the tag of its node's trigger, given once the cooldown is over.
local ARMED_TAGS = { heat = "vt_xenoarch_heat", water = "vt_xenoarch_water", electricity = "vt_xenoarch_electricity" }

local activate

-- what the electricity trigger's effect asks of the container: a powered machine, not a holder or the analyzer
local function inPoweredMachine(item)
    local container = item.Container
    if container == nil or container.HasTag("artifactcontainer") or container.HasTag("vt_artifact_analyzer") then return false end
    local powered = container.GetComponentString("Powered")
    return powered ~= nil and powered.Voltage >= 0.5
end

local function armTrigger(item, state)
    local visit, trigger = state.Visit, state.Nodes[state.Current].Trigger
    local function stillHere()
        return artifacts ~= nil and artifacts[item] == state and state.Visit == visit and not item.Removed
    end
    if trigger == "timer" then
        local function tick()
            if not stillHere() then return end
            activate(item, state)
            if stillHere() then Timer.Wait(tick, config.TimerSeconds * 1000) end
        end
        Timer.Wait(tick, config.TimerSeconds * 1000)
    elseif ARMED_TAGS[trigger] ~= nil then
        local function arm()
            if not stillHere() then return end
            item.AddTag(ARMED_TAGS[trigger])
            -- an item applies its contained effects only while it updates (Item.Update), and what lies in an idle
            -- machine does not, so one already in a powered machine goes off here
            if trigger == "electricity" and inPoweredMachine(item) then activate(item, state) end
        end
        local wait = state.LastActivation + config.Cooldown - Timer.GetTime()
        if wait > 0 then Timer.Wait(arm, math.ceil(wait * 1000)) else arm() end
    end
end

-- the effects the artifact keeps while on a node go with the node (effects.Passive)
local function enterNode(item, state, id)
    local leaving = state.Current ~= nil and effects.Passive[state.Nodes[state.Current].Effect] or nil
    if leaving ~= nil and leaving.Exit ~= nil then leaving.Exit(item, entryOf(config.Effects, state.Nodes[state.Current].Effect)) end
    local armed = state.Current ~= nil and ARMED_TAGS[state.Nodes[state.Current].Trigger] or nil
    if armed ~= nil then item.RemoveTag(armed) end
    state.Current = id
    state.Visit = (state.Visit or 0) + 1
    state.Damage = 0
    local node = state.Nodes[id]
    node.Discovered = true
    local entering = effects.Passive[node.Effect]
    if entering ~= nil and entering.Enter ~= nil then entering.Enter(item, entryOf(config.Effects, node.Effect), node) end
    armTrigger(item, state)
end

local function stateOf(item)
    local state = artifacts[item]
    if state == nil then
        local nodes, root = generateTree(item.Prefab.ConfigElement.GetAttributeInt("vttiers", 0))
        state = { Nodes = nodes, LastActivation = -math.huge, Consumed = 0 }
        artifacts[item] = state
        enterNode(item, state, root)
    end
    return state
end

-- shown to the clients near the artifact: its own sound and sparkles when it goes off, a blast, a flash
function xenoarch.Fx(item, kind, range)
    local message = Networking.Start("VoidTraitor_ArtifactFx")
    message.WriteUInt16(UShort(item.ID))
    message.WriteString(kind)
    message.WriteSingle(item.WorldPosition.X)
    message.WriteSingle(item.WorldPosition.Y)
    message.WriteSingle(range)
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and Vector2.Distance(character.WorldPosition, item.WorldPosition) < 3000 then
            Networking.Send(message, client.Connection)
        end
    end
end

-- a powered artifact holder keeps an artifact quiet, as SS14's suppression container
local function suppressed(item)
    local holder = item.Container
    if holder == nil or not holder.HasTag("artifactcontainer") then return false end
    local powered = holder.GetComponentString("Powered")
    return powered ~= nil and powered.Voltage >= 0.5
end

local refreshConsoles

-- The analyzer an artifact lies on and the direction it steers the artifact, as SS14's traversal distorter on the
-- analyzer: only while powered.
local function biasOf(item)
    local analyzer = item.Container
    if analyzer == nil or consoles.Analyzers[analyzer] == nil then return nil end
    local powered = analyzer.GetComponentString("Powered")
    if powered == nil or powered.Voltage < 0.5 then return nil end
    return consoles.Bias[analyzer] or "up"
end

-- SS14's TryActivateArtifact: the node's effect, then on to a neighbour, unseen ones three times in four
function activate(item, state, activator)
    local now = Timer.GetTime()
    if now - state.LastActivation < config.Cooldown or suppressed(item) then return end
    state.LastActivation = now
    local node = state.Nodes[state.Current]
    xenoarch.Fx(item, "activation", 0)
    effects[node.Effect](item, entryOf(config.Effects, node.Effect), activator)
    node.Triggered = true
    Traitormod.Log("Artifact " .. item.ID .. " node " .. node.Id .. ": " .. node.Trigger .. " -> " .. node.Effect)
    if #node.Edges > 0 then
        local edges, bias = node.Edges, biasOf(item)
        if bias ~= nil then
            local steered = {}
            for _, id in ipairs(node.Edges) do
                local depth = state.Nodes[id].Depth
                if (bias == "up" and depth < node.Depth) or (bias == "down" and depth > node.Depth) then steered[#steered + 1] = id end
            end
            if #steered > 0 then edges = steered end
        end
        local unseen = {}
        for _, id in ipairs(edges) do
            if not state.Nodes[id].Discovered then unseen[#unseen + 1] = id end
        end
        local nextId = edges[math.random(#edges)]
        if #unseen > 0 and math.random() < 0.75 then nextId = unseen[math.random(#unseen)] end
        enterNode(item, state, nextId)
    end
    refreshConsoles()
end

-- the artifact's status effects (pack Lua/extensions/artifacts.lua) report what happened to it
Hook.Add("VoidTraitor.ArtifactTrigger", "Traitormod.Xenoarch.Trigger", function(_, _, item, _, _, element)
    if artifacts == nil or item == nil or item.Removed then return end
    local state = stateOf(item)
    if element.GetAttributeString("trigger", "") ~= state.Nodes[state.Current].Trigger then return end
    local holder = item.ParentInventory ~= nil and item.ParentInventory.Owner or nil
    activate(item, state, holder ~= nil and LuaUserData.IsTargetType(holder, "Barotrauma.Character") and holder or nil)
end)

-- SS14's landed trigger: the artifact was thrown and has come down (features/throwing.lua)
Hook.Add("VoidTraitor.ThrownItemLanded", "Traitormod.Xenoarch.Landed", function(item)
    if artifacts == nil or artifactKind(item) == "" then return end
    local state = stateOf(item)
    if state.Nodes[state.Current].Trigger == "landed" then activate(item, state) end
end)

-- SS14's damage triggers count brute damage (blunt, slash, piercing); here the physical afflictions of a hit or a blast
local function physicalDamage(attack)
    local total = 0
    for affliction in attack.GetMultipliedAfflictions(attack.DamageMultiplier) do
        if damageTypes[affliction.Identifier.Value] then total = total + affliction.Strength end
    end
    return total
end

-- blows add up while the node waits for them, as SS14's ArtifactDamageTrigger
local function addDamage(item, state, amount)
    local trigger = state.Nodes[state.Current].Trigger
    local threshold = trigger == "damage" and config.DamageThreshold or trigger == "highdamage" and config.HighDamageThreshold
    if not threshold or amount <= 0 then return end
    state.Damage = state.Damage + amount
    if state.Damage >= threshold then activate(item, state) end
end

-- Patched on the first Station round and kept for the session, as station/radio.lua does; outside Station rounds they
-- return at once. A blast lowers an item's condition without OnDamaged, so it is counted where it goes off.
local damagePatched = false
local function patchDamage()
    if damagePatched then return end
    damagePatched = true
    Hook.Patch("Traitormod.Xenoarch.Hit", "Barotrauma.Item", "AddDamage", function(item, ptable)
        if artifacts == nil or artifactKind(item) == "" then return end
        -- a blow handles the artifact as picking it up does, so one from the ruins gets its tree here too
        local state = stateOf(item)
        -- the artifact itself never breaks: it gets back what the blow took
        local attack, taken = ptable["attack"], ptable.ReturnValue.Damage
        if taken > 0 then item.Condition = item.Condition + taken end
        addDamage(item, state, physicalDamage(attack) * (attack.Duration ~= 0 and ptable["deltaTime"] or 1))
    end, Hook.HookMethodType.After)
    Hook.Patch("Traitormod.Xenoarch.Blast", "Barotrauma.Explosion", "Explode", function(explosion, ptable)
        if artifacts == nil then return end
        local damage = physicalDamage(explosion.Attack)
        if damage <= 0 then return end
        local center, range = ptable["worldPosition"], explosion.Attack.Range
        for item, state in pairs(artifacts) do
            local distance = not item.Removed and Vector2.Distance(item.WorldPosition, center)
            if distance and distance < range then
                addDamage(item, state, damage * (explosion.DistanceFalloff and 1 - distance / range or 1))
            end
        end
    end, Hook.HookMethodType.After)
end

-- an instrument played near the artifact, as SS14's music trigger
local instruments
Hook.Add("item.use", "Traitormod.Xenoarch.Music", function(used)
    if artifacts == nil or used == nil then return end
    if instruments == nil then
        instruments = {}
        for _, id in ipairs(config.Instruments) do instruments[id] = true end
    end
    if not instruments[used.Prefab.Identifier.Value] then return end
    for item, state in pairs(artifacts) do
        if not item.Removed and state.Nodes[state.Current].Trigger == "music"
            and Vector2.Distance(item.WorldPosition, used.WorldPosition) <= config.MusicRange then
            activate(item, state)
        end
    end
end)

Hook.Add("characterDeath", "Traitormod.Xenoarch.Death", function(character)
    if artifacts == nil then return end
    for item, state in pairs(artifacts) do
        if not item.Removed and state.Nodes[state.Current].Trigger == "death"
            and Vector2.Distance(item.WorldPosition, character.WorldPosition) <= config.DeathRange then
            activate(item, state)
        end
    end
end)

-- SS14's points: a node is worth more the deeper and the more dangerous; a seen but untriggered one a quarter
local function pointsOf(state)
    local total, all = 0, true
    for _, node in pairs(state.Nodes) do
        if node.Discovered then
            -- an own node is as dangerous as it is deep
            local effectDepth = node.Effect == "Own" and node.Depth or entryOf(config.Effects, node.Effect).Depth
            local danger = (node.Depth + entryOf(config.Triggers, node.Trigger).Depth + effectDepth) / 3
            total = total + config.PointsPerNode * config.DangerMultiplier ^ danger * (node.Triggered and 1 or 0.25)
        end
        if not node.Triggered then all = false end
    end
    return math.max(0, math.floor(total * (all and config.FullyExploredBonus or 1)) - state.Consumed)
end

local function powered(item)
    local component = item.GetComponentString("Powered")
    return component ~= nil and component.Voltage >= 0.5
end

-- the analyzer nearest the console and the artifact on it
local function analyzerOf(console)
    local best, bestDistance
    for item in pairs(consoles.Analyzers) do
        local distance = Vector2.Distance(item.WorldPosition, console.WorldPosition)
        if not item.Removed and distance <= config.AnalyzerRange and (best == nil or distance < bestDistance) then
            best, bestDistance = item, distance
        end
    end
    if best == nil then return nil, nil end
    for contained in best.OwnInventory.AllItems do
        if artifactKind(contained) ~= "" then return best, contained end
    end
    return best, nil
end

function xenoarch.Snapshot(console)
    local analyzer, artifact = analyzerOf(console)
    local scan = consoles.Scans[console]
    local snapshot = { Analyzer = analyzer ~= nil, Artifact = artifact ~= nil, Powered = analyzer ~= nil and powered(analyzer) and powered(console),
        Bias = analyzer ~= nil and (consoles.Bias[analyzer] or "up") or nil, Text = {} }
    if scan ~= nil and scan.Artifact == artifact and artifact ~= nil then
        local elapsed = Timer.GetTime() - scan.Started
        snapshot.Progress = math.min(1, elapsed / config.AnalysisSeconds)
        if elapsed >= config.AnalysisSeconds then
            -- the whole tree, as the node map of SS14's newer analysis console; what a node does only once it was seen
            local state = stateOf(artifact)
            snapshot.Result = { Current = state.Current, Points = pointsOf(state), Nodes = {} }
            for _, node in pairs(state.Nodes) do
                local entry = { Id = node.Id, Depth = node.Depth, Edges = node.Edges, Discovered = node.Discovered == true,
                    Triggered = node.Triggered == true }
                if node.Discovered then
                    entry.Trigger = Traitormod.Language.XenoarchTriggerHints[node.Trigger]
                    entry.Effect = Traitormod.Language.XenoarchEffectHints[effects.Hints[node.Effect]]
                end
                snapshot.Result.Nodes[#snapshot.Result.Nodes + 1] = entry
            end
        end
    end
    for _, key in ipairs(consoleTexts) do snapshot.Text[key] = Traitormod.GetText(key) end
    return snapshot
end

local function validConsole(client, console, requireSelected)
    return artifacts ~= nil and Game.RoundStarted and console ~= nil and not console.Removed and console.Prefab.Identifier == "vt_analysis_console"
        and client.Character ~= nil and client.Character.IsHuman and not client.Character.IsDead and not client.Character.IsIncapacitated
        and (not requireSelected or client.Character.SelectedItem == console) and console.CanClientAccess(client)
end

local function sendConsole(client, console)
    local message = Networking.Start("VoidTraitor_AnalysisSnapshot")
    message.WriteUInt16(UShort(console.ID))
    message.WriteString(json.encode(xenoarch.Snapshot(console)))
    Networking.Send(message, client.Connection)
end

refreshConsoles = function()
    for client, console in pairs(sessions) do
        if validConsole(client, console, false) then sendConsole(client, console) else sessions[client] = nil end
    end
end

local function consoleAction(client, console, action)
    local analyzer, artifact = analyzerOf(console)
    if analyzer ~= nil and powered(analyzer) and powered(console) and (action == "up" or action == "down") then
        -- SS14 lets the direction change once a second
        local now = Timer.GetTime()
        if (consoles.BiasChanged[analyzer] or 0) + 1 <= now then
            consoles.Bias[analyzer], consoles.BiasChanged[analyzer] = action, now
        end
        return
    end
    if artifact == nil or not powered(analyzer) or not powered(console) then return end
    if action == "scan" then
        consoles.Scans[console] = { Artifact = artifact, Started = Timer.GetTime() }
    elseif action == "extract" then
        local scan = consoles.Scans[console]
        if scan == nil or scan.Artifact ~= artifact or Timer.GetTime() - scan.Started < config.AnalysisSeconds then return end
        local state = stateOf(artifact)
        local points = pointsOf(state)
        if points > 0 and Traitormod.Research.AddPoints(points) then
            state.Consumed = state.Consumed + points
            Traitormod.Log(Traitormod.ClientLogName(client) .. " extracted " .. points .. " research points from artifact " .. artifact.ID)
        end
    end
end

function xenoarch.Start(mode)
    config, artifacts, sessions = mode.Xenoarch, {}, {}
    damageTypes = {}
    for _, id in ipairs(config.DamageTypes) do damageTypes[id] = true end
    patchDamage()
    consoles = { Analyzers = {}, Scans = {}, Bias = {}, BiasChanged = {}, Elapsed = 0 }
    pending = {}
    for item in Item.ItemList do
        if item.Prefab.Identifier == "vt_artifact_analyzer" then consoles.Analyzers[item] = true end
        if artifactKind(item) ~= "" then pending[item] = true end
    end
    -- shots and blows reach an item (Item.AddDamage) only if its prefab lets them
    for prefab in ItemPrefab.Prefabs do
        if prefab.ConfigElement.GetAttributeString("vtartifact", "") ~= "" then
            damageable[prefab] = { prefab.DamagedByProjectiles, prefab.DamagedByMeleeWeapons }
            prefab.DamagedByProjectiles, prefab.DamagedByMeleeWeapons = true, true
        end
    end
end

Hook.Add("item.created", "Traitormod.Xenoarch.NewItem", function(item)
    if artifacts == nil then return end
    if item.Prefab.Identifier == "vt_artifact_analyzer" then consoles.Analyzers[item] = true end
    if artifactKind(item) ~= "" then pending[item] = true end
end)

-- new artifacts' trees on the next frame; the effects kept on a node and open consoles once a second
Hook.Add("think", "Traitormod.Xenoarch.Update", function(deltaTime)
    if artifacts == nil then return end
    if next(pending) ~= nil then
        for item in pairs(pending) do
            -- by its hull: a spawned item learns its submarine only a frame later
            local hull = not item.Removed and Hull.FindHull(item.WorldPosition, nil, true, true) or nil
            if hull ~= nil and hull.Submarine == Submarine.MainSub then stateOf(item) end
        end
        pending = {}
    end
    consoles.Elapsed = consoles.Elapsed + deltaTime
    if consoles.Elapsed < 1 then return end
    consoles.Elapsed = 0
    for item, state in pairs(artifacts) do
        if item.Removed then
            artifacts[item] = nil
        else
            local node = state.Nodes[state.Current]
            local passive = effects.Passive[node.Effect]
            if passive ~= nil and passive.Tick ~= nil and not suppressed(item) then passive.Tick(item, entryOf(config.Effects, node.Effect)) end
        end
    end
    if next(sessions) ~= nil then refreshConsoles() end
end)

Networking.Receive("VoidTraitor_AnalysisOpen", function(message, client)
    local console = Entity.FindEntityByID(message.ReadUInt16())
    -- the request can arrive before the server sees the console selected; actions require the selection
    if not validConsole(client, console, false) then return end
    sessions[client] = console
    sendConsole(client, console)
end)
Networking.Receive("VoidTraitor_AnalysisAction", function(message, client)
    local console, action = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    if console == nil or sessions[client] ~= console then return end
    if action == "close" then sessions[client] = nil return end
    if not validConsole(client, console, true) then return end
    consoleAction(client, console, action)
    sendConsole(client, console)
end)
Hook.Add("roundEnd", "Traitormod.Xenoarch.End", function()
    artifacts, sessions, pending = nil, {}, {}
    for prefab, before in pairs(damageable) do prefab.DamagedByProjectiles, prefab.DamagedByMeleeWeapons = before[1], before[2] end
    damageable = {}
end)
Hook.Add("client.disconnected", "Traitormod.Xenoarch.Disconnect", function(client) sessions[client] = nil end)

return xenoarch
