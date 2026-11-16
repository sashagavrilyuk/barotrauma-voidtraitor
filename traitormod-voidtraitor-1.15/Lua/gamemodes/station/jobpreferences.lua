-- The player's choice in the lobby's Station jobs window, as in SS14: a level for each role (1 low, 2 medium, 3 high,
-- only one high) and the outfit variant of each role. The server keeps it with the player's data and sends it, with the
-- roles of the config, on joining and after every change; station.lua hands out the roles from it.
-- The time the player has played each role is kept here too, for SS14's role timers (Requirements in the config).
local jobs = {}
Traitormod.StationJobs = jobs

local config = Traitormod.Config.GamemodeConfig.Station
local NET_JOBS = "VoidTraitor_StationJobs"
local NET_JOB_SET = "VoidTraitor_StationJobSet"
local NET_OUTFIT_SET = "VoidTraitor_StationOutfitSet"
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
    jobs.Send(client)
end)

Networking.Receive(NET_OUTFIT_SET, function(message, client)
    local id, variant = message.ReadString(), message.ReadByte()
    local job = roleJob(id)
    if job == nil or variant >= job.Variants or not accept(client) then return end
    local outfits = Traitormod.GetData(client, "StationOutfits") or {}
    outfits[id] = variant > 0 and variant or nil
    Traitormod.SetData(client, "StationOutfits", outfits)
    jobs.Send(client)
end)

Hook.Add("client.disconnected", "Traitormod.StationJobs.Disconnect", function(client)
    nextSetTime[client.SessionId] = nil
end)

return jobs
