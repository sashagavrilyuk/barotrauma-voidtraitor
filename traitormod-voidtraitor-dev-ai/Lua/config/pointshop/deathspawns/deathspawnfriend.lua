local category = {}

category.Identifier = "deathspawnfriend"
category.Decoration = "huskinvite"

category.CanAccess = function(client)
    return client.Character == nil or client.Character.IsDead or not client.Character.IsHuman
end

local function SpawnCreature(species, client, product, paidPrice, insideHuman)
    local waypoints = Submarine.MainSub.GetWaypoints(true)

    if LuaUserData.IsTargetType(Game.GameSession.GameMode, "Barotrauma.PvPMode") then
        waypoints = Submarine.MainSubs[math.random(2)].GetWaypoints(true)
    end

    local spawnPositions = {}

    if insideHuman then
        for key, value in pairs(Character.CharacterList) do
            if value.IsHuman and not value.IsDead and value.TeamID == CharacterTeamType.Team1 then
                table.insert(spawnPositions, value.WorldPosition)
            end
        end
    else
        for key, value in pairs(waypoints) do
            if value.CurrentHull == nil then
                local walls = Level.Loaded.GetTooCloseCells(value.WorldPosition, 250)
                if #walls == 0 then
                    table.insert(spawnPositions, value.WorldPosition)
                end
            end
        end
    end

    local spawnPosition

    if #spawnPositions == 0 then
        -- no waypoints? https://c.tenor.com/RgExaLgYIScAAAAC/megamind-megamind-meme.gif
        spawnPosition = Submarine.MainSub.WorldPosition -- spawn it in the middle of the sub

        Traitormod.Log("Couldnt find any good waypoints, spawning in the middle of the sub.")
    else
        spawnPosition = spawnPositions[math.random(#spawnPositions)]
    end

    Entity.Spawner.AddCharacterToSpawnQueue(species, spawnPosition, function (character)
        client.SetClientCharacter(character)
        Traitormod.Pointshop.TrackRefund(client, product, paidPrice)
    end)
end

category.Products = {
    {
        Identifier = "spawnaspeanut",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "peanut",
        Icon = "vt_preview_creature_peanut",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("peanut", client, product, paidPrice, true)
        end
    },

    {
        Identifier = "spawnasorangeboy",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "orangeboy",
        Icon = "vt_preview_creature_orangeboy",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("orangeboy", client, product, paidPrice, true)
        end
    },

    {
        Identifier = "spawnascthulhu",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "balloon",
        Icon = "vt_preview_creature_balloon",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("balloon", client, product, paidPrice, true)
        end
    },

    {
        Identifier = "spawnaspsilotoad",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "psilotoad",
        Icon = "vt_preview_creature_psilotoad",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("psilotoad", client, product, paidPrice, true)
        end
    },
	
    {
        Identifier = "spawnasClownOrangeboy",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "Clown_Orangeboy",
        Icon = "vt_preview_creature_clown_orangeboy",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Clown_Orangeboy", client, product, paidPrice, true)
        end
    },
	
    {
        Identifier = "spawnasClownPeanut",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "Clown_Peanut",
        Icon = "vt_preview_creature_clown_peanut",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Clown_Peanut", client, product, paidPrice, true)
        end
    },
	
    {
        Identifier = "spawnasClownPsilotoad",
        Price = 50,
        Limit = 2,
        IsLimitGlobal = false,

        GuiCreature = "Clown_Psilotoad",
        Icon = "vt_preview_creature_clown_psilotoad",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Clown_Psilotoad", client, product, paidPrice, true)
        end
    },
	
    {
        Identifier = "spawnasDefensebot",
        Price = 900,
        Limit = 2,
        IsLimitGlobal = true,

        GuiCreature = "Defensebot",
        Icon = "vt_preview_creature_defensebot",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Defensebot", client, product, paidPrice, true)
			Traitormod.SendMessage(client, Traitormod.Language.FriendPet, "GameModeIcon.sandbox")
        end
    },
    
    {
        Identifier = "spawnasMudraptorpet",
        Price = 1250,
        Limit = 2,
        IsLimitGlobal = true,

        GuiCreature = "Mudraptor_pet",
        Icon = "vt_preview_creature_mudraptor_pet",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
			Traitormod.SendMessage(client, Traitormod.Language.FriendPet, "GameModeIcon.sandbox")
            SpawnCreature("Mudraptor_pet", client, product, paidPrice, true)
        end
    },
		
    {
        Identifier = "STransformedMudraptor",
        Price = 2500,
        Limit = 1,
        IsLimitGlobal = true,

        GuiCreature = "STransformedMudraptor",
        Icon = "vt_preview_creature_stransformedmudraptor",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("STransformedMudraptor", client, product, paidPrice, true)
            Traitormod.SendMessage(client, Traitormod.Language.FriendPet, "GameModeIcon.sandbox")
        end
    },

    {
        Identifier = "Huskmutanthunteraddict",
        Price = 4000,
        Limit = 1,
        IsLimitGlobal = true,

        GuiCreature = "Huskmutanthunteraddict",
        Icon = "vt_preview_creature_huskmutanthunteraddict",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutanthunteraddict", client, product, paidPrice, true)
            Traitormod.SendMessage(client, Traitormod.Language.FriendPet, "GameModeIcon.sandbox")
        end
    },
}

return category