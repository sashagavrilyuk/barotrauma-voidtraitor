-- random event defaults (config.RandomEventConfig); override them in config.lua
return {
    -- events the random rolls and the director may start in each mode; shops and admins can start any event
    ModeEvents = {
        Secret = {
            "MaintenanceToolsDelivery", "MedicalDelivery", "AmmoDelivery", "ArmoryCrate", "EmergencyTeam",
            "VentCreatures", "ClownCrateSurprise", "OxygenGeneratorHusk", "RandomLights",
            "ClownMagic", "LightsOff", "ReactorShutdown",
            "SupercapacitorFailure", "JunctionBoxOverload", "OxygenGeneratorPoison",
            "OxygenSufforin", "OxygenParalyzant", "OxygenMorbusine", "OxygenCyanide",
            "SecurityMindSense", "SecurityTurretCoilgun", "SecurityTurretChaingun",
            "SecurityTurretFlakcannon", "SecurityTurretPulseLaser", "SecurityTurretDoubleCoilgun",
            "SecurityTurretRailgun", "MechanicMechanicalRepair", "MechanicHullRepair",
            "MechanicSkillBoost", "EngineerElectricalRepair", "EngineerSkillBoost",
            "MedicSkillBoost", "SurgeonSkillBoost", "ElectricalFixDischarge", "FixHull",
            "FullFixHull", "FullElectricalFixDischarge",
            "SuperBallastFlora", "WeakBallastFlora", "AbyssHelp", "ShadyMission", "Prisoner",
            "WreckRescue", "BeaconRescue", "CaptainHelmBoost", "OutpostPirateAttack",
            "PirateCrew", "HiddenPirate", "WreckPirate", "BeaconPirate",
            "BreackElectrical", "BreackHull", "KillElectrical", "KillHull", "WildCreature", "MalfunctioningBot",
            "SeismicTremor", "GuardedCargo", "CommunicationsOffline",
        },
        Station = { "StationAttack" }, -- the waves; Station draws its other events from its scheduler
    },
    -- Like the SS14 station event scheduler: the first event a few minutes in, then one event every few minutes, drawn by
    -- weight from those that may run now. The weights and limits follow the closest SS14 events.
    Schedulers = {
        Station = {
            FirstEventSeconds = { 200, 320 },
            IntervalSeconds = { 180, 600 },
            -- defaults for the events below
            EarliestMinute = 5,
            RepeatAfterMinutes = 30,
            -- Weight, and optionally EarliestMinute, RepeatAfterMinutes, MinPlayers (connected) and MaxPerRound
            Events = {
                RadiationStorm = { Weight = 8 }, -- solar flare
                SeismicTremor = { Weight = 7 }, -- breaker flip
                WildCreature = { Weight = 6 }, -- random sentience
                VentCreatures = { Weight = 5, EarliestMinute = 20, MinPlayers = 15 }, -- vent hordes
                MalfunctioningBot = { Weight = 2.5, EarliestMinute = 15, MinPlayers = 4, RepeatAfterMinutes = 20 }, -- derelict cyborg
                IceCollapse = { Weight = 5, EarliestMinute = 10 }, -- no SS14 counterpart
                IceSpear = { Weight = 3.5, EarliestMinute = 30, MinPlayers = 25 }, -- immovable rod
                VentClog = { Weight = 5, EarliestMinute = 15, MinPlayers = 15 }, -- vent clog
                Visitors = { Weight = 5, EarliestMinute = 15 }, -- unknown shuttle
                SaboteurBoat = { Weight = 6, EarliestMinute = 30, MinPlayers = 30, RepeatAfterMinutes = 20 }, -- space ninja
                LoneOperative = { Weight = 5.5, EarliestMinute = 35, MinPlayers = 20 }, -- lone operative
                LifeSupportFailure = { Weight = 8 }, -- gas leak
                ShortCircuit = { Weight = 5, MinPlayers = 15 }, -- no SS14 counterpart
                BreakerFlip = { Weight = 7, MinPlayers = 15 }, -- breaker flip
                PowerGridCheck = { Weight = 5 }, -- power grid check
                WeakBallastFlora = { Weight = 7, EarliestMinute = 15, MinPlayers = 15 }, -- kudzu
                CoalitionGifts = { Weight = 6, EarliestMinute = 20, MinPlayers = 10 }, -- cargo gifts
                SleeperAgents = { Weight = 8, EarliestMinute = 30, MinPlayers = 15, MaxPerRound = 1 }, -- sleeper agents
                PatientZero = { Weight = 1, EarliestMinute = 45, MinPlayers = 15, MaxPerRound = 1 }, -- zombie outbreak
                ClericalError = { Weight = 5, MinPlayers = 15 }, -- clerical error
                BureaucraticError = { Weight = 3, MinPlayers = 25 }, -- bureaucratic error
                Stowaway = { Weight = 5, MinPlayers = 10 }, -- closet skeleton
                CritterMigration = { Weight = 6, EarliestMinute = 15 }, -- mouse migration
            },
        },
    },
    -- The director watches the round and starts events itself: help when the crew is going under, a threat after a calm
    -- stretch, a neutral event now and then and once in a while a false trail. The random events above keep running.
    Director = {
        Modes = { Secret = true },
        OpeningMinutes = 5, -- the director stays out of the opening, where the early events run on their own
        -- any of these, whoever starts it, resets the calm count and keeps random threats apart
        Threats = {
            "VentCreatures", "ClownCrateSurprise", "OxygenGeneratorHusk", "RandomLights", "ClownMagic", "LightsOff",
            "CommunicationsOffline", "ReactorShutdown", "SupercapacitorFailure", "JunctionBoxOverload",
            "OxygenGeneratorPoison", "OxygenSufforin", "OxygenParalyzant", "OxygenMorbusine", "OxygenCyanide",
            "SuperBallastFlora", "WeakBallastFlora", "ShadyMission", "Prisoner", "WreckRescue", "BeaconRescue",
            "OutpostPirateAttack", "PirateCrew", "HiddenPirate", "WreckPirate", "BeaconPirate",
            "BreackElectrical", "BreackHull", "KillElectrical", "KillHull", "WildCreature", "MalfunctioningBot", "SeismicTremor", "GuardedCargo",
        },
        MinThreatGapMinutes = 2, -- no random threat this soon after another threat
        CalmIntensity = 0.35, -- below this the minute counts as calm; the game's own event threshold on Medium
        LightThreatAfter = 4, -- calm minutes before the director starts a light threat
        MediumThreatAfter = 6, -- calm minutes before it may pick a medium one, or from MediumThreatFromMinute on
        MediumThreatFromMinute = 8,
        GraceAfterHelpMinutes = 4, -- no threat from the director this soon after its help
        LightThreats = {
            "LightsOff", "CommunicationsOffline", "JunctionBoxOverload", "SupercapacitorFailure", "ReactorShutdown",
            "WeakBallastFlora", "BreackElectrical", "BreackHull", "SeismicTremor",
        },
        MediumThreats = {
            "VentCreatures", "HiddenPirate", "SuperBallastFlora", "WreckRescue", "BeaconRescue", "AbyssHelp", "WildCreature",
            "MalfunctioningBot", "GuardedCargo",
        },
        -- preferred while dead players wait, so they get a role
        GhostRoleThreats = {
            VentCreatures = true, HiddenPirate = true, WreckRescue = true, BeaconRescue = true, WildCreature = true,
            MalfunctioningBot = true, GuardedCargo = true,
        },
        NeutralEveryMinutes = { 6, 10 },
        Neutral = {
            "MechanicSkillBoost", "EngineerSkillBoost", "MedicSkillBoost", "SurgeonSkillBoost", "CaptainHelmBoost",
            "SecurityMindSense", "SecurityTurretCoilgun", "SecurityTurretChaingun", "SecurityTurretFlakcannon",
            "SecurityTurretPulseLaser", "SecurityTurretDoubleCoilgun", "SecurityTurretRailgun", "ClownCrateSurprise",
        },
        -- an event of an antagonist role nobody has this round, so the crew suspects the wrong people
        FalseFlagFromMinute = 8,
        FalseFlagChancePerMinute = 0.02,
        FalseFlags = { Clown = { "RandomLights", "ClownMagic" }, Cultist = { "OxygenGeneratorHusk" } },
        -- Help comes by chance and seldom: the crew should first get by on its own and with the Pointshop.
        Help = {
            CheckSeconds = 15,
            MaxPerRound = 3,
            SustainSeconds = 30, -- trouble shorter than this never gets help
            Chance = 0.15, -- per check; halves with every help the director already gave
            CoveredChance = 0.07, -- when crew of the right job are on their feet
            OverwhelmedSeconds = 90, -- with such crew, help only when the trouble lasts this long or gets worse
            LowVitality = 0.25, -- below this share of vitality a crew member counts as down
            -- half the living crew down, or MaxAlive or fewer left with MinDead dead
            Collapse = { CooldownMinutes = 4, MaxAlive = 3, MinDead = 2, Events = { "EmergencyTeam" } },
            Medical = { CooldownMinutes = 3, Events = { "MedicalDelivery", "MedicSkillBoost", "SurgeonSkillBoost" } },
            -- creatures inside the sub while too few of the crew carry a gun
            Armory = {
                CooldownMinutes = 4,
                InsideEnemies = 3,
                WeaponTags = { "rangedweapon" },
                Events = { "ArmoryCrate" },
            },
            -- a swarm on the sub: creatures inside it or attacking it; AmmoDelivery itself picks ammo for the
            -- turrets the sub has and how much of it is left
            Defense = {
                CooldownMinutes = 4,
                Enemies = 8,
                Events = {
                    "AmmoDelivery", "SecurityMindSense", "SecurityTurretCoilgun", "SecurityTurretChaingun",
                    "SecurityTurretFlakcannon", "SecurityTurretPulseLaser", "SecurityTurretDoubleCoilgun",
                    "SecurityTurretRailgun",
                },
            },
            Hull = {
                CooldownMinutes = 4,
                Integrity = 0.6, Flooding = 0.3, -- the game's own measures; flooding 0.3 is about 20% water
                SevereIntegrity = 0.3, SevereFlooding = 0.75,
                Events = { "FixHull", "MechanicHullRepair" },
                SevereEvents = { "FullFixHull" },
            },
            Electrical = {
                CooldownMinutes = 4,
                Items = { "junctionbox", "supercapacitor", "battery", "reactor" },
                Broken = 2, SevereBroken = 4,
                Events = { "ElectricalFixDischarge", "EngineerElectricalRepair" },
                SevereEvents = { "FullElectricalFixDischarge" },
            },
        },
    },
    Events = {
        dofile(Traitormod.Path .. "/Lua/config/randomevents/stationattack.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/radiationstorm.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/icecollapse.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/icespear.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/ventclog.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/visitors.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/saboteurboat.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/loneoperative.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/lifesupportfailure.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/shortcircuit.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/breakerflip.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/powergridcheck.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/coalitiongifts.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sleeperagents.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/patientzero.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/clericalerror.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/bureaucraticerror.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/stowaway.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/crittermigration.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/superballastflora.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/maintenancetoolsdelivery.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/medicaldelivery.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/ammodelivery.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/armorycrate.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abysshelp.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/emergencyteam.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/shadymission.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/prisoner.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/ventcreatures.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/wildcreature.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/malfunctioningbot.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/seismictremor.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/guardedcargo.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/clowncratesurprise.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/weakballastflora.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/wreckrescue.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/beaconrescue.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/cultist/oxygengenhusk.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/clown/randomlights.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/clown/clownmagic.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/lightsoff.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/communicationsoffline.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/reactorshutdown.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/supercapacitorfailure.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/junctionboxoverload.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/oxygengenpoison.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/oxygensufforin.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/oxygenparalyzant.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/oxygenmorbusine.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/sabotage/traitor/oxygencyanide.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/captainhelmboost.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securitymindsense.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretcoilgun.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretchaingun.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretflakcannon.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretpulselaser.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretdoublecoilgun.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/securityturretrailgun.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/mechanicmechanicalrepair.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/mechanichullrepair.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/mechanicskillboost.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/engineerelectricalrepair.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/engineerskillboost.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/medicskillboost.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/abilities/surgeonskillboost.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/pirate/outpostpirateattack.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/pirate/piratecrew.lua"),
				dofile(Traitormod.Path .. "/Lua/config/randomevents/pirate/hiddenpirate.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/pirate/wreckpirate.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/pirate/beaconpirate.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/repair/electricalfixdischarge.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/repair/fixhull.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/repair/fullfixshull.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/repair/fullelectricalfixdischarge.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/break/breackelectrical.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/break/breackhull.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/break/killelectrical.lua"),
        dofile(Traitormod.Path .. "/Lua/config/randomevents/break/killhull.lua"),
    }
}
