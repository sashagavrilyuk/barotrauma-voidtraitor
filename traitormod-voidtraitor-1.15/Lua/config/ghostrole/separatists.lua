local function keepLife(client)
    Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
end

local category = {}

category.Identifier = "separatists"

category.Roles = {
    {
        Identifier = "saboteur",
        Name = "GhostRoleSeparatistSaboteurName",
        Description = "GhostRoleSeparatistSaboteurDescription",
        Price = 0,
        Icon = "character",
        Action = keepLife,
    },
    {
        Identifier = "operative",
        Name = "GhostRoleSeparatistOperativeName",
        Description = "GhostRoleSeparatistOperativeDescription",
        Price = 0,
        Icon = "character",
        Action = keepLife,
    },
}

return category
