from __future__ import annotations

import codecs
import copy
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "mods.json"
CUSTOM_DIR = BASE_DIR / "Custom"
OVERRIDES_DIR = BASE_DIR / "Overrides"
BUILD_DIR = BASE_DIR / "Build"
TEXT_EXTENSIONS = {".xml", ".lua", ".json", ".txt", ".cfg"}
OTHER_MODDIR_PATTERN = re.compile(r"%ModDir:(.+?)%", re.IGNORECASE)
ANY_MODDIR_PATTERN = re.compile(r"%ModDir(?::.+?)?%", re.IGNORECASE)


def fail(message: str) -> None:
    print(f"\nERROR: {message}")
    raise SystemExit(1)


def load_config() -> dict:
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"Не найден {CONFIG_PATH.name}")
    except json.JSONDecodeError as exc:
        fail(f"Ошибка в {CONFIG_PATH.name}: {exc}")


def workshop_root_from_config(config: dict) -> Path:
    configured = str(config.get("workshop_root", "")).strip()
    if configured:
        return Path(os.path.expandvars(configured)).expanduser()

    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        fail("Не найдена переменная LOCALAPPDATA. Укажи workshop_root в mods.json.")

    return Path(local_app_data) / "Daedalic Entertainment GmbH" / "Barotrauma" / "WorkshopMods" / "Installed"


