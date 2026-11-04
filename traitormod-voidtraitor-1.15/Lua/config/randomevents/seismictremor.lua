local event = {}

-- Europa's tidal tectonics shake the sub: everyone aboard staggers, a few junction boxes take a hit and some wall
-- sections crack. The rumble and the camera shake play on the clients (Void traitor pack Lua/client/tremor.lua).
event.Name = "SeismicTremor"
event.MinRoundTime = 8
event.MinIntensity = 0
event.MaxIntensity = 0.5
event.ChancePerMinute = 0.01
event.OnlyOncePerRound = false

local NET_TREMOR = "VoidTraitor_SeismicTremor"
local stunSeconds = 2
local junctionBoxDamage = 40
local crackedSections = 2

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

    local walls = {}
    for _, wall in pairs(Structure.WallList) do
        if wall.Submarine == Submarine.MainSub then table.insert(walls, wall) end
    end
    for i = 1, math.min(#walls, crackedSections) do
        local wall = walls[math.random(#walls)]
        wall.AddDamage(math.random(0, wall.SectionCount - 1), wall.MaxHealth * 0.6)
    end

    Networking.Send(Networking.Start(NET_TREMOR))
    Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.SeismicTremor, "GameModeIcon.sandbox")

    event.End()
end

event.End = function ()

end

return event
