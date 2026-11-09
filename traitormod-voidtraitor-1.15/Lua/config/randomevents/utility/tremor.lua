-- A tremor through the main sub: people and loose items inside are thrown aside the way the game does it when the sub
-- hits something, without damage to the walls or moving the sub. The clients apply the same impact to see their own
-- character move at once, and add the rumble and the camera shake (Void traitor pack Lua/client/tremor.lua).
local NET_TREMOR = "VoidTraitor_SeismicTremor"
-- from 5 on the game's impact also deals impact damage
local impact = 4.5
-- people on their feet keep their footing against the impact, so everyone aboard is knocked down for a moment
local knockdownSeconds = 1

LuaUserData.MakeMethodAccessible(LuaUserData.RegisterType("Barotrauma.SubmarineBody"), "ApplyImpact")

return function ()
    local sub = Submarine.MainSub
    for _, character in pairs(Character.CharacterList) do
        if not character.IsDead and character.Submarine == sub then
            character.Stun = math.max(character.Stun, knockdownSeconds)
        end
    end

    local direction = Vector2(math.random() < 0.5 and -1 or 1, 0)
    -- below the sub, so the impact finds no wall nearby to play a hit sound on
    local impactPosition = ConvertUnits.ToSimUnits(sub.WorldPosition - Vector2(0, sub.Borders.Height))
    sub.SubBody.ApplyImpact(impact, direction, impactPosition, false)

    local message = Networking.Start(NET_TREMOR)
    message.WriteSingle(impact)
    message.WriteSingle(direction.X)
    Networking.Send(message)
end
