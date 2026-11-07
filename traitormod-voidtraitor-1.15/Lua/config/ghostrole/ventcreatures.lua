local function keepLife(client)
    Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
end

local category = {}

category.Identifier = "ventcreatures"

category.Roles = {
    {
        Identifier = "crawler_hatchling",
        Species = "crawler_hatchling",
        Name = "GhostRoleCrawlerHatchlingName",
        Description = "GhostRoleVentCreatureDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "tigerthresher_hatchling",
        Species = "tigerthresher_hatchling",
        Name = "GhostRoleTigerthresherHatchlingName",
        Description = "GhostRoleVentCreatureDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "mudraptor_hatchling",
        Species = "mudraptor_hatchling",
        Name = "GhostRoleMudraptorHatchlingName",
        Description = "GhostRoleVentCreatureDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "crawler_hatchlinghusk",
        Species = "Crawler_hatchlinghusk",
        Name = "GhostRoleCrawlerHuskName",
        Description = "GhostRoleVentHuskDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "tigerthresher_hatchlinghusk",
        Species = "Tigerthresher_hatchlinghusk",
        Name = "GhostRoleTigerthresherHuskName",
        Description = "GhostRoleVentHuskDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "mudraptor_hatchlinghusk",
        Species = "Mudraptor_hatchlinghusk",
        Name = "GhostRoleMudraptorHuskName",
        Description = "GhostRoleVentHuskDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "orangeboy",
        Species = "orangeboy",
        Name = "GhostRoleOrangeBoyName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "balloon",
        Species = "balloon",
        Name = "GhostRoleBalloonName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "psilotoad",
        Species = "psilotoad",
        Name = "GhostRolePsilotoadName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "clown_orangeboy",
        Species = "Clown_Orangeboy",
        Name = "GhostRoleClownOrangeBoyName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "clown_peanut",
        Species = "Clown_Peanut",
        Name = "GhostRoleClownPeanutName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },

    {
        Identifier = "clown_psilotoad",
        Species = "Clown_Psilotoad",
        Name = "GhostRoleClownPsilotoadName",
        Description = "GhostRoleVentPetDescription",
        Price = 0,
        Action = keepLife,
    },
}

return category
