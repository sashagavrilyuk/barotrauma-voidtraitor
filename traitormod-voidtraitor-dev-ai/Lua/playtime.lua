local playtimeUpdateTimer = 0

Hook.Add("think", "Traitormod.Playtime.think", function(deltaTime)
    playtimeUpdateTimer = playtimeUpdateTimer + deltaTime
    if playtimeUpdateTimer < 1 then return end

    local elapsed = playtimeUpdateTimer
    playtimeUpdateTimer = 0

    for _, client in pairs(Client.ClientList) do
        Traitormod.AddData(client, "Playtime", elapsed)
    end
end)
