---@diagnostic disable: redundant-parameter
NTCS = {}

NTCS.HF = LuaUserData.CreateStatic("Neurotrauma.HF", false)
NTCS.Info = LuaUserData.CreateStatic("Neurotrauma.NTInfo", false)
NTCS.Addon = LuaUserData.CreateStatic("Neurotrauma.NTAddon", true)
NTCS.NTC = LuaUserData.CreateStatic("Neurotrauma.NTC", false)

NTCS.Config = LuaUserData.CreateStatic("Neurotrauma.NTConfig", false)
NTCS.ConfigExpansion = LuaUserData.CreateStatic("Neurotrauma.ConfigExpansion", true)
NTCS.ConfigEntry = LuaUserData.CreateStatic("Neurotrauma.ConfigEntry", true)
NTCS.ConfigEntryType = LuaUserData.CreateEnumTable("Neurotrauma.ConfigEntryType")

NTCS.NeurotraumaInit = LuaUserData.CreateStatic("Neurotrauma.Initialization", false)

NTCS.Afflictions = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions", false)
NTCS.AfflictionsPriority = LuaUserData.CreateEnumTable("Neurotrauma.NTAfflictions+AfflictionPriority")
NTCS.AfflictionPrefabBuilder = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions+NTAfflictionPrefabBuilder", true)
NTCS.AfflictionsLoader = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions+NTAfflictionsLoader", true)
NTCS.AfflictionPrefab = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions+NTAfflictionPrefab", true)

NTCS.Human = LuaUserData.CreateStatic("Neurotrauma.NTHuman", true)
NTCS.HumanUpdate = LuaUserData.CreateStatic("Neurotrauma.NTHumanUpdate", false)
NTCS.CharacterTags = LuaUserData.CreateStatic("Neurotrauma.NTHuman+CharacterTags", true)

NTCS.Stats = LuaUserData.CreateStatic("Neurotrauma.NTStats", false)
NTCS.Stat = LuaUserData.CreateStatic("Neurotrauma.NTStats+NTStat", true)
NTCS.StatBool = LuaUserData.CreateStatic("Neurotrauma.NTStats+NTStatBool", true)
NTCS.StatFloat = LuaUserData.CreateStatic("Neurotrauma.NTStats+NTStatFloat", true)
NTCS.StatLoader = LuaUserData.CreateStatic("Neurotrauma.NTStats+NTStatLoader", true)

NTCS.Items = LuaUserData.CreateStatic("Neurotrauma.NTItems", false)
NTCS.ItemsAfflictionInfos = LuaUserData.CreateStatic("Neurotrauma.NTItems+ItemsAfflictionInfos", true)
NTCS.ItemUpdateFunctionInfos = LuaUserData.CreateStatic("Neurotrauma.NTItems+ItemUpdateFunctionInfos", true)
NTCS.ItemFunctionLoader = LuaUserData.CreateStatic("Neurotrauma.NTItems+NTItemFunctionLoader", true)

NTCS.NTBloodTypes = LuaUserData.CreateStatic("Neurotrauma.NTBloodTypes", true)