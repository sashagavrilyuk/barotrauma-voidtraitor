local event = {}

-- Station's take on the SS14 bureaucratic error: the job slots for newcomers change. Mostly a few jobs get more or fewer
-- slots; sometimes every job closes but one, which takes everyone.
event.Name = "BureaucraticError"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

-- SS14 values
local closeAllButOneChance = 0.25
local minShare, maxShare = 0.2, 0.3
local minChange, maxChange = -3, 5
-- one captain is enough
local ignoredJobs = { captain = true }

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station"
end

event.Start = function ()
    local mode = Traitormod.SelectedGamemode
    -- the slot table comes from the config, which the next rounds read too, so the round gets its own copy
    local slots, jobs = {}, {}
    for id, limit in pairs(mode.JobSlots) do
        slots[id] = limit
        if not ignoredJobs[id] and JobPrefab.Prefabs.ContainsKey(id) then jobs[#jobs + 1] = id end
    end
    mode.JobSlots = slots

    if math.random() < closeAllButOneChance then
        local open = table.remove(jobs, math.random(#jobs))
        slots[open] = math.huge
        for _, id in ipairs(jobs) do slots[id] = 0 end
    else
        for _ = 1, math.floor(#jobs * (minShare + math.random() * (maxShare - minShare))) do
            local id = table.remove(jobs, math.random(#jobs))
            slots[id] = math.max(0, slots[id] + math.random(minChange, maxChange))
        end
    end

    mode:SendCoalitionAnnouncement(Traitormod.GetText("BureaucraticError"), "green")
    event.End()
end

event.End = function ()

end

return event
