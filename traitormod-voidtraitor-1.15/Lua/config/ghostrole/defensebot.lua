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
        Icon = "vt_preview_creature_defensebot",
        Action = keepLife,
    },
}

return category
