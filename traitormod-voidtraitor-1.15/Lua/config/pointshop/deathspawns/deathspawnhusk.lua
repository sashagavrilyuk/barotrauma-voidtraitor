local category = {}

category.Identifier = "deathspawnhusk"
category.Decoration = "huskinvite"

category.CanAccess = function(client)
    return client.Character == nil or client.Character.IsDead or not client.Character.IsHuman
end

local SpawnCreature = dofile(Traitormod.Path .. "/Lua/config/pointshop/utility/deathspawncreature.lua")

category.Products = {
	{
        Identifier = "spawnascrawlerhusk",
        Price = 500,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 100,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 200,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "Crawlerhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Crawlerhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnaslegacyhusk",
        Price = 400,
        Limit = 5,
        IsLimitGlobal = true,
        PricePerLimit = 100,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 150,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "legacyhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("legacyhusk", client, product, paidPrice)
        end
    },

    {
        Identifier = "spawnasHammerhead_mhusk",
        Price = 2900,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1750,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "Hammerhead_mhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Hammerhead_mhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasHammerheadmatriarchhusk",
        Price = 3500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1950,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "Hammerhead_mhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Hammerhead_mhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasCoelanthhusk",
        Price = 1600,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 250,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 750,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "Coelanthhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Coelanthhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasBonethresherhusk",
        Price = 2250,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1000,
            StartTime = 15,
            EndTime = 35,
        },

        GuiCreature = "Bonethresherhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Bonethresherhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasTigerthresherhusk",
        Price = 2850,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1500,
            StartTime = 20,
            EndTime = 40,
        },

        GuiCreature = "Tigerthresherhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Tigerthresherhusk", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnasSnatcher",
        Price = 500,
        Limit = 1,
        IsLimitGlobal = false,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 250,
            StartTime = 10,
            EndTime = 20,
        },

        GuiCreature = "Snatcher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Snatcher", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasMolochhusk",
        Price = 7500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 3000,
            StartTime = 25,
            EndTime = 45,
        },

        GuiCreature = "Molochhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Molochhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasMolochblackhusk",
        Price = 10000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 4500,
            StartTime = 30,
            EndTime = 45,
        },

        GuiCreature = "Molochblackhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Molochblackhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasMantishusk",
        Price = 1800,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1000,
            StartTime = 25,
            EndTime = 45,
        },

        GuiCreature = "Mantishusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Mantishusk", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnasLegacycrawlerhusk",
        Price = 800,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 400,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 300,
            StartTime = 15,
            EndTime = 30,
        },

        GuiCreature = "Legacycrawlerhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Legacycrawlerhusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasHuskmutanthunterranged",
        Price = 12000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 5500,
            StartTime = 30,
            EndTime = 45,
        },

        GuiCreature = "Huskmutanthunterranged",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutanthunterranged", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnasHuskmutanttigerthresher",
        Price = 6000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 3500,
            StartTime = 25,
            EndTime = 40,
        },

        GuiCreature = "Huskmutanttigerthresher",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutanttigerthresher", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasHuskmutantcrawler",
        Price = 2250,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1650,
            StartTime = 25,
            EndTime = 40,
        },

        GuiCreature = "Huskmutantcrawler",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutantcrawler", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnasHuskmutantmudraptor",
        Price = 2250,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1250,
            StartTime = 25,
            EndTime = 40,
        },

        GuiCreature = "Huskmutantmudraptor",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutantmudraptor", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnasHuskmutantarmoredpucs",
        Price = 18000,
        Limit = 2,
        IsLimitGlobal = true,
        PricePerLimit = 500,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 9500,
            StartTime = 35,
            EndTime = 50,
        },

        GuiCreature = "Huskmutantmudraptor",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Huskmutantmudraptor", client, product, paidPrice)
        end
    },	
	
    {
        Identifier = "spawnasEndwormhuskhead",
        Price = 5500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 3500,
            StartTime = 20,
            EndTime = 40,
        },

        GuiCreature = "Endwormhuskhead",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Endwormhuskhead", client, product, paidPrice)
        end
    },	
	
   {
        Identifier = "spawnasEndwormhusk",
        Price = 80000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 77000,
            StartTime = 50,
            EndTime = 60,
        },

        GuiCreature = "Endwormhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Endwormhusk", client, product, paidPrice)
        end
    },	
   {
        Identifier = "spawnasCharybdishusk",
        Price = 65000,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 62500,
            StartTime = 50,
            EndTime = 60,
        },

        GuiCreature = "Charybdishusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Charybdishusk", client, product, paidPrice)
        end
    },	

   {
        Identifier = "spawnasWatcherhusk",
        Price = 7500,
        Limit = 1,
        IsLimitGlobal = true,
        PricePerLimit = 0,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 4500,
            StartTime = 25,
            EndTime = 45,
        },

        GuiCreature = "Charybdishusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Charybdishusk", client, product, paidPrice)
        end
    },
	
    {
        Identifier = "spawnashuskedhuman",
        Price = 2000,
        Limit = 3,
        IsLimitGlobal = true,
        PricePerLimit = 400,
        Timeout = 150,

        RoundPrice = {
            PriceReduction = 1250,
            StartTime = 25,
            EndTime = 45,
        },

        GuiCreature = "Humanhusk",
        -- a husked human's head is generated per character, so show the legacy husk's helmet
        Icon = "creature:legacyhusk",
        CloseGuiAfterPurchase = true,

        Action = function (client, product, items, paidPrice)
            SpawnCreature("Humanhusk", client, product, paidPrice)
        end
    },	
	
}

return category