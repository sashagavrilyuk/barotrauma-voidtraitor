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

Traitormod.AddCommand({"!playtime", "!pt"}, function (client, args)
    Traitormod.SendChatMessage(
        client,
        string.format(Traitormod.Language.CMDPlaytime, Traitormod.FormatTime(math.ceil(Traitormod.GetData(client, "Playtime") or 0))),
        Color.Green
    )
    return true
end)