Maintain LuaCsForBarotrauma mods, primarily VoidTraitor (`traitormod-voidtraitor-dev-ai`) and its client/content pack (`Void traitor pack`). Correct, minimal, readable code outranks speed.

## Core
- Never invent APIs, causes, facts, tests, commits or game success. Declare impossibility/unsuitability ONLY with cited source proof; distinguish facts from hypotheses.
- Preserve exact requested scope/behavior: no extra features, reinterpretations or unrelated edits/explanations.
- Resolve ambiguity from code/logs/source BEFORE coding. State assumptions, uncertainty, interpretations, trade-offs; never treat assumptions as engine facts. Ask only about unresolved material decisions.
- For EVERY engine-dependent claim/change, inspect relevant C#/Lua/XML source FIRST; cite exact file path, symbol, line/code excerpt for decisive claims, limitations and mode behavior. Record source version; flag unknown deployed version. If absent after searching local sources/GitHub, identify missing evidence; never guess, declare impossibility or patch from memory.
- Analyze FULL relevant subsystem, dependencies, paths and affected modes before edits; skip unrelated code. Compare working equivalents/other modes END TO END before rejecting a method.

## Simplicity
Write the smallest clear solution (never write 200 lines when 50 lines solve the exact task). NO speculative features/flexibility, needless abstractions/wrappers or unjustified one-use helpers, impossible-case guards, redundant checks or symptom-masking “protection”. Search existing working patterns first. Share logic ONLY if semantics match and it truly simplifies; never merge superficially similar behavior.
- Do not add a second event handler, UI manager, state machine, polling loop, or helper if the current system can correctly handle the feature.

## Surgical changes
Change ONLY task-required lines; preserve style. NO unrelated refactor, reformat, rename, comment rewrite or adjacent improvement. Report unrelated defects without editing them.
- Remove imports/variables/functions only if YOUR changes made them unused.
- Preserve working modes, settings, persistence, server authorization, behavior; check regressions. Support clients WITH/WITHOUT client LuaCs, NOT obsolete VoidTraitor builds. NEVER ADD V2/incremental network messages, legacy handlers, version branches, fallbacks or migrations; exception ONLY for explicit user request backed by verified real consumers.
- Never split files for GitHub upload.

## Evidence gate
- BEFORE bug edits establish ORIGINAL expected/observed behavior, reproduction, trigger. Trace callers/hooks, state, event order, ownership/lifetime, cleanup, Lua/XML/C#/client/network/server paths. Compare working equivalents and competing causes against code/logs/source. Suspicious code is NOT proof.
- Report reproduction, cited evidence, alternatives tested, proven cause or UNKNOWN, minimal fix and regressions. “Unverified” is NOT permission to skip source inspection. If cause remains unproven: targeted diagnostics, NO production patch.
- If game fix fails, verify changed path loaded/ran, discard unsupported diagnosis and obtain NEW evidence BEFORE another patch. Never mask faults with delays, retries, polling, caches, flags, hooks, extra guards or weaker authorization.
- Crashes, GUI, networking, physics, round lifecycle, ANY newly used/changed Barotrauma/LuaCs API, mode/submarine mechanics or repeat failures: PHASE 1 = RESEARCH ONLY, NO edits/commits. PHASE 2 only after user's LATER explicit approval of diagnosis. “Fix it” does not waive this. Explicit combined-pass waiver still requires completed source-based diagnosis before edits. Low-risk tasks: one pass.
- EVERY new/changed engine call/hook: cite exact C# declaration/overload, args/return, enums/static semantics, Lua exposure, client/server availability, nil/null, removed/disposed lifetime; trace delayed callbacks (Timer.Wait) and consumers. GUI: click/pathing, create/layout, Update/Draw, item insert/remove, cleanup/reopen. Network: serialization, server authority/role/distance/inventory, clients WITH/WITHOUT LuaCs. Verify XML IDs/assets and builder sync.
- Do not arbitrarily close a window because of a transient engine selection change if interaction should remain active. Equally, do not keep a window or authorize actions after genuine loss of interaction rights. Verify the intended lifecycle from source and an existing working implementation.
- Reuse established VoidTraitor UI primitives and layouts. Account for resolution and HUD scale; avoid fixed dimensions that clip controls. Use existing drag/resize behavior when asked for it, not a partial imitation.
- Mode/PvP/spawn/sub/level claims: inspect relevant BarotraumaShared C# (SubmarineInfo, GameMode, LevelGenerationParams), vanilla Content/Map XML AND working modes before technical conclusions.
- “Checked” without cited source evidence is invalid. Separately mark SOURCE VERIFIED / STATICALLY CHECKED / GAME TESTED / USER CONFIRMED / NOT TESTED. Syntax/CI/mocks ≠ game/crash safety. Never release unaccepted or unverified crash-prone changes to Ai.

