-- The player's choice in the lobby's Station jobs window, as in SS14: a level for each role (1 low, 2 medium, 3 high,
-- only one high) and the outfit variant of each role. The server keeps it with the player's data and sends it, with the
-- roles of the config, on joining and after every change; station.lua hands out the roles from it.
-- The time the player has played each role is kept here too, for SS14's role timers (Requirements in the config);
-- admins see and change it in the admin menu's role time window.
local jobs = {}
Traitormod.StationJobs = jobs

local config = Traitormod.Config.GamemodeConfig.Station
local NET_JOBS = "VoidTraitor_StationJobs"
local NET_JOB_SET = "VoidTraitor_StationJobSet"
local NET_OUTFIT_SET = "VoidTraitor_StationOutfitSet"
local NET_TIMES_REQUEST = "VoidTraitor_StationRoleTimesRequest"
local NET_TIME_SET = "VoidTraitor_StationRoleTimeSet"
local NET_ROLE_UNLOCK = "VoidTraitor_StationRoleUnlock"
local NET_TIMES = "VoidTraitor_StationRoleTimes"
-- the most minutes an admin sets a time to
local MAX_MINUTES = 60000
local HIGH = 3
-- what a role's missing time is for, as the window names it
local OVERALL, ROLE, DEPARTMENT = 0, 1, 2

local departmentRoles = {}
for _, department in ipairs(config.Departments) do
    departmentRoles[department.Id] = department.Roles
end

-- roles whose job is loaded, so a role of a disabled mod is neither shown nor taken
local function roleJob(id)
    local role = config.Roles[id]
    if role == nil or not JobPrefab.Prefabs.ContainsKey(role.Job) then return nil end
    return JobPrefab.Get(role.Job)
end

-- seconds of play on each role, by role
function jobs.AddRoleTime(client, id, seconds)
    local times = Traitormod.GetData(client, "StationRoleTime") or {}
    times[id] = (times[id] or 0) + seconds
    Traitormod.SetData(client, "StationRoleTime", times)
end

