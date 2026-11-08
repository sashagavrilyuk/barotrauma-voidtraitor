local secret = Traitormod.Gamemodes.Secret
local gm = secret:new()
dofile(Traitormod.Path .. "/Lua/gamemodes/station/idconsole.lua")
dofile(Traitormod.Path .. "/Lua/gamemodes/station/cargo.lua")
dofile(Traitormod.Path .. "/Lua/gamemodes/station/cloning.lua")
dofile(Traitormod.Path .. "/Lua/gamemodes/station/nuclear.lua")
dofile(Traitormod.Path .. "/Lua/gamemodes/station/communications.lua")
dofile(Traitormod.Path .. "/Lua/gamemodes/station/powercontroller.lua")
local evacuation = dofile(Traitormod.Path .. "/Lua/gamemodes/station/evacuation.lua")
local weightedRandom = dofile(Traitormod.Path .. "/Lua/weightedrandom.lua")
local bodyTypes = LuaUserData.CreateEnumTable("FarseerPhysics.BodyType")
local alertCodes = {
    green = "StationAlertGreen",
    yellow = "StationAlertYellow",
    blue = "StationAlertBlue",
    violet = "StationAlertViolet",
    red = "StationAlertRed",
    delta = "StationAlertDelta",
    gamma = "StationAlertGamma",
    epsilon = "StationAlertEpsilon"
}
LuaUserData.RegisterType("Barotrauma.EventPrefab")
LuaUserData.RegisterType("Barotrauma.ScriptedEvent")
local stationSuffixes = {"LV", "NX", "EV", "QT", "PR"}

local function escapeMinutesText(minutes)
    local rest = minutes % 100
    local form = rest >= 11 and rest <= 14 and "OutpostEscapeMinutesMany"
        or minutes % 10 == 1 and "OutpostEscapeMinutesOne"
        or minutes % 10 >= 2 and minutes % 10 <= 4 and "OutpostEscapeMinutesFew"
        or "OutpostEscapeMinutesMany"
    return string.format("%d %s", minutes, Traitormod.GetText(form))
