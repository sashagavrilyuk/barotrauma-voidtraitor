local category = {}

category.Identifier = "deathspawn"
category.Decoration = "huskinvite"

category.CanAccess = function(client)
    return client.Character == nil or client.Character.IsDead or not client.Character.IsHuman
end

local SpawnCreature = dofile(Traitormod.Path .. "/Lua/config/pointshop/utility/deathspawncreature.lua")

category.Products = {
    {
        Identifier = "spawnascrawler",
        Price = 400,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 100,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 250,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "crawler",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("crawler", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasLeucocyte",
        Price = 250,
        Limit = 5,
        IsLimitGlobal = true,
        PricePerLimit = 30,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 175,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "Leucocyte",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Leucocyte", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnaslegacycrawler",
        Price = 400,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 100,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 250,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "legacycrawler",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("legacycrawler", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnascrawlerbaby",
        Price = 250,
        Limit = 5,
        IsLimitGlobal = true,
        PricePerLimit = 15,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 150,
            StartTime = 5,
            EndTime = 10,
        },

        GuiCreature = "crawler_hatchling",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("crawler_hatchling", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasmudraptorbaby",
        Price = 400,
        Limit = 5,
        IsLimitGlobal = true,
        PricePerLimit = 150,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 225,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "mudraptor_hatchling",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("mudraptor_hatchling", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasthresherbaby",
        Price = 700,
        Limit = 5,
        IsLimitGlobal = true,
        PricePerLimit = 250,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 400,
            StartTime = 10,
            EndTime = 25,
        },

        GuiCreature = "tigerthresher_hatchling",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("tigerthresher_hatchling", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasspineling",
        Price = 1000,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 700,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 700,
            StartTime = 15,
            EndTime = 30,
        },

        GuiCreature = "spineling",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("spineling", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasSpinelingmorbusine",
        Price = 5000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 1500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1500,
            StartTime = 20,
            EndTime = 30,
        },

        GuiCreature = "Spineling_morbusine",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Spineling_morbusine", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasmudraptor",
        Price = 650,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 200,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 450,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "mudraptor",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("mudraptor", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasmantis",
        Price = 1200,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 400,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 800,
            StartTime = 20,
            EndTime = 35,
        },

        GuiCreature = "mantis",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("mantis", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasbonethresher",
        Price = 1500,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1000,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "Bonethresher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Bonethresher", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnastigerthresher",
        Price = 2500,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1500,
            StartTime = 20,
            EndTime = 40,
        },

        GuiCreature = "Tigerthresher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Tigerthresher", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnaslegacymoloch",
        Price = 2500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Enabled = true,
        Timeout = 150,
		
        RoundPrice = {
            PriceReduction = 1200,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "legacymoloch",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("legacymoloch", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasMoloch",
        Price = 6500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 2250,
            StartTime = 25,
            EndTime = 45,
        },
		
        GuiCreature = "legacymoloch",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("legacymoloch", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasMolochblack",
        Price = 8500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 2850,
            StartTime = 30,
            EndTime = 45,
        },

        GuiCreature = "Molochblack",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Molochblack", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnaslegacycarrier",
        Price = 500,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 75,
        Enabled = true,
        Timeout = 150,
		
        RoundPrice = {
            PriceReduction = 350,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "Carrier",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Carrier", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnashammerhead",
        Price = 2500,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 400,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1500, 
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "hammerhead",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("hammerhead", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasHammerheadmatriarch",
        Price = 5500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 3250,
            StartTime = 25,
            EndTime = 45,
        },

        GuiCreature = "Hammerheadmatriarch",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Hammerheadmatriarch", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasfractalguardian",
        Price = 5000,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 1750,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 2000,
            StartTime = 15,
            EndTime = 40,
        },

        GuiCreature = "fractalguardian",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("fractalguardian", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasgiantspineling",
        Price = 30000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 20500,
            StartTime = 40,
            EndTime = 55,
        },

        GuiCreature = "Spineling_giant",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Spineling_giant", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasveteranmudraptor",
        Price = 4500,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 900,
        Enabled = true,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 2250,
            StartTime = 20,
            EndTime = 40,
        },

        GuiCreature = "Mudraptor_veteran",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Mudraptor_veteran", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnaslatcher",
        Price = 20000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 11250,
            StartTime = 45,
            EndTime = 55,
        },

        GuiCreature = "latcher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("latcher", client, product, paidPrice)
        end
    },
	
  {
        Identifier = "spawnaWatcher",
        Price = 6500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,
		
        RoundPrice = {
            PriceReduction = 3250,
            StartTime = 25,
            EndTime = 45,
        },
		
        GuiCreature = "Watcher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Watcher", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnascharybdis",
        Price = 50000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 47750,
            StartTime = 50,
            EndTime = 60,
        },

        GuiCreature = "charybdis",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("charybdis", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasendworm",
        Price = 75000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 73500,
            StartTime = 50,
            EndTime = 60,
        },

        GuiCreature = "endworm",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("endworm", client, product, paidPrice)
        end
    },
}

return category