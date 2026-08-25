local extension = {}

extension.Identifier = "servermessageutf8fix"

extension.Init = function ()
    local descriptor
    if LuaUserData.IsRegistered("Barotrauma.Steam.SteamManager") then
        descriptor = Descriptors["Barotrauma.Steam.SteamManager"]
    else
        descriptor = LuaUserData.RegisterType("Barotrauma.Steam.SteamManager")
    end

    LuaUserData.MakeMethodAccessible(
        descriptor,
        "SetServerListInfo",
        {"Barotrauma.Identifier", "System.Object"}
    )

    local steamManager = LuaUserData.CreateStatic("Barotrauma.Steam.SteamManager")
    local logged = false

    Hook.Patch(
        "Traitormod.ServerMessageUTF8Fix",
        "Barotrauma.Steam.SteamManager",
        "SetServerListInfo",
        {"Barotrauma.Identifier", "System.Object"},
        function (_, ptable)
            local key = ptable["key"]
            if key == nil or tostring(key) ~= "message" then return end

            local serverMessage = ptable["value"]
            local messageLength = #serverMessage
            local chunkStart = 1
            local chunkIndex = 0

            while chunkStart + 127 < messageLength do
                steamManager.SetServerListInfo(
                    Identifier("message" .. chunkIndex),
                    string.sub(serverMessage, chunkStart, chunkStart + 127)
                )

                chunkStart = chunkStart + 128
                chunkIndex = chunkIndex + 1
            end

            if chunkStart <= messageLength then
                steamManager.SetServerListInfo(
                    Identifier("message" .. chunkIndex),
                    string.sub(serverMessage, chunkStart)
                )
                chunkIndex = chunkIndex + 1
            end

            steamManager.SetServerListInfo(Identifier("message" .. chunkIndex), "")
            ptable.PreventExecution = true

            if not logged then
                logged = true
                Traitormod.Log("[ServerMessageUTF8Fix] Published server message in " .. tostring(chunkIndex) .. " UTF-8-safe chunks")
            end
        end,
        Hook.HookMethodType.Before
    )
end

return extension
