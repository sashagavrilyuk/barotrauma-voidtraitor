-- role defaults (config.RoleConfig); override them in config.lua
return {
    Crew = {
        AvailableObjectives = {
            ["captain"] = {"KillLargeMonsters", "FinishRoundFast", "SecurityTeamSurvival"},
            ["engineer"] = {"RepairElectrical", "RepairMechanical", "KillSmallMonsters"},
            ["mechanic"] = {"RepairMechanical", "RepairHull", "KillSmallMonsters"},
            ["securityofficer"] = {"KillLargeMonsters", "KillSmallMonsters"},
            ["medicaldoctor"] = {"HealCharacters", "KillSmallMonsters"},
            ["assistant"] = {"RepairElectrical", "RepairMechanical", "KillPets"},
			["surgeon"] = {"HealCharacters", "KillSmallMonsters"},
        }
    },

    Cultist = {
        SubObjectives = {"Assassinate", "Kidnap", "TurnHusk", "DestroyCaly"},
        MinSubObjectives = 2,
        MaxSubObjectives = 3,

        NextObjectiveDelayMin = 30,
        NextObjectiveDelayMax = 60,

        TraitorBroadcast = true,           -- traitors can broadcast to other traitors using !tc
        TraitorBroadcastHearable = false,  -- if true, !tc will be hearable in the vicinity via local chat
        TraitorDm = true,                  -- traitors can send direct messages to other players using !tdm

        -- Names, None
        TraitorMethodCommunication = "Names",

        SelectBotsAsTargets = true,
        SelectPiratesAsTargets = false,
    },

    -- a cultist who carries the parasite (Station event PatientZero); the rest comes from Cultist
    PatientZero = {
        SubObjectives = {"DestroyCaly"},
        MinSubObjectives = 1,
        MaxSubObjectives = 1,
    },

    HuskServant = {
        TraitorBroadcast = true,
    },

    Traitor = {
        SubObjectives = {"StealCaptainID", "Survive", "Kidnap", "PoisonCaptain"},
        MinSubObjectives = 2,
        MaxSubObjectives = 3,

        NextObjectiveDelayMin = 30,
        NextObjectiveDelayMax = 60,

        TraitorBroadcast = true,           -- traitors can broadcast to other traitors using !tc
        TraitorBroadcastHearable = false,  -- if true, !tc will be hearable in the vicinity via local chat
        TraitorDm = true,                  -- traitors can send direct messages to other players using !tdm

        -- Names, Codewords, None
        TraitorMethodCommunication = "Names",

        SelectBotsAsTargets = true,
        SelectPiratesAsTargets = false,
        SelectUniqueTargets = true,     -- every traitor target can only be chosen once per traitor (respawn+false -> no end)
        PointsPerAssassination = 100,
    },

    Clown = {
        SubObjectives = {"BananaSlip", "SuffocateCrew", "AssassinateDrunk", "GrowMudraptors", "DetonateLocation", "Survive"},
        MinSubObjectives = 3,
        MaxSubObjectives = 3,

        NextObjectiveDelayMin = 30,
        NextObjectiveDelayMax = 60,

        TraitorBroadcast = true,           -- traitors can broadcast to other traitors using !tc
        TraitorBroadcastHearable = false,  -- if true, !tc will be hearable in the vicinity via local chat
        TraitorDm = true,                  -- traitors can send direct messages to other players using !tdm

        -- Names, None
        TraitorMethodCommunication = "Names",

        SelectBotsAsTargets = true,
        SelectPiratesAsTargets = false,
    },

    Saboteur = {
        SubObjectives = {"SabotageReactor", "FloodSubmarine", "DestroyFuelRods", "Survive"},
        MinSubObjectives = 2,
        MaxSubObjectives = 3,

        NextObjectiveDelayMin = 30,
        NextObjectiveDelayMax = 60,
        PointsPerSabotage = 50,

        TraitorBroadcast = true,
        TraitorBroadcastHearable = false,
        TraitorDm = true,
        TraitorMethodCommunication = "Names",
    },
}
