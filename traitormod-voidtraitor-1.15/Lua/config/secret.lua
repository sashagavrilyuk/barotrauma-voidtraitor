-- Secret mode defaults (config.GamemodeConfig.Secret); override them in config.lua
return {
    PointshopCategories = {"clown", "traitor", "saboteur", "cultist", "deathspawn", "deathspawnhusk", "deathspawnfriend", "deathtrigerevent", "deathtrigereventevil", "deathtrigereventrandom", "abilities", "surgery", "medical", "security", "wiring", "maintenance", "materials", "ores", "otherresources", "other", "randomize", "ships"},
    EndOnComplete = true,           -- end round everyone but traitors are dead
    EndWhenCrewDown = true,         -- end round when every crew player is dead or unconscious (not in test mode or while a respawn is pending)
    CrewDownEndDelaySeconds = 120,
    EnableRandomEvents = true,
    EndGameDelaySeconds = 60,
    TraitorSelectDelayMin = 120,
    TraitorSelectDelayMax = 150,

    PointsGainedFromHandcuffedTraitors = 3500,
    DistanceToEndOutpostRequired = 8000,
    SurvivorRewardEnabled = true,
    SurvivorRewardPercent = 50,
    SurvivorRewardRequiredDeathsPercent = 60,

    MissionPoints = {
        Salvage = 1100,
        SalvageWreck = 1250,
        SalvageCave = 1350,
        SalvageRuin = 1500,
        Monster = 1050,
        EliminateThalamus = 2200,
        Cargo = 1000,
        Beacon = 1200,
        Nest = 1700,
        Mineral = 1000,
        Combat = 1400,
        Escort = 1200,
        Pirate = 1300,
        GoTo = 1000,
        OutpostDestroy = 1500,
        OutpostRescue = 1400,
        AbandonedOutpost = 1200,
        AbandonedOutpostMonsters = 1300,
        AbandonedOutpostAssassinate = 1500,
        ["jailbreak"] = 1600,
        ScanAlienRuins = 1600,
        ClearAlienRuins = 2000,
        End = 3500,
        SubVsSubCombat = 1400,
        OutpostCombat = 1400,
        KingOfTheHull = 1500,
        Default = 1000,
    },
    PointsGainedFromCrewMissionsCompleted = 1000,
    LivesGainedFromCrewMissionsCompleted = 1,
    MissionEndAdditionalReward = function ()
        return 0
    end,

    TraitorTypeSelectionMode = "Random", -- Vote | Random
    TraitorTypeChance = {
        Traitor = 50,
        Cultist = 50,
        Clown = 50,
        Saboteur = 50,
    },

    AmountTraitors = function (amountPlayers)
        if amountPlayers > 18 and math.random() < 0.25 then return 4 end
        if amountPlayers > 12 then return 3 end
        if amountPlayers > 7 then return 2 end
        if amountPlayers > 3 then return 1 end
        if amountPlayers == 1 then return 1 end
        print("Not enough players to start traitor mode.")
        return 0
    end,

    -- 0 = 0% chance
    -- 1 = 100% chance
    TraitorFilter = function (client)
        if client.Character.TeamID ~= CharacterTeamType.Team1 then return 0 end
        if not client.Character.IsHuman then return 0 end
        if client.Character.HasJob("captain") then return 0 end
        if client.Character.HasJob("securityofficer") then return 0 end
        if client.Character.HasJob("medicaldoctor") then return 0.5 end
        if client.Character.HasJob("surgeon") then return 0.5 end
        return 1
    end
}
