local event = {}

-- The ice vault over the station shifts: the Coalition warns the station, then a stretch of the roof gives way. A few
-- roof sections break open and let the water in, people under them are knocked down and hurt, and the whole station
-- hears and feels it through the seismic tremor effect of the clients (Void traitor pack Lua/client/tremor.lua).
event.Name = "IceCollapse"
event.MinRoundTime = 10
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local NET_TREMOR = "VoidTraitor_SeismicTremor"
local minWarningSeconds, maxWarningSeconds = 20, 40
local roofDepth = 300 -- the roof is searched this far down from the top of the station
local radius = 600
local minSections, maxSections = 2, 4
-- share of the wall's health: a section leaks from 0.1 on and has a large hole that floods a room in seconds from 0.7 on
local minDamage, maxDamage = 0.3, 0.6
local stunSeconds = 3
local minInjury, maxInjury = 10, 25

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station"
end

-- a random point of the roof and the roof sections around it; a roof section has no room above it, so the floors of
-- the upper rooms stay whole
local function pickCollapse()
    local station = Submarine.MainSub
    local top = station.WorldPosition.Y + station.Borders.Y
    local roof = {}
    for _, wall in pairs(Structure.WallList) do
        if wall.Submarine == station and wall.IsHorizontal and wall.WorldRect.Y >= top - roofDepth then
            for i = 0, wall.SectionCount - 1 do
                local position = wall.SectionPosition(i, true)
                if Hull.FindHull(Vector2(position.X, wall.WorldRect.Y + 32), nil, true) == nil then
                    table.insert(roof, { Wall = wall, Index = i, Position = position })
                end
            end
        end
    end

    local center = roof[math.random(#roof)].Position
    local sections = {}
    for _, section in ipairs(roof) do
        if Vector2.Distance(section.Position, center) <= radius then table.insert(sections, section) end
    end
    return center, sections
end

event.Start = function ()
    event.Center, event.Sections = pickCollapse()
    event.CollapseAt = Traitormod.RoundTime + math.random(minWarningSeconds, maxWarningSeconds)
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("IceCollapseWarning"), "green")
end

event.Think = function ()
    if Traitormod.RoundTime < event.CollapseAt then return end

    local sections = event.Sections
    for i = 1, math.min(#sections, math.random(minSections, maxSections)) do
        local section = table.remove(sections, math.random(#sections))
        local wall = section.Wall
        wall.AddDamage(section.Index, wall.MaxHealth * (minDamage + math.random() * (maxDamage - minDamage)))
    end

    local bluntTrauma = AfflictionPrefab.Prefabs["blunttrauma"]
    for _, character in pairs(Character.CharacterList) do
        if not character.IsDead and character.Submarine == Submarine.MainSub
            and Vector2.Distance(character.WorldPosition, event.Center) <= radius then
            character.Stun = math.max(character.Stun, stunSeconds)
            -- creatures without a head or torso take the hit on their main limb
            local animController = character.AnimController
            local limb = animController.GetLimb(math.random() < 0.5 and LimbType.Head or LimbType.Torso)
                or animController.MainLimb
            character.CharacterHealth.ApplyAffliction(limb, bluntTrauma.Instantiate(math.random(minInjury, maxInjury)))
        end
    end

    Networking.Send(Networking.Start(NET_TREMOR))
    event.End()
end

event.End = function ()
    event.Sections = nil
end

return event