## Structure
Keep code, localization, roles, objectives, settings, assets and persistence with actual owners. Mode rules belong to their own game mode only. Before creating or editing ANY file, inspect 1–2 existing files in that exact target folder and strictly match their table structure, style, and registration pattern. Never invent new folders or place files in the wrong layer.
- Preserve existing mode-selection, generated-level, antagonist, role, objective and shop behavior unless the task explicitly changes it. Check every affected game mode for regressions, including those not directly modified.
- Put configurable defaults in `config/baseconfig.lua`; use `config/config.lua` for user overrides. Do not create a separate file just for one feature's settings.
- `extensions/` is for independently switchable game fixes or modifications. A patch required by a particular feature belongs with that feature's implementation, not in a separate extension.

### 1. Server & Shared Mod (`traitormod-voidtraitor-dev-ai`)
- `Lua/Autorun/init.lua` — entry point.
- `Lua/` — important/shared core logic ONLY (`traitormod.lua`, `traitormodutil.lua`, `clientmenu.lua`, `commands.lua`, `ghostroles.lua`, `json.lua`, `objectivehud.lua`, `pointshop.lua`, `rolemanager.lua`, `roundevents.lua`, `roundstats.lua`, `statistics.lua`, `stringbuilder.lua`, `submarinebuilder.lua`, `textpromptutils.lua`, `voting.lua`, `weightedrandom.lua`, `xmlpatching.lua`).
- `Lua/config/` — settings, categories, events, and logic local to them (`baseconfig.lua`, `config.lua`, `config.lua.example`).
- `Lua/config/ghostrole/` — ONLY descriptions and configuration of ghost roles: categories, parameters, names, descriptions, prices, icons, and actions when selected (`clowncrate.lua`, `emergency.lua`, `misc.lua`, `monsterbeacon.lua`, `pointshop.lua`, `prisoner.lua`, `rescue.lua`, `system.lua`, `ventcreatures.lua`, and `pirates/{beacon,crew,hidden,mission,wreck}.lua`).
- `Lua/config/pointshop/` — category definitions (`abilities.lua`, `maintenance.lua`, `materials.lua`, `medical.lua`, `ores.lua`, `other.lua`, `otherresources.lua`, `randomize.lua`, `security.lua`, `ships.lua`, `surgery.lua`, `wiring.lua`) and mode/role sub-folders (`attackdefend/{spawnBlue,spawnRed}.lua`, `deathspawns/{deathspawn,deathspawnfriend,deathspawnhusk}.lua`, `events/{deathtrigerevent,deathtrigereventevil,deathtrigereventrandom}.lua`, `hideandseek/{hideBlue,hideRed}.lua`, `traitors/{clown,cultist,saboteur,traitor}.lua`).
- `Lua/config/pointshop/utility/` — complex logic local to pointshop features when moving it out improves structure (`abilities.lua`, `deathspawncreature.lua`, `monsterbeacon.lua`, `randomizer.lua`, plus `Lua/config/pointshop/attackdefend/utility/adv2.lua`).
- `Lua/config/randomevents/` — random event definitions (`abysshelp.lua`, `ammodelivery.lua`, `beaconrescue.lua`, `clowncratesurprise.lua`, `emergencyteam.lua`, `maintenancetoolsdelivery.lua`, `medicaldelivery.lua`, `prisoner.lua`, `shadymission.lua`, `stationattack.lua`, `superballastflora.lua`, `ventcreatures.lua`, `weakballastflora.lua`, `wreckrescue.lua`), sub-folders (`abilities/`, `break/`, `pirate/`, `pirate/utility/upcpirate.lua`, `repair/`, `sabotage/{clown,cultist,traitor}/`), and shared event utilities in `Lua/config/randomevents/utility/` (`eventnpc.lua`, `oxygenevent.lua`, `rescueevent.lua`, `securityturretevent.lua`, `skillboostevent.lua`).
- `Lua/gamemodes/` — game mode logic (`gamemode.lua`, `attackdefendv2.lua`, `hideandseekv2.lua`, `pvp.lua`, `secret.lua`, `submarineroyale.lua`) and station mode modules in `Lua/gamemodes/station/` (`station.lua`, `cargo.lua`, `cloning.lua`, `communications.lua`, `evacuation.lua`, `idconsole.lua`, `nuclear.lua`).
- `Lua/language/` — localization (`russian.lua` and `Lua/language/russian/{cargo,cloning,communications,core,discord,gamemodes,ghostroles,idconsole,nuclear,pointshop,roles_objectives,station}.lua`); avoid hardcoded user-facing text when localization exists/is appropriate.
- `Lua/objectives/` — traitor/crew objectives and completion logic (`objective.lua`, antagonist objectives, and crew objectives in `Lua/objectives/crew/`).
- `Lua/roles/` — role definitions/logic (`role.lua`, `antagonist.lua`, `clown.lua`, `crew.lua`, `cultist.lua`, `huskservant.lua`, `saboteur.lua`, `traitor.lua`).
- `Lua/extensions/` — fixes, patches, auxiliary game-related extensions (`attackdefendreactorblastfix.lua`, `brokenhandcuffs.lua`, `deathswarm.lua`, `paralysisnerf.lua`, `pressuremidjoin.lua`, `servermessageutf8fix.lua`, `spectatorjobfix.lua`, `stationragdollplatforms.lua`, `weaponnerfs.lua`).
- `Lua/features/` — standalone runtime functions of VoidTraitor that are not related to core, gamemodes, roles, objectives, pointshop, or extensions (`camerateleport.lua`, `deathlogbook.lua`, `discordwebhooks.lua`, `killfeed.lua`, `midroundspawn.lua`, `piratemissionghostroles.lua`, `pointitems.lua`, `respawnshuttle.lua`, `serverlogs.lua`, `skillbuffs.lua`, `welcome.lua`).
- `Lua/data/` — permanent saved data (`data.json`, `discordstate.json`, `roundcounter.json`, `stats.json`).
- `types/` & `definitions/` — type definitions (`Traitormod.lua`, `event.lua`, `gamemodes.lua`, `team.lua`, `definitions/main.lua`).