end
local alertColors = {
    green = Color(80, 220, 110, 255),
    yellow = Color(255, 215, 60, 255),
    blue = Color(85, 165, 255, 255),
    violet = Color(200, 100, 225, 255),
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
-- Station hides only player characters from the crew list (HidePlayerFromCrew); bots stay listed.
gm.HandlesCrewListHiding = true
-- Dead antagonists keep their role so a clone can inherit it.
gm.KeepRolesOnDeath = true
-- The ID console can rewrite job IDs, so only the round-start captain card counts.
gm.CaptainCardTag = "vt_station_original_captain_id"

function gm:HidePlayerFromCrew(character)
    if Traitormod.Config.HideCrewList then
        Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
    end
end

function gm:PreStart()
    Traitormod.Gamemodes.Gamemode.PreStart(self)
    self.Passengers = {}
    self.PendingJobs = {}
    local settings = Game.ServerSettings
    settings.MissionTypes = "VoidTraitorStation"
    settings.RespawnMode = respawnModes.Permadeath
    settings.UseRespawnShuttle = true
    settings.AllowSpectating = true
    settings.MinRespawnRatio = 0
    settings.ServerDetailsChanged = true
end

function gm:Start()
    local onlyClient
    for _, client in pairs(Client.ClientList) do
        if onlyClient ~= nil then
            onlyClient = false
            break
        end
        onlyClient = client
    end
    Traitormod.Config.TestMode = onlyClient ~= nil and onlyClient ~= false
        and onlyClient.HasPermission(ClientPermissions.ConsoleCommands)
    local submarine = Submarine.MainSub
    self.StationAnnouncementName = string.format("%s %s-%03d", string.upper(submarine.Info.Name), stationSuffixes[math.random(#stationSuffixes)], math.random(0, 999))
    local borders = submarine.GetDockedBorders()
    submarine.SetPosition(Vector2(submarine.WorldPosition.X, Level.Loaded.Size.Y - borders.Y - 200))
    submarine.SubBody.Body.BodyType = bodyTypes.Static

    self.SpawnedAccounts = {}
    self.StationCrew = {}
    self.CrewHusks = {}
    self.PendingShuttleArrivals = {}
    self.BiohazardAnnounced = false
    self.NextHuskCheck = 0
    self.OutpostEscapeAt = nil
    for _, client in pairs(Client.ClientList) do
        self.SpawnedAccounts[Traitormod.GetClientAccountKey(client)] = true
        local character = client.Character
        if character ~= nil and not character.IsDead then self:HidePlayerFromCrew(character) end
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
            self:InitializeIdCard(character)
        end
    end
    self.AlertCode = "green"
    evacuation.Start(self)
    Traitormod.Communications.Start()
end

-- Test mode is set in Start (a single admin), not by the player count.
function gm:UpdateTestMode() end

function gm:CharacterDeath(character)
    if not Traitormod.Config.TestMode then secret.CharacterDeath(self, character) end
end

-- the client maps the sound name to its file (pack Lua/client/station/announcements.lua)
function gm:PlayAlertSound(sound)
    local message = Networking.Start("VoidTraitor_StationAlertSound")
    message.WriteString(sound)
    Networking.Send(message)
end

local function writeColor(message, color)
    message.WriteByte(Byte(color.R))
    message.WriteByte(Byte(color.G))
    message.WriteByte(Byte(color.B))
end

-- the client puts the header in the chat line above the text, in a bold font
function gm:SendAlertMessage(text, color, headerColor, header)
    header = header or Traitormod.FormatText("StationAnnouncementHeader", self.StationAnnouncementName)
    local tint = headerColor or Color(math.floor(color.R * 0.8 + 51),
        math.floor(color.G * 0.8 + 51), math.floor(color.B * 0.8 + 51))
    local message = Networking.Start("VoidTraitor_StationAnnouncement")
    message.WriteString(header)
    message.WriteString(text)
    writeColor(message, color)
    writeColor(message, tint)
    Networking.Send(message)
end

-- station events are announced by the Coalition Command: gold text under a pale header, like the communications console
function gm:SendCoalitionAnnouncement(text, sound)
    self:SendAlertMessage(text, Color(255, 215, 0, 255), Color(255, 255, 170, 255), Traitormod.GetText("CoalitionAnnouncementHeader"))
    self:PlayAlertSound(sound)
end

function gm:SetAlertCode(code)
    if alertCodes[code] == nil or self.AlertCode == code then return false end
    self.AlertCode = code
    self:SendAlertMessage(Traitormod.GetText(alertCodes[code]), alertColors[code])
    self:PlayAlertSound(code)
    return true
end

function gm:OnNuclearArmed(item, remaining)
    self:SetAlertCode("delta")
    local hull = Hull.FindHull(item.WorldPosition, item.CurrentHull)
    local room = hull ~= nil and tostring(hull.DisplayName) or Traitormod.GetText("NukeUnknownRoom")
    local station = Submarine.MainSub
    local borders = station.GetDockedBorders()
    local middle = station.WorldPosition + Vector2(borders.X + borders.Width / 2, borders.Y - borders.Height / 2)
    local offset = item.WorldPosition - middle
    local vertical = offset.Y >= 0 and "North" or "South"
    local horizontal = offset.X >= 0 and "East" or "West"
    local direction = math.abs(offset.X) < 50 and math.abs(offset.Y) < 50 and "Center"
        or math.abs(offset.X) > math.abs(offset.Y) * 2 and horizontal
        or math.abs(offset.Y) > math.abs(offset.X) * 2 and vertical or vertical .. horizontal
    local text = Traitormod.FormatText("NukeArmedAnnouncement", room,
        Traitormod.GetText("NukeDirection" .. direction), math.ceil(remaining))
    for _, player in pairs(Client.ClientList) do
        local message = ChatMessage.Create(Traitormod.GetText("NukeAnnouncementSender"), text, ChatMessageType.Default, nil, nil)
        message.Color = Color(255, 0, 0, 255)
        Game.SendDirectChatMessage(message, player)
    end
end

function gm:OnNuclearDisarmed()
    Traitormod.SendMessageEveryone(Traitormod.GetText("NukeDisarmedAnnouncement"))
    self:SetAlertCode("green")
end

-- living crew who may become a mid-round antagonist, weighted the way the round start picks traitors
function gm:MidRoundAntagonistCandidates()
    local weights, count = {}, 0
    for _, client in pairs(Client.ClientList) do
        local character = client.Character
        if client.InGame and not client.SpectateOnly and character ~= nil and not character.IsDead
            and not Traitormod.AdminGhost.IsGhost(character) and self.TraitorFilter(client) > 0
            and Traitormod.GetData(client, "NonTraitor") ~= true and not Traitormod.RoleManager.IsAntagonist(character) then
            weights[client] = (Traitormod.GetData(client, "Weight") or 0) * self.TraitorFilter(client)
            count = count + 1
        end
    end
    return weights, count
end

-- turns up to amount of those candidates into the given antagonist role and returns their characters
function gm:AssignMidRoundAntagonists(roleName, amount)
    local roles = Traitormod.RoleManager
    local weights = self:MidRoundAntagonistCandidates()
    local chosen = {}
    for _ = 1, amount do
        local client = weightedRandom.Choose(weights)
        if client == nil then break end
        weights[client] = nil

        local character = client.Character
        -- the crew role makes way for the antagonist one
        roles.RemoveRole(character)
        roles.AssignRole(character, roles.Roles[roleName]:new())
        Traitormod.SetData(client, "Weight", 0)
        self.InitialCrew[Traitormod.GetClientAccountKey(client)] = nil
        table.insert(chosen, character)
    end
    return chosen
end

-- Biohazard level 5 once husks that were crew outnumber the living crew, the way SS14 counts zombies among the living.
-- The infected are not counted: they may still be cured.
function gm:CheckHuskOutbreak()
    local husks, crew = 0, 0
    for _, husk in ipairs(self.CrewHusks) do
        if not husk.Removed and not husk.IsDead then husks = husks + 1 end
    end
    for _, character in ipairs(self.StationCrew) do
        if not character.Removed and not character.IsDead then crew = crew + 1 end
    end

    if husks > crew then
        self.BiohazardAnnounced = true
        self:SendAlertMessage(Traitormod.GetText("StationBiohazard5"), alertColors.biohazard)
        self:PlayAlertSound("biohazard")
    end
end

function gm:CountJobSlots()
    local counts = {}
    for _, client in pairs(Client.ClientList) do
        local account = Traitormod.GetClientAccountKey(client)
        local job = self.PendingJobs[account]
        local character = client.Character
        if job == nil and not self.Passengers[account] and character ~= nil
            and not character.IsDead and character.IsHuman
            and character.TeamID == CharacterTeamType.Team1 and character.Info.Job ~= nil then
            job = character.Info.Job.Prefab.Identifier.Value
        end
        if job ~= nil then
            counts[job] = (counts[job] or 0) + 1
        end
    end
    return counts
end

function gm:HasJobSlot(client, job, counts)
    if job == nil or job.Prefab.HiddenJob or client.Karma < job.Prefab.MinKarma then
        return false
    end
    local id = job.Prefab.Identifier.Value
    return (counts[id] or 0) < (self.JobSlots[id] or 0)
end

function gm:ReserveJobSlot(client, job, counts, passenger)
    local account = Traitormod.GetClientAccountKey(client)
    local id = job.Prefab.Identifier.Value
    self.Passengers[account] = passenger or nil
    self.PendingJobs[account] = not passenger and id or nil
    if not passenger then
        counts[id] = (counts[id] or 0) + 1
    end
    return job
end

function gm:ChooseStationJob(client, counts)
    for _, job in ipairs(client.JobPreferences) do
        if self:HasJobSlot(client, job, counts) then
            return self:ReserveJobSlot(client, job, counts)
        end
    end
    local available = {}
    for id, limit in pairs(self.JobSlots) do
        if limit > 0 and JobPrefab.Prefabs.ContainsKey(id) then
            local job = Traitormod.MidRoundSpawn.GetJobVariant(id)
            if self:HasJobSlot(client, job, counts) then
                available[#available + 1] = job
            end
        end
    end
    if #available > 0 then
        return self:ReserveJobSlot(client, available[math.random(#available)], counts)
    end
    for _, job in ipairs(client.JobPreferences) do
        if job.Prefab.Identifier == "assistant" then
            return self:ReserveJobSlot(client, job, counts, true)
        end
    end
    return self:ReserveJobSlot(client, Traitormod.MidRoundSpawn.GetJobVariant("assistant"), counts, true)
end

function gm:ApplyJobSlots(clients)
    local counts, overflow = self:CountJobSlots(), {}
    for _, client in pairs(clients) do
        if self:HasJobSlot(client, client.AssignedJob, counts) then
            self:ReserveJobSlot(client, client.AssignedJob, counts)
        else
            overflow[#overflow + 1] = client
        end
    end
    for _, client in ipairs(overflow) do
        client.AssignedJob = self:ChooseStationJob(client, counts)
    end
end

function gm:InitializeIdCard(character)
    local client = Traitormod.FindClientCharacter(character)
    local passenger = false
    if client ~= nil then
        local account = Traitormod.GetClientAccountKey(client)
        self.PendingJobs[account] = nil
        passenger = self.Passengers[account] == true
    end
    Traitormod.IdConsole.InitializeCard(character, passenger)
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
    local accountKey = Traitormod.GetClientAccountKey(client)
    local job = self:ChooseStationJob(client, self:CountJobSlots())
    if Traitormod.MidRoundSpawn.SpawnClientCharacterOnSub(submarine, client, job) then
        self.SpawnedAccounts[accountKey] = true
        self.PendingShuttleArrivals[accountKey] = true
    else
        self.PendingJobs[accountKey] = nil
    end
end

function gm:Think()
    if not Game.RoundStarted then return end
    self:UpdateCrewDown()
    local endOutpost = Level.Loaded.EndOutpost
    if endOutpost ~= nil and not self.Ending then
        local inside, total = 0, 0
        for _, client in pairs(Client.ClientList) do
            local character = client.Character
            if character ~= nil and not character.IsDead and not character.IsUnconscious and not Traitormod.AdminGhost.IsGhost(character) then
                total = total + 1
                if character.Submarine == endOutpost then inside = inside + 1 end
            end
        end
        if inside > 0 and inside * 100 >= total * self.OutpostEscapePercent then
            if self.OutpostEscapeAt == nil then
                self.OutpostEscapeAt = Timer.GetTime() + self.OutpostEscapeMinutes * 60
                Traitormod.SendMessageEveryone(Traitormod.FormatText("OutpostEscapeCountdown",
                    escapeMinutesText(self.OutpostEscapeMinutes)))
            elseif Timer.GetTime() >= self.OutpostEscapeAt then
                self:BeginEnding("outpost")
            end
        elseif self.OutpostEscapeAt ~= nil then
            self.OutpostEscapeAt = nil
            Traitormod.SendMessageEveryone(Traitormod.GetText("OutpostEscapeCancelled"))
        end
    end
    evacuation.Think(self)
    Traitormod.Communications.Think()
    if not self.BiohazardAnnounced and Timer.GetTime() >= self.NextHuskCheck then
        self.NextHuskCheck = Timer.GetTime() + 5
        self:CheckHuskOutbreak()
    end
    for _, client in pairs(Client.ClientList) do
        local accountKey = Traitormod.GetClientAccountKey(client)
        if client.Character ~= nil and not client.Character.IsDead and not Traitormod.AdminGhost.IsGhost(client.Character) then
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

        -- the game doesn't send positions of submarines that don't move, so queue the station and a parked ship here
        local queue = client.PendingPositionUpdates
        if not queue.Contains(Submarine.MainSub) then queue.Enqueue(Submarine.MainSub) end
        local evac = self.EvacuationState
        if evac.Status == "Parked" and not queue.Contains(evac.Ship) then
            queue.Enqueue(evac.Ship)
        end
        local available = Traitormod.Pointshop.CanUseShop(client)
        if self.ShopAvailability[client] ~= available then
            self.ShopAvailability[client] = available
            Traitormod.ClientMenu.SendSnapshot(client)
        end
    end
end

function gm:GetEvacuationStatus()
    return evacuation.Snapshot(self)
end

function gm:ToggleEvacuation()
    evacuation.Action(self)
end

function gm:BeginEnding(reason, transitionType, viaCampaignTransition)
    if self.Ending or not Game.RoundStarted then return end
    for mission in Game.GameSession.Missions do
        if mission.Prefab.Identifier == "vt_station" then
            mission.State = reason == "crew" and 1 or -1
        end
    end
    local previousDelay = self.EndGameDelaySeconds
    if reason == "outpost" then self.EndGameDelaySeconds = 0 end
    secret.BeginEnding(self, reason, transitionType, viaCampaignTransition)
    self.EndGameDelaySeconds = previousDelay
end

function gm:End()
    Traitormod.Config.TestMode = false
    Traitormod.Communications.End()
    self.EvacuationState = nil
    self.PendingJobs = nil
    self.Passengers = nil
    secret.End(self)
    if Traitormod.OriginalGamemode ~= nil then
        Game.NetLobbyScreen.SelectedModeIdentifier = Traitormod.OriginalGamemode
        Traitormod.OriginalGamemode = nil
    end
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

-- A crew member who turns into a husk is removed, and the husk is created in their place with their info and name.
Hook.Add("character.created", "Traitormod.Station.CrewHusk", function(character)
    local selected = Traitormod.SelectedGamemode
    -- the mode is chosen before the level loads, the crew is listed only when the round starts
    if selected == nil or selected.Name ~= "Station" or selected.CrewHusks == nil
        or not character.IsHusk or character.Info == nil then return end

    for _, member in ipairs(selected.StationCrew) do
        if member.IsDead and member.Name == character.Name then
            table.insert(selected.CrewHusks, character)
            return
        end
    end
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
    if client ~= nil and character ~= nil and not character.IsDead and not Traitormod.AdminGhost.IsGhost(character) then
        client.SpectateOnly = false
        selected:HidePlayerFromCrew(character)
    end
end, Hook.HookMethodType.After)

Hook.Patch("Barotrauma.Character", "Revive", function(character)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" or character.IsDead then return end
    if character.IsPlayer then selected:HidePlayerFromCrew(character) end
    for _, client in pairs(Client.ClientList) do
        if client.SpectateOnly and (client.Character == nil or client.Character == character)
            and character.IsClientOwner(client) then
            client.SpectateOnly = false
        end
    end
end, Hook.HookMethodType.After)

Hook.Add("jobsAssigned", "Traitormod.Station.JobSlots", function(clients)
    local selected = Traitormod.SelectedGamemode
    if selected ~= nil and selected.Name == "Station" then
        selected:ApplyJobSlots(clients)
    end
end)

Hook.Add("character.giveJobItems", "Traitormod.Station.IdCardAccess", function(character)
    local selected = Traitormod.SelectedGamemode
    if selected == nil or selected.Name ~= "Station" then return end
    Timer.Wait(function()
        if not character.Removed and Traitormod.SelectedGamemode == selected then
            selected:InitializeIdCard(character)
        end
    end, 0)
end)

return gm
