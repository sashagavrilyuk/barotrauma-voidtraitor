-- SERVER ONLY: локализация серверной логики VoidTraitor.
-- Здесь остаются чат/команды, динамические сообщения и fallback для игроков без client Lua.
local language = {}
language.Name = "Russian"

local path = Traitormod.Path .. "/Lua/language/russian/"

-- Общие команды, системные сообщения и серверные события
assert(loadfile(path .. "core.lua"))(language)

-- Роли антагонистов и цели
assert(loadfile(path .. "roles_objectives.lua"))(language)

-- Гост-роли и их серверный fallback
assert(loadfile(path .. "ghostroles.lua"))(language)

-- PointShop: серверные товары, категории, проверки и fallback
assert(loadfile(path .. "pointshop.lua"))(language)

-- Игровые режимы, итог раунда и голосования
assert(loadfile(path .. "gamemodes.lua"))(language)

-- Discord/webhook сообщения
assert(loadfile(path .. "discord.lua"))(language)

return language
