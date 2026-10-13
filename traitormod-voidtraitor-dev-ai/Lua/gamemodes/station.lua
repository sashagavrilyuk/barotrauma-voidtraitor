local secret = Traitormod.Gamemodes.Secret
local gm = secret:new()
local bodyTypes = LuaUserData.CreateEnumTable("FarseerPhysics.BodyType")
local alertCodes = {
    green = "StationAlertGreen",
    yellow = "StationAlertYellow",
    blue = "StationAlertBlue",
    red = "StationAlertRed",
    delta = "StationAlertDelta",
    gamma = "StationAlertGamma",
    epsilon = "StationAlertEpsilon"
}
local alertSounds = {
    green = "vt_station_sound_green",
    yellow = "vt_station_sound_yellow",
    blue = "vt_station_sound_blue",
    red = "vt_station_sound_red",
    delta = "vt_station_sound_delta",
    gamma = "vt_station_sound_gamma",
    epsilon = "vt_station_sound_epsilon",
    biohazard = "vt_station_sound_biohazard"
}
local eventSet = LuaUserData.CreateStatic("Barotrauma.EventSet", true)
LuaUserData.RegisterType("Barotrauma.EventPrefab")
LuaUserData.RegisterType("Barotrauma.ScriptedEvent")
local alertColors = {
    green = Color(80, 220, 110, 255),
    yellow = Color(255, 215, 60, 255),
    blue = Color(85, 165, 255, 255),
    red = Color(255, 80, 80, 255),
    delta = Color(190, 55, 55, 255),
    gamma = Color(219, 112, 147, 255),
    epsilon = Color(180, 70, 230, 255),
    biohazard = Color(200, 100, 225, 255)
}
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
    self.StationCrew = {}
    self.PendingShuttleArrivals = {}
    self.BiohazardAnnounced = false
    self.NextHuskCheck = 0
    for _, client in pairs(Client.ClientList) do
        self.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] = true
        local character = client.Character
        if not client.SpectateOnly and character ~= nil and character.IsHuman
            and not character.IsDead and character.Submarine == submarine then
            table.insert(self.StationCrew, character)
        end
    end
    Traitormod.DisableMidRoundSpawn = true

    self.ShopAvailability = {}
    secret.Start(self)
    Traitormod.Cargo.Start()
    Traitormod.Cloning.Start()
    Traitormod.Nuclear.Start()
    for character in Character.CharacterList do
        if character.IsHuman and not character.IsDead and character.Submarine == Submarine.MainSub then
            Traitormod.IdConsole.InitializeCard(character)
        end
    end
    self.AlertCode = "green"
end

function gm:PlayAlertSound(code)
    local eventPrefab = eventSet.GetEventPrefab(Identifier(alertSounds[code]))
    if eventPrefab == nil then
        Traitormod.Error("Station alert sound event not found: " .. alertSounds[code])
        return
    end

    for hull in Hull.HullList do
        if hull.Submarine == Submarine.MainSub then
            local event = eventPrefab.CreateInstance(Game.GameSession.EventManager.RandomSeed)
            event.AddTarget(Identifier("station"), hull)
            Game.GameSession.EventManager.ActivateEvent(event)
            return
        end
    end
end

function gm:SendAlertMessage(text, color)
    local stationName = Submarine.MainSub.Info.Name
    for _, client in pairs(Client.ClientList) do
        local message = ChatMessage.Create(stationName, text, ChatMessageType.Default, nil, nil)
        message.Color = color
        Game.SendDirectChatMessage(message, client)
    end
end

function gm:SetAlertCode(code)
    if alertCodes[code] == nil or self.AlertCode == code then return false end
    self.AlertCode = code
    self:SendAlertMessage(Traitormod.GetText(alertCodes[code]), alertColors[code])
    if alertSounds[code] ~= nil then self:PlayAlertSound(code) end
    return true
end

function gm:CheckHuskOutbreak()
    if self.BiohazardAnnounced or #self.StationCrew == 0 then return end

    local infected = 0
    for _, character in ipairs(self.StationCrew) do
        if not character.Removed then
            local infection = character.CharacterHealth.GetAffliction("huskinfection", true)
            if (infection ~= nil and infection.Strength > 0) or character.IsHusk then
                infected = infected + 1
            end
        end
    end

    if infected * 2 > #self.StationCrew then
        self.BiohazardAnnounced = true
        self:SendAlertMessage(Traitormod.GetText("StationBiohazard5"), alertColors.biohazard)
        self:PlayAlertSound("biohazard")
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
        local accountKey = Traitormod.GetClientAccountKey(client)
        self.SpawnedAccounts[accountKey] = true
        self.PendingShuttleArrivals[accountKey] = true
    end
