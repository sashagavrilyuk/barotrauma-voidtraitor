Maintain LuaCsForBarotrauma mods, primarily VoidTraitor. Correct, minimal, readable code outranks speed.

## Core
- Never invent APIs, causes, facts, tests, commits or game success. Declare impossibility/unsuitability ONLY with cited source proof; distinguish facts from hypotheses.
- Preserve exact requested scope/behavior: no extra features, reinterpretations or unrelated edits/explanations.
- Resolve ambiguity from code/logs/source BEFORE coding. State assumptions, uncertainty, interpretations, trade-offs; never treat assumptions as engine facts. Ask only about unresolved material decisions.
- For EVERY engine-dependent claim/change, inspect relevant C#/Lua/XML source FIRST; cite exact file path, symbol, line/code excerpt for decisive claims, limitations and mode behavior. Record source version; flag unknown deployed version. If absent after searching local sources/GitHub, identify missing evidence; never guess, declare impossibility or patch from memory.
- Analyze FULL relevant subsystem, dependencies, paths and affected modes before edits; skip unrelated code. Compare working equivalents/other modes END TO END before rejecting a method.

## Simplicity
Write the smallest clear solution. NO speculative features/flexibility, needless abstractions/wrappers or unjustified one-use helpers, impossible-case guards, redundant checks or symptom-masking “protection”. Search existing working patterns first. Share logic ONLY if semantics match and it truly simplifies; never merge superficially similar behavior.
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
Keep code, localization, roles, objectives, settings, assets and persistence with actual owners. Mode rules belong to their own game mode only.
- Preserve existing mode-selection, generated-level, antagonist, role, objective and shop behavior unless the task explicitly changes it. Check every affected game mode for regressions, including those not directly modified.
- Put configurable defaults in `config/baseconfig.lua`; use `config/config.lua` for user overrides. Do not create a separate file just for one feature's settings.
- `extensions/` is for independently switchable game fixes or modifications. A patch required by a particular feature belongs with that feature's implementation, not in a separate extension.

VoidTraitor:
- `Lua/` — important/shared core logic.
- `config/` — settings, categories, events, and logic local to them.
- `gamemodes/` — game mode logic.
- `language/` — localization; avoid hardcoded user-facing text when localization exists/is appropriate.
- `objectives/` — traitor/crew objectives and completion logic.
- `roles/` — role definitions/logic.
- `extensions/` — fixes, patches, auxiliary game-related extensions.
- `features/` — standalone runtime functions of VoidTraitor that are not related to core, gamemodes, roles, objectives, pointshop, or extensions
- `config/ghostrole/` — only descriptions and configuration of ghost roles: categories, parameters, names, descriptions, prices, icons, and actions when selected
- `config/pointshop/utility/` — complex logic local to those features when moving it out improves structure.
- `data/` — permanent saved data.

No category/event/Pointshop/roundevents editing helpers without real reuse.
Prefer server-side Lua for small fixes/features. Use XML/client-side content only when server-side Lua cannot implement it correctly or would require excessive code/performance cost.

### Local paths 
- `C:\Users\shuri\Desktop\barotrauma-voidtraitor\LuaCsForBarotrauma\` — LuaCs and available Barotrauma C# source; verify APIs, hooks, and engine behavior here.
- `D:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\traitormod-voidtraitor-dev-ai` — main VoidTraitor Lua mod.
- `D:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\Void traitor pack\` — pack XML/Lua content, items, afflictions, submarines, and client content.
- `C:\Users\shuri\Desktop\barotrauma-voidtraitor\VoidTraitorPackBuilder\` — pack builder.
- `D:\SteamLibrary\steamapps\common\Barotrauma\Content` — vanilla content/maps.
- `D:\SteamLibrary\steamapps\common\Barotrauma\DedicatedServer.exe` — local dedicated server.

## Sources/Git
For EACH source-dependent question, search local source files again; not only once/session. Locate the first FOUR source sets above on disk; `Content`/`Map` are separate sources and must be searched for vanilla behavior. Never bulk-search GitHub; query GitHub ONLY for target Ai-temp/Ai files and HEAD. One outdated local file does not invalidate the other sources.
Repository: `https://github.com/sashagavrilyuk/barotrauma-voidtraitor`
`Ai-temp` = ALL development; `Ai` = ONLY accepted stable releases. NEVER push development directly to Ai. Local sources for analysis; GitHub HEAD/files govern writes. Fetch current `Ai-temp` target files/HEAD before edits; if changed, re-fetch/reapply. Never overwrite newer work or create branches without permission.

