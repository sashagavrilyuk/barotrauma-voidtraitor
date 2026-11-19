-- Station anomalies, as SS14's (SS14 f00a972 Content.Shared/Anomaly/SharedAnomalySystem.cs, Content.Server/Anomaly;
-- config/station.lua Anomalies; pack items/anomalies.xml and Lua/client/station/anomalies.lua). An anomaly has a
-- stability, a severity and a health and pulses every few minutes with its kind's effect. Above the growth threshold
-- each pulse makes it more severe; at full severity it goes supercritical and ends with a big effect, leaving its core.
-- Below the decay threshold it loses health and fades, leaving an inert core. The scanner reads it, a vessel the scanner
-- linked to it turns it into research points, and the APE's particles move its numbers. The anomaly generator in
-- science and a station event bring new ones.
local anomalies = {}
Traitormod.Anomalies = anomalies
local effects = dofile(Traitormod.Path .. "/Lua/gamemodes/station/anomaly_effects.lua")
local weightedRandom = dofile(Traitormod.Path .. "/Lua/weightedrandom.lua")
local json = require("json")

-- the readings SS14's SecretDataAnomaly can hide from the scanner
local SECRETS = { "Severity", "Stability", "Points", "Danger", "Unstable", "Containment", "Transformation", "Behavior" }
local ROLES = { "Danger", "Unstable", "Containment", "Transformation" }
local config, states, typeOf
-- scanner -> the anomaly it read last; vessel -> its anomaly or false; generator -> its timers
local scanned, vessels, generators, sessions = {}, {}, {}, {}
-- when each client last asked for a window or pressed a button
local requests = {}
local updating, elapsed, serverTakesPoints = false, 0, true

local function between(range) return range[1] + math.random() * (range[2] - range[1]) end

local function powered(item)
    local component = item.GetComponentString("Powered")
    return component ~= nil and component.Voltage >= 0.5
end

-- a property the game syncs to every client, as pointitems.lua does
local function setProperty(item, owner, name, value)
    owner[name] = value
    Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(owner.SerializableProperties[Identifier(name)], owner))
end

-- shown to the clients near the item: a pulse, a bolt to target, the vessel's beep, a blast
function anomalies.Fx(item, kind, range, target)
    local message = Networking.Start("VoidTraitor_AnomalyFx")
    message.WriteUInt16(UShort(item.ID))
    message.WriteString(kind)
    message.WriteSingle(item.WorldPosition.X)
    message.WriteSingle(item.WorldPosition.Y)
    target = target or item.WorldPosition
    message.WriteSingle(target.X)
    message.WriteSingle(target.Y)
    message.WriteSingle(range or 0)
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and Vector2.Distance(character.WorldPosition, item.WorldPosition) < 3000 then
            Networking.Send(message, client.Connection)
        end
    end
end