end

function gm:Think()
    if not Game.RoundStarted then return end
    if not self.BiohazardAnnounced and Timer.GetTime() >= self.NextHuskCheck then
        self.NextHuskCheck = Timer.GetTime() + 5
        self:CheckHuskOutbreak()
    end
    -- The native server omits static submarine positions from regular updates.
    for _, client in pairs(Client.ClientList) do
        local accountKey = Traitormod.GetClientAccountKey(client)
        if client.Character ~= nil and not client.Character.IsDead then
            self.SpawnedAccounts[accountKey] = true
        elseif self.SpawnedAccounts[accountKey] and client.Character == nil and not client.SpectateOnly then
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

-- RespawnManager also respawns dead bots in Permadeath outside campaigns.
LuaUserData.RegisterType("System.Collections.Generic.List`1[[Barotrauma.CharacterInfo]], System.Collections")
Hook.Patch("Barotrauma.Networking.RespawnManager", "GetBotsToRespawn", function(_, parameters)
    if Traitormod.SelectedGamemode ~= nil and Traitormod.SelectedGamemode.Name == "Station" then
        parameters.ReturnValue.Clear()
    end
end, Hook.HookMethodType.After)

Traitormod.AddCommand("!stationcode", function(client, args)
    local selected = Traitormod.SelectedGamemode
    if not Game.RoundStarted or selected == nil or selected.Name ~= "Station" then
        Traitormod.SendChatMessage(client, Traitormod.GetText("StationAlertUnavailable"))
        return true
    end

    if args[1] == nil then
        Traitormod.SendChatMessage(client, Traitormod.FormatText("StationAlertCurrent", selected.AlertCode))
        return true
    end

    if not client.HasPermission(ClientPermissions.ConsoleCommands)
        and (client.Character == nil or client.Character.IsDead or not client.Character.HasJob("captain")) then
        Traitormod.SendChatMessage(client, Traitormod.GetText("StationAlertDenied"))
        return true
    end

    local code = string.lower(args[1])
    if alertCodes[code] == nil then
        Traitormod.SendChatMessage(client, Traitormod.GetText("StationAlertUsage"))
    elseif not selected:SetAlertCode(code) then
        Traitormod.SendChatMessage(client, Traitormod.GetText("StationAlertUnchanged"))
    end
    return true
end)

Hook.Add("traitormod.midroundspawn", "Traitormod.Station.ShuttleArrival", function(client, character)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" then return end

    local accountKey = Traitormod.GetClientAccountKey(client)
    if not selected.PendingShuttleArrivals[accountKey] then return end
    selected.PendingShuttleArrivals[accountKey] = nil
    table.insert(selected.StationCrew, character)
end)

Hook.Add("client.connected", "Traitormod.Station.Reconnect", function(client)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" or selected.SpawnedAccounts == nil then return end
    if not selected.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] then return end

    for character in Character.CharacterList do
        if not character.IsDead and character.IsClientOwner(client) then return end
    end
    client.SpectateOnly = true
end)

Hook.Patch("Barotrauma.Networking.GameServer", "SetClientCharacter", function(instance, parameters)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" then return end
    local client, character = parameters["client"], parameters["newCharacter"]
    if client ~= nil and character ~= nil and not character.IsDead then client.SpectateOnly = false end
end, Hook.HookMethodType.After)

Hook.Patch("Barotrauma.Character", "Revive", function(character)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" or character.IsDead then return end
    for _, client in pairs(Client.ClientList) do
        if client.SpectateOnly and (client.Character == nil or client.Character == character)
            and character.IsClientOwner(client) then
            client.SpectateOnly = false
        end
    end
end, Hook.HookMethodType.After)

Hook.Add("character.giveJobItems", "Traitormod.Station.IdCardAccess", function(character)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Station" then return end
    Timer.Wait(function()
        if not character.Removed and character.Submarine == Submarine.MainSub then Traitormod.IdConsole.InitializeCard(character) end
    end, 0)
end)

return gm
