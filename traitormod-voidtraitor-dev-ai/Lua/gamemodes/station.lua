local secret = Traitormod.Gamemodes.Secret
local gm = secret:new()
local bodyTypes = LuaUserData.CreateEnumTable("FarseerPhysics.BodyType")
LuaUserData.RegisterType("System.Collections.Generic.Queue`1[[Barotrauma.Entity]], System.Collections")

gm.Name = "Station"
gm.RequiredGamemode = "mission"
gm.EndOnComplete = false
gm.RestrictShopToAccessibleCategories = true

function gm:PreStart()
    Traitormod.Gamemodes.Gamemode.PreStart(self)
    self.PreviousMissionTypes = Game.ServerSettings.MissionTypes
    Game.ServerSettings.MissionTypes = "VoidTraitorStation"
    Game.ServerSettings.ServerDetailsChanged = true
end

function gm:Start()
    Submarine.MainSub.SubBody.Body.BodyType = bodyTypes.Static
    self.ShopAvailability = {}
    secret.Start(self)
    Traitormod.Cargo.Start()
    for character in Character.CharacterList do
        if character.IsHuman and not character.IsDead and character.Submarine == Submarine.MainSub then
            Traitormod.IdConsole.InitializeCard(character)
        end
    end
end

function gm:Think()
    if not Game.RoundStarted then return end
    -- The native server omits static submarine positions from regular updates.
    for _, client in pairs(Client.ClientList) do
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
    Game.ServerSettings.MissionTypes = self.PreviousMissionTypes
    Game.ServerSettings.ServerDetailsChanged = true
end

Hook.Add("character.giveJobItems", "Traitormod.Station.IdCardAccess", function(character)
    if Traitormod.SelectedGamemode == nil or Traitormod.SelectedGamemode.Name ~= "Station" then return end
    Timer.Wait(function()
        if not character.Removed and character.Submarine == Submarine.MainSub then Traitormod.IdConsole.InitializeCard(character) end
    end, 0)
end)

return gm