-- SS14's ShuffleParticlesEffect: each role gets a particle of its own
local function shuffleParticles(state)
    local left = {}
    for _, particle in ipairs(config.Particles) do left[#left + 1] = particle end
    state.Particles = {}
    for _, role in ipairs(ROLES) do state.Particles[role] = table.remove(left, math.random(#left)) end
end

local function hideReadings(state)
    local range = state.Behavior.Secrets or config.Secrets
    local left = {}
    for _, key in ipairs(SECRETS) do left[#left + 1] = key end
    state.Secret = {}
    -- SS14's Random.Next leaves the upper bound out
    for _ = 1, math.min(math.random(range[1], range[2] - 1), #left) do state.Secret[table.remove(left, math.random(#left))] = true end
end

local function setBehavior(state, behavior)
    state.Behavior = behavior
    if behavior.Secrets ~= nil then hideReadings(state) end
    state.NextJump = behavior.Jump ~= nil and Timer.GetTime() + between(behavior.Jump.Seconds) or nil
end

local startSupercritical, finish

local function changeStability(state, change)
    state.Stability = math.max(0, math.min(1, state.Stability + change))
end

local function changeSeverity(item, state, change)
    if state.Severity + change >= 1 then startSupercritical(item, state) end
    state.Severity = math.max(0, math.min(1, state.Severity + change))
end

local function changeHealth(item, state, change)
    if state.Health + change < 0 then
        finish(item, state, false)
        return
    end
    state.Health = math.max(0, math.min(1, state.Health + change))
end

-- SS14's GetPulseLength: the further past the growth threshold, the longer between pulses
local function pulseLength(state)
    local modifier = math.max(0, math.min(1, (state.Stability - config.GrowthThreshold) / config.GrowthThreshold))
    local seconds = config.PulseSeconds
    return ((seconds[2] - seconds[1]) * modifier + seconds[1]) * (state.Behavior.PulseFrequency or 1)
end

local function refreshPulse(state)
    state.NextPulse = Timer.GetTime() + pulseLength(state) * (1 + (math.random() * 2 - 1) * config.PulseVariation)
end

-- SS14's GetAnomalyPointValue
local function pointValue(state)
    local multiplier = state.Stability > config.GrowthThreshold and config.GrowingPointMultiplier or 1
    multiplier = multiplier * (1.5 ^ state.Health - 0.5) * (state.Behavior.Points or 1)
    local severity = 1 / (1 + math.exp(-7 * (state.Severity - 0.5)))
    local range = config.PointsPerSecond
    return math.floor((range[2] - range[1]) * severity * multiplier) + range[1]
end

-- SS14's SpawnOnRandomGridLocation: somewhere inside the station, here a dry room big enough for the anomaly; with a
-- centre, a room between the two distances from it
function anomalies.RandomSpot(center, minDistance, maxDistance)
    local station, rooms = Submarine.MainSub, {}
    for hull in Hull.HullList do
        if hull.Submarine == station and not hull.IsAirlock and not hull.IsWetRoom and not hull.AvoidStaying
            and hull.Rect.Width >= 200 and hull.Rect.Height >= 150 and hull.WaterPercentage < 30 then
            local distance = center ~= nil and Vector2.Distance(hull.WorldPosition, center) or 0
            if center == nil or (distance >= minDistance and distance <= maxDistance) then rooms[#rooms + 1] = hull end
        end
    end
    if #rooms == 0 then return nil end
    local rect = rooms[math.random(#rooms)].WorldRect
    return Vector2(rect.X + rect.Width * (0.2 + 0.6 * math.random()), rect.Y - rect.Height * (0.3 + 0.3 * math.random()))
end

-- a teleport of the anomaly; the clients learn where a resting item went only when the server sends it at once
function anomalies.MoveTo(item, position)
    anomalies.Fx(item, "teleport", 0, item.WorldPosition)
    local station = item.Submarine
    item.SetTransform(ConvertUnits.ToSimUnits(station ~= nil and position - station.Position or position), 0, true, true, station)
    item.PositionUpdateInterval = 0
    anomalies.Fx(item, "teleport", 0, position)
end

-- SS14's ChaoticJump: a short jump in a random direction, onto a spot inside the station
local function jump(item, state)
    local jumpConfig = state.Behavior.Jump
    state.NextJump = Timer.GetTime() + between(jumpConfig.Seconds)
    for _ = 1, 10 do
        local angle = math.random() * math.pi * 2
        local target = item.WorldPosition + Vector2(math.cos(angle), math.sin(angle)) * between(jumpConfig.Distance)
        local hull = Hull.FindHull(target, nil, true)
        if hull ~= nil and hull.Submarine == item.Submarine then
            anomalies.MoveTo(item, target)
            return
        end
    end
end

local update

local function wake()
    if updating then return end
    updating, elapsed = true, 0
    Hook.Add("think", "Traitormod.Anomalies.Update", update)
end

-- SS14's OnMapInit; the first pulse comes three times later
local function register(item)
    if states == nil or states[item] ~= nil or typeOf[item.Prefab.Identifier.Value] == nil then return end
    local state = { Type = typeOf[item.Prefab.Identifier.Value], Stability = 0, Severity = 0, Health = 1, Continuity = between(config.Continuity) }
    setBehavior(state, config.Behaviors[weightedRandom.Choose(config.Behaviors, "Weight")])
    if state.Secret == nil then hideReadings(state) end
    changeStability(state, between(config.InitialStability))
    changeSeverity(item, state, between(config.InitialSeverity))
    shuffleParticles(state)
    states[item] = state
    state.NextPulse = Timer.GetTime() + pulseLength(state) * 3
    Traitormod.Log("Anomaly " .. item.ID .. " (" .. state.Type.Id .. ") appeared, behaviour " .. state.Behavior.Id)
    wake()
end

local function pulse(item, state)
    refreshPulse(state)
    if state.Stability > config.GrowthThreshold then
        -- SS14's GetSeverityIncreaseFromGrowth
        changeSeverity(item, state, (1 + math.max(state.Stability - config.GrowthThreshold, 0) * 10) * config.SeverityGrowth)
    end
    changeStability(state, between(config.PulseStability) * state.Severity)
    anomalies.Fx(item, "pulse")
    effects[state.Type.Id].Pulse(item, state.Type, state.Stability, state.Severity, state.Behavior.PulsePower or 1)
    if state.Behavior.ShuffleOnPulse ~= nil and math.random() < state.Behavior.ShuffleOnPulse then shuffleParticles(state) end
    Traitormod.Log(string.format("Anomaly %d pulsed: stability %.2f, severity %.2f", item.ID, state.Stability, state.Severity))
end

startSupercritical = function(item, state)
    if state.SupercriticalAt ~= nil then return end
    state.SupercriticalAt = Timer.GetTime() + config.SupercriticalSeconds
    setProperty(item, item.GetComponentString("LightComponent"), "Flicker", 0.8)
    anomalies.Fx(item, "supercritical")
    Traitormod.Log("Anomaly " .. item.ID .. " is going supercritical")
end

-- SS14's EndAnomaly: the core falls out, the vessel lets go, and blows up if the anomaly went supercritical
finish = function(item, state, supercritical)
    if states[item] == nil then return end
    states[item] = nil
    if supercritical then effects[state.Type.Id].Supercritical(item, state.Type, state.Behavior.PulsePower or 1) end
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[supercritical and state.Type.Core or state.Type.InertCore], item.WorldPosition)
    for vessel, anomaly in pairs(vessels) do
        if anomaly == item then
            vessels[vessel] = false
            setProperty(vessel, vessel.GetComponentString("LightComponent"), "IsOn", false)
            if supercritical then
                local blast = config.VesselExplosion
                Explosion(blast.Range, blast.Force, blast.Damage, blast.StructureDamage, blast.Damage, 0).Explode(vessel.WorldPosition, vessel)
                anomalies.Fx(vessel, "explosion", blast.Range)
            end
        end
    end
    Entity.Spawner.AddEntityToRemoveQueue(item)
    Traitormod.Log("Anomaly " .. item.ID .. (supercritical and " went supercritical" or " decayed"))
end

-- what one APE particle does, SS14's OnStartCollide; the particle's OnImpact effect (items/anomalies.xml) reports it
Hook.Add("VoidTraitor.AnomalyParticle", "Traitormod.Anomalies.Particle", function(_, _, _, targets, _, element)
    if states == nil then return end
    local particle, numbers = element.GetAttributeString("particle", ""), config.Particle
    for target in targets do
        local state = states[target]
        if state ~= nil then
            local function vary(value) return value * (state.Behavior.Sensitivity or 1) * between(numbers.Variation) end
            if particle == state.Particles.Unstable then changeStability(state, vary(numbers.Stability)) end
            if particle == state.Particles.Danger then changeSeverity(target, state, vary(numbers.Severity)) end
            if particle == state.Particles.Containment then
                changeHealth(target, state, vary(numbers.Health))
                changeStability(state, vary(numbers.WeakeningStability))
            end
            if particle == state.Particles.Transformation then
                changeSeverity(target, state, vary(numbers.Severity))
                if math.random() < state.Continuity then setBehavior(state, config.Behaviors[weightedRandom.Choose(config.Behaviors, "Weight")]) end
            end
            if state.Behavior.ShuffleOnHit ~= nil and math.random() < state.Behavior.ShuffleOnHit then shuffleParticles(state) end
        end
    end
end)

function anomalies.CanSpawn()
    return states ~= nil and Submarine.MainSub ~= nil and anomalies.RandomSpot() ~= nil
end

-- an anomaly of a random kind at a random spot of the station
function anomalies.Spawn()
    local position = anomalies.RandomSpot()
    if states == nil or position == nil then return false end
    local station = Submarine.MainSub
    local kind = config.Types[math.random(#config.Types)]
    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.Prefabs[kind.Item], position - station.Position, station, nil, nil, register)
    return true
end

local function stabilityText(state)
    return state.Stability < config.DecayThreshold and Traitormod.GetText("AnomalyStabilityLow")
        or state.Stability > config.GrowthThreshold and Traitormod.GetText("AnomalyStabilityHigh")
        or Traitormod.GetText("AnomalyStabilityMedium")
end

local function clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function scannerOf(character)
    for held in character.HeldItems do
        if held.Prefab.Identifier == "vt_anomaly_scanner" then return held end
    end
end

-- SS14's GetScannerMessage; a hidden reading shows as an error
local function anomalyPanel(state)
    local language, lines = Traitormod.Language, {}
    local function add(text, color) lines[#lines + 1] = { Text = text, Color = color } end
    local function reading(secret, key, value, color)
        if state.Secret[secret] then add(Traitormod.FormatText(key, language.AnomalyError), "error") else add(Traitormod.FormatText(key, value), color) end
    end
    reading("Severity", "AnomalySeverity", string.format("%.2f%%", state.Severity * 100))
    reading("Stability", "AnomalyStability", stabilityText(state),
        state.Stability < config.DecayThreshold and "warning" or state.Stability > config.GrowthThreshold and "danger" or "good")
    reading("Points", "AnomalyPoints", pointValue(state))
    add("")
    add(language.AnomalyParticleReadout)
    reading("Danger", "AnomalyParticleDanger", language.AnomalyParticles[state.Particles.Danger], "danger")
    reading("Unstable", "AnomalyParticleUnstable", language.AnomalyParticles[state.Particles.Unstable], "unstable")
    reading("Containment", "AnomalyParticleContainment", language.AnomalyParticles[state.Particles.Containment], "warning")
    reading("Transformation", "AnomalyParticleTransformation", language.AnomalyParticles[state.Particles.Transformation], "transformation")
    add("")
    add(language.AnomalyBehaviorTitle)
    if state.Secret.Behavior then
        add(language.AnomalyBehaviorUnknown, "error")
    else
        add(language.AnomalyBehaviors[state.Behavior.Id])
        add(Traitormod.FormatText("AnomalyBehaviorPoints", math.floor((state.Behavior.Points or 1) * 100)), "warning")
    end
    add("")
    if state.SupercriticalAt ~= nil then
        add(language.AnomalySupercritical, "danger")
    else
        add(Traitormod.FormatText("AnomalyPulseTimer", clock(state.NextPulse - Timer.GetTime())))
    end
    return { Title = language.AnomalyScannerTitle, Lines = lines, Buttons = {} }
end

-- the scanner in hand has read an anomaly that no vessel holds yet
local function linkableAnomaly(character)
    local scanner = scannerOf(character)
    local anomaly = scanner ~= nil and scanned[scanner] or nil
    if anomaly == nil or states[anomaly] == nil then return nil end
    for _, linked in pairs(vessels) do
        if linked == anomaly then return nil end
    end
    return anomaly
end

local function vesselPanel(vessel, character)
    local language, lines = Traitormod.Language, {}
    local anomaly = vessels[vessel]
    local state = anomaly and states[anomaly] or nil
    if state == nil then
        lines[1] = { Text = language.AnomalyVesselEmpty, Color = "muted" }
    else
        lines[1] = { Text = language.AnomalyVesselLinked, Color = "good" }
        lines[2] = { Text = Traitormod.FormatText("AnomalyStability", stabilityText(state)) }
        if not powered(vessel) then
            lines[3] = { Text = language.AnomalyVesselNoPower, Color = "warning" }
        elseif not serverTakesPoints then
            lines[3] = { Text = language.AnomalyVesselNoServer, Color = "warning" }
        else
            lines[3] = { Text = Traitormod.FormatText("AnomalyVesselOutput", pointValue(state)) }
        end
    end
    return { Title = language.AnomalyVesselTitle, Lines = lines,
        Buttons = { { Action = "link", Label = language.AnomalyVesselLink, Enabled = state == nil and linkableAnomaly(character) ~= nil } } }
end

local function fuelOf(generator)
    local count = 0
    for contained in generator.OwnInventory.AllItems do
        if contained.Prefab.Identifier == config.Generator.Material then count = count + 1 end
    end
    return count
end

local function generatorPanel(generator)
    local language, timers, now = Traitormod.Language, generators[generator], Timer.GetTime()
    local material = ItemPrefab.Prefabs[config.Generator.Material]
    local lines = { { Text = Traitormod.FormatText("AnomalyGeneratorFuel", fuelOf(generator), material.Name.Value) } }
    lines[2] = now < timers.CooldownEnd and { Text = Traitormod.FormatText("AnomalyGeneratorCooldown", clock(timers.CooldownEnd - now)) }
        or { Text = language.AnomalyGeneratorReady, Color = "good" }
    if not powered(generator) then
        lines[3] = { Text = language.AnomalyGeneratorNoPower, Color = "warning" }
    elseif timers.GeneratingEnd ~= nil then
        lines[3] = { Text = language.AnomalyGeneratorGenerating, Color = "transformation" }
    elseif timers.CreatedAt ~= nil and now - timers.CreatedAt < 15 then
        lines[3] = { Text = language.AnomalyGeneratorCreated, Color = "good" }
    end
    local ready = powered(generator) and timers.GeneratingEnd == nil and now >= timers.CooldownEnd and fuelOf(generator) > 0
    return { Title = language.AnomalyGeneratorTitle, Lines = lines,
        Buttons = { { Action = "generate", Label = language.AnomalyGeneratorGenerate, Enabled = ready } } }
end

local function panelOf(item, character)
    local panel = states[item] ~= nil and anomalyPanel(states[item]) or vessels[item] ~= nil and vesselPanel(item, character)
        or generatorPanel(item)
    panel.Close = Traitormod.GetText("AnomalyClose")
    return panel
end

local function validPanel(client, item, requireSelected)
    local character = client.Character
    if states == nil or not Game.RoundStarted or item == nil or not LuaUserData.IsTargetType(item, "Barotrauma.Item") or item.Removed then return false end
    if states[item] == nil and vessels[item] == nil and generators[item] == nil then return false end
    if character == nil or not character.IsHuman or character.IsDead or character.IsIncapacitated then return false end
    if requireSelected and character.SelectedItem ~= item then return false end
    -- only the scanner in hand reads an anomaly, as SS14's
    if states[item] ~= nil and scannerOf(character) == nil then return false end
    return item.CanClientAccess(client)
end

-- a window or a button at most twice a second per client
local function tooSoon(client)
    local now = Timer.GetTime()
    if (requests[client] or 0) + 0.5 > now then return true end
    requests[client] = now
    return false
end

local function sendPanel(client, item)
    local message = Networking.Start("VoidTraitor_AnomalyPanel")
    message.WriteUInt16(UShort(item.ID))
    message.WriteString(json.encode(panelOf(item, client.Character)))
    Networking.Send(message, client.Connection)
end

local function panelAction(client, item, action)
    local character = client.Character
    if action == "link" and vessels[item] ~= nil and not (vessels[item] and states[vessels[item]]) then
        local anomaly = linkableAnomaly(character)
        if anomaly == nil then return end
        vessels[item] = anomaly
        setProperty(item, item.GetComponentString("LightComponent"), "IsOn", true)
        Traitormod.Log(Traitormod.ClientLogName(client) .. " linked anomaly " .. anomaly.ID .. " to vessel " .. item.ID)
    elseif action == "generate" and generators[item] ~= nil then
        local timers, now = generators[item], Timer.GetTime()
        if not powered(item) or timers.GeneratingEnd ~= nil or now < timers.CooldownEnd then return end
        for contained in item.OwnInventory.AllItems do
            if contained.Prefab.Identifier == config.Generator.Material then
                Entity.Spawner.AddEntityToRemoveQueue(contained)
                timers.GeneratingEnd = now + config.Generator.GenerationSeconds
                timers.CooldownEnd = now + config.Generator.CooldownSeconds
                anomalies.Fx(item, "generate")
                Traitormod.Log(Traitormod.ClientLogName(client) .. " started the anomaly generator " .. item.ID)
                wake()
                return
            end
        end
    end
end

-- the vessel's light shows how its anomaly fares, as the SS14 vessel's screen
local VESSEL_COLORS = { stable = Color(90, 220, 120, 255), decaying = Color(240, 200, 60, 255), growing = Color(240, 70, 60, 255) }

local function tick()
    local now = Timer.GetTime()
    for item, state in pairs(states) do
        if item.Removed then
            states[item] = nil
        elseif state.SupercriticalAt ~= nil and now >= state.SupercriticalAt then
            finish(item, state, true)
        else
            if state.Stability < config.DecayThreshold then changeHealth(item, state, config.HealthPerSecond) end
            if states[item] ~= nil then
                if now >= state.NextPulse then pulse(item, state) end
                if state.NextJump ~= nil and now >= state.NextJump then jump(item, state) end
                local passive = effects[state.Type.Id].Tick
                if passive ~= nil then passive(item, state.Type, state.Stability, state.Severity) end
            end
        end
    end
    local points = 0
    for vessel, anomaly in pairs(vessels) do
        local state = anomaly and states[anomaly] or nil
        if vessel.Removed then
            vessels[vessel] = nil
        elseif state ~= nil then
            if powered(vessel) then points = points + pointValue(state) end
            -- SS14's UpdateVessels: it beeps while the anomaly is unstable, the faster the further it went
            local share = state.Stability <= config.DecayThreshold and (config.DecayThreshold - state.Stability) / config.DecayThreshold
                or state.Stability >= config.GrowthThreshold and (state.Stability - config.GrowthThreshold) / (1 - config.GrowthThreshold) or nil
            local look = share == nil and "stable" or state.Stability <= config.DecayThreshold and "decaying" or "growing"
            if look ~= state.VesselLook then
                state.VesselLook = look
                setProperty(vessel, vessel.GetComponentString("LightComponent"), "LightColor", VESSEL_COLORS[look])
            end
            if share ~= nil and now >= (state.NextBeep or 0) then
                anomalies.Fx(vessel, "beep")
                state.NextBeep = now + 1.25 * (1 - share) + 0.75
            end
        end
    end
    if points > 0 then serverTakesPoints = Traitormod.Research.AddPoints(points) end
    for generator, timers in pairs(generators) do
        if generator.Removed then
            generators[generator] = nil
        elseif timers.GeneratingEnd ~= nil and now >= timers.GeneratingEnd then
            timers.GeneratingEnd, timers.CreatedAt = nil, now
            anomalies.Spawn()
        end
    end
    for client, item in pairs(sessions) do
        if validPanel(client, item, false) then sendPanel(client, item) else sessions[client] = nil end
    end
end

-- once a second, and only while there is an anomaly, a generator at work or a window open
update = function(deltaTime)
    elapsed = elapsed + deltaTime
    if elapsed < 1 then return end
    elapsed = 0
    tick()
    local generating = false
    for _, timers in pairs(generators) do
        if timers.GeneratingEnd ~= nil then generating = true end
    end
    if next(states) == nil and next(sessions) == nil and not generating then
        updating = false
        Hook.Remove("think", "Traitormod.Anomalies.Update")
    end
end

local function track(item)
    local id = item.Prefab.Identifier.Value
    if id == "vt_anomaly_vessel" then vessels[item] = false
    elseif id == "vt_anomaly_generator" then generators[item] = { CooldownEnd = 0 }
    else register(item) end
end

function anomalies.Start(mode)
    config, states, scanned, vessels, generators, sessions = mode.Anomalies, {}, {}, {}, {}, {}
    serverTakesPoints = true
    typeOf = {}
    for _, kind in ipairs(config.Types) do typeOf[kind.Item] = kind end
    for item in Item.ItemList do track(item) end
end

Hook.Add("item.created", "Traitormod.Anomalies.NewItem", function(item)
    if states ~= nil then track(item) end
end)

Networking.Receive("VoidTraitor_AnomalyOpen", function(message, client)
    local item = Entity.FindEntityByID(message.ReadUInt16())
    -- the request can arrive before the server sees the item selected; actions require the selection
    if tooSoon(client) or not validPanel(client, item, false) then return end
    if states[item] ~= nil then scanned[scannerOf(client.Character)] = item end
    sessions[client] = item
    sendPanel(client, item)
    wake()
end)
Networking.Receive("VoidTraitor_AnomalyAction", function(message, client)
    local item, action = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    if item == nil or sessions[client] ~= item then return end
    if action == "close" then sessions[client] = nil return end
    if tooSoon(client) or not validPanel(client, item, true) then return end
    panelAction(client, item, action)
    sendPanel(client, item)
end)
Hook.Add("roundEnd", "Traitormod.Anomalies.End", function()
    states, sessions = nil, {}
    if updating then
        updating = false
        Hook.Remove("think", "Traitormod.Anomalies.Update")
    end
end)
Hook.Add("client.disconnected", "Traitormod.Anomalies.Disconnect", function(client) sessions[client], requests[client] = nil, nil end)

return anomalies
