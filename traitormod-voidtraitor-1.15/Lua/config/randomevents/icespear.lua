local Tremor = dofile(Traitormod.Path .. "/Lua/config/randomevents/utility/tremor.lua")

local event = {}

-- SS14's immovable rod: an ice spear goes through the whole station from top to bottom. The Coalition warns the station
-- first; then every floor and ceiling on the spear's line gets a large hole, whoever stands on the line dies, and the
-- whole station shakes with the tremor.
event.Name = "IceSpear"
event.MinRoundTime = 30
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local minWarningSeconds, maxWarningSeconds = 10, 20
-- people this far from the line to either side are hit
local halfWidth = 60

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station"
end

event.Start = function ()
    event.StrikeAt = Traitormod.RoundTime + math.random(minWarningSeconds, maxWarningSeconds)
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("IceSpear"), "attention")
end

event.Think = function ()
    if Traitormod.RoundTime < event.StrikeAt then return end

    local station = Submarine.MainSub
    local floors = {}
    for _, wall in pairs(Structure.WallList) do
        if wall.Submarine == station and wall.IsHorizontal then table.insert(floors, wall) end
    end
    -- a point of a random floor, so that the line goes through the station
    local rect = floors[math.random(#floors)].WorldRect
    local x = rect.X + math.random() * rect.Width

    for _, wall in ipairs(floors) do
        if wall.WorldRect.X <= x and x <= wall.WorldRect.X + wall.WorldRect.Width then
            wall.AddDamage(wall.FindSectionIndex(Vector2(x, wall.WorldPosition.Y), true, true), wall.MaxHealth)
        end
    end

    for _, character in pairs(Character.CharacterList) do
        if not character.IsDead and character.Submarine == station and math.abs(character.WorldPosition.X - x) <= halfWidth then
            character.Kill(CauseOfDeathType.Unknown, nil)
        end
    end

    Tremor()
    event.End()
end

event.End = function ()

end

return event
