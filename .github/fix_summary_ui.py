from pathlib import Path
import subprocess


def sha(path):
    return subprocess.check_output(["git", "hash-object", path], text=True).strip()


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise RuntimeError(f"expected one match in {path}, got {text.count(old)}")
    p.write_text(text.replace(old, new), encoding="utf-8")


pack_admin = "Void traitor pack/Lua/client/lobby/admin.lua"
builder_admin = "VoidTraitorPackBuilder/Custom/Lua/client/lobby/admin.lua"
secret = "traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua"

if sha(pack_admin) != "c45780b9f88aa7baa4d144890efb6737d5c3fae4":
    raise RuntimeError("pack admin.lua changed")
if sha(builder_admin) != "c45780b9f88aa7baa4d144890efb6737d5c3fae4":
    raise RuntimeError("builder admin.lua changed")
if sha(secret) != "bce78f0224b7f9b42341bc91511f32c230377449":
    raise RuntimeError("secret.lua changed")

old_actions = '{ "roundinfo", "roles", "traitoralive", "allpoints", "ongoingevents" }'
new_actions = '{ "roundinfo", "roles", "traitoralive", "allpoints", "ongoingevents", "endroundnow" }'
replace_once(pack_admin, old_actions, new_actions)
replace_once(builder_admin, old_actions, new_actions)

replace_once(
    secret,
    '    Traitormod.SendMessageEveryone(message)\n    Traitormod.SendMessageEveryone(Traitormod.HighlightClientNames(self.FinalSummary, Color.Red))\n\n',
    '    Traitormod.SendMessageEveryone(message)\n\n',
)

if sha(pack_admin) != "76ac3001e24e5f8b81ae55e06d4028bc04203ee3":
    raise RuntimeError("unexpected pack admin.lua result")
if sha(builder_admin) != "76ac3001e24e5f8b81ae55e06d4028bc04203ee3":
    raise RuntimeError("unexpected builder admin.lua result")
