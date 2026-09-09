---@module "utility.randomizer"
local randomizer = dofile(Traitormod.Path .. "/Lua/config/pointshop/utility/randomizer.lua")

-- Создание нового списка
local categories = {
	Structure = 1,
	Decorative = 2,
	Machine = 4,
	Medical = 8,
	Weapon = 16,
	Diving = 32,
	Equipment = 64,
	Fuel = 128,
	Electrical = 256,
	Material = 1024,
	Alien = 2048,
	Wrecked = 4096,
	ItemAssembly = 8192,
	Legacy = 16384,
	Misc = 32768
}
local btest = bit32.btest

-- Создание нового списка
-- randomizer.CreateList("Weapons", function (prefab)
-- 	return
-- 		btest(prefab.Category, categories.Weapon)
-- 		and not btest(prefab.Category, categories.Machine)
-- 		and (prefab.CanBeBought or prefab.CanBeSold)
-- 		and not prefab.ConfigElement.GetAttributeBool('NonInteractable', false)
-- end)

-- Создание списка на основе имеющегося
randomizer.CreateFrom("Weapons", "CanBeBoughtOrSold", function (prefab)
	return
		btest(prefab.Category, categories.Weapon)
		and not btest(prefab.Category, categories.Machine)
end)

-- Фильтр списка через чёрный список
local blacklist = {}
randomizer.Filter(randomizer.BlacklistFilter(blacklist), "Weapons")

-- Использование фильтра-функции
randomizer.Filter(function (prefab)
	for tag in prefab.Tags do
		if tag == "weapon" then
			return true
		end
	end
	return false
end, "Weapons")

randomizer.CreateList("Material", function (prefab)
	return btest(prefab.Category, categories.Material)
end)

randomizer.CreateList("All", function (prefab)
	return not prefab.ConfigElement.GetAttributeBool('NonInteractable', false)
end)

randomizer.CreateList("Medical", function (prefab)
	return btest(prefab.Category, categories.Medical)
end)

local crateLists = {
	vtcasinocratecrazy = "All",
	vtcasinocratenormal = "CanBeBoughtOrSold",
	vtcasinocratematerials = "Material",
	vtcasinocratemedical = "Medical",
	vtcasinocrateweapons = "Weapons"
}
local openingCrates = setmetatable({}, { __mode = "k" })

Hook.Add("item.interact", "Traitormod.Pointshop.RandomizeCrateInteract", function (item, character, _, forceSelectKey)
	if item == nil or character == nil or openingCrates[item] then return end

	local list = crateLists[item.Prefab.Identifier.Value]
	if list == nil then return end

	local holdable = item.GetComponentString("Holdable")
	if holdable == nil or not holdable.IsAttached then return end
	if not forceSelectKey and not character.IsKeyHit(InputType.Select) then return end

	openingCrates[item] = true
	local prefab = randomizer.GetRandom(list)
	local floorY = item.WorldRect.Y - item.WorldRect.Height
	local position = Vector2(item.WorldPosition.X, floorY + prefab.Size.Y * prefab.Scale / 2)
	local submarine = item.Submarine

	if submarine == nil then
		Entity.Spawner.AddItemToSpawnQueue(prefab, position)
	else
		Entity.Spawner.AddItemToSpawnQueue(prefab, position - submarine.Position, submarine)
	end
	Entity.Spawner.AddEntityToRemoveQueue(item)
	return true
end)

---@type Pointshop.Category
local category = {

Identifier = "randomize",

CanAccess = function (client)
	return client.Character and not client.Character.IsDead
end,

Products = {
	{
		Identifier = "randomize_crazy_all",
		Price = 150,
		Limit = 10,
		Items = {"vtcasinocratecrazy"},
	},
	{
		Identifier = "randomize_normal_all",
		Price = 75,
		Limit = 15,
		Items = {"vtcasinocratenormal"},
	},
	{
		Identifier = "randomize_materials",
		Price = 25,
		Limit = 20,
		Items = {"vtcasinocratematerials"},
	},
	{
		Identifier = "randomize_medical",
		Price = 50,
		Limit = 10,
		Items = {"vtcasinocratemedical"},
	},
	{
		Identifier = "randomize_weapons",
		Price = 750,
		Limit = 5,
		Items = {"vtcasinocrateweapons"},
	},
}

}

return category
