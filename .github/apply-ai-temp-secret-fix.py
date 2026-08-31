from pathlib import Path
import subprocess

ROOT = Path('.')

def sha(path):
    return subprocess.check_output(['git','hash-object',str(path)], text=True).strip()

def require_sha(rel, expected):
    p = ROOT / rel
    actual = sha(p)
    if actual != expected:
        raise SystemExit(f'{rel}: expected source {expected}, got {actual}')
    return p

def require_final(rel, expected):
    actual = sha(ROOT / rel)
    if actual != expected:
        raise SystemExit(f'{rel}: expected final {expected}, got {actual}')

def replace_text(p, old, new, count=1):
    s = p.read_text(encoding='utf-8')
    found = s.count(old)
    if found != count:
        raise SystemExit(f'{p}: expected {count} matches, got {found}: {old[:80]!r}')
    p.write_text(s.replace(old, new, count), encoding='utf-8', newline='')

def replace_bytes(p, old, new, count=1):
    b = p.read_bytes()
    found = b.count(old)
    if found != count:
        raise SystemExit(f'{p}: expected {count} byte matches, got {found}')
    p.write_bytes(b.replace(old, new, count))

base = 'traitormod-voidtraitor-dev-ai/Lua/'

p = require_sha(base+'config/baseconfig.lua', '136e2c542453faf31d4d712e70d334c86c86ffcf')
replace_bytes(p, b'EndGameDelaySeconds = 15,', b'EndGameDelaySeconds = 60,')
require_final(base+'config/baseconfig.lua', 'bc0f760bb2854b32f9a52b665fb575c7a5e7ce0e')

p = require_sha(base+'language/english.lua', 'ac929067dcc143bee9bb71068f0224a0f334ec52')
replace_text(p, 'language.SecretSummary = "Objectives Completed: %s - Points Gained: %s\\n"\nlanguage.SecretTraitorAssigned = "You have been assigned to be a traitor, vote which type you want to be."', 'language.SecretSummary = "Objectives Completed: %s - Points Gained: %s\\n"\nlanguage.SecretRoundEndingCountdown = "The round will end in %s seconds."\nlanguage.SecretCrewReachedStation = "The crew has reached the final station."\nlanguage.SecretTraitorAssigned = "You have been assigned to be a traitor, vote which type you want to be."')
require_final(base+'language/english.lua', '0309260ac5dc239395fb8517cae2424b1a0847bc')

p = require_sha(base+'language/russian.lua', '6e252b1afa5c8e0b66d3188333443f89e900eb47')
replace_text(p, 'language.SecretSummary = "Задачи выполнены: %s - Очки получены: %s\\n"\nlanguage.SecretTraitorAssigned = "Вы были избраны предателем, проголосуйте,им именно вы хотите быть."', 'language.SecretSummary = "Задачи выполнены: %s - Очки получены: %s\\n"\nlanguage.SecretRoundEndingCountdown = "Раунд завершится через %s секунд."\nlanguage.SecretCrewReachedStation = "Экипаж достиг конечной станции."\nlanguage.SecretTraitorAssigned = "Вы были избраны предателем, проголосуйте,им именно вы хотите быть."')
require_final(base+'language/russian.lua', 'ccd919198edd425972f02387c03df8bbfe76d473')

p = require_sha(base+'traitormodutil.lua', '2e7a712dd6220d5873a47ab8c45d43b6809a658f')
replace_text(p, 'Traitormod.SetData = function (client, name, amount)', 'Traitormod.IsSecretEnding = function ()\n    return Traitormod.SelectedGamemode ~= nil\n        and Traitormod.SelectedGamemode.Name == "Secret"\n        and Traitormod.SelectedGamemode.Ending == true\nend\n\nTraitormod.SetData = function (client, name, amount)')
replace_text(p, 'Traitormod.AwardPoints = function (client, amount, isMissionXP)\n    if not Traitormod.Config.TestMode then', 'Traitormod.AwardPoints = function (client, amount, isMissionXP)\n    if Traitormod.IsSecretEnding() then return 0 end\n    if not Traitormod.Config.TestMode then')
replace_text(p, 'Traitormod.AdjustLives = function (client, amount)\n    if not amount or amount == 0 then', 'Traitormod.AdjustLives = function (client, amount)\n    if Traitormod.IsSecretEnding() then return end\n    if not amount or amount == 0 then')
require_final(base+'traitormodutil.lua', '6567974c7f7341ca891512c41361763796704298')

require_sha(base+'rolemanager.lua', '399b075554e0185c8ace27c8b9101de56d1fc33f')

