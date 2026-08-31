from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, got {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8", newline="")

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/config/pointshop/traitors/cultist.lua",
    'LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Affliction"], "_strength")',
    'LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.AfflictionHusk"] or LuaUserData.RegisterType("Barotrauma.AfflictionHusk"), "_strength")',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua",
    'local updatingVoteStatus = false\nlocal lobbySummaryPending = nil',
    'local updatingVoteStatus = false\nlocal handlingServerCommand = false\nlocal lobbySummaryPending = nil',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua",
    '''Hook.Patch("Traitormod.Secret.UpdateVoteStatus.After", "Barotrauma.Networking.GameServer", "UpdateVoteStatus", function ()\n    updatingVoteStatus = false\nend, Hook.HookMethodType.After)\n\nHook.Patch("Traitormod.Secret.EndGame.Before", "Barotrauma.Networking.GameServer", "EndGame", function (instance, ptable)''',
    '''Hook.Patch("Traitormod.Secret.UpdateVoteStatus.After", "Barotrauma.Networking.GameServer", "UpdateVoteStatus", function ()\n    updatingVoteStatus = false\nend, Hook.HookMethodType.After)\n\nHook.Patch("Traitormod.Secret.ClientReadServerCommand.Before", "Barotrauma.Networking.GameServer", "ClientReadServerCommand", function ()\n    handlingServerCommand = true\nend, Hook.HookMethodType.Before)\n\nHook.Patch("Traitormod.Secret.ClientReadServerCommand.After", "Barotrauma.Networking.GameServer", "ClientReadServerCommand", function ()\n    handlingServerCommand = false\nend, Hook.HookMethodType.After)\n\nHook.Patch("Traitormod.Secret.EndGame.Before", "Barotrauma.Networking.GameServer", "EndGame", function (instance, ptable)''',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua",
    '''    if updatingVoteStatus then\n        selected:BeginEnding("vote")\n        ptable.PreventExecution = true\n    end''',
    '''    if updatingVoteStatus or handlingServerCommand then\n        selected:BeginEnding(updatingVoteStatus and "vote" or "manual")\n        ptable.PreventExecution = true\n    end''',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/commands.lua",
    '''end)\n\nTraitormod.AddCommand({"!allpoint", "!allpoints"}, function (client, args)''',
    '''end)\n\nTraitormod.AddCommand("!endroundnow", function (client, args)\n    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end\n\n    local selected = Traitormod.SelectedGamemode\n    if not Game.RoundStarted or selected == nil or selected.Name ~= "Secret" or not selected.Ending then\n        Traitormod.SendMessage(client, Traitormod.Language.CommandNotActive)\n        return true\n    end\n\n    selected.AllowRealEndGame = true\n    Game.EndGame()\n    return true\nend)\n\nTraitormod.AddCommand({"!allpoint", "!allpoints"}, function (client, args)''',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/clientmenu.lua",
    'addAdminAction("ongoingevents", "!ongoingevents", "ClientMenuAdminOngoingEvents", "ClientMenuAdminHintOngoingEvents", "ClientMenuAdminCategoryInfo", 14)',
    'addAdminAction("ongoingevents", "!ongoingevents", "ClientMenuAdminOngoingEvents", "ClientMenuAdminHintOngoingEvents", "ClientMenuAdminCategoryInfo", 14)\naddAdminAction("endroundnow", "!endroundnow", "ClientMenuAdminEndRoundNow", "ClientMenuAdminHintEndRoundNow", "ClientMenuAdminCategoryInfo", 15)',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/language/clientmenu_admin.lua",
    '        ClientMenuAdminHintOngoingEvents = "Same as !ongoingevents",',
    '        ClientMenuAdminHintOngoingEvents = "Same as !ongoingevents",\n        ClientMenuAdminEndRoundNow = "End round now",\n        ClientMenuAdminHintEndRoundNow = "Immediately ends the round during the Secret ending countdown.",',
)
replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/language/clientmenu_admin.lua",
    '        ClientMenuAdminHintOngoingEvents = "Аналог !ongoingevents",',
    '        ClientMenuAdminHintOngoingEvents = "Аналог !ongoingevents",\n        ClientMenuAdminEndRoundNow = "Закончить раунд сейчас",\n        ClientMenuAdminHintEndRoundNow = "Немедленно завершает раунд во время финального отсчёта Secret.",',
)

replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/language/english.lua",
    '\\n!roundinfo - show round information (spoiler!)\\n!allpoints',
    '\\n!roundinfo - show round information (spoiler!)\\n!endroundnow - immediately ends Secret during the final countdown\\n!allpoints',
)
replace_once(
    "traitormod-voidtraitor-dev-ai/Lua/language/russian.lua",
    '\\n!roundinfo - показать информацию о раунде (спойлер!)\\n!allpoints',
    '\\n!roundinfo - показать информацию о раунде (спойлер!)\\n!endroundnow - немедленно завершить Secret во время финального отсчёта\\n!allpoints',
)