-- What the player still lacks for a role: nil when it is open, otherwise a list of { Kind, Id, Seconds }.
function jobs.MissingTime(client, id)
    local requirements = config.Roles[id].Requirements
    if not config.RoleTimeRequirements or requirements == nil then return nil end
    local times = Traitormod.GetData(client, "StationRoleTime") or {}
    local missing
    for _, requirement in ipairs(requirements) do
        local kind, target, played = OVERALL, "", 0
        if requirement.Role ~= nil then
            kind, target, played = ROLE, requirement.Role, times[requirement.Role] or 0
        elseif requirement.Department ~= nil then
            kind, target = DEPARTMENT, requirement.Department
            for _, role in ipairs(departmentRoles[target]) do played = played + (times[role] or 0) end
        else
            played = Traitormod.GetData(client, "Playtime") or 0
        end
        local left = requirement.Hours * 3600 - played
        if left > 0 then
            missing = missing or {}
            missing[#missing + 1] = { Kind = kind, Id = target, Seconds = left }
        end
    end
    return missing
end

function jobs.Send(client)
    local levels = Traitormod.GetData(client, "StationJobs") or {}
    local outfits = Traitormod.GetData(client, "StationOutfits") or {}
    local message = Networking.Start(NET_JOBS)
    message.WriteByte(#config.Departments)
    for _, department in ipairs(config.Departments) do
        local shown = {}
        for _, id in ipairs(department.Roles) do
            if roleJob(id) ~= nil then shown[#shown + 1] = id end
        end
        message.WriteString(department.Id)
        message.WriteByte(#shown)
        for _, id in ipairs(shown) do message.WriteString(id) end
    end
    local roles = {}
    for id in pairs(config.Roles) do
        if roleJob(id) ~= nil then roles[#roles + 1] = id end
    end
    message.WriteByte(#roles)
    for _, id in ipairs(roles) do
        local job = roleJob(id)
        message.WriteString(id)
        message.WriteString(job.Identifier.Value)
        message.WriteByte(job.Variants)
        -- the karma the role needs, 0 when the player has enough
        message.WriteUInt16(client.Karma < job.MinKarma and math.ceil(job.MinKarma) or 0)
        message.WriteByte(levels[id] or 0)
        message.WriteByte(outfits[id] or 0)
        -- the time still missing, in minutes
        local missing = jobs.MissingTime(client, id) or {}
        message.WriteByte(#missing)
        for _, need in ipairs(missing) do
            message.WriteByte(need.Kind)
            message.WriteString(need.Id)
            message.WriteUInt16(math.min(math.ceil(need.Seconds / 60), 65535))
        end
    end
    Networking.Send(message, client.Connection)
end

-- one change per message, at most five a second; the reply carries everything, so the window shows what is stored
local nextSetTime = {}
local function accept(client)
    local now = Timer.GetTime()
    if (nextSetTime[client.SessionId] or 0) > now then return false end
    nextSetTime[client.SessionId] = now + 0.2
    return true
end

Networking.Receive(NET_JOB_SET, function(message, client)
    local id, level = message.ReadString(), message.ReadByte()
    if roleJob(id) == nil or level > HIGH or not accept(client) then return end
    local levels = Traitormod.GetData(client, "StationJobs") or {}
    if level == HIGH then
        for other, value in pairs(levels) do
            if value == HIGH then levels[other] = HIGH - 1 end
        end
    end
    levels[id] = level > 0 and level or nil
    Traitormod.SetData(client, "StationJobs", levels)
    Traitormod.QueuePreferenceSave()
    jobs.Send(client)
end)

Networking.Receive(NET_OUTFIT_SET, function(message, client)
    local id, variant = message.ReadString(), message.ReadByte()
    local job = roleJob(id)
    if job == nil or variant >= job.Variants or not accept(client) then return end
    local outfits = Traitormod.GetData(client, "StationOutfits") or {}
    outfits[id] = variant > 0 and variant or nil
    Traitormod.SetData(client, "StationOutfits", outfits)
    Traitormod.QueuePreferenceSave()
    jobs.Send(client)
end)

local function findClient(accountKey)
    for _, client in pairs(Client.ClientList) do
        if Traitormod.GetClientAccountKey(client) == accountKey then return client end
    end
    return nil
end

-- a player's total time and time on each role, for an admin
local function sendTimes(admin, target)
    local times = Traitormod.GetData(target, "StationRoleTime") or {}
    local roles = {}
    for id in pairs(times) do
        if config.Roles[id] ~= nil then roles[#roles + 1] = id end
    end
    local message = Networking.Start(NET_TIMES)
    message.WriteString(Traitormod.GetClientAccountKey(target))
    message.WriteString(target.Name)
    message.WriteUInt32(math.floor(Traitormod.GetData(target, "Playtime") or 0))
    message.WriteByte(#roles)
    for _, id in ipairs(roles) do
        message.WriteString(id)
        message.WriteUInt32(math.floor(times[id]))
    end
    Networking.Send(message, admin.Connection)
end

local function isAdmin(client)
    return client.HasPermission(ClientPermissions.ConsoleCommands)
end

Networking.Receive(NET_TIMES_REQUEST, function(message, client)
    local target = findClient(message.ReadString())
    if not isAdmin(client) or target == nil or not accept(client) then return end
    sendTimes(client, target)
end)

-- an admin sets the minutes on a role, or the total time when the role is ""
Networking.Receive(NET_TIME_SET, function(message, client)
    local target, id, minutes = findClient(message.ReadString()), message.ReadString(), message.ReadInt32()
    if not isAdmin(client) or target == nil or (id ~= "" and config.Roles[id] == nil) or minutes < 0
        or minutes > MAX_MINUTES or not accept(client) then
        return
    end
    if id == "" then
        Traitormod.SetData(target, "Playtime", minutes * 60)
    else
        local times = Traitormod.GetData(target, "StationRoleTime") or {}
        times[id] = minutes * 60
        Traitormod.SetData(target, "StationRoleTime", times)
    end
    Traitormod.Log(Traitormod.ClientLogName(client) .. ": " .. string.format(Traitormod.Language.StationRoleTimeSet,
        id == "" and "playtime" or id, minutes, Traitormod.ClientLogName(target)))
    sendTimes(client, target)
    jobs.Send(target)
end)

-- Where an admin's unlock puts the time a department lacks: on the role itself when it is in that department,
-- otherwise on the department's first role that is not a head, or its first role when all are heads.
local function departmentRole(id, department)
    for _, role in ipairs(departmentRoles[department]) do
        if role == id then return id end
    end
    for _, role in ipairs(departmentRoles[department]) do
        if config.Roles[role].Head == nil then return role end
    end
    return departmentRoles[department][1]
end

-- an admin gives a player the time a role still lacks
Networking.Receive(NET_ROLE_UNLOCK, function(message, client)
    local target, id = findClient(message.ReadString()), message.ReadString()
    if not isAdmin(client) or target == nil or config.Roles[id] == nil or not accept(client) then return end
    local missing = jobs.MissingTime(target, id)
    if missing ~= nil then
        -- one requirement at a time: a role's time also counts for its department; whole seconds, so each one is met
        while missing ~= nil do
            local need = missing[1]
            local seconds = math.ceil(need.Seconds)
            if need.Kind == OVERALL then
                Traitormod.AddData(target, "Playtime", seconds)
            else
                jobs.AddRoleTime(target, need.Kind == ROLE and need.Id or departmentRole(id, need.Id), seconds)
            end
            missing = jobs.MissingTime(target, id)
        end
        Traitormod.Log(Traitormod.ClientLogName(client) .. ": " .. string.format(Traitormod.Language.StationRoleUnlocked,
            id, Traitormod.ClientLogName(target)))
        jobs.Send(target)
    end
    sendTimes(client, target)
end)

Hook.Add("client.disconnected", "Traitormod.StationJobs.Disconnect", function(client)
    nextSetTime[client.SessionId] = nil
end)

return jobs
