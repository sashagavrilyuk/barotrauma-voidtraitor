local re = {}

local eventManagerDescriptor = LuaUserData.RegisterType("Barotrauma.EventManager") -- temporary
-- the game's own measures of the round, refreshed every 5 seconds in EventManager.CalculateCurrentIntensity
for _, field in ipairs({ "avgHullIntegrity", "floodingAmount", "enemyDanger" }) do
    LuaUserData.MakeFieldAccessible(eventManagerDescriptor, field)
end

re.OnGoingEvents = {}

re.ThisRoundEvents = {}
re.EventConfigs = Traitormod.Config.RandomEventConfig

re.AllowedEvents = {}

-- Director state for the current round; Config is nil when the director is off for the mode
re.Director = { QuietMinutes = 0 }

---Notes that a threat started, whatever started it: the next random threat has to wait and the calm count starts over
re.RecordThreat = function ()
    re.Director.QuietMinutes = 0
    re.Director.LastThreatTime = Traitormod.RoundTime
end

-- after the opening a random threat waits until the gap since the last threat has passed
local function threatHeldBack(event)
    local director = re.Director
    if director.Config == nil or not director.Threats[event.Name] or director.LastThreatTime == nil then return false end
    local now = Traitormod.RoundTime
    return now >= director.Config.OpeningMinutes * 60
        and now - director.LastThreatTime < director.Config.MinThreatGapMinutes * 60
end

local eventsByName = {}
for _, event in pairs(re.EventConfigs.Events) do
    eventsByName[event.Name] = event
end

-- the order the director checks help in; at most one help per check
local helpKinds = { "Collapse", "Medical", "Defense", "Hull", "Electrical" }
-- help of a kind from any source starts that kind's cooldown
local helpKindOf = {}
for _, kind in ipairs(helpKinds) do
    local config = re.EventConfigs.Director.Help[kind]
    for _, name in ipairs(config.Events) do helpKindOf[name] = kind end
    for _, name in ipairs(config.SevereEvents or {}) do helpKindOf[name] = kind end
end

---Checks if event is happenning right now
---@param eventName string event.Name field
---@return boolean
re.IsEventActive = function (eventName)
    if re.OnGoingEvents[eventName] then
        return true
    end
    return false
end