## Workflow
Before code: inspect local source, working patterns, evidence/API gates, `Ai-temp` files/HEAD; define smallest fix and regression cases.
After code: check Lua/XML syntax, exact APIs, interactions, modes, permissions and regressions; FULL diff: no unrelated edits/dead patches/unchecked large changes. Recheck HEAD before push, re-fetch/reapply if changed. Large tasks: implement one part, VERIFY, commit/push, THEN continue; avoid huge uncommitted changes/excess planning. Verify remote commits/diffs.
Release: inspect BOTH HEADs, merge-base, tree/file diff, reverts/restores/cherry-picks, independent Ai commits (counts are insufficient). Select ONLY user-accepted/tested changes + dependencies; if unsafe to isolate, STOP. Review against current Ai + assets/builder. NEVER mass-merge Ai-temp. Release one/several coherent commits to current Ai through required protection/PR, no force-push/reset/history rewrite. Recheck HEAD before writing; preserve independent changes. Verify CI, remote commits/diff; reconcile release to Ai-temp safely. ZIP ONLY changed production files with original paths; no temp tests/backups. On upload failure send ZIP, NEVER split files.
Barotrauma itself may contain engine bugs; verify its source before masking faults in VoidTraitor.

## Local workspace and tools
- Start by inspecting the real workspace and repository state using locally available tools: `pwd`, `git rev-parse --show-toplevel`, `git status --short --branch`, `git branch --show-current`, and targeted `rg --files` / `rg -n` searches. On Windows use the equivalent supported shell commands. Never invent an installation path, checkout state, game version, or available executable.
- Read the full relevant files and their callers, dependencies, C#/Lua/XML declarations, prefab assets, client/server paths and working mode equivalents directly from accessible local source directories. Repeat searches for each question; do not treat earlier snippets or remembered APIs as current evidence. Use targeted upstream retrieval only if required source is genuinely absent locally; record the exact source commit/version and unresolved deployed-version mismatch.
- For each decisive engine-dependent conclusion, include repository-relative or locally verified file path, symbol, line reference or actual code excerpt. Cite working counterparts and `BarotraumaShared`/vanilla Content/Map declarations for mode/submarine claims. Missing evidence prevents an implementation claim; it does not authorize guesses or an unfounded impossibility statement.
- If local tools permit, run relevant Lua syntax checks, XML parsing, builder/package synchronization checks, targeted scripts/tests, and inspect real client/server logs. If the game or dedicated server executable is installed and executing it is permitted, use it for focused in-game testing after the required research approval. A tool's presence, passing CI, or local mock is not a substitute for actually exercising gameplay.
- Before changing tracked files, inspect uncommitted work and compare current local and remote refs (`git fetch`/targeted `git ls-remote` where available). Keep unrelated local modifications untouched. Do not reset, stash, clean, switch branches, discard work, or modify the user's installed game outside the approved task just to make a patch convenient.
- After edits, use `git diff --check`, `git diff`, `git diff --cached`, and precise checks suited to the modified files. Review all changed paths and lines, compare asset/build outputs, check cross-mode/network effects, and never mark unrun game tests as passed. Verify remote HEAD again before any authorized push; preserve remote and local concurrent changes.
- Use local file editing and command execution capability when available. For GitHub releases, follow the branch/PR constraints above. If local access, source, privileges, or test executables are unavailable, state exactly what is missing instead of claiming local verification.
- When context or limits require a checkpoint, keep **one concise current status**: task scope, current commit/branch, changed files, verified tests, outstanding defects, and next action.
