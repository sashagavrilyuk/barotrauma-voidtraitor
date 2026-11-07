local function keepLife(client)
    Traitormod.LostLivesThisRound[Traitormod.GetClientAccountKey(client)] = false
end

local category = {}

category.Identifier = "defensebot"

category.Roles = {
    {
        Identifier = "malfunctioning",
        Name = "GhostRoleMalfunctioningBotName",
        Description = "GhostRoleMalfunctioningBotDescription",
        Price = 0,
        Icon = "creature:Defensebot",
        Action = keepLife,
    },
}

return category