### 2. Client GUI & Content Pack (`Void traitor pack/Lua`)
Client-side GUI is strictly modular. Never dump everything into a single file or duplicate shared UI primitives:
- `Lua/Autorun/` — `init.lua` and `__vtpack_bundled_loader.lua` (must stay synchronized with `VoidTraitorPackBuilder` when files are added/renamed).
- `Lua/client/init.lua` & `Lua/client/common.lua` — client bootstrap and shared GUI core helpers (`common.lua`). Shared UI primitives/layout helpers belong in `common.lua`.
- `Lua/client/` — standalone client UI screens (`attackdefend_respawn.lua`, `killfeed.lua`, `roundsummary.lua`, `submarine_description.lua`, `welcome.lua`).
- `Lua/client/lobby/` — strictly separated lobby & voting layers:
  - Lobby menu: `menu.lua`, `menu_core.lua`, `menu_window.lua`, `menu_widgets.lua`, `menu_controls.lua`, `menu_runtime.lua`, `admin.lua`.
  - Voting UI: `voting.lua`, `voting_menu.lua`, `voting_layout.lua`, `voting_display.lua`, `voting_runtime.lua`.
- `Lua/client/pointshop/` — strictly separated Pointshop client layers:
  - GUI core & widgets: `gui.lua`, `gui_core.lua`, `widgets.lua`, `input.lua`.
  - Data/state/network models: `model_state.lua`, `model_folders.lua`, `model_text.lua`, `model_network.lua`, `network.lua`.
  - Panels: `shop_panel.lua`, `shop_categories.lua`, `shop_filters.lua`, `shop_products.lua`, `cart_panel.lua`, `cart_items.lua`.
- `Lua/client/spectator/` — spectator UI (`camera_teleport.lua`, `ghostroles.lua`), paired with server `camerateleport.lua` and `ghostroles.lua`.
- `Lua/client/station/` — station console client UI (`cargo.lua`, `communications.lua`, `idconsole.lua`, `nuclear.lua`), paired with `Lua/gamemodes/station/` on the server.
- `Lua/extensions/` — client/pack extensions (`enhanced_husks_optimization.lua`, `headset_stun.lua`, `nt_surgery_access_fix.lua`).
- `Lua/language/` — client localization (`russian.lua`, `welcome_russian.lua`).

No category/event/Pointshop/roundevents editing helpers without real reuse.
Prefer server-side Lua for small fixes/features. Use XML/client-side content only when server-side Lua cannot implement it correctly or would require excessive code/performance cost.

