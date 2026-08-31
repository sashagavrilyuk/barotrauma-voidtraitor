from pathlib import Path

path = Path("traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua")
text = path.read_text(encoding="utf-8")
old = '''    table.sort(entries, function(a, b)\n        return string.lower(tostring(a.Character.Name)) < string.lower(tostring(b.Character.Name))\n    end)'''
new = '''    table.sort(entries, function(a, b)\n        if a.Role.IsAntagonist ~= b.Role.IsAntagonist then\n            return a.Role.IsAntagonist\n        end\n        return string.lower(tostring(a.Character.Name)) < string.lower(tostring(b.Character.Name))\n    end)'''
if text.count(old) != 1:
    raise SystemExit(f"expected one RoundSummary sort block, got {text.count(old)}")
path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="")