p = require_sha(base+'pointshop.lua', 'd18c8457ff0e1eed2695cbb814de5d3d4ebde2fa')
replace_text(p, '    local previousTimeout = nil\n    local accountKey = Traitormod.GetClientAccountKey(client)', '    local previousTimeout = nil\n    local accountKey = Traitormod.GetClientAccountKey(client)\n    local secretEnding = Traitormod.IsSecretEnding()')
replace_text(p, '        Traitormod.SetData(client, "Points", points - price)\n    end\n\n    local success, result = ps.ActivateProduct(client, product, price, itemsToSpawn)\n    if success == false then\n        if not Traitormod.Config.TestMode then\n            Traitormod.SetData(client, "Points", points)', '        if not secretEnding then\n            Traitormod.SetData(client, "Points", points - price)\n        end\n    end\n\n    local paidPrice = secretEnding and 0 or price\n    local success, result = ps.ActivateProduct(client, product, paidPrice, itemsToSpawn)\n    if success == false then\n        if not Traitormod.Config.TestMode then\n            if not secretEnding then\n                Traitormod.SetData(client, "Points", points)\n            end')
replace_text(p, 'Hook.Add("roundEnd", "TraitorMod.PointShop.RoundEnd", function ()\n    ps.ResetProductLimits()\n    ps.ActiveCategories = {}\n\n    if Traitormod.Config.TestMode then return end\n    if config.PointShopConfig.DeathSpawnRefundAtEndRound then\n        for client, refundTable in pairs(ps.Refunds) do\n            if client.Character ~= nil and not client.Character.IsPet then -- client.Character is surely alive\n                -- it will also remove elements in the ps.Refunds\n                refundTable.Price = refundTable.Price * math.min(client.Character.Vitality / client.Character.MaxVitality, 1)\n                refundProduct(client, refundTable)\n            end\n        end\n    end \nend)', 'ps.FinalizeRefunds = function ()\n    if Traitormod.Config.TestMode or not config.PointShopConfig.DeathSpawnRefundAtEndRound then return end\n\n    for client, refundTable in pairs(ps.Refunds) do\n        if client.Character ~= nil and not client.Character.IsPet then\n            refundTable.Price = refundTable.Price * math.min(client.Character.Vitality / client.Character.MaxVitality, 1)\n            refundProduct(client, refundTable)\n        end\n    end\nend\n\nHook.Add("roundEnd", "TraitorMod.PointShop.RoundEnd", function ()\n    ps.ResetProductLimits()\n    ps.ActiveCategories = {}\n    ps.FinalizeRefunds()\nend)')
require_final(base+'pointshop.lua', '52d617dd7b5c45f9dc63257bf8e4088d660f3ab5')

p = require_sha(base+'traitormod.lua', '1d88ab91dc4355b2b82c4007d32ec2e25ad7a3c9')
replace_text(p, '        Traitormod.SendMessageEveryone(Traitormod.HighlightClientNames(endMessage, Color.Red))', '        if Traitormod.SelectedGamemode.Name ~= "Secret" or Traitormod.SelectedGamemode.FinalSummary == nil then\n            Traitormod.SendMessageEveryone(Traitormod.HighlightClientNames(endMessage, Color.Red))\n        end')
replace_text(p, '    Traitormod.RoundTime = Traitormod.RoundTime + deltaTime', '    if not Traitormod.IsSecretEnding() then\n        Traitormod.RoundTime = Traitormod.RoundTime + deltaTime\n    end')
replace_text(p, '    -- give points/xp on the configured experience timer', '    if Traitormod.IsSecretEnding() then return end\n\n    -- give points/xp on the configured experience timer')
replace_text(p, 'Hook.HookMethod("Barotrauma.CharacterInfo", "IncreaseSkillLevel", function(instance, ptable)\n    if not ptable', 'Hook.HookMethod("Barotrauma.CharacterInfo", "IncreaseSkillLevel", function(instance, ptable)\n    if Traitormod.IsSecretEnding() then return end\n    if not ptable')
replace_text(p, 'Traitormod.DropPointItem = function(client, amount)\n    if client == nil or client.Character == nil or client.Character.IsDead then', 'Traitormod.DropPointItem = function(client, amount)\n    if Traitormod.IsSecretEnding() or client == nil or client.Character == nil or client.Character.IsDead then')
require_final(base+'traitormod.lua', '30e4bcb37c0aaad1265bc74655b03e269f436781')

p = require_sha(base+'ghostroles.lua', 'cd7fee55b008af032b9d52c9d502b2ebde3a39c2')
replace_text(p, '    if price > 0 and not Traitormod.Config.TestMode then\n        local points = math.floor(Traitormod.GetData(client, "Points") or 0)\n        Traitormod.SetData(client, "Points", points - price)\n        paid = true\n    end', '    if price > 0 and not Traitormod.Config.TestMode and not Traitormod.IsSecretEnding() then\n        local points = math.floor(Traitormod.GetData(client, "Points") or 0)\n        Traitormod.SetData(client, "Points", points - price)\n        paid = true\n    end')
require_final(base+'ghostroles.lua', 'e9227d7872361d7c8c18f009495a77817fae8034')

