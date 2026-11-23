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
    -- SS14's smuggler stash: at round start valuables are hidden in a random one of the containers the map tags with
    -- Tag in the sub editor, or on a map that tags none, of these cabinets of the station
    SmugglerStash = {
        Tag = "vt_smugglerstash",
        Containers = { "suppliescabinet", "mediumsteelcabinet", "mediumwindowedsteelcabinet", "steelcabinet" },
        Items = { "physicorium", "incendium", "fulgurium", "dementonite", "combatstimulantsyringe", "fulguriumbatterycell" },
        ItemCount = 3,
        Points = 1000,
    },
    -- What a round puts into the station's containers at its start, by the tag the map gives a container in the sub
    -- editor (the category "Станция", the pack's ContainerTags.xml). Fixed: these items and how many of each; Random:
    -- from Count[1] to Count[2] items drawn by their weights. A base after SS14's filled lockers and maintenance spawners.
    StationLoot = {
        -- SS14's maintenance spawners: odds and ends in the tunnels, tools most of all
        vt_maintloot = { Count = { 1, 3 }, Random = {
            wrench = 4, screwdriver = 4, wire = 4, crowbar = 3, flashlight = 3, batterycell = 3, flare = 3, glowstick = 3,
            weldingtool = 2, weldingfueltank = 2, oxygentank = 2, antibleeding1 = 2, divingmask = 1, toolbelt = 1,
            handheldsonar = 1, fixfoamgrenade = 1, plasmacutter = 1, harmonica = 1, cigar = 1,
        } },
        -- ClosetEmergencyFilled: air for two
        vt_emergencyloot = { Fixed = { divingmask = 2, oxygentank = 2 } },
        -- ClosetFireFilled
        vt_fireloot = { Fixed = { extinguisher = 1, divingmask = 1, oxygentank = 1 } },
        -- ClosetToolFilled
        vt_toolloot = { Count = { 2, 4 }, Random = {
            wrench = 3, screwdriver = 3, wire = 3, crowbar = 2, weldingtool = 2, weldingfueltank = 2, flashlight = 2,
            batterycell = 2, toolbelt = 1, plasmacutter = 1,
        } },
        -- LockerSecurityFilled
        vt_securityloot = { Fixed = { handcuffs = 2, stunbaton = 1, batterycell = 1, bodyarmor = 1, ballistichelmet1 = 1 } },
        -- LockerMedicineFilled
        vt_medicalloot = { Fixed = { antibleeding1 = 4, antibleeding2 = 2, antidama1 = 2, antibiotics = 1, healthscanner = 1 } },
        -- LockerEngineerFilled
        vt_engineeringloot = { Fixed = { toolbelt = 1, wrench = 1, screwdriver = 1, weldingtool = 1, weldingfueltank = 1, wire = 2 } },
    },
    -- Xenoarchaeology, as SS14's before its 2025 rework (gamemodes/station/xenoarch.lua; SS14 e9d13ea
    -- Content.Server/Xenoarchaeology). Depth is a trigger's or effect's target depth in the node tree: the closer to a
    -- node's depth, the likelier. Effects: gamemodes/station/xenoarch_effects.lua; texts: language Xenoarch*.
    Xenoarch = {
        -- nodes in a tree: SS14 takes random.Next(3, 9)
        NodesMin = 3,
        NodesMax = 8,
        Cooldown = 5,
        -- how often a big artifact's node below the root is its own (pack Lua/extensions/artifacts.lua): there its
        -- family's effects run, the vanilla artifact's at depth 1 and stronger ones deeper
        OwnNodeChance = 0.4,
        -- research points of a node: PointsPerNode * DangerMultiplier ^ danger, danger being the mean depth of the
        -- node, its trigger and its effect; a node seen but never triggered gives a quarter; a fully explored tree 1.25x
        PointsPerNode = 6500,
        DangerMultiplier = 1.35,
        FullyExploredBonus = 1.25,
        AnalysisSeconds = 30,
        -- how far the analysis console reaches its analyzer
        AnalyzerRange = 500,
        -- triggers: physical damage taken in total (DamageTypes, as SS14's brute damage), the timer's period, how far a
        -- death is felt
        DamageTypes = { "blunttrauma", "lacerations", "gunshotwound", "explosiondamage" },
        DamageThreshold = 50,
        HighDamageThreshold = 500,
        TimerSeconds = 5,
        DeathRange = 1500,
        -- how hard an artifact has to hit something to have landed (Item.ImpactTolerance)
        LandingImpact = 6,
        -- music: an instrument played this close
        Instruments = { "harmonica", "guitar", "accordion" },
        MusicRange = 600,
        Triggers = {
            { Id = "timer", Depth = 0 },
            { Id = "examine", Depth = 0 },
            -- in a powered machine's container, as SS14's electricity trigger on a powered cable
            { Id = "electricity", Depth = 0 },
            { Id = "music", Depth = 1 },
            { Id = "damage", Depth = 1 },
            { Id = "landed", Depth = 1 },
            { Id = "heat", Depth = 1 },
            { Id = "water", Depth = 1 },
            { Id = "death", Depth = 2 },
            { Id = "highdamage", Depth = 3 },
        },
        Effects = {
            { Id = "GoodFeeling", Depth = 0 },
            -- PointLight, Radiate, Magnet, AntiMagnet and Invisibility act while the artifact sits on their node
            { Id = "PointLight", Depth = 0 },
            { Id = "Throw", Depth = 0, Range = 400, Force = 15 },
            { Id = "JunkSpawn", Depth = 0, Items = { "scrap" }, Max = 10 },
            { Id = "BananaSpawn", Depth = 0, Items = { "bananapeel" }, Max = 6 },
            { Id = "ChemicalPuddle", Depth = 0, Items = { "chlorine", "ethanol", "sulphuricacid", "adrenaline", "antibiotics", "opium", "stabilozine" }, Max = 2 },
            { Id = "FloraSpawn", Depth = 1, Items = { "aquaticpoppy", "elastinplant", "fiberplant", "yeastshroom" }, Max = 4 },
            { Id = "InstrumentSpawn", Depth = 1, Items = { "harmonica", "guitar", "accordion" }, Max = 1 },
            { Id = "MonkeySpawn", Depth = 1, Species = { "peanut", "orangeboy", "psilotoad" }, Max = 1 },
            { Id = "Radiate", Depth = 1, Affliction = "radiationsickness", Strength = 2, Range = 400 },
            { Id = "Heat", Depth = 1, Affliction = "burn", Strength = 15, Range = 400 },
            { Id = "Magnet", Depth = 1, Range = 600, Force = 3 },
            { Id = "AntiMagnet", Depth = 1, Range = 600, Force = -3 },
            { Id = "Knock", Depth = 1, Range = 600 },
            { Id = "ExplosionScary", Depth = 2, Range = 300, Force = 3, Damage = 0, Stun = 0 },
            { Id = "RareMaterialSpawn", Depth = 2, Items = { "uranium", "incendium", "fulgurium", "physicorium" }, Max = 3 },
            { Id = "AngryCarpSpawn", Depth = 2, Species = { "crawler", "spineling" }, Max = 2 },
            { Id = "FaunaSpawn", Depth = 2, Species = { "peanut", "orangeboy", "psilotoad", "crawler", "mudraptor_unarmored" }, Max = 3 },
            { Id = "CashSpawn", Depth = 2, Points = { 100, 500 } },
            { Id = "Blink", Depth = 2, Range = 600 },
            { Id = "Emp", Depth = 2, Range = 600, Strength = 1 },
            { Id = "Invisibility", Depth = 2 },
            { Id = "FoamGood", Depth = 2, Amount = 30, Range = 400 },
            { Id = "HealAll", Depth = 3, Amount = 100, Range = 800 },
            { Id = "RadiateStrong", Depth = 3, Affliction = "radiationsickness", Strength = 6, Range = 600 },
            { Id = "Shuffle", Depth = 3, Range = 750 },
            { Id = "MaterialSpawn", Depth = 3, Items = { "steel", "plastic", "titaniumaluminiumalloy" }, Max = 5 },
            { Id = "Ignite", Depth = 3, Range = 700 },
            { Id = "Mitosis", Depth = 3 },
            { Id = "Boom", Depth = 3, Range = 500, Force = 20, Damage = 60, StructureDamage = 60 },
            { Id = "Singulo", Depth = 10, Item = "Sthal_singularity" },
        },
    },
    -- Anomalies, as SS14's (gamemodes/station/anomalies.lua; SS14 Content.Shared/Anomaly and Content.Server/Anomaly at
    -- f00a972). The numbers are SS14's; ranges are in Barotrauma units, an SS14 tile counted as 100. Texts: language
    -- Anomaly*.
    Anomalies = {
        InitialStability = { 0.4, 0.6 },
        InitialSeverity = { 0.1, 0.5 },
        -- below DecayThreshold an anomaly loses health every second; above GrowthThreshold it grows at each pulse
        DecayThreshold = 0.15,
        GrowthThreshold = 0.5,
        HealthPerSecond = -0.01,
        SeverityGrowth = 0.07,
        -- a pulse every 2-4 minutes, the more stable the rarer; the first one three times later
        PulseSeconds = { 120, 240 },
        PulseVariation = 0.1,
        PulseStability = { -0.1, 0.15 },
        SupercriticalSeconds = 10,
        -- research points a second through a vessel; an unstable (growing) anomaly gives more
        PointsPerSecond = { 10, 70 },
        GrowingPointMultiplier = 1.5,
        -- the chance that a transformation particle changes the anomaly's behaviour
        Continuity = { 0.1, 1 },
        -- what one APE particle does (SS14 AnomalousParticleComponent), each time varied by 0.8-1.2
        Particle = { Severity = 0.025, Stability = 0.04, Health = -0.05, WeakeningStability = -0.1, Variation = { 0.8, 1.2 } },
        Particles = { "delta", "epsilon", "zeta", "sigma" },
        -- how many of the scanner's readings an anomaly hides (SS14 SecretDataAnomaly, the upper bound excluded)
        Secrets = { 0, 2 },
        -- the vessel of an anomaly that went supercritical blows up
        VesselExplosion = { Range = 300, Force = 5, Damage = 40, StructureDamage = 40 },
        -- SS14 takes half a stack of plasma; incendium is the nearest Barotrauma has
        Generator = { Material = "incendium", CooldownSeconds = 300, GenerationSeconds = 8 },
        -- SS14's behaviours (Prototypes/Anomaly/behaviours.yml) but those that hide the anomaly; drawn by weight. Jump:
        -- every Seconds the anomaly jumps Distance away (SS14 ChaoticJump)
        Behaviors = {
            { Id = "Balanced", Weight = 3 },
            { Id = "FullSafe", Weight = 0.1, PulseFrequency = 3, PulsePower = 0.5, Points = 0.05 },
            { Id = "Slow", Weight = 0.5, PulseFrequency = 2, Points = 0.5 },
            { Id = "Light", Weight = 0.5, PulsePower = 0.5, Points = 0.5 },
            { Id = "DelayedForce", Weight = 1, PulseFrequency = 2, PulsePower = 2, Points = 1.15 },
            { Id = "Rapid", Weight = 1, PulseFrequency = 0.5, PulsePower = 0.5, Points = 1.15 },
            { Id = "BalancedSecret", Weight = 1, Points = 1.2, Secrets = { 2, 3 } },
            { Id = "NonSensivity", Weight = 1, Points = 0.8, Sensitivity = 0.5 },
            { Id = "Sensivity", Weight = 1, Points = 1.2, Sensitivity = 1.5 },
            { Id = "Fast", Weight = 0.5, PulseFrequency = 0.5, Points = 1.9 },
            { Id = "Strenght", Weight = 0.5, PulsePower = 1.5, Points = 1.4 },
            { Id = "Inconstancy", Weight = 0.5, Points = 1.7, ShuffleOnPulse = 1 },
            { Id = "InconstancyParticle", Weight = 0.5, Points = 1.8, ShuffleOnHit = 0.8 },
            { Id = "FullUnknown", Weight = 0.5, Points = 1.9, Secrets = { 4, 6 } },
            { Id = "FastUnknown", Weight = 0.2, PulseFrequency = 0.5, Points = 1.9, Secrets = { 3, 5 } },
            { Id = "InconstancyParticleUnknown", Weight = 0.1, Points = 1.95, ShuffleOnHit = 0.5, Secrets = { 3, 5 } },
            { Id = "Jumping", Weight = 0.3, Points = 1.8, Jump = { Seconds = { 15, 25 }, Distance = { 100, 400 } } },
            { Id = "JumpingUnknown", Weight = 0.1, Points = 1.9, Jump = { Seconds = { 15, 25 }, Distance = { 100, 100 } }, Secrets = { 3, 5 } },
        },
        -- the kinds an event or the generator brings, each with its core after a supercritical end and its inert core
        -- after it decayed (effects: gamemodes/station/anomaly_effects.lua)
        Types = {
            -- sets people on fire, Burn for each of SS14's fire stacks (SS14 PyroclasticAnomaly)
            { Id = "pyro", Item = "vt_anomaly_pyro", Core = "vt_anomaly_core_pyro", InertCore = "vt_anomaly_core_pyro_inert",
                IgnitionRange = 500, Burn = 5 },
            -- lightning bolts and shocks, an EMP at the end (SS14 ElectricityAnomaly)
            { Id = "electric", Item = "vt_anomaly_electric", Core = "vt_anomaly_core_electric", InertCore = "vt_anomaly_core_electric_inert",
                Range = 700, Bolts = { 2, 5 }, ShockChance = 0.05, Burn = 20, Stun = 8 },
            -- throws and pulls, radiates, tears the hull at the end (SS14 GravityAnomaly)
            { Id = "gravity", Item = "vt_anomaly_gravity", Core = "vt_anomaly_core_gravity", InertCore = "vt_anomaly_core_gravity_inert",
                ThrowRange = 500, ThrowForce = 10, PullRange = 1000, PullForce = 2, Radiation = 1.5, TearRange = 300, TearDamage = 200 },
            -- floods its room (SS14's liquid anomaly spills reagents; the sea is Barotrauma's)
            { Id = "liquid", Item = "vt_anomaly_liquid", Core = "vt_anomaly_core_liquid", InertCore = "vt_anomaly_core_liquid_inert",
                Flood = 0.3 },
            -- swaps places with the people near it, sends whoever touches it elsewhere in the station, scatters everyone
            -- near it across the station at the end (SS14 BluespaceAnomaly and its portal)
            { Id = "bluespace", Item = "vt_anomaly_bluespace", Core = "vt_anomaly_core_bluespace", InertCore = "vt_anomaly_core_bluespace_inert",
                ShuffleRange = 1000, TouchRange = 100, PortalRange = { 1000, 2500 }, ScatterRange = 5000 },
        },
    },
    -- Research, as SS14's with Goob Station's tree (gamemodes/station/research.lua). Costs are SS14's; Position is the
    -- technology's cell in Goob's tree and Requires its arrows. A fabricator prints its Static recipes and those of
    -- the vanilla fabricator StaticFrom names from the start; a technology adds Recipes by fabricator. The vanilla
    -- fabricator is SS14's autolathe, the medical fabricator its medical techfab. Names: language ResearchTechnologies.
    Research = {
        StartPoints = 0,
        -- the ID card access a player needs to research at the console; anyone can look at the tree
        AccessTag = "vt_access_science",
        -- the share of a discipline's technologies of the tier below that opens the next tier
        TierShare = { 0, 0.75, 0.75 },
        Disciplines = {
            { Id = "Industrial", Color = { 238, 172, 52 } },
            { Id = "Arsenal", Color = { 220, 55, 59 } },
            { Id = "Experimental", Color = { 154, 110, 240 } },
            { Id = "CivilianServices", Color = { 126, 205, 72 } },
        },
        Lathes = {
            fabricator = { Static = {
                "screwdriver", "wrench", "crowbar", "weldingtool", "weldingfueltank", "flashlight", "flare", "glowstick",
                "extinguisher", "toolbox", "toolbelt", "batterycell", "oxygentank", "divingmask", "headset", "sprayer",
                "electriciansgoggles", "steel", "plastic", "rubber", "titaniumaluminiumalloy", "ballisticfiber",
                "redwire", "bluewire", "orangewire", "greenwire", "blackwire", "brownwire", "button", "switch", "lever",
                "terminal", "textdisplay", "lightcomponent", "lightcomponent90", "lightcomponentround", "andcomponent",
                "orcomponent", "xorcomponent", "notcomponent", "equalscomponent", "greatercomponent", "addercomponent",
                "subtractcomponent", "multiplycomponent", "dividecomponent", "relaycomponent", "delaycomponent",
                "memorycomponent", "signalcheckcomponent", "regexcomponent", "oscillator", "wificomponent",
                "multiplexercomponent", "demultiplexercomponent", "concatcomponent", "colorcomponent", "oxygendetector",
                "waterdetector", "smokedetector", "motiondetector", "emergencysiren", "alarmbuzzer", "healthscanner",
            } },
            vt_protolathe = { Static = {} },
            vt_sectechfab = { Static = { "handcuffs", "stunbaton", "bodyarmor", "ballistichelmet1", "divingknife" } },
            medicalfabricator = { StaticFrom = "medicalfabricator", Static = {} },
        },
        Technologies = {
            { Id = "PowerGeneration", Discipline = "Industrial", Tier = 1, Cost = 7500, Position = { 0, -2 }, Icon = "fuelrod",
                Recipes = { vt_protolathe = { "fuelrod", "thoriumfuelrod" } } },
            { Id = "SpaceScanning", Discipline = "Industrial", Tier = 1, Cost = 5000, Position = { 0, -3 }, Requires = { "PowerGeneration" },
                Icon = "handheldsonar", Recipes = { vt_protolathe = { "handheldsonar", "sonarbeacon", "handhelditemfinder" } } },
            { Id = "SalvageEquipment", Discipline = "Industrial", Tier = 1, Cost = 7500, Position = { 0, -4 }, Requires = { "SpaceScanning" },
                Icon = "plasmacutter", Recipes = { vt_protolathe = { "plasmacutter", "underwaterscooter" } } },
            { Id = "MechanicalCompression", Discipline = "Industrial", Tier = 1, Cost = 10000, Position = { 1, -4 }, Requires = { "SpaceScanning" },
                Icon = "repairpack", Recipes = { vt_protolathe = { "repairpack", "fixfoamgrenade", "portablepump" } } },
            { Id = "IndustrialEngineering", Discipline = "Industrial", Tier = 1, Cost = 10000, Position = { 1, -5 }, Requires = { "MechanicalCompression" },
                Icon = "handheldstatusmonitor", Recipes = { vt_protolathe = { "handheldelectricalmonitor", "handheldstatusmonitor",
                    "reactorpda", "circuitbox", "fpgacircuit" } } },
            { Id = "AdvancedPowercells", Discipline = "Industrial", Tier = 1, Cost = 7500, Position = { 1, -6 }, Requires = { "IndustrialEngineering" },
                Icon = "fulguriumbatterycell", Recipes = { vt_protolathe = { "fulguriumbatterycell" } } },
            { Id = "AtmosphericTech", Discipline = "Industrial", Tier = 1, Cost = 7500, Position = { -2, -4 }, Requires = { "SpaceScanning" },
                Icon = "oxygenitetank", Recipes = { vt_protolathe = { "oxygenitetank", "safetyharness" } } },
            { Id = "AdvancedAtmospherics", Discipline = "Industrial", Tier = 2, Cost = 7500, Position = { -2, -5 }, Requires = { "AtmosphericTech" },
                Icon = "abyssdivingsuit", Recipes = { vt_protolathe = { "abyssdivingsuit", "pucs" } } },
            { Id = "Shuttlecraft", Discipline = "Industrial", Tier = 2, Cost = 10000, Position = { 2, -4 }, Requires = { "MechanicalCompression" },
                Icon = "cargoscooter", Recipes = { vt_protolathe = { "cargoscooter", "thermalgoggles" } } },
            { Id = "OptimizedMicrogalvanism", Discipline = "Industrial", Tier = 3, Cost = 10000, Position = { 2, -6 }, Requires = { "AdvancedPowercells" },
                Icon = "fulguriumfuelrod", Recipes = { vt_protolathe = { "fulguriumfuelrod" } } },

            { Id = "SalvageWeapons", Discipline = "Arsenal", Tier = 1, Cost = 5000, Position = { 1, 1 }, Icon = "harpoongun",
                Recipes = { vt_sectechfab = { "harpoongun", "spear", "explosivespear" } } },
            { Id = "DraconicMunitions", Discipline = "Arsenal", Tier = 1, Cost = 10000, Position = { 2, 2 }, Requires = { "SalvageWeapons" },
                Icon = "flamer", Recipes = { vt_sectechfab = { "incendiumgrenade", "flamer", "incendiumfueltank" } } },
            { Id = "NonlethalAmmunition", Discipline = "Arsenal", Tier = 1, Cost = 5000, Position = { 2, 3 }, Requires = { "SalvageWeapons" },
                Icon = "stungun", Recipes = { vt_sectechfab = { "stungun", "stungundart", "shotgunshellblunt", "40mmstungrenade" } } },
            { Id = "UraniumMunitions", Discipline = "Arsenal", Tier = 1, Cost = 7500, Position = { 3, 2 }, Requires = { "DraconicMunitions" },
                Icon = "revolverrounddepletedfuel", Recipes = { vt_sectechfab = { "revolverrounddepletedfuel", "smgmagazinedepletedfuel" } } },
            { Id = "AdvancedRiotControl", Discipline = "Arsenal", Tier = 1, Cost = 8000, Position = { 3, 3 }, Requires = { "NonlethalAmmunition" },
                Icon = "riotshield", Recipes = { vt_sectechfab = { "riotshield", "stungrenade", "ballistichelmet2" } } },
            { Id = "ExplosiveTechnology", Discipline = "Arsenal", Tier = 1, Cost = 10000, Position = { 4, 3 }, Requires = { "AdvancedRiotControl" },
                Icon = "c4block", Recipes = { vt_sectechfab = { "detonator", "timeddetonator", "c4block", "fraggrenade", "40mmgrenade" } } },
            { Id = "WeaponizedLaserManipulation", Discipline = "Arsenal", Tier = 1, Cost = 7500, Position = { 4, 0 }, Requires = { "DraconicMunitions" },
                Icon = "arcemitter", Recipes = { vt_sectechfab = { "arcemitter" } } },
            { Id = "ConcentratedLaserWeaponry", Discipline = "Arsenal", Tier = 2, Cost = 10000, Position = { 5, 0 }, Requires = { "WeaponizedLaserManipulation" },
                Icon = "hmg", Recipes = { vt_sectechfab = { "assaultrifle", "assaultriflemagazine", "hmg", "hmgmagazine" } } },
            { Id = "PortableMicrofusionWeaponry", Discipline = "Arsenal", Tier = 3, Cost = 15000, Position = { 6, 0 }, Requires = { "ConcentratedLaserWeaponry" },
                Icon = "nucleargun", Recipes = { vt_sectechfab = { "nucleargun" } } },

            { Id = "BasicRobotics", Discipline = "Experimental", Tier = 1, Cost = 5000, Position = { -1, 0 }, Icon = "defensebotspawner",
                Recipes = { vt_protolathe = { "defensebotspawner" } } },
            { Id = "BasicXenoArcheology", Discipline = "Experimental", Tier = 1, Cost = 5000, Position = { -2, 2 }, Requires = { "BasicRobotics" },
                Icon = "artifacttransportcase", Recipes = { vt_protolathe = { "artifacttransportcase" } } },
            { Id = "BasicAnomalousResearch", Discipline = "Experimental", Tier = 1, Cost = 5000, Position = { -2, 0 }, Requires = { "BasicRobotics" },
                Icon = "vt_anomaly_scanner", Recipes = { vt_protolathe = { "vt_anomaly_scanner", "vt_anomaly_locator",
                    "vt_anomaly_locator_wide", "vt_ape", "vt_particle_cell_delta", "vt_particle_cell_epsilon",
                    "vt_particle_cell_zeta", "vt_particle_cell_sigma" } } },
            { Id = "DeterrenceTechnologies", Discipline = "Experimental", Tier = 2, Cost = 7500, Position = { -3, -2 }, Requires = { "BasicRobotics" },
                Icon = "empgrenade", Recipes = { vt_protolathe = { "empgrenade" } } },
            { Id = "GravityManipulation", Discipline = "Experimental", Tier = 2, Cost = 10000, Position = { -4, 2 }, Requires = { "BasicXenoArcheology" },
                Icon = "gravityshell", Recipes = { vt_protolathe = { "gravityshell", "flakcannonammoboxgravity" } } },

            { Id = "AdvancedEntertainment", Discipline = "CivilianServices", Tier = 1, Cost = 7500, Position = { 0, 2 }, Icon = "cymbals",
                Recipes = { vt_protolathe = { "cymbals", "cigar" } } },
            { Id = "Hydroponics", Discipline = "CivilianServices", Tier = 1, Cost = 5000, Position = { -3, 4 }, Requires = { "AdvancedEntertainment" },
                Icon = "largeplanter", Recipes = { vt_protolathe = { "smallplanter", "largeplanter", "seedbag", "fertilizer",
                    "wateringcan", "plantergoggles", "growlight" } } },
            { Id = "AccessibilityTech", Discipline = "CivilianServices", Tier = 1, Cost = 4500, Position = { 3, 4 }, Requires = { "AdvancedEntertainment" },
                Icon = "autoinjectorheadset", Recipes = { vt_protolathe = { "autoinjectorheadset" } } },
            { Id = "MechanizedTreatment", Discipline = "CivilianServices", Tier = 2, Cost = 5000, Position = { -2, 4 }, Requires = { "AdvancedEntertainment", "BasicRobotics" },
                Icon = "syringegun", Recipes = { vt_protolathe = { "syringegun", "advancedsyringegun" } } },
            { Id = "BiochemicalStasis", Discipline = "CivilianServices", Tier = 2, Cost = 7500, Position = { 3, 5 }, Requires = { "AccessibilityTech" },
                Icon = "combatstimulantsyringe", Recipes = { medicalfabricator = { "combatstimulantsyringe", "pressurestabilizer", "endocrinebooster" } } },
            { Id = "BluespaceChemistry", Discipline = "CivilianServices", Tier = 3, Cost = 10000, Position = { 4, 5 }, Requires = { "BiochemicalStasis" },
                Icon = "sulphuricacidsyringe", Recipes = { medicalfabricator = { "sulphuricacidsyringe", "europabrew" } } },
        },
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