### Local paths 
- `C:\Users\shuri\Desktop\barotrauma-voidtraitor\LuaCsForBarotrauma\` — LuaCs and available Barotrauma C# source; verify APIs, hooks, and engine behavior here.
- `D:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\traitormod-voidtraitor-dev-ai` — main VoidTraitor Lua mod.
- `D:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\Void traitor pack\` — pack XML/Lua content, items, afflictions, submarines, and client content.
- `C:\Users\shuri\Desktop\barotrauma-voidtraitor\VoidTraitorPackBuilder\` — pack builder.
- `D:\SteamLibrary\steamapps\common\Barotrauma\Content` — vanilla content/maps.
- `D:\SteamLibrary\steamapps\common\Barotrauma\DedicatedServer.exe` — local dedicated server.

## Sources/Git & Token Protection
- **Token-Burn Exclusions (NEVER read, grep, or index unless explicitly requested for the current task):**
  - `Submarines/**` (`*.sub` files are massive submarine XML/binary blobs).
  - `Lua/data/**` (`data.json`, `stats.json`, `discordstate.json*` contain huge runtime dumps).
  - `.serena/cache/**` (`*.pkl` symbol caches).
- **Source Verification & Session Reuse:** Locate the first FOUR source sets above on disk; `Content`/`Map` are separate sources and must be searched for vanilla behavior. Inspect the relevant local C#/Lua/XML files BEFORE making claims or edits. Within the SAME session, reuse already-verified file excerpts/declarations unless those files were edited or a new question requires checking uninspected lines (do not re-read the entire workspace from scratch on every prompt). One outdated local file does not invalidate the other sources.
- Never bulk-search GitHub; query GitHub ONLY for target `Ai-temp`/`Ai` files and HEAD.
- Repository: `https://github.com/sashagavrilyuk/barotrauma-voidtraitor`
- `Ai-temp` = ALL development; `Ai` = ONLY accepted stable releases. NEVER push development directly to `Ai`. Local sources for analysis; GitHub HEAD/files govern writes. Fetch current `Ai-temp` target files/HEAD before edits; if changed, re-fetch/reapply. Never overwrite newer work or create branches without permission.

## Workflow
Before code: inspect local source, working patterns, evidence/API gates, `Ai-temp` files/HEAD; define smallest fix and regression cases.
After code: check Lua/XML syntax, exact APIs, interactions, modes, permissions and regressions; FULL diff: no unrelated edits/dead patches/unchecked large changes. Recheck HEAD before push, re-fetch/reapply if changed. Large tasks: implement one part, VERIFY, commit/push, THEN continue; avoid huge uncommitted changes/excess planning. Verify remote commits/diffs.
Release (ONLY when explicitly requested by user): inspect BOTH HEADs, merge-base, tree/file diff, reverts/restores/cherry-picks, independent `Ai` commits (counts are insufficient). Select ONLY user-accepted/tested changes + dependencies; if unsafe to isolate, STOP. Review against current `Ai` + assets/builder. NEVER mass-merge `Ai-temp`. Release one/several coherent commits to current `Ai` through required protection/PR, no force-push/reset/history rewrite. Recheck HEAD before writing; preserve independent changes. Verify CI, remote commits/diff; reconcile release to `Ai-temp` safely. ZIP ONLY changed production files with original paths; no temp tests/backups. On upload failure send ZIP, NEVER split files.
Barotrauma itself may contain engine bugs; verify its source before masking faults in VoidTraitor.

## Local workspace and tools
- Start by inspecting the real workspace and repository state using locally available tools: `pwd`, `git rev-parse --show-toplevel`, `git status --short --branch`, `git branch --show-current`, and targeted `rg --files` / `rg -n` searches (always excluding `Submarines/`, `Lua/data/`, and `.serena/cache/`). On Windows use the equivalent supported shell commands. Never invent an installation path, checkout state, game version, or available executable.
- Read the full relevant files and their callers, dependencies, C#/Lua/XML declarations, prefab assets, client/server paths and working mode equivalents directly from accessible local source directories. Do not treat unverified memory as evidence. Use targeted upstream retrieval only if required source is genuinely absent locally; record the exact source commit/version and unresolved deployed-version mismatch.
- For each decisive engine-dependent conclusion, include repository-relative or locally verified file path, symbol, line reference or actual code excerpt. Cite working counterparts and `BarotraumaShared`/vanilla Content/Map declarations for mode/submarine claims. Missing evidence prevents an implementation claim; it does not authorize guesses or an unfounded impossibility statement.
- If local tools permit, run relevant Lua syntax checks, XML parsing, builder/package synchronization checks, targeted scripts/tests, and inspect real client/server logs. If the game or dedicated server executable is installed and executing it is permitted, use it for focused in-game testing after the required research approval. A tool's presence, passing CI, or local mock is not a substitute for actually exercising gameplay.
- Before changing tracked files, inspect uncommitted work and compare current local and remote refs (`git fetch`/targeted `git ls-remote` where available). Keep unrelated local modifications untouched. Do not reset, stash, clean, switch branches, discard work, or modify the user's installed game outside the approved task just to make a patch convenient.
- After edits, use `git diff --check`, `git diff`, `git diff --cached`, and precise checks suited to the modified files. Review all changed paths and lines, compare asset/build outputs, check cross-mode/network effects, and never mark unrun game tests as passed. Verify remote HEAD again before any authorized push; preserve remote and local concurrent changes.
- Use local file editing and command execution capability when available. For GitHub releases, follow the branch/PR constraints above. If local access, source, privileges, or test executables are unavailable, state exactly what is missing instead of claiming local verification.
- When context or limits require a checkpoint, keep **one concise current status**: task scope, current commit/branch, changed files, verified tests, outstanding defects, and next action.
