local Tremor = dofile(Traitormod.Path .. "/Lua/config/randomevents/utility/tremor.lua")

local event = {}

-- Europa's tidal tectonics shake the sub: everyone aboard staggers and is thrown aside with the loose items, a few
-- junction boxes take a hit and wall sections crack.
event.Name = "SeismicTremor"
event.MinRoundTime = 8
event.MinIntensity = 0
event.MaxIntensity = 0.5
event.ChancePerMinute = 0.01
event.OnlyOncePerRound = false

local stunSeconds = 2
local junctionBoxDamage = 40
-- one crack per this many wall sections, so a large station cracks in many more places than a sub
local sectionsPerCrack = 150
local minCracks = 2
-- share of the section's health; a section has a large hole from 0.7 on
local minDamage, maxDamage = 0.5, 0.8

event.CanStart = function ()
    return Submarine.MainSub ~= nil
end

event.Start = function ()
    for _, character in pairs(Character.CharacterList) do
        if not character.IsDead and character.Submarine == Submarine.MainSub then
            character.Stun = math.max(character.Stun, stunSeconds)
        end
    end

    local junctionBoxes = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if string.find(item.Prefab.Identifier.Value, "junctionbox", 1, true) ~= nil then
            table.insert(junctionBoxes, item)
        end
    end
    for i = 1, math.min(#junctionBoxes, math.random(1, 3)) do
        local box = table.remove(junctionBoxes, math.random(#junctionBoxes))
        box.Condition = box.Condition - junctionBoxDamage
    end

    -- the wall list also holds walls with collision turned off, platforms and indestructible walls, which take no damage
    local walls, sectionCount = {}, 0
    for _, wall in pairs(Structure.WallList) do
        if wall.Submarine == Submarine.MainSub and wall.HasBody and not wall.Prefab.Platform and not wall.Indestructible then
            table.insert(walls, wall)
            sectionCount = sectionCount + wall.SectionCount
        end
    end
    for i = 1, math.min(#walls, math.max(minCracks, math.floor(sectionCount / sectionsPerCrack))) do
        local wall = walls[math.random(#walls)]
        wall.AddDamage(math.random(0, wall.SectionCount - 1),
            wall.MaxHealth * (minDamage + math.random() * (maxDamage - minDamage)))
    end

    Tremor()
    local mode = Traitormod.SelectedGamemode
    if mode ~= nil and mode.Name == "Station" then
        mode:SendCoalitionAnnouncement(Traitormod.GetText("SeismicTremorStation"), "green")
    else
        Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.SeismicTremor, "GameModeIcon.sandbox")
    end

    event.End()
end

event.End = function ()

end

return event
