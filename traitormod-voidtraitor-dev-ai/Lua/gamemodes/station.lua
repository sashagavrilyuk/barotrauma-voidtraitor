local secret = Traitormod.Gamemodes.Secret
local gm = secret:new()
local bodyTypes = LuaUserData.CreateEnumTable("FarseerPhysics.BodyType")
local respawnModes = LuaUserData.CreateEnumTable("Barotrauma.Networking.RespawnMode")
local serverSettings = Descriptors["Barotrauma.Networking.ServerSettings"] or LuaUserData.RegisterType("Barotrauma.Networking.ServerSettings")
LuaUserData.MakePropertyAccessible(serverSettings, "UseRespawnShuttle")
LuaUserData.MakePropertyAccessible(serverSettings, "AllowSpectating")
LuaUserData.MakePropertyAccessible(serverSettings, "MinRespawnRatio")
LuaUserData.RegisterType("System.Collections.Generic.Queue`1[[Barotrauma.Entity]], System.Collections")

gm.Name = "Station"
gm.RequiredGamemode = "mission"
gm.EndOnComplete = false
gm.RestrictShopToAccessibleCategories = true

function gm:PreStart()
    Traitormod.Gamemodes.Gamemode.PreStart(self)
    local settings = Game.ServerSettings
    self.PreviousMissionTypes = settings.MissionTypes
    self.PreviousRespawnMode = settings.RespawnMode
    self.PreviousUseRespawnShuttle = settings.UseRespawnShuttle
    self.PreviousAllowSpectating = settings.AllowSpectating
    self.PreviousMinRespawnRatio = settings.MinRespawnRatio
    settings.MissionTypes = "VoidTraitorStation"
    settings.RespawnMode = respawnModes.Permadeath
    settings.UseRespawnShuttle = true
    settings.AllowSpectating = true
    settings.MinRespawnRatio = 0
    settings.ServerDetailsChanged = true
end

function gm:Start()
    local submarine = Submarine.MainSub
    local borders = submarine.GetDockedBorders()
    submarine.SetPosition(Vector2(submarine.WorldPosition.X, Level.Loaded.Size.Y - borders.Y - 200))
    submarine.SubBody.Body.BodyType = bodyTypes.Static

    self.SpawnedAccounts = {}
    for _, client in pairs(Client.ClientList) do
        self.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] = true
    end
    Traitormod.DisableMidRoundSpawn = true

    self.ShopAvailability = {}
    secret.Start(self)
    Traitormod.Cargo.Start()
    Traitormod.Cloning.Start()
    for character in Character.CharacterList do
        if character.IsHuman and not character.IsDead and character.Submarine == Submarine.MainSub then
            Traitormod.IdConsole.InitializeCard(character)
        end
    end
end

function gm:CanShuttleRespawn(client)
    return not self.SpawnedAccounts[Traitormod.GetClientAccountKey(client)]
        and client.InGame and not client.SpectateOnly
        and (client.Character == nil or client.Character.IsDead)
end

function gm:ShouldStartShuttleRespawn(pending)
    return pending > 0
end

function gm:SpawnNewcomerOnShuttle(client, submarine)
    if Traitormod.MidRoundSpawn.SpawnClientCharacterOnSub(submarine, client) then
        self.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] = true
    end
end

function gm:Think()
    if not Game.RoundStarted then return end
    -- The native server omits static submarine positions from regular updates.
    for _, client in pairs(Client.ClientList) do
        local accountKey = Traitormod.GetClientAccountKey(client)
        if client.Character ~= nil and not client.Character.IsDead then
            self.SpawnedAccounts[accountKey] = true
        elseif self.SpawnedAccounts[accountKey] and not client.SpectateOnly then
            local reclaimable = false
            for character in Character.CharacterList do
                if not character.IsDead and character.IsClientOwner(client) then
                    reclaimable = true
                    break
                end
            end
            if not reclaimable then client.SpectateOnly = true end
        end

        local queue = client.PendingPositionUpdates
        if not queue.Contains(Submarine.MainSub) then queue.Enqueue(Submarine.MainSub) end
        local available = Traitormod.Pointshop.CanUseShop(client)
        if self.ShopAvailability[client] ~= available then
            self.ShopAvailability[client] = available
            Traitormod.ClientMenu.SendSnapshot(client)
        end
    end
end

function gm:BeginEnding(reason, transitionType, viaCampaignTransition)
    if self.Ending or not Game.RoundStarted then return end
    for mission in Game.GameSession.Missions do
        if mission.Prefab.Identifier == "vt_station" then
            mission.State = reason == "crew" and 1 or -1
        end
    end
    secret.BeginEnding(self, reason, transitionType, viaCampaignTransition)
end

function gm:End()
    secret.End(self)
    if Traitormod.OriginalGamemode ~= nil then
        Game.NetLobbyScreen.SelectedModeIdentifier = Traitormod.OriginalGamemode
        Traitormod.OriginalGamemode = nil
    end
    local settings = Game.ServerSettings
    settings.MissionTypes = self.PreviousMissionTypes
    local previousRespawnMode = self.PreviousRespawnMode
    Timer.Wait(function()
        settings.RespawnMode = previousRespawnMode
    end, 0)
    settings.UseRespawnShuttle = self.PreviousUseRespawnShuttle
    settings.AllowSpectating = self.PreviousAllowSpectating
    settings.MinRespawnRatio = self.PreviousMinRespawnRatio
    settings.ServerDetailsChanged = true
end

Hook.Add("client.connected", "Traitormod.Station.Reconnect", function(client)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" or selected.SpawnedAccounts == nil then return end
    if not selected.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] then return end

    for character in Character.CharacterList do
        if not character.IsDead and character.IsClientOwner(client) then return end
    end
    client.SpectateOnly = true
end)

Hook.Add("character.giveJobItems", "Traitormod.Station.IdCardAccess", function(character)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Station" then return end
    Timer.Wait(function()
        if not character.Removed and character.Submarine == Submarine.MainSub then Traitormod.IdConsole.InitializeCard(character) end
    end, 0)
end)

return gm
