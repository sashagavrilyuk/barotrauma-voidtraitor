local lastPlaytimeUpdate = Timer.GetTime()

Hook.Add("think", "Traitormod.Playtime.think", function()
    local now = Timer.GetTime()
    local elapsed = now - lastPlaytimeUpdate
    if elapsed < 1 then return end
    lastPlaytimeUpdate = now

    for _, client in pairs(Client.ClientList) do
        Traitormod.AddData(client, "Playtime", elapsed)
    end
end)
