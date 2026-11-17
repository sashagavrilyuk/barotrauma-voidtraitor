-- Station mode defaults (config.GamemodeConfig.Station); override them in config.lua
return {
    EndWhenCrewDown = true,
    CrewDownEndDelaySeconds = 120,
    OutpostEscapePercent = 60,
    OutpostEscapeMinutes = 2,
    -- Roles as SS14's jobs: the game sees each role's Job, Slots is how many players can have it at once (none: any
    -- number). Heads are handed out first, the higher Head the earlier, and are never antagonists. IdPreset is the ID
    -- card preset (IdConsole.Presets) and Radio the department keys of the headset. Passenger is the role of everyone
    -- who got no other: no access and only the common channel. A map sets its own seats in the [traitormod] JSON of
    -- its description, for example "RoleSlots": { "engineer": 6, "cook": 0 }; roles it leaves out keep these.
    -- Requirements are SS14's role timers: the role opens once the player has the hours of every line, on a role
    -- ({ Role = "engineer", Hours = 5 }), in a department, which adds up the time of its roles ({ Department =
    -- "engineering", Hours = 10 }), or in total on the server, as !playtime shows it ({ Hours = 4 }).
    Roles = {
        captain = { Job = "captain", Slots = 1, Head = 7, IdPreset = "captain",
            Radio = { "command", "engineering", "medical", "security", "cargo", "science" },
            Requirements = { { Department = "command", Hours = 4 }, { Department = "security", Hours = 4 },
                { Department = "engineering", Hours = 4 }, { Department = "medical", Hours = 4 }, { Department = "science", Hours = 4 } } },
        headofpersonnel = { Job = "assistant", Slots = 1, Head = 6, IdPreset = "headofpersonnel", Radio = { "command" },
            Requirements = { { Department = "command", Hours = 2.5 }, { Department = "security", Hours = 2.5 },
                { Department = "engineering", Hours = 2.5 }, { Department = "medical", Hours = 2.5 }, { Department = "science", Hours = 2.5 } } },
        headofsecurity = { Job = "securityofficer", Slots = 1, Head = 5, IdPreset = "headofsecurity", Radio = { "command", "security" },
            Requirements = { { Role = "securityofficer", Hours = 5 }, { Department = "security", Hours = 10 } } },
        chiefengineer = { Job = "engineer", Slots = 1, Head = 4, IdPreset = "chiefengineer", Radio = { "command", "engineering" },
            Requirements = { { Role = "engineer", Hours = 5 }, { Department = "engineering", Hours = 10 } } },
        chiefmedicalofficer = { Job = "medicaldoctor", Slots = 1, Head = 3, IdPreset = "chiefmedicalofficer", Radio = { "command", "medical" },
            Requirements = { { Role = "medicaldoctor", Hours = 5 }, { Department = "medical", Hours = 10 } } },
        researchdirector = { Job = "scientist", Slots = 1, Head = 2, IdPreset = "researchdirector", Radio = { "command", "science" },
            Requirements = { { Role = "scientist", Hours = 5 }, { Department = "science", Hours = 10 } } },
        quartermaster = { Job = "mechanic", Slots = 1, Head = 1, IdPreset = "quartermaster", Radio = { "command", "cargo" },
            Requirements = { { Role = "cargotechnician", Hours = 5 }, { Role = "miner", Hours = 2.5 }, { Department = "cargo", Hours = 10 } } },
        -- SS14 asks 4 hours in Security, played as a cadet; there are no cadets here
        securityofficer = { Job = "securityofficer", Slots = 5, IdPreset = "securityofficer", Radio = { "security" },
            Requirements = { { Hours = 4 } } },
        engineer = { Job = "engineer", Slots = 4, IdPreset = "engineer", Radio = { "engineering" } },
        cargotechnician = { Job = "mechanic", Slots = 3, IdPreset = "cargo", Radio = { "cargo" } },
        miner = { Job = "mechanic", Slots = 2, IdPreset = "cargo", Radio = { "cargo" } },
        medicaldoctor = { Job = "medicaldoctor", Slots = 3, IdPreset = "medicaldoctor", Radio = { "medical" } },
        surgeon = { Job = "surgeon", Slots = 2, IdPreset = "surgeon", Radio = { "medical" } },
        scientist = { Job = "scientist", Slots = 4, IdPreset = "scientist", Radio = { "science" } },
        cook = { Job = "he-chef", Slots = 1, IdPreset = "assistant" },
        janitor = { Job = "assistant", Slots = 2, IdPreset = "assistant" },
        passenger = { Job = "assistant", Passenger = true },
    },
    -- the lobby's jobs window, in this order; heads are both in Command and in their own department, as in SS14
    Departments = {
        { Id = "command", Roles = { "captain", "headofpersonnel", "headofsecurity", "chiefengineer", "chiefmedicalofficer", "researchdirector", "quartermaster" } },
        { Id = "security", Roles = { "headofsecurity", "securityofficer" } },
        { Id = "engineering", Roles = { "chiefengineer", "engineer" } },
        { Id = "cargo", Roles = { "quartermaster", "cargotechnician", "miner" } },
        { Id = "medical", Roles = { "chiefmedicalofficer", "medicaldoctor", "surgeon" } },
        { Id = "science", Roles = { "researchdirector", "scientist" } },
        { Id = "service", Roles = { "headofpersonnel", "cook", "janitor", "passenger" } },
    },
    -- false opens every role whatever its Requirements. Time on a role counts while the player lives with it in a
    -- Station round and has touched the controls in the last RoleTimeIdleSeconds, as SS14 leaves out AFK players.
    RoleTimeRequirements = true,
    RoleTimeIdleSeconds = 180,
    -- the Hungry Europans talent that gives players hunger and thirst when they spawn; nil turns needs off
    NeedsTalent = "he-hungryeuropan",
    -- minutes for each need to fill up from empty at 100 vitality; a need left out stays off
    NeedsFullMinutes = { hunger = 167, thirst = 83 },
    WavesEnabled = true,
    SuppressOutdoorWaves = true,
    WaveMinPlayers = 20,
    WaveMaxPlayers = 40,
    WaveMinAmountMultiplier = 1,
    WaveMaxAmountMultiplier = 1.25,
    WaveInitialDelayMinMinutes = 14,
    WaveInitialDelayMaxMinutes = 19,
    WaveIntervals = {
        { Players = 2, Min = 19, Max = 24 },
        { Players = 5, Min = 16, Max = 20 },
        { Players = 9, Min = 14, Max = 18 },
        { Players = 40, Min = 12, Max = 16 },
    },
    WaveMaxDifficulty = 100,
    WaveDifficultyBands = {
        { Min = 1, Max = 10 }, { Min = 10, Max = 30 },
        { Min = 30, Max = 60 }, { Min = 60, Max = 100 },
    },
    WaveDifficultyCurve = {
        { Minutes = 20, Weights = { 100, 0, 0, 0 } },
        { Minutes = 30, Weights = { 80, 20, 0, 0 } },
        { Minutes = 45, Weights = { 55, 35, 9, 1 } },
        { Minutes = 60, Weights = { 25, 45, 25, 5 } },
        { Minutes = 90, Weights = { 5, 30, 50, 15 } },
        { Minutes = 120, Weights = { 0, 15, 50, 35 } },
        { Minutes = 150, Weights = { 0, 5, 40, 55 } },
    },
    WavePopulationLimits = {
        { Fraction = 0.15, Band = 1 },
        { Fraction = 0.40, Band = 2 },
        { Fraction = 0.75, Band = 3 },
    },
    WavePools = {
        { Weight = 75, Sets = {
            "Difficulty level 1", "Difficulty level 2", "Difficulty level 3",
            "Difficulty level 4", "Difficulty level 5", "Difficulty level 6",
            "Difficulty level 7", "Difficulty level 8", "Difficulty level 9", "Difficulty level 10",
        } },
        { Weight = 25, Sets = { "HuskOne", "HuskTwo", "HuskThree" } },
    },
    WaveSpawnMinDistance = 5,
    WaveSpawnMaxDistance = 15,
    WaveWallClearance = 10,
    WaveActiveDistance = 250,
    Evacuation = {
        InitialDelay = 600,
        RecallDelay = 60,
        BoardingTime = 180,
        OtherDockBoardingTime = 300,
        NoDockBoardingTime = 360,
        TravelTime = 300,
        PumpFlowMultiplier = 1,
    },
    -- boats of the events from outside, by the tag of their helm; they wait parked above the level and come out at its
    -- far end when their event starts, each boat once, so more boats with a tag let it come again
    EventBoats = {
        Saboteur = "vt_saboteur_helm",
        LoneOperative = "vt_loneop_helm",
        Visitors = "vt_visitor_helm",
    },
    -- SS14's smuggler stash: at round start valuables are hidden in a random one of these cabinets of the station
    SmugglerStash = {
        Containers = { "suppliescabinet", "mediumsteelcabinet", "mediumwindowedsteelcabinet", "steelcabinet" },
        Items = { "physicorium", "incendium", "fulgurium", "dementonite", "combatstimulantsyringe", "fulguriumbatterycell" },
        ItemCount = 3,
        Points = 1000,
    },
    PointshopCategories = {"traitor", "cultist", "saboteur", "clown"},
    -- antagonist products that start a random event; Station runs its own events
    HiddenProducts = {
        ReactorShutdown = true, SupercapacitorFailure = true, JunctionBoxOverload = true, OxygenSufforin = true,
        OxygenParalyzant = true, OxygenMorbusine = true, OxygenCyanide = true, turnofflights = true,
        turnoffcommunications = true, clownmagic = true, randomizelights = true, huskoxygensupply = true,
    },
    EndOnComplete = false,
    EnableRandomEvents = true,
    TraitorTypeSelectionMode = "Random",
    TraitorTypeChance = {
        Traitor = 50,
        Cultist = 50,
        Saboteur = 50,
        Clown = 50,
    },
}
