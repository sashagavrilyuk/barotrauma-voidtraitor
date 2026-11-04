local function keepLife(client)
    Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
end

local category = {}

category.Identifier = "wild"

category.Roles = {
    {
        Identifier = "creature",
        Name = "GhostRoleWildCreatureName",
        Description = "GhostRoleWildCreatureDescription",
        Price = 0,
        Icon = "character",
        Action = keepLife,
    },
}

return category
