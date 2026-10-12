local config = {}

-- Doors use these tags in RequiredItem (type="Picked", characterinventoryslottype="Card").
-- Keep editable access tags on item instances, never in the ID prefab's Tags.
config.Access = {
    { Tag = "vt_access_maintenance", Name = "IdConsoleMaintenance" },
    { Tag = "vt_access_engineering", Name = "IdConsoleEngineering" },
    { Tag = "vt_access_reactor", Name = "IdConsoleReactor" },
    { Tag = "vt_access_engineering_stock", Name = "IdConsoleEngineeringStock" },
    { Tag = "vt_access_medical", Name = "IdConsoleMedical" },
    { Tag = "vt_access_medical_stock", Name = "IdConsoleMedicalStock" },
    { Tag = "vt_access_security", Name = "IdConsoleSecurity" },
    { Tag = "vt_access_armory", Name = "IdConsoleArmory" },
    { Tag = "vt_access_cargo", Name = "IdConsoleCargo" },
    { Tag = "vt_access_command", Name = "IdConsoleCommand" },
    { Tag = "vt_access_personnel", Name = "IdConsolePersonnel" },
}

config.Presets = {
    { Id = "assistant", JobId = "assistant", Tags = { "vt_access_maintenance" } },
    { Id = "mechanic", JobId = "mechanic", Tags = { "vt_access_maintenance", "vt_access_engineering", "vt_access_engineering_stock" } },
    { Id = "engineer", JobId = "engineer", Tags = { "vt_access_maintenance", "vt_access_engineering", "vt_access_reactor", "vt_access_engineering_stock" } },
    { Id = "medicaldoctor", JobId = "medicaldoctor", Tags = { "vt_access_maintenance", "vt_access_medical", "vt_access_medical_stock" } },
    { Id = "surgeon", JobId = "surgeon", Tags = { "vt_access_maintenance", "vt_access_medical", "vt_access_medical_stock" } },
    { Id = "securityofficer", JobId = "securityofficer", Tags = { "vt_access_maintenance", "vt_access_security", "vt_access_armory" } },
    { Id = "captain", JobId = "captain", AllAccess = true, Tags = {} },
    { Id = "headpersonnel", Name = "IdConsoleHeadPersonnel", AllAccess = true, Tags = {} },
    { Id = "cargo", Name = "IdConsoleCargoJob", Tags = { "vt_access_maintenance", "vt_access_cargo" } },
}
return config
