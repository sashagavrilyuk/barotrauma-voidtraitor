---@diagnostic disable-next-line: unknown-cast-variable
---@cast Traitormod.SelectedGamemode Gamemodes.HideAndSeekV2

local respawnStart = dofile(Traitormod.Path .. "/Lua/config/pointshop/attackdefend/utility/adv2.lua").RespawnStart
local ShopTeamID = CharacterTeamType.Team2

local classSubcategory = {
    Identifier = "hideandseek_seeker_classes",
    CounterType = "ClassGroup",
    CounterId = "hideandseek_seeker_classes",
}

---@type Pointshop.Category
local category = {
    Identifier = "hideRed",
    CanAccess = function(client)
        local entry = Traitormod.SelectedGamemode.Teams[ShopTeamID].Respawns[client.AccountId]
        return entry ~= nil and not entry.Spawned
    end,
    Products = {
        {
            Identifier = "hide_seeker_1",
            Price = 0,
            Limit = math.huge,
            Subcategory = classSubcategory,
            GuiJobIdentifier = "securityofficer",
            Action = function(client, product)
                local entry = respawnStart(client, ShopTeamID, product.Identifier, "securityofficer", product)
                entry.OnSpawn = function(character) end
            end,
        },
        {
            Identifier = "hide_seeker_2",
            Price = 0,
            Limit = math.huge,
            Subcategory = classSubcategory,
            GuiJobIdentifier = "captain",
            Action = function(client, product)
                local entry = respawnStart(client, ShopTeamID, product.Identifier, "captain", product)
                entry.OnSpawn = function(character) end
            end,
        },
    }
}

return category
