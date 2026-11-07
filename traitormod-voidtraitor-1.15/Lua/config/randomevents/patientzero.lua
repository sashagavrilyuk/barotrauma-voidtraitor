local event = {}

-- Station's take on the SS14 zombie outbreak: a few of the crew learn they carry the husk parasite. It sleeps unseen for
-- a few minutes, then takes them over; until then they prepare the outbreak with the cultist shop. Unannounced, as in
-- SS14. Players who turn into husks get their husk and the Husk role (roles/cultist.lua, husk.clientControlHusk).
event.Name = "PatientZero"
event.MinRoundTime = 45
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = true

local playersPerCarrier, maxCarriers = 15, 3
local minHiddenSeconds, maxHiddenSeconds = 300, 450

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    if mode == nil or mode.Name ~= "Station" then return false end
    local _, count = mode:MidRoundAntagonistCandidates()
    return count > 0
end

event.Start = function ()
    local amount = math.max(1, math.min(maxCarriers, math.floor(#Client.ClientList / playersPerCarrier)))
    event.Carriers = {}
    for _, character in ipairs(Traitormod.SelectedGamemode:AssignMidRoundAntagonists("PatientZero", amount)) do
        table.insert(event.Carriers, {
            Character = character,
            WakeAt = Traitormod.RoundTime + math.random(minHiddenSeconds, maxHiddenSeconds),
            Strength = 1,
        })
    end
    Game.EnableControlHusk(true)
    event.NextCheck = 0
end

-- The event lasts to the end of the round, so husk control stays on while the infection spreads.
event.Think = function ()
    local now = Traitormod.RoundTime
    if now < event.NextCheck then return end
    event.NextCheck = now + 1

    for i = #event.Carriers, 1, -1 do
        local carrier = event.Carriers[i]
        local character = carrier.Character
        if character.Removed or character.IsDead then
            table.remove(event.Carriers, i)
        else
            if now < carrier.WakeAt and character.IsIncapacitated then
                -- knocked out before its time, the parasite takes over at once
                carrier.WakeAt, carrier.Strength = now, 100
            end
            if now >= carrier.WakeAt then
                local infection = character.CharacterHealth.GetAffliction("huskinfection", true)
                if infection ~= nil then
                    carrier.Strength = infection.Strength
                else
                    -- the infection cannot be cured: it comes back as strong as it was
                    character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb,
                        AfflictionPrefab.Prefabs["huskinfection"].Instantiate(carrier.Strength))
                end
            end
        end
    end
end

event.End = function ()
    Game.EnableControlHusk(false)
    event.Carriers = nil
end

return event
