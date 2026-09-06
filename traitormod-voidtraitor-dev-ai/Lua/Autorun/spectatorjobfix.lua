if CLIENT then return end

Hook.Patch("Traitormod.SpectatorCharacterInfo", "Barotrauma.Networking.GameServer", "UpdateCharacterInfo", function (instance, ptable)
    local client = ptable["sender"]
    local characterInfo = client ~= nil and client.SpectateOnly and client.CharacterInfo or nil
    if characterInfo ~= nil and characterInfo.Job ~= nil and characterInfo.Job.Prefab.HiddenJob then
        characterInfo.Job = nil
    end
end, Hook.HookMethodType.After)
