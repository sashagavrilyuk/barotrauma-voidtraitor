local category = {}

category.Identifier = "stowaway"

category.Roles = {
    {
        Identifier = "stowaway",
        Name = "GhostRoleStowawayName",
        Description = "GhostRoleStowawayDescription",
        Price = 0,
        Icon = "character",
        Action = function(client)
            Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
        end,
    },
}

return category
