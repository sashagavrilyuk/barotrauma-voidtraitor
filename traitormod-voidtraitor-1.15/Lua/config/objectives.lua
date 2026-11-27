-- objective defaults (config.ObjectiveConfig); override them in config.lua
return {
    Assassinate = {
        AmountPoints = 600,
    },

    Survive = {
        AlwaysActive = true,
        AmountPoints = 500,
        AmountLives = 1,
    },

    StealCaptainID = {
        AmountPoints = 1300,
    },

    Kidnap = {
        AmountPoints = 2500,
        Seconds = 100,
    },

    PoisonCaptain = {
        AmountPoints = 1600,
    },

    Husk = {
        AmountPoints = 800,
    },

    TurnHusk = {
        AmountPoints = 500,
        AmountLives = 1,
    },

    SuffocateCrew = {
        AmountPoints = 900,
        RequiredLowOxygenSeconds = 4,
        SuffocationKillWindowSeconds = 20,
        SevereOxygenThreshold = 15,
        LowOxygenAfflictionThreshold = 35,
        AdditionalLowOxygenAfflictions = {"oxygenlow", "hypoxemia", "asphyxia"},
    },

    HealCharacters = {
        AmountPoints = 400,
        Amount = 500,
        RecentTreatmentAttributionSeconds = 12,
        DedupWindowSeconds = 0.05,
        MinimumReportedHeal = 0.5,
    },

    DestroyCaly = {

        AmountPoints = 500,
    },

    DetonateLocation = {
        AmountPoints = 1200,
        AmountPointsWithVictim = 1800,
        RequireVictimChance = 0.5,
        MaxVictimDistance = 500,
        DetonatorIdentifiers = {"detonator", "timeddetonator", "artmod_detonator"},
    },

    Sabotage = {
        AmountPoints = 50,
    },

    SabotageReactor = {
        AmountPoints = 2500,
    },

    FloodSubmarine = {
        AmountPoints = 400,
        RequiredFloodPercent = 80,
        CheckInterval = 1,
    },

    DestroyFuelRods = {
        AmountPoints = 500,
        Amount = 3,
    },
}
