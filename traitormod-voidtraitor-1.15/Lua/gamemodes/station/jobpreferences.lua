-- The player's choice in the lobby's Station jobs window, as in SS14: a level for each role (1 low, 2 medium, 3 high,
-- only one high) and the outfit variant of each role. The server keeps it with the player's data and sends it, with the
-- roles of the config, on joining and after every change; station.lua hands out the roles from it.
local jobs = {}
Traitormod.StationJobs = jobs

local config = Traitormod.Config.GamemodeConfig.Station
local NET_JOBS = "VoidTraitor_StationJobs"
local NET_JOB_SET = "VoidTraitor_StationJobSet"
local NET_OUTFIT_SET = "VoidTraitor_StationOutfitSet"
local HIGH = 3

-- roles whose job is loaded, so a role of a disabled mod is neither shown nor taken
local function roleJob(id)
    local role = config.Roles[id]
    if role == nil or not JobPrefab.Prefabs.ContainsKey(role.Job) then return nil end
    return JobPrefab.Get(role.Job)
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