p = require_sha(base+'gamemodes/secret.lua', 'e2d4777ca12707593f3315b9e0de1df93f1b6ab2')
s = p.read_text(encoding='utf-8')
def one(old, new):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'secret.lua: expected 1 match, got {n}: {old[:80]!r}')
    s = s.replace(old, new, 1)
one('local summaryNetMessage = "VoidTraitor_RoundSummary"\nlocal softEndDelaySeconds = 60\nlocal updatingVoteStatus = false', 'local summaryNetMessage = "VoidTraitor_RoundSummary"\nlocal updatingVoteStatus = false\nlocal lobbySummaryPending = nil')
start = s.index('\nlocal function finalizePointshopRefunds()')
end = s.index('\nlocal function sendSummaryPopup', start)
s = s[:start] + '\n' + s[end:]
one('    self.AllowRealEndGame = false\n    self.FinalSummary = nil', '    self.AllowRealEndGame = false\n    self.FinalSummary = nil\n    self.AwardedPoints = {}\n    lobbySummaryPending = nil')
one('    finalizePointshopRefunds()\n    Traitormod.RoundEvents.EndRound()', '    Traitormod.Pointshop.FinalizeRefunds()\n    Traitormod.Pointshop.Refunds = {}\n    Traitormod.RoundEvents.EndRound()')
one('        sb("\\n%s — %s (%s)\\n", character.Name, role.Name, state)\n\n        for _, objective in ipairs(role.Objectives or {}) do', '        sb("\\n%s — %s (%s)\\n", character.Name, role.Name, state)\n\n        local objectivesCompleted = 0\n        for _, objective in ipairs(role.Objectives or {}) do\n            if not objective.Failed then objectivesCompleted = objectivesCompleted + 1 end\n        end\n        local client = Traitormod.FindClientCharacter(character)\n        local accountKey = client ~= nil and Traitormod.GetClientAccountKey(client) or nil\n        sb(Traitormod.Language.SecretSummary, objectivesCompleted, math.floor((accountKey ~= nil and self.AwardedPoints[accountKey]) or 0))\n\n        for _, objective in ipairs(role.Objectives or {}) do')
one('    self.Ending = true\n    self.EndReason = reason\n    lockProgress(self)\n', '    self.Ending = true\n    self.EndReason = reason\n')
one('    self.FinalSummary = self:RoundSummary()\n    Traitormod.LastRoundSummary = self.FinalSummary\n\n    local delay = softEndDelaySeconds\n    local message = string.format(Traitormod.Language.HideAndSeekRoundCountdown, delay)\n    if reason == "traitors" then\n        message = Traitormod.Language.TraitorsWin .. "\\n" .. message\n    elseif reason == "crew" then\n        local reachedText = tostring(TextManager.Get("hint.onavailabletransition.progresstonextemptylocation"))\n        reachedText = string.match(reachedText, "^(.-%.)") or reachedText\n        message = reachedText .. "\\n" .. message\n    end', '    self.FinalSummary = self:RoundSummary()\n    Traitormod.LastRoundSummary = self.FinalSummary\n    lobbySummaryPending = self.FinalSummary\n\n    local delay = self.EndGameDelaySeconds or 0\n    local message = string.format(Traitormod.Language.SecretRoundEndingCountdown, delay)\n    if reason == "traitors" then\n        message = Traitormod.Language.TraitorsWin .. "\\n" .. message\n    elseif reason == "crew" then\n        message = Traitormod.Language.SecretCrewReachedStation .. "\\n" .. message\n    end')
one('    unlockProgress(self)\n    Game.EnableControlHusk(false)', '    Game.EnableControlHusk(false)')
one('    if self.Ending then\n        Traitormod.PointsToBeGiven = {}\n        if not self.AllowRealEndGame', '    if self.Ending then\n        if not self.AllowRealEndGame')
one('end, Hook.HookMethodType.Before)\n\n\nreturn gm', 'end, Hook.HookMethodType.Before)\n\nHook.Patch("Traitormod.Secret.EndGame.After", "Barotrauma.Networking.GameServer", "EndGame", function ()\n    if lobbySummaryPending == nil or Game.RoundStarted then return end\n\n    Traitormod.SendMessageEveryone(Traitormod.HighlightClientNames(lobbySummaryPending, Color.Red))\n    lobbySummaryPending = nil\nend, Hook.HookMethodType.After)\n\n\nreturn gm')
p.write_text(s, encoding='utf-8', newline='')
require_final(base+'gamemodes/secret.lua', '3149c43fae50b566d5d8dcbb1d18e24571b7e8fc')
print('All files transformed and hashes verified.')