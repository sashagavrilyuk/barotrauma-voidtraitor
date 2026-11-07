local event = {}

-- Station's take on the SS14 sleeper agents: Coalition internal security intercepts a transmission of the Jovian
-- Separatists, and one or two of the crew wake up as traitors.
event.Name = "SleeperAgents"
event.MinRoundTime = 30
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = true

local weightedRandom = dofile(Traitormod.Path .. "/Lua/weightedrandom.lua")
local playersPerAgent = 15
local maxAgents = 2

-- living crew who may become traitors, weighted the way the round start picks traitors
local function candidates(mode)
    local weights, count = {}, 0
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if client.InGame and not client.SpectateOnly and character ~= nil and not character.IsDead
            and not Traitormod.AdminGhost.IsGhost(character) and mode.TraitorFilter(client) > 0
            and Traitormod.GetData(client, "NonTraitor") ~= true and not Traitormod.RoleManager.IsAntagonist(character) then
            weights[client] = (Traitormod.GetData(client, "Weight") or 0) * mode.TraitorFilter(client)
            count = count + 1
        end
    end
    return weights, count
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    if mode == nil or mode.Name ~= "Station" then return false end
    local _, count = candidates(mode)
    return count > 0
end

event.Start = function ()
    local mode = Traitormod.SelectedGamemode
    local roles = Traitormod.RoleManager
    local weights = candidates(mode)
    local amount = math.max(1, math.min(maxAgents, math.floor(#Client.ClientList / playersPerAgent)))
    for _ = 1, amount do
        local client = weightedRandom.Choose(weights)
        if client == nil then break end
        weights[client] = nil

        local character = client.Character
        -- the crew role makes way for the traitor one
        roles.RemoveRole(character)
        roles.AssignRole(character, roles.Roles["Traitor"]:new())
        Traitormod.SetData(client, "Weight", 0)
        mode.InitialCrew[Traitormod.GetClientAccountKey(client)] = nil
    end

    mode:SendCoalitionAnnouncement(Traitormod.GetText("SleeperAgents"), "green")
    event.End()
end

event.End = function ()

end

return event
