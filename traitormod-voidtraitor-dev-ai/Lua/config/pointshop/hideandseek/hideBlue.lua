---@diagnostic disable-next-line: unknown-cast-variable
---@cast Traitormod.SelectedGamemode Gamemodes.HideAndSeekV2

---@module "adv2"
local ADV2 = dofile(Traitormod.Path .. "/Lua/config/pointshop/attackdefend/utility/adv2.lua")
local respawnStart = ADV2.RespawnStart
local spawnItems = ADV2.SpawnItems
ADV2 = nil

local ShopTeamID = CharacterTeamType.Team1

local classSubcategory = {
    Identifier = "hideandseek_hider_classes",
    CounterType = "ClassGroup",
    CounterId = "hideandseek_hider_classes",
}

---@type Pointshop.Category
local category = {
    Identifier = "hideBlue",
    CanAccess = function(client)
        local entry = Traitormod.SelectedGamemode.Teams[ShopTeamID].Respawns[client.AccountId]
        return entry ~= nil and not entry.Forfeited and not entry.Spawned
    end,
    Products = {
        {
            Identifier = "hide_hider_1",
            Price = 0,
            Limit = math.huge,
            Subcategory = classSubcategory,
            GuiJobIdentifier = "assistant",
            Action = function(client, product)
                local entry = respawnStart(client, ShopTeamID, product.Identifier, "assistant", product)
                entry.OnSpawn = function(character)
                    local clothes = { "vipclothes1", "vipclothes2", "vipclothes3" }
                    local hats = { "captainscap1", "captainscap2", "captainscap3" }

                    ---@type ItemTable
                    local inventoryItems = {
                        [clothes[math.random(1, #clothes)]] = {
                            InvSlotType = InvSlotType.InnerClothes,
                        },
                        [hats[math.random(1, #hats)]] = {
                            InvSlotType = InvSlotType.Head,
                        },
                        ["wrench"] = 1,
                        ["screwdriver"] = 1,
                        ["crowbar"] = 1,
                        ["weldingtool"] = {
                            Items = {
                                ["incendiumfueltank"] = 1,
                            },
                        },
                        ["plasmacutter"] = {
                            Items = {
                                ["oxygenitetank"] = 1,
                            },
                        },
                        ["flashlight"] = {
                            Items = {
                                ["fulguriumbatterycell"] = 1,
                            },
                        },
                        ["divingmask"] = {
                            Items = {
                                ["oxygenitetank"] = 1,
                            },
                        },
                        ["mudraptorshell"] = 1,
                        ["safetyharness"] = 1,
                        ["advancedgenesplicer"] = {
                            InvSlotType = InvSlotType.HealthInterface,
                            Items = {
                                ["geneticmaterialmantis"] = 1,
                                ["geneticmaterialmoloch"] = 1,
                            },
                        },
                        ["autoinjectorheadset"] = {
                            InvSlotType = InvSlotType.Headset,
                        },
                        ["medtoolbox"] = {
                            Items = {
                                ["suture"] = 16,
                                ["traumashears"] = 1,
                                ["adrenaline"] = 4,
                                ["antiparalysis"] = 2,
                                ["antibleeding2"] = 8,
                                ["pomegrenadeextract"] = 8,
                                ["antidama1"] = 8,
                                ["combatstimulantsyringe"] = 2,
                                ["needle"] = 1,
                            },
                        },
                        ["toolbelt"] = {
                            InvSlotType = InvSlotType.Bag,
                            Items = {
                                ["energydrink"] = 8,
                                ["stungrenade"] = 2,
                                ["syringegun"] = {
                                    Items = {
                                        ["chloralhydrate"] = 2,
                                    },
                                },
                                ["detonator"] = 1,
                                ["blackwire"] = 2,
                                ["delaycomponent"] = 1,
                            },
                        },
                    }

                    for itemId, itemEntry in pairs(inventoryItems) do
                        spawnItems(itemId, character.Inventory, itemEntry)
                    end
                end
            end,
        },
    }
}

return category