def read_text_preserve_encoding(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    if data.startswith(codecs.BOM_UTF8):
        return data.decode("utf-8-sig"), "utf-8-sig"
    if data.startswith(codecs.BOM_UTF16_LE):
        return data.decode("utf-16"), "utf-16"
    if data.startswith(codecs.BOM_UTF16_BE):
        return data.decode("utf-16"), "utf-16"
    return data.decode("utf-8"), "utf-8"


def write_text_preserve_encoding(path: Path, text: str, encoding: str) -> None:
    path.write_text(text, encoding=encoding, newline="")


def prefix_moddir_text(text: str, target_folder: str) -> str:
    prefix = f"%ModDir%/{target_folder}"
    pattern = re.compile(
        r"%ModDir%(?![\\/]" + re.escape(target_folder) + r"(?:[\\/]|$))",
        re.IGNORECASE,
    )
    return pattern.sub(lambda _: prefix, text)


def rewrite_named_moddirs(text: str, named_moddirs: dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        target_folder = named_moddirs.get(match.group(1).strip().casefold())
        if target_folder is None:
            return match.group(0)
        return f"%ModDir%/{target_folder}"

    return OTHER_MODDIR_PATTERN.sub(replace, text)


def rewrite_moddir_text(text: str, target_folder: str, named_moddirs: dict[str, str]) -> str:
    # Bare %ModDir% belongs to the source mod. Named %ModDir:...% references are
    # resolved afterwards so the generated %ModDir% is not prefixed a second time.
    return rewrite_named_moddirs(prefix_moddir_text(text, target_folder), named_moddirs)


def rewrite_moddir_file(path: Path, target_folder: str, named_moddirs: dict[str, str]) -> None:
    if not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS:
        return
    try:
        text, encoding = read_text_preserve_encoding(path)
    except UnicodeError:
        return
    if "%moddir" not in text.casefold():
        return
    updated = rewrite_moddir_text(text, target_folder, named_moddirs)
    if updated != text:
        write_text_preserve_encoding(path, updated, encoding)


def rewrite_moddir_references(folder: Path, target_folder: str, named_moddirs: dict[str, str]) -> None:
    for path in folder.rglob("*"):
        rewrite_moddir_file(path, target_folder, named_moddirs)


def rewrite_node_paths(node: ET.Element, target_folder: str, named_moddirs: dict[str, str]) -> None:
    prefix = f"%ModDir%/{target_folder}"
    for current in node.iter():
        for key, value in list(current.attrib.items()):
            if ANY_MODDIR_PATTERN.search(value):
                current.set(key, rewrite_moddir_text(value, target_folder, named_moddirs))

        file_value = current.attrib.get("file")
        if file_value and not ANY_MODDIR_PATTERN.search(file_value):
            normalized = file_value.replace("\\", "/").lstrip("/")
            if not re.match(r"^[A-Za-z]+://", normalized):
                current.set("file", f"{prefix}/{normalized}")


def normalize_excludes(raw: object, target_folder: str) -> set[str]:
    if raw is None:
        return set()
    if not isinstance(raw, list):
        fail(f"{target_folder}: exclude в mods.json должен быть списком путей")

    result: set[str] = set()
    for value in raw:
        path = str(value).replace("\\", "/").strip().strip("/")
        if not path:
            continue
        if path == ".." or path.startswith("../") or "/../" in path:
            fail(f"{target_folder}: недопустимый exclude-путь '{value}'")
        result.add(path.casefold())
    return result


def is_excluded(relative: Path, excludes: set[str]) -> bool:
    normalized = relative.as_posix().strip("/").casefold()
    return any(normalized == excluded or normalized.startswith(excluded + "/") for excluded in excludes)


def copy_package(source: Path, destination: Path, excludes: set[str]) -> int:
    destination.mkdir(parents=True, exist_ok=True)
    excluded_files = 0
    for path in source.rglob("*"):
        relative = path.relative_to(source)
        if len(relative.parts) == 1 and relative.name.casefold() == "filelist.xml":
            continue
        if is_excluded(relative, excludes):
            if path.is_file():
                excluded_files += 1
            continue

        target = destination / relative
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    return excluded_files


def lua_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def collect_lua_autoruns(source: Path, target_folder: str) -> tuple[list[tuple[str, str]], bool]:
    lua_root = source / "Lua"
    if not lua_root.is_dir():
        return [], False

    mod_config = source / "ModConfig.xml"
    if mod_config.exists():
        fail(
            f"{target_folder}: найден ModConfig.xml. Такой Lua/C# мод нельзя безопасно вложить "
            "обычным legacy-загрузчиком; сборка остановлена, чтобы не получить тихо сломанный мод."
        )

    scripts: list[tuple[str, str]] = []
    for autorun_name in ("ForcedAutorun", "Autorun"):
        source_autorun = lua_root / autorun_name
        if not source_autorun.is_dir():
            continue

        files = sorted((p for p in source_autorun.rglob("*.lua") if p.is_file()), key=lambda p: p.as_posix().lower())
        for script in files:
            scripts.append((target_folder, script.relative_to(source).as_posix()))

    return scripts, True


def guard_bundled_autorun(path: Path, target_folder: str, relative_script: str) -> None:
    text, encoding = read_text_preserve_encoding(path)
    if text.startswith("-- VoidTraitorPackBuilder bundled autorun guard"):
        return

    newline = "\r\n" if "\r\n" in text else "\n"
    marker = lua_quote(f"{target_folder}/{relative_script}")
    guard = newline.join([
        "-- VoidTraitorPackBuilder bundled autorun guard",
        f'local __vtpackBundledAutorun = "{marker}"',
        'if rawget(_G, "__VTPACK_BUNDLED_AUTORUN") ~= __vtpackBundledAutorun then return end',
        "",
    ])
    write_text_preserve_encoding(path, guard + text, encoding)


def order_bundled_lua(
    autoruns: list[tuple[str, str]],
    lua_folders: list[str],
    configured_order: list[str],
) -> tuple[list[tuple[str, str]], list[str]]:
    if not configured_order:
        return autoruns, lua_folders

    known = {folder.casefold(): folder for folder in lua_folders}
    ordered: list[str] = []
    seen: set[str] = set()
    for name in configured_order:
        key = str(name).strip().casefold()
        if not key:
            continue
        if key not in known:
            fail(f"lua_order: Lua-мод '{name}' не найден среди собираемых модов")
        if key in seen:
            fail(f"lua_order: мод '{name}' указан дважды")
        seen.add(key)
        ordered.append(known[key])

    ordered.extend(folder for folder in lua_folders if folder.casefold() not in seen)
    rank = {folder.casefold(): i for i, folder in enumerate(ordered)}
    return sorted(autoruns, key=lambda item: rank[item[0].casefold()]), ordered


def generate_lua_loader(
    output: Path,
    autoruns: list[tuple[str, str]],
    lua_folders: list[str],
) -> None:
    if not autoruns:
        return

    wrapper_dir = output / "Lua" / "Autorun"
    wrapper_dir.mkdir(parents=True, exist_ok=True)

    lines = [
        "-- Generated by VoidTraitorPackBuilder. Do not edit.",
        "local packPath = table.pack(...)[1]",
        "",
        "-- Keep LuaCs module paths belonging to every other enabled Lua mod.",
        "local modulePaths = {}",
        "for i = 1, #package.path do",
        "    modulePaths[#modulePaths + 1] = package.path[i]",
        "end",
        "",
        "local function addModulePath(path)",
        "    for i = 1, #modulePaths do",
        "        if modulePaths[i] == path then return end",
        "    end",
        "    modulePaths[#modulePaths + 1] = path",
        "end",
        "",
        'addModulePath(packPath .. "/Lua/?.lua")',
    ]
    for target_folder in lua_folders:
        lines.append(f'addModulePath(packPath .. "/{lua_quote(target_folder)}/Lua/?.lua")')
    lines.extend([
        "setmodulepaths(modulePaths)",
        "package.path = modulePaths",
        "",
        "local function runBundled(modFolder, scriptPath)",
        '    local modPath = packPath .. "/" .. modFolder',
        '    local chunk, loadError = loadfile(modPath .. "/" .. scriptPath)',
        '    if chunk == nil then error(loadError, 0) end',
        '',
        '    local markerName = "__VTPACK_BUNDLED_AUTORUN"',
        '    local previousMarker = rawget(_G, markerName)',
        '    _G[markerName] = modFolder .. "/" .. scriptPath',
        '    local ok, runError = pcall(chunk, modPath)',
        '    _G[markerName] = previousMarker',
        '    if not ok then error(runError, 0) end',
        "end",
        "",
    ])

    for target_folder, relative_script in autoruns:
        lines.append(
            f'runBundled("{lua_quote(target_folder)}", "{lua_quote(relative_script)}")'
        )


    lines.append("")
    (wrapper_dir / "__vtpack_bundled_loader.lua").write_text(
        "\n".join(lines), encoding="utf-8", newline="\n"
    )

def find_case_insensitive(root: Path, relative: str) -> Path | None:
    current = root
    for part in relative.replace("\\", "/").split("/"):
        if not part or part == ".":
            continue
        if not current.is_dir():
            return None

        entries = list(current.iterdir())
        exact_matches = [entry for entry in entries if entry.name == part]
        if len(exact_matches) == 1:
            current = exact_matches[0]
            continue

        lowered = part.casefold()
        matches = [entry for entry in entries if entry.name.casefold() == lowered]
        if len(matches) != 1:
            return None
        current = matches[0]
    return current


def normalize_filelist_case(root: ET.Element, output: Path) -> None:
    prefix = "%ModDir%/"
    for node in root.iter():
        value = node.attrib.get("file")
        if not value:
            continue
        normalized = value.replace("\\", "/")
        if not normalized.casefold().startswith(prefix.casefold()):
            continue
        relative = normalized[len(prefix):]
        resolved = find_case_insensitive(output, relative)
        if resolved is not None:
            node.set("file", prefix + resolved.relative_to(output).as_posix())


def validate_filelist(root: ET.Element, output: Path) -> list[str]:
    missing: list[str] = []
    prefix = "%ModDir%/"
    for node in root.iter():
        value = node.attrib.get("file")
        if not value:
            continue
        normalized = value.replace("\\", "/")
        if not normalized.casefold().startswith(prefix.casefold()):
            continue
        relative = normalized[len(prefix):]
        resolved = find_case_insensitive(output, relative)
        if resolved is None or resolved.relative_to(output).as_posix() != relative:
            missing.append(value)
    return missing


def is_checkable_moddir_path(value: str) -> bool:
    normalized = value.replace("\\", "/")
    if not normalized.lower().startswith("%moddir%/"):
        return False
    relative = normalized[len("%ModDir%/"):]
    if "[gender]" in relative.casefold():
        return False
    return not any(ch in relative for ch in (';', '|', '<', '>', '*', '?'))


def collect_source_broken_references(
    prepared_mods: list[tuple],
    named_moddirs: dict[str, str],
) -> set[tuple[Path, str]]:
    sources_by_target = {target_folder: source for _, target_folder, _, source, _, _ in prepared_mods}
    broken: set[tuple[Path, str]] = set()

    for _, target_folder, _, source, _, _ in prepared_mods:
        for xml_path in source.rglob("*.xml"):
            if xml_path.name.casefold() == "filelist.xml":
                continue
            try:
                root = ET.parse(xml_path).getroot()
            except ET.ParseError:
                continue

            for node in root.iter():
                for value in node.attrib.values():
                    normalized = value.replace("\\", "/")
                    match = re.match(r"^%ModDir(?::(.+?))?%/(.+)$", normalized, re.IGNORECASE)
                    if not match:
                        continue
                    relative = match.group(2)
                    if "[gender]" in relative.casefold():
                        continue
                    if any(ch in relative for ch in (';', '|', '<', '>', '*', '?')):
                        continue

                    named = match.group(1)
                    referenced_source = source
                    if named:
                        referenced_target = named_moddirs.get(named.strip().casefold())
                        if referenced_target is None:
                            continue
                        referenced_source = sources_by_target[referenced_target]

                    if find_case_insensitive(referenced_source, relative) is not None:
                        continue

                    output_xml = Path(target_folder) / xml_path.relative_to(source)
                    rewritten = rewrite_moddir_text(value, target_folder, named_moddirs)
                    if is_checkable_moddir_path(rewritten):
                        broken.add((output_xml, rewritten))

    return broken


def validate_xml_moddir_references(
    output: Path,
    source_broken: set[tuple[Path, str]],
) -> tuple[list[tuple[Path, str]], list[tuple[Path, str]]]:
    missing: list[tuple[Path, str]] = []
    inherited: list[tuple[Path, str]] = []
    for xml_path in output.rglob("*.xml"):
        try:
            root = ET.parse(xml_path).getroot()
        except ET.ParseError:
            # Barotrauma will report malformed XML itself; this validator only checks paths.
            continue
        for node in root.iter():
            for value in node.attrib.values():
                if not is_checkable_moddir_path(value):
                    continue
                normalized = value.replace("\\", "/")
                relative = normalized[len("%ModDir%/"):]
                if find_case_insensitive(output, relative) is not None:
                    continue

                entry = (xml_path.relative_to(output), value)
                if entry in source_broken:
                    inherited.append(entry)
                else:
                    missing.append(entry)
    return missing, inherited


def normalized_filelist_relative(value: str) -> str | None:
    normalized = value.replace("\\", "/")
    prefix = "%ModDir%/"
    if not normalized.casefold().startswith(prefix.casefold()):
        return None
    return normalized[len(prefix):].lstrip("/")


def source_name_from_relative(relative: str) -> str:
    parts = relative.replace("\\", "/").split("/")
    return parts[0] if len(parts) > 1 else "Custom"


def collect_override_prefabs(file_type: str, root: ET.Element) -> list[tuple[str, str, bool, ET.Element]]:
    result: list[tuple[str, str, bool, ET.Element]] = []
    content_type = file_type.casefold()

    def visit(node: ET.Element, overriding: bool) -> None:
        name = str(node.tag).split("}")[-1].casefold()
        if name == "override":
            for child in list(node):
                visit(child, True)
            return

        if content_type == "item":
            if name == "items":
                for child in list(node):
                    visit(child, overriding)
            elif name == "item":
                identifier = node.attrib.get("identifier", "").strip().casefold()
                if identifier:
                    result.append(("item", identifier, overriding, node))
            return

        if content_type == "afflictions":
            if name == "afflictions":
                for child in list(node):
                    visit(child, overriding)
            else:
                identifier = node.attrib.get("identifier", "").strip().casefold()
                if identifier:
                    result.append((name, identifier, overriding, node))
            return

        if content_type == "randomevents":
            if name == "randomevents":
                for child in list(node):
                    visit(child, overriding)
            elif name == "eventset":
                identifier = node.attrib.get("identifier", "").strip().casefold()
                if identifier:
                    result.append(("eventset", identifier, overriding, node))
            elif name == "eventprefabs":
                for child in list(node):
                    identifier = child.attrib.get("identifier", "").strip().casefold()
                    if identifier:
                        kind = str(child.tag).split("}")[-1].casefold()
                        result.append((kind, identifier, overriding, child))
            return

        if content_type == "particles":
            if name in {"particles", "prefabs"}:
                for child in list(node):
                    visit(child, overriding)
            elif name != "clear":
                # ParticlePrefab uses the XML element name itself as the identifier.
                result.append(("particle", name, overriding, node))

    visit(root, False)
    return result


def write_modified_xml(path: Path, root: ET.Element, encoding: str) -> None:
    ET.indent(root, space="  ")
    declaration_encoding = "utf-16" if encoding == "utf-16" else "utf-8"
    text = f'<?xml version="1.0" encoding="{declaration_encoding}"?>\n' + ET.tostring(root, encoding="unicode")
    write_text_preserve_encoding(path, text, encoding)


def resolve_same_package_overrides(
    output: Path,
    final_root: ET.Element,
    file_sources: dict[str, tuple[str, bool, int]],
    override_winners: dict[frozenset[str], str],
) -> list[tuple[str, str, str, str]]:
    supported = {"item", "afflictions", "randomevents", "particles"}
    documents: dict[Path, dict] = {}
    occurrences: dict[tuple[str, str, str], list[dict]] = {}

    for node in list(final_root):
        file_value = node.attrib.get("file")
        if not file_value or node.tag.casefold() not in supported:
            continue
        relative = normalized_filelist_relative(file_value)
        if relative is None:
            continue
        source_info = file_sources.get(relative.casefold())
        if source_info is None:
            continue

        path = output / Path(relative)
        if not path.is_file():
            continue
        try:
            text, encoding = read_text_preserve_encoding(path)
            parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
            root = ET.fromstring(text, parser=parser)
        except (UnicodeError, ET.ParseError):
            continue

        parent_map = {child: parent for parent in root.iter() for child in list(parent)}
        doc = {"root": root, "encoding": encoding, "parent_map": parent_map, "modified": False}
        documents[path] = doc

        source_name, is_custom, priority = source_info
        for kind, identifier, overriding, element in collect_override_prefabs(node.tag, root):
            key = (node.tag.casefold(), kind, identifier)
            occurrences.setdefault(key, []).append({
                "source": source_name,
                "custom": is_custom,
                "priority": priority,
                "overriding": overriding,
                "element": element,
                "path": path,
            })

    resolved: list[tuple[str, str, str, str]] = []
    custom_conflicts: list[str] = []

    for (content_type, kind, identifier), entries in occurrences.items():
        overrides = [entry for entry in entries if entry["overriding"]]
        sources = {entry["source"] for entry in overrides}
        if len(sources) < 2:
            continue

        custom_sources = {entry["source"] for entry in overrides if entry["custom"]}
        if len(custom_sources) > 1:
            custom_conflicts.append(
                f"{content_type}/{kind} '{identifier}': " + ", ".join(sorted(custom_sources))
            )
            continue

        if custom_sources:
            winner = next(iter(custom_sources))
        else:
            source_keys = frozenset(source.casefold() for source in sources)
            configured_winner = override_winners.get(source_keys)
            if configured_winner is not None:
                winner = next(source for source in sources if source.casefold() == configured_winner)
            else:
                winner_entry = min(overrides, key=lambda entry: entry["priority"])
                winner = winner_entry["source"]

        winner_entries = [entry for entry in overrides if entry["source"] == winner]
        for entry in winner_entries:
            variant_of = entry["element"].attrib.get("variantof", "").strip().casefold()
            if variant_of == identifier:
                fail(
                    f"Нельзя безопасно объединить override '{identifier}': победитель '{winner}' "
                    "наследуется от предыдущего override через variantof. Оставь эти моды отдельными пакетами "
                    "или сделай специальный совместимый XML-патч."
                )

        for entry in overrides:
            if entry["source"] == winner:
                continue
            doc = documents[entry["path"]]
            parent = doc["parent_map"].get(entry["element"])
            if parent is None:
                continue
            parent.remove(entry["element"])
            doc["modified"] = True
            resolved.append((winner, entry["source"], content_type, identifier))

    if custom_conflicts:
        print("\nКонфликт между несколькими Custom XML override:")
        for conflict in custom_conflicts:
            print(f"  - {conflict}")
        fail("Сборщик не будет сам выбирать победителя между двумя твоими Custom-патчами")

    for path, doc in documents.items():
        if doc["modified"]:
            write_modified_xml(path, doc["root"], doc["encoding"])

    return resolved


def parse_override_winners(config: dict, known_sources: set[str]) -> dict[frozenset[str], str]:
    raw_rules = config.get("override_winners", [])
    if not isinstance(raw_rules, list):
        fail("override_winners в mods.json должен быть списком")

    known = {source.casefold(): source for source in known_sources}
    rules: dict[frozenset[str], str] = {}
    for rule in raw_rules:
        if not isinstance(rule, dict):
            fail("Каждый override_winners должен содержать winner и loser")
        winner = str(rule.get("winner", "")).strip()
        loser = str(rule.get("loser", "")).strip()
        if not winner or not loser or winner.casefold() == loser.casefold():
            fail("Каждый override_winners должен содержать разные winner и loser")
        if winner.casefold() not in known:
            fail(f"override_winners: неизвестный winner '{winner}'")
        if loser.casefold() not in known:
            fail(f"override_winners: неизвестный loser '{loser}'")
        key = frozenset((winner.casefold(), loser.casefold()))
        previous = rules.get(key)
        if previous is not None and previous != winner.casefold():
            fail(f"override_winners: противоречивые правила для '{winner}' и '{loser}'")
        rules[key] = winner.casefold()
    return rules


def save_filelist(root: ET.Element, destination: Path) -> None:
    ET.indent(root, space="  ")
    data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    destination.write_bytes(codecs.BOM_UTF8 + data)


def main() -> None:
    config = load_config()
    workshop_root = workshop_root_from_config(config)
    if not workshop_root.is_dir():
        fail(f"Не найдена папка WorkshopMods: {workshop_root}")

    custom_filelist = CUSTOM_DIR / "filelist.xml"
    if not custom_filelist.is_file():
        fail("Не найден Custom/filelist.xml")

    output_name = str(config.get("output_folder", "")).strip()
    if not output_name:
        fail("В mods.json не задан output_folder")

    output = BUILD_DIR / output_name
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    # Custom is the source of truth for the user's own files.
    for child in CUSTOM_DIR.iterdir():
        if child.name.lower() == "filelist.xml":
            continue
        target = output / child.name
        if child.is_dir():
            shutil.copytree(child, target, dirs_exist_ok=True)
        else:
            shutil.copy2(child, target)

    # This file is generated below. Never keep a stale Custom copy when the
    # bundled Lua set changes or becomes empty.
    generated_loader = output / "Lua" / "Autorun" / "__vtpack_bundled_loader.lua"
    if generated_loader.exists():
        generated_loader.unlink()

    try:
        custom_root = ET.parse(custom_filelist).getroot()
        final_root = ET.Element(custom_root.tag, dict(custom_root.attrib))
    except ET.ParseError as exc:
        fail(f"Ошибка в Custom/filelist.xml: {exc}")

    print(f"Workshop: {workshop_root}")
    print(f"Output:   {output}")
    print()

    mods = config.get("mods")
    if not isinstance(mods, list):
        fail("mods в mods.json должен быть списком")

    prepared_mods = []
    named_moddirs: dict[str, str] = {}
    excludes_by_target: dict[str, set[str]] = {}
    file_sources: dict[str, tuple[str, bool, int]] = {}
    for mod in mods:
        workshop_id = str(mod.get("workshop_id", "")).strip()
        target_folder = str(mod.get("target_folder", "")).strip()
        expected_name = str(mod.get("package_name", "")).strip()
        if not workshop_id or not target_folder:
            fail("У каждого мода должны быть workshop_id и target_folder")

        excludes_by_target[target_folder.casefold()] = normalize_excludes(mod.get("exclude"), target_folder)

        source = workshop_root / workshop_id
        source_filelist = source / "filelist.xml"
        if not source_filelist.is_file():
            fail(
                f"{target_folder}: не найден Workshop-мод {workshop_id}. "
                "Проверь подписку и дождись, пока Steam/Barotrauma его установит."
            )

        try:
            source_root = ET.parse(source_filelist).getroot()
        except ET.ParseError as exc:
            fail(f"{target_folder}: ошибка в исходном filelist.xml: {exc}")

        source_name = source_root.attrib.get("name", "").strip()
        prepared_mods.append((workshop_id, target_folder, expected_name, source, source_root, source_name))

        for alias in (workshop_id, expected_name, source_name):
            key = alias.strip().casefold()
            if not key:
                continue
            existing = named_moddirs.get(key)
            if existing is not None and existing != target_folder:
                fail(f"Одинаковое имя/ID мода '{alias}' ведёт в разные target_folder")
            named_moddirs[key] = target_folder

    source_broken = collect_source_broken_references(prepared_mods, named_moddirs)

    bundled_autoruns: list[tuple[str, str]] = []
    bundled_lua_folders: list[str] = []
    for mod_priority, (workshop_id, target_folder, expected_name, source, source_root, source_name) in enumerate(prepared_mods):
        if expected_name and source_name and source_name.casefold() != expected_name.casefold():
            print(f"WARNING: {target_folder}: package name '{source_name}' вместо ожидаемого '{expected_name}'")

        destination = output / target_folder
        excluded_files = copy_package(
            source, destination, excludes_by_target.get(target_folder.casefold(), set())
        )
        rewrite_moddir_references(destination, target_folder, named_moddirs)

        for child in list(source_root):
            imported = copy.deepcopy(child)
            rewrite_node_paths(imported, target_folder, named_moddirs)
            final_root.append(imported)
            file_value = imported.attrib.get("file")
            if file_value:
                relative = normalized_filelist_relative(file_value)
                if relative is not None:
                    file_sources[relative.casefold()] = (target_folder, False, mod_priority)

        autoruns, has_lua = collect_lua_autoruns(destination, target_folder)
        for _, relative_script in autoruns:
            guard_bundled_autorun(destination / relative_script, target_folder, relative_script)
        bundled_autoruns.extend(autoruns)
        if has_lua:
            bundled_lua_folders.append(target_folder)
        suffix = f", Lua autorun: {len(autoruns)}" if autoruns else ""
        excluded_suffix = f", excluded files: {excluded_files}" if excluded_files else ""
        print(f"OK: {target_folder} [{workshop_id}]{suffix}{excluded_suffix}")

    lua_order = config.get("lua_order", [])
    if not isinstance(lua_order, list):
        fail("lua_order в mods.json должен быть списком")
    bundled_autoruns, bundled_lua_folders = order_bundled_lua(
        bundled_autoruns, bundled_lua_folders, lua_order
    )
    generate_lua_loader(output, bundled_autoruns, bundled_lua_folders)

    # Keep the same load principle as the current pack: bundled Workshop content
    # first, the user's own entries/fixes after it so they can override it.
    for child in list(custom_root):
        imported = copy.deepcopy(child)
        final_root.append(imported)
        file_value = imported.attrib.get("file")
        if file_value:
            relative = normalized_filelist_relative(file_value)
            if relative is not None:
                file_sources[relative.casefold()] = (source_name_from_relative(relative), True, -1)

    # Overrides are applied after every Workshop update.
    if OVERRIDES_DIR.is_dir():
        for child in OVERRIDES_DIR.iterdir():
            if child.name.startswith("_"):
                continue
            target = output / child.name
            if child.is_dir():
                shutil.copytree(child, target, dirs_exist_ok=True)
                for override_file in child.rglob("*"):
                    if override_file.is_file():
                        rewrite_moddir_file(
                            target / override_file.relative_to(child),
                            child.name,
                            named_moddirs,
                        )
            else:
                shutil.copy2(child, target)
                rewrite_moddir_file(target, child.name, named_moddirs)

    override_winners = parse_override_winners(
        config, {source_info[0] for source_info in file_sources.values()}
    )
    resolved_overrides = resolve_same_package_overrides(
        output, final_root, file_sources, override_winners
    )
    if resolved_overrides:
        pairs: dict[tuple[str, str], list[str]] = {}
        for winner, loser, content_type, identifier in resolved_overrides:
            pairs.setdefault((winner, loser), []).append(f"{content_type}:{identifier}")
        print("\nРазрешены XML override-конфликты внутри общего пакета:")
        for (winner, loser), identifiers in pairs.items():
            preview = ", ".join(identifiers[:8])
            suffix = f" ... +{len(identifiers) - 8}" if len(identifiers) > 8 else ""
            print(f"  - {winner} > {loser}: {preview}{suffix}")

    normalize_filelist_case(final_root, output)
    save_filelist(final_root, output / "filelist.xml")

    missing_filelist = validate_filelist(final_root, output)
    if missing_filelist:
        print("\nВ filelist.xml отсутствуют файлы:")
        for value in missing_filelist:
            print(f"  - {value}")
        fail("Сборка остановлена из-за отсутствующих файлов в filelist.xml")

    missing_xml, inherited_xml = validate_xml_moddir_references(output, source_broken)
    if inherited_xml:
        print("\nWARNING: В исходных Workshop-модах уже есть ссылки на отсутствующие пути:")
        for xml_path, value in inherited_xml[:50]:
            print(f"  - {xml_path}: {value}")
        if len(inherited_xml) > 50:
            print(f"  ... и ещё {len(inherited_xml) - 50}")
        print("Эти ссылки не созданы сборщиком; сборка будет продолжена.")

    if missing_xml:
        print("\nНайдены новые битые ссылки %ModDir%:")
        for xml_path, value in missing_xml[:50]:
            print(f"  - {xml_path}: {value}")
        if len(missing_xml) > 50:
            print(f"  ... и ещё {len(missing_xml) - 50}")
        fail("Сборка остановлена: ссылка сломана после сборки или находится в Custom/Overrides")

    print(f"\nГОТОВО: {output}")
    print(f"Bundled Lua autorun: {len(bundled_autoruns)}")


if __name__ == "__main__":
    main()