---Checks if event is registered in the mod
---@param eventName string event.Name field
---@return boolean
re.EventExists = function (eventName)
    local event = nil
    for _, value in pairs(re.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    return event ~= nil
end

local function canStartEvent(event)
    if event == nil or event.CanStart == nil then
        return true
    end

    local ok, result = pcall(event.CanStart, event)
    if not ok then
        Traitormod.Error("Event " .. tostring(event.Name) .. " CanStart failed: " .. tostring(result))
        return false
    end

    return result ~= false
end

local wrappedEventEnds = {}

local function ensureEventEndCleanup(event)
    if wrappedEventEnds[event] then return end

    local originalEnd = event.End
    event.End = function (isRoundEnd)
        re.OnGoingEvents[event.Name] = nil

        if originalEnd then
            return originalEnd(isRoundEnd)
        end
    end

    wrappedEventEnds[event] = true
end

---Triggers event
---@param eventName string event.Name field
re.TriggerEvent = function (eventName)
    if not Game.RoundStarted then
        Traitormod.Error("Tried to trigger event " .. eventName .. ", but round is not started.")
        return false
    end

    if re.OnGoingEvents[eventName] then
        Traitormod.Error("Event " .. eventName .. " is already running.")
        return
    end

    local event = nil
    --// TODO: maybe change so the event name can be used for searching
    for _, value in pairs(re.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    if event == nil then
        Traitormod.Error("Tried to trigger event " .. eventName .. " but it doesnt exist or is disabled.")
        return false
    end

    if not canStartEvent(event) then
        Traitormod.Log("Event " .. eventName .. " can not start right now.")
        return false
    end

    ensureEventEndCleanup(event)

    re.OnGoingEvents[eventName] = event

    local ok, result = pcall(event.Start)
    if not ok then
        re.OnGoingEvents[eventName] = nil
        Traitormod.Error("Event " .. eventName .. " Start failed: " .. tostring(result))
        return false
    end

    Traitormod.Stats.AddStat("EventTriggered", event.Name, 1)

    if re.ThisRoundEvents[eventName] == nil then
        re.ThisRoundEvents[eventName] = 0
    end
    re.ThisRoundEvents[eventName] = re.ThisRoundEvents[eventName] + 1

    local director = re.Director
    if director.Config ~= nil then
        if director.Threats[eventName] then re.RecordThreat() end
        if helpKindOf[eventName] then director.LastHelp[helpKindOf[eventName]] = Traitormod.RoundTime end
    end

    local alive = 0
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character ~= nil and not character.Removed and not character.IsDead
            and character.IsHuman and character.TeamID == CharacterTeamType.Team1 then
            alive = alive + 1
        end
    end
    Traitormod.Log(string.format("Event %s triggered (intensity %.2f, alive crew %d of %d players).",
        eventName, Game.GameSession.EventManager.CurrentIntensity, alive, #Client.ClientList))
    return true
end

---Randomly triggers an event if conditions are met
---@param event RandomEvent
re.CheckRandomEvent = function (event)
    if event.MinRoundTime ~= nil and Traitormod.RoundTime / 60 < event.MinRoundTime then
        return
    end

    if event.MaxRoundTime ~= nil and Traitormod.RoundTime / 60 > event.MaxRoundTime then
        return
    end

    local intensity = Game.GameSession.EventManager.CurrentIntensity

    if event.MinIntensity ~= nil and intensity < event.MinIntensity then
        return
    end

    if event.MaxIntensity ~= nil and intensity > event.MaxIntensity then
        return
    end

    if not canStartEvent(event) then
        return
    end

    if threatHeldBack(event) or math.random() > event.ChancePerMinute then
        return
    end

    Traitormod.Log("Selected random event to trigger \"" .. event.Name .. "\" with intensity " .. intensity .. " and round time " .. Traitormod.RoundTime / 60 .. " minutes.")

    re.TriggerEvent(event.Name)
end

re.SendEventMessage = function (text, icon, color)
    for key, value in pairs(Client.ClientList) do
        local messageChat = ChatMessage.Create("", text, ChatMessageType.Default, nil, nil)
        messageChat.Color = Color(200, 30, 241, 255)
        Game.SendDirectChatMessage(messageChat, value)

        local messageBox = ChatMessage.Create("", text, ChatMessageType.ServerMessageBoxInGame, nil, nil)
        messageBox.IconStyle = icon
        if color then messageBox.Color = color end
        Game.SendDirectChatMessage(messageBox, value)
    end 
end

-- events the director may start now: in this mode, inside their round time window, not running and not used up
local function startableEvents(names)
    local minutes = Traitormod.RoundTime / 60
    local result = {}
    for _, name in ipairs(names) do
        local event = eventsByName[name]
        if event ~= nil and re.AllowedEvents[name] and re.OnGoingEvents[name] == nil
            and (event.MinRoundTime == nil or minutes >= event.MinRoundTime)
            and (event.MaxRoundTime == nil or minutes <= event.MaxRoundTime)
            and not (event.OnlyOncePerRound and re.ThisRoundEvents[name] ~= nil)
            and canStartEvent(event) then
            table.insert(result, name)
        end
    end
    return result
end

local function startOneOf(options, reason)
    if #options == 0 then return false end
    local name = options[math.random(#options)]
    Traitormod.Log("Director starts " .. name .. ": " .. reason .. ".")
    return re.TriggerEvent(name) == true
end

local function isDown(character, lowVitality)
    -- Neurotrauma knocks people out with its own symptom while their vitality is still above zero
    local knockedOut = character.CharacterHealth.GetAffliction("sym_unconsciousness")
    return character.IsUnconscious or (knockedOut ~= nil and knockedOut.Strength > 0)
        or character.Vitality / character.MaxVitality <= lowVitality
end

local function countCrew(lowVitality)
    local crew = { Alive = 0, Down = 0, Dead = 0, Medics = 0, Security = 0, Mechanics = 0, Engineers = 0 }
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if character == nil or character.IsDead then
            if not client.SpectateOnly then crew.Dead = crew.Dead + 1 end
        elseif character.IsHuman and character.TeamID == CharacterTeamType.Team1
            and not Traitormod.AdminGhost.IsGhost(character) then
            crew.Alive = crew.Alive + 1
            if isDown(character, lowVitality) then
                crew.Down = crew.Down + 1
            elseif character.HasJob("medicaldoctor") or character.HasJob("surgeon") then
                crew.Medics = crew.Medics + 1
            elseif character.HasJob("securityofficer") or character.HasJob("captain") then
                crew.Security = crew.Security + 1
            elseif character.HasJob("mechanic") then
                crew.Mechanics = crew.Mechanics + 1
            elseif character.HasJob("engineer") then
                crew.Engineers = crew.Engineers + 1
            end
        end
    end
    return crew
end

-- Each returns how bad the trouble is (0 when there is none), whether crew of the right job are up to it,
-- the events that fit and what to write in the log.
local helpMeasures = {
    Collapse = function (crew, config)
        local collapsing = crew.Down * 2 >= crew.Alive or (crew.Alive <= config.MaxAlive and crew.Dead >= config.MinDead)
        if crew.Alive == 0 or not collapsing then return 0 end
        return crew.Down + crew.Dead, false, config.Events,
            string.format("%d of %d living crew down, %d dead", crew.Down, crew.Alive, crew.Dead)
    end,
    Medical = function (crew, config)
        if crew.Down == 0 then return 0 end
        return crew.Down, crew.Medics >= crew.Down, config.Events,
            string.format("%d crew down, %d medics up", crew.Down, crew.Medics)
    end,
    Defense = function (crew, config, eventManager)
        local danger = eventManager.enemyDanger
        if danger < config.EnemyDanger or crew.Down == 0 then return 0 end
        return danger, crew.Security > 0, config.Events,
            string.format("enemy danger %.2f, %d crew down, %d security up", danger, crew.Down, crew.Security)
    end,
    Hull = function (crew, config, eventManager)
        local integrity, flooding = eventManager.avgHullIntegrity, eventManager.floodingAmount
        if integrity > config.Integrity and flooding < config.Flooding then return 0 end
        local severe = integrity <= config.SevereIntegrity or flooding >= config.SevereFlooding
        return 1 - integrity + flooding, crew.Mechanics > 0, severe and config.SevereEvents or config.Events,
            string.format("hull integrity %.2f, flooding %.2f, %d mechanics up", integrity, flooding, crew.Mechanics)
    end,
    Electrical = function (crew, config)
        local broken = 0
        for _, item in ipairs(re.Director.ElectricalItems) do
            if not item.Removed and item.Condition <= 0 then broken = broken + 1 end
        end
        if broken < config.Broken then return 0 end
        return broken, crew.Engineers > 0, broken >= config.SevereBroken and config.SevereEvents or config.Events,
            string.format("%d power items broken, %d engineers up", broken, crew.Engineers)
    end,
}

-- Help only for trouble that lasts, by chance, and with able crew of the right job only when they are not coping.
local function checkHelp(director)
    local help = director.Config.Help
    if director.HelpGiven >= help.MaxPerRound then return end
    local crew = countCrew(help.LowVitality)
    local eventManager = Game.GameSession.EventManager
    local now = Traitormod.RoundTime
    for _, kind in ipairs(helpKinds) do
        local config = help[kind]
        local trouble, covered, events, reason = helpMeasures[kind](crew, config, eventManager)
        local state = director.Trouble[kind]
        if trouble <= 0 then
            director.Trouble[kind] = nil
        elseif state == nil then
            director.Trouble[kind] = { Since = now, Start = trouble }
        else
            local lasted = now - state.Since
            local lastHelp = director.LastHelp[kind]
            local ready = lasted >= help.SustainSeconds
                and (lastHelp == nil or now - lastHelp >= config.CooldownMinutes * 60)
                and (not covered or lasted >= help.OverwhelmedSeconds or trouble > state.Start)
            local chance = (covered and help.CoveredChance or help.Chance) * 0.5 ^ director.HelpGiven
            if ready and math.random() < chance
                and startOneOf(startableEvents(events), string.format("%s help, %s for %.0f s", kind, reason, lasted)) then
                director.HelpGiven = director.HelpGiven + 1
                director.LastHelpTime = now
                director.Trouble[kind] = nil
                return
            end
        end
    end
end

local function startBoredThreat(director, crew)
    local config = director.Config
    local now = Traitormod.RoundTime
    if director.QuietMinutes < config.LightThreatAfter
        or Game.GameSession.EventManager.CurrentIntensity >= config.CalmIntensity
        or (director.LastThreatTime ~= nil and now - director.LastThreatTime < config.MinThreatGapMinutes * 60)
        or (director.LastHelpTime ~= nil and now - director.LastHelpTime < config.GraceAfterHelpMinutes * 60) then
        return
    end
    local options = startableEvents(config.LightThreats)
    if director.QuietMinutes >= config.MediumThreatAfter or now >= config.MediumThreatFromMinute * 60 then
        for _, name in ipairs(startableEvents(config.MediumThreats)) do
            table.insert(options, name)
        end
    end
    if crew.Dead > 0 then
        local withGhostRoles = {}
        for _, name in ipairs(options) do
            if config.GhostRoleThreats[name] then table.insert(withGhostRoles, name) end
        end
        if #withGhostRoles > 0 then options = withGhostRoles end
    end
    startOneOf(options, string.format("%d calm minutes, %d players dead", director.QuietMinutes, crew.Dead))
end

local function directorMinute(director)
    local config = director.Config
    local now = Traitormod.RoundTime
    if Game.GameSession.EventManager.CurrentIntensity < config.CalmIntensity then
        director.QuietMinutes = director.QuietMinutes + 1
    end
    startBoredThreat(director, countCrew(config.Help.LowVitality))

    if director.NextNeutralTime ~= nil and now >= director.NextNeutralTime then
        startOneOf(startableEvents(config.Neutral), "neutral event")
        director.NextNeutralTime = nil
    end
    if director.NextNeutralTime == nil then
        director.NextNeutralTime = now + math.random(config.NeutralEveryMinutes[1], config.NeutralEveryMinutes[2]) * 60
    end

    if not director.FalseFlagDone and now >= config.FalseFlagFromMinute * 60
        and math.random() < config.FalseFlagChancePerMinute then
        local options = {}
        for role, names in pairs(config.FalseFlags) do
            if #Traitormod.RoleManager.FindCharactersByRole(role) == 0 then
                for _, name in ipairs(startableEvents(names)) do
                    table.insert(options, name)
                end
            end
        end
        director.FalseFlagDone = startOneOf(options, "false trail, no such antagonist this round")
    end
end

local lastRandomEventCheck = 0
local nextHelpCheck = 0
Hook.Add("think", "TraitorMod.RoundEvents.Think", function ()
    if not Game.RoundStarted then return end

    for _, event in pairs(re.OnGoingEvents) do
        if event.Think then event.Think() end
    end

    local director = re.Director
    local directing = director.Config ~= nil and Traitormod.RoundTime >= director.Config.OpeningMinutes * 60
    if directing and Timer.GetTime() > nextHelpCheck then
        checkHelp(director)
        nextHelpCheck = Timer.GetTime() + director.Config.Help.CheckSeconds
    end

    if Timer.GetTime() > lastRandomEventCheck then
        if directing then directorMinute(director) end
        for _, event in pairs(re.EventConfigs.Events) do
            if re.OnGoingEvents[event.Name] == nil and re.AllowedEvents[event.Name] then
                if not event.OnlyOncePerRound or re.ThisRoundEvents[event.Name] == nil then
                    re.CheckRandomEvent(event)
                end
            end
        end
        lastRandomEventCheck = Timer.GetTime() + 60
    end
end)

re.Initialize = function (allowedEvents, modeName)
    re.AllowedEvents = {}

    local groups = re.EventConfigs.ModeEvents
    if allowedEvents == nil and groups[modeName] ~= nil then
        for _, name in ipairs(groups.Shared) do
            re.AllowedEvents[name] = true
        end
        for _, name in ipairs(groups[modeName]) do
            re.AllowedEvents[name] = true
        end
    elseif allowedEvents == nil then
        for key, value in pairs(re.EventConfigs.Events) do
            re.AllowedEvents[value.Name] = true
        end
    else
        for key, value in pairs(allowedEvents) do
            re.AllowedEvents[value] = true
        end
    end

    for _, event in pairs(re.EventConfigs.Events) do
        if re.AllowedEvents[event.Name] and event.RoundStart then event.RoundStart() end
    end

    re.Director = { QuietMinutes = 0 }
    local director = re.EventConfigs.Director
    if director.Modes[modeName] then
        re.Director.Config = director
        re.Director.Threats = {}
        for _, name in ipairs(director.Threats) do
            re.Director.Threats[name] = true
        end
        re.Director.HelpGiven = 0
        re.Director.LastHelp = {}
        re.Director.Trouble = {}
        re.Director.ElectricalItems = {}
        for _, item in pairs(Submarine.MainSub.GetItems(false)) do
            local identifier = string.lower(item.Prefab.Identifier.Value)
            for _, part in ipairs(director.Help.Electrical.Items) do
                if string.find(identifier, part, 1, true) ~= nil then
                    table.insert(re.Director.ElectricalItems, item)
                    break
                end
            end
        end
    end
end

re.EndRound = function ()
    for key, value in pairs(re.OnGoingEvents) do
        value.End(true)
        re.OnGoingEvents[key] = nil
    end

    re.ThisRoundEvents = {}
    re.AllowedEvents = {}
    re.Director = { QuietMinutes = 0 }
end

for _, value in pairs(re.EventConfigs.Events) do
    if value.Init then value.Init() end
end

return re
