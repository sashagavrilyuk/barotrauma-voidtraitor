local category = {}

category.Identifier = "visitors"

category.Roles = {
    {
        Identifier = "visitor",
        Name = "GhostRoleVisitorName",
        Description = "GhostRoleVisitorDescription",
        Price = 0,
        Icon = "character",
        Action = function(client)
            Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
        end,
    },
}

return category
