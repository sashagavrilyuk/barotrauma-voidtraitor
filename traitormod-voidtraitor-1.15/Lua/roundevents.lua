local re = {}

LuaUserData.RegisterType("Barotrauma.EventManager") -- temporary

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

local function threatChanceMultiplier(event, intensity)
    local director = re.Director
    if director.Config == nil or not director.Threats[event.Name] then return 1 end
    if director.LastThreatTime ~= nil
        and Traitormod.RoundTime - director.LastThreatTime < director.Config.MinThreatGapMinutes * 60 then
        return 0
    end
    -- a crew that is already in trouble gets no extra threats
    if intensity >= director.Config.CalmIntensity then return 1 end
    local extra = math.max(0, director.QuietMinutes - director.Config.QuietMinutes) * director.Config.BoostPerMinute
    return math.min(director.Config.MaxBoost, 1 + extra)
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

    if re.Director.Config ~= nil and re.Director.Threats[eventName] then
        re.RecordThreat()
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

    local multiplier = threatChanceMultiplier(event, intensity)
    if math.random() > event.ChancePerMinute * multiplier then
        return
    end

    Traitormod.Log("Selected random event to trigger \"" .. event.Name .. "\" with intensity " .. intensity .. " and round time " .. Traitormod.RoundTime / 60 .. " minutes."
        .. (re.Director.Config ~= nil and string.format(" Director chance x%.1f after %d calm minutes.", multiplier, re.Director.QuietMinutes) or ""))

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

local lastRandomEventCheck = 0
Hook.Add("think", "TraitorMod.RoundEvents.Think", function ()
    if not Game.RoundStarted then return end

    for _, event in pairs(re.OnGoingEvents) do
        if event.Think then event.Think() end
    end

    if Timer.GetTime() > lastRandomEventCheck then
        local director = re.Director
        if director.Config ~= nil and Game.GameSession.EventManager.CurrentIntensity < director.Config.CalmIntensity then
            director.QuietMinutes = director.QuietMinutes + 1
        end
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
