---@diagnostic disable-next-line: unknown-cast-variable
---@cast Traitormod.SelectedGamemode Gamemodes.HideAndSeekV2

---@module "adv2"
local ADV2 = dofile(Traitormod.Path .. "/Lua/config/pointshop/attackdefend/utility/adv2.lua")
local respawnStart = ADV2.RespawnStart
local spawnItems = ADV2.SpawnItems
ADV2 = nil

local ShopTeamID = CharacterTeamType.Team2

local function gearUpSeeker(character)
    spawnItems("headset", character.Inventory, { InvSlotType = InvSlotType.Headset })
end

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
        return entry ~= nil and not entry.Forfeited and not entry.Spawned
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
                entry.OnSpawn = gearUpSeeker
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
                entry.OnSpawn = gearUpSeeker
            end,
        },
    }
}

return category
