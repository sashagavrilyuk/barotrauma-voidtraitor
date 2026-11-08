Maintain LuaCsForBarotrauma mods, primarily VoidTraitor (`traitormod-voidtraitor-1.15`) and its client/content pack (`Void traitor pack-1.15`). Correct, minimal, readable code outranks speed.

Machine paths, versions, tools and long-term memory are in the global `~/.codex/AGENTS.md` (Claude Code keeps the same rules in `~/.claude/CLAUDE.md`).

## Skills
Load the matching skill before the work starts; its rules add to this file and never relax it.
- `barotrauma-luacs-networking` — network sync, entity spawn/remove, physics, teleport, NPC control, Agent Bridge MCP.
- `barotrauma-gui` — any client GUI in `Void traitor pack-1.15/Lua/client/` (windows, menus, Pointshop, consoles, HUD).
- `barotrauma-sandbox-test` — any in-game test or measurement in `D:\BaroSandbox`.
- `voidtraitor-release` — only when the user explicitly asks for a release to `Ai` or a ZIP.

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
- Preserve working modes, settings, persistence, server authorization, behavior; check regressions. Client LuaCs is REQUIRED (user decision 2026-11-04): new features may use client code and Lua net messages; add NO paths for clients without client Lua and remove existing ones only in a task that covers them. Support only the current VoidTraitor build, NOT obsolete ones. NEVER ADD V2/incremental network messages, legacy handlers, version branches, fallbacks or migrations; exception ONLY for explicit user request backed by verified real consumers.
- Never split files for GitHub upload.

## Server load
Server load comes first: the production server runs inside a game client, and a lagging server ruins every round. Treat load as a correctness requirement for every feature, event and client feature.
- `think` (alias of `IEventUpdate.OnUpdate`, `LuaScriptManagementService.cs:270`) runs every update: no per-frame work without a throttle or early exit; add the hook only while its feature/event is active and remove it on finish and round end.
- Prefer an existing event hook over polling. In hot paths do not iterate `Character.CharacterList`/`Item.ItemList`/`GetItems`, build strings, log or allocate tables when a held reference or an event does the job.
- Events and directors: do the work once at start or on engine events; periodic checks run on timers of seconds, not frames, and stop when the event ends. Scan entity lists at most on such a timer, or collect references once at start.
- Keep authority and state on the server and move presentation to the client (UI, sounds, camera, particles, text formatting): the server sends a short message, the client does the work.
- Send net messages and entity events only on state change, never per tick, with small payloads, and only to the clients that need them.
- New periodic work or spawns in bulk: measure it in the sandbox (counts, timings, profiler) before it ships. Cost claims need evidence; no speculative optimization of code that was not measured.

## Security
The pack and all client code are public and editable by any player; a client is never trusted.
- Every client message is validated on the server: the sender is in the round and allowed (role, job, permission, alive/dead state, ownership, distance), values are type-checked and bounded, and requests that cost server work are rate-limited. The server computes outcomes itself (prices, points, spawns, damage, roles) and never applies a value the client claims.
- Send each client only what its player may know at that moment: no antagonist roles or objectives of others, other players' points or data, hidden events or entities, admin-only data, config, webhooks or tokens. Filter on the server before sending, not in client code.
- Never put secrets, admin logic, hidden-information tables or anything that grants power into the pack or client Lua. Admin features check permissions on the server for every request, not only when showing the UI.

## Readable code
The repository is public; code must read as written by a careful maintainer.
- Names and structure say what the code does; comments only explain a non-obvious why (engine quirk, ordering, network constraint), in the style of the original traitormod: short plain one-liners, mostly lowercase English; Russian stays Russian in files that already use it. Source evidence (file:line) goes in the report, not in code comments.
- No process markers in code: no `-- FIX:`, `-- Added`, `-- NEW`, `-- IMPORTANT`, emoji, change-log wording, `SERVER ONLY:` or decorative banners, comments restating the code. No leftover debug prints, diagnostic hooks or commented-out code in production files.
- Commit messages: a short imperative summary of what changed, then why if it is not obvious, in plain language.

## Evidence gate
- BEFORE bug edits establish ORIGINAL expected/observed behavior, reproduction, trigger. Trace callers/hooks, state, event order, ownership/lifetime, cleanup, Lua/XML/C#/client/network/server paths. Compare working equivalents and competing causes against code/logs/source. Suspicious code is NOT proof.
- Report reproduction, cited evidence, alternatives tested, proven cause or UNKNOWN, minimal fix and regressions. “Unverified” is NOT permission to skip source inspection. If cause remains unproven: targeted diagnostics, NO production patch.
- If game fix fails, verify changed path loaded/ran, discard unsupported diagnosis and obtain NEW evidence BEFORE another patch. Never mask faults with delays, retries, polling, caches, flags, hooks, extra guards or weaker authorization.
- Crashes, GUI, networking, physics, round lifecycle, ANY newly used/changed Barotrauma/LuaCs API, mode/submarine mechanics or repeat failures: PHASE 1 = RESEARCH ONLY, NO edits/commits. PHASE 2 only after user's LATER explicit approval of diagnosis. “Fix it” does not waive this. Explicit combined-pass waiver still requires completed source-based diagnosis before edits. Low-risk tasks (one pass): text/localization, comments/docs, config values/prices/weights, and edits that add no new engine call/hook and touch no GUI, network or lifecycle code.
- EVERY new/changed engine call/hook: cite exact C# declaration/overload, args/return, enums/static semantics, Lua exposure, client/server availability, nil/null, removed/disposed lifetime; trace delayed callbacks (Timer.Wait) and consumers. Network: serialization, server authority/role/distance/inventory, what each client receives and may send (Security). Verify XML IDs/assets and builder sync.
- Mode/PvP/spawn/sub/level claims: inspect relevant BarotraumaShared C# (SubmarineInfo, GameMode, LevelGenerationParams), vanilla Content/Map XML AND working modes before technical conclusions.
- “Checked” without cited source evidence is invalid. Separately mark SOURCE VERIFIED / STATICALLY CHECKED / GAME TESTED / USER CONFIRMED / NOT TESTED. Syntax/CI/mocks ≠ game/crash safety. Never release unaccepted or unverified crash-prone changes to Ai.
- Barotrauma itself may contain engine bugs; verify its source before masking faults in VoidTraitor.

## Structure
Keep code, localization, roles, objectives, settings, assets and persistence with actual owners. Mode rules belong to their own game mode only. Before creating or editing ANY file, inspect 1–2 existing files in that exact target folder and strictly match their table structure, style, and registration pattern. Never invent new folders or place files in the wrong layer.
- Preserve existing mode-selection, generated-level, antagonist, role, objective and shop behavior unless the task explicitly changes it. Check every affected game mode for regressions, including those not directly modified.
- Put configurable defaults in `config/baseconfig.lua`; use `config/config.lua` for user overrides. Do not create a separate file just for one feature's settings.
- `extensions/` is for independently switchable game fixes or modifications. A patch required by a particular feature belongs with that feature's implementation, not in a separate extension.
- Avoid hardcoded user-facing text when localization exists/is appropriate. No category/event/Pointshop/roundevents editing helpers without real reuse.
- Server-side Lua owns rules, state and authority. Use client Lua for presentation when it spares the server work or traffic, and XML content when the engine already does the job (item behavior, locks, sounds on items).

### 1. Server & Shared Mod (`traitormod-voidtraitor-1.15`)
- `Lua/Autorun/init.lua` — entry point.
- `Lua/` — important/shared core logic ONLY (`traitormod.lua`, `traitormodutil.lua`, `clientmenu.lua`, `commands.lua`, `ghostroles.lua`, `json.lua`, `objectivehud.lua`, `pointshop.lua`, `rolemanager.lua`, `roundevents.lua`, `roundstats.lua`, `statistics.lua`, `stringbuilder.lua`, `submarinebuilder.lua`, `textpromptutils.lua`, `voting.lua`, `weightedrandom.lua`, `xmlpatching.lua`).
- `Lua/config/` — settings, categories, events, and logic local to them (`baseconfig.lua`, `config.lua`, `config.lua.example`).
- `Lua/config/ghostrole/` — ONLY descriptions and configuration of ghost roles: categories, parameters, names, descriptions, prices, icons, and actions when selected (`clowncrate.lua`, `defensebot.lua`, `emergency.lua`, `misc.lua`, `monsterbeacon.lua`, `pointshop.lua`, `prisoner.lua`, `rescue.lua`, `system.lua`, `ventcreatures.lua`, `wild.lua`, and `pirates/{beacon,crew,hidden,mission,wreck}.lua`).
- `Lua/config/pointshop/` — category definitions (`abilities.lua`, `maintenance.lua`, `materials.lua`, `medical.lua`, `ores.lua`, `other.lua`, `otherresources.lua`, `randomize.lua`, `security.lua`, `ships.lua`, `surgery.lua`, `wiring.lua`) and mode/role sub-folders (`attackdefend/{spawnBlue,spawnRed}.lua` built from `attackdefend/classes.lua`, `deathspawns/{deathspawn,deathspawnfriend,deathspawnhusk}.lua`, `events/{deathtrigerevent,deathtrigereventevil,deathtrigereventrandom}.lua`, `hideandseek/{hideBlue,hideRed}.lua`, `traitors/{clown,cultist,saboteur,traitor}.lua`).
- `Lua/config/pointshop/utility/` — complex logic local to pointshop features when moving it out improves structure (`abilities.lua`, `deathspawncreature.lua`, `monsterbeacon.lua`, `randomizer.lua`, plus `Lua/config/pointshop/attackdefend/utility/adv2.lua`).
- `Lua/config/randomevents/` — random event definitions (`abysshelp.lua`, `ammodelivery.lua`, `armorycrate.lua`, `beaconrescue.lua`, `clowncratesurprise.lua`, `emergencyteam.lua`, `guardedcargo.lua`, `maintenancetoolsdelivery.lua`, `malfunctioningbot.lua`, `medicaldelivery.lua`, `prisoner.lua`, `seismictremor.lua`, `shadymission.lua`, `stationattack.lua`, `superballastflora.lua`, `ventcreatures.lua`, `weakballastflora.lua`, `wildcreature.lua`, `wreckrescue.lua`), sub-folders (`abilities/`, `break/`, `pirate/`, `pirate/utility/upcpirate.lua`, `repair/`, `sabotage/{clown,cultist,traitor}/`), and shared event utilities in `Lua/config/randomevents/utility/` (`eventnpc.lua`, `oxygenevent.lua`, `rescueevent.lua`, `securityturretevent.lua`, `skillboostevent.lua`). The event director lives in `Lua/roundevents.lua`, its settings in `RandomEventConfig.Director`.
- `Lua/gamemodes/` — game mode logic (`gamemode.lua`, `attackdefendv2.lua`, `hideandseekv2.lua`, `pvp.lua`, `secret.lua`, `submarineroyale.lua`) and station mode modules in `Lua/gamemodes/station/` (`station.lua`, `cargo.lua`, `cloning.lua`, `communications.lua`, `evacuation.lua`, `idconsole.lua`, `nuclear.lua`).
- `Lua/language/` — localization (`russian.lua` and `Lua/language/russian/{cargo,cloning,communications,core,discord,gamemodes,ghostroles,idconsole,nuclear,pointshop,roles_objectives,station}.lua`).
- `Lua/objectives/` — traitor/crew objectives and completion logic (`objective.lua`, antagonist objectives, and crew objectives in `Lua/objectives/crew/`).
- `Lua/roles/` — role definitions/logic (`role.lua`, `antagonist.lua`, `clown.lua`, `crew.lua`, `cultist.lua`, `huskservant.lua`, `saboteur.lua`, `traitor.lua`).
- `Lua/extensions/` — fixes, patches, auxiliary game-related extensions (`attackdefendreactorblastfix.lua`, `brokenhandcuffs.lua`, `deathswarm.lua`, `paralysisnerf.lua`, `pressuremidjoin.lua`, `servermessageutf8fix.lua`, `spectatorjobfix.lua`, `stationragdollplatforms.lua`, `weaponnerfs.lua`).
- `Lua/features/` — standalone runtime functions of VoidTraitor that are not related to core, gamemodes, roles, objectives, pointshop, or extensions (`adminghost.lua`, `camerateleport.lua`, `deathlogbook.lua`, `discordwebhooks.lua`, `killfeed.lua`, `midroundspawn.lua`, `piratemissionghostroles.lua`, `pointitems.lua`, `respawnshuttle.lua`, `serverlogs.lua`, `skillbuffs.lua`, `welcome.lua`).
- `Lua/data/` — permanent saved data (`data.json`, `discordstate.json`, `roundcounter.json`, `stats.json`).
- `types/` & `definitions/` — type definitions (`Traitormod.lua`, `event.lua`, `gamemodes.lua`, `team.lua`, `definitions/main.lua`).

### 2. Client GUI & Content Pack (`Void traitor pack-1.15/Lua`)
Client-side code is strictly modular. Never dump everything into a single file or duplicate shared UI primitives. `VoidTraitorPackBuilder/Custom` is the source of the pack's own files: add or change them there AND in `Void traitor pack-1.15`, keeping both identical.
- `Lua/Autorun/` — `init.lua` and `__vtpack_bundled_loader.lua` (generated by `VoidTraitorPackBuilder`; must stay synchronized with it when bundled mods change).
- `Lua/client/init.lua` & `Lua/client/common.lua` — client bootstrap (loads every client module) and shared GUI core helpers. Shared UI primitives/layout helpers belong in `common.lua`.
- `Lua/client/` — standalone client screens and effects (`attackdefend_respawn.lua`, `killfeed.lua`, `missions.lua`, `roundsummary.lua`, `submarine_description.lua`, `tremor.lua`, `welcome.lua`).
- `Lua/client/lobby/` — strictly separated lobby & voting layers:
  - Lobby menu: `menu.lua`, `menu_core.lua`, `menu_window.lua`, `menu_widgets.lua`, `menu_controls.lua`, `menu_runtime.lua`, `admin.lua`, `menu_events.lua` (admin event window).
  - Voting UI: `voting.lua`, `voting_menu.lua`, `voting_layout.lua`, `voting_display.lua`, `voting_runtime.lua`.
- `Lua/client/pointshop/` — strictly separated Pointshop client layers:
  - GUI core & widgets: `gui.lua`, `gui_core.lua`, `widgets.lua`, `input.lua`.
  - Data/state/network models: `model_state.lua`, `model_folders.lua`, `model_text.lua`, `model_network.lua`, `network.lua`.
  - Panels: `shop_panel.lua`, `shop_categories.lua`, `shop_filters.lua`, `shop_products.lua`, `cart_panel.lua`, `cart_items.lua`.
- `Lua/client/spectator/` — spectator UI (`camera_teleport.lua`, `ghostroles.lua`) and the admin ghost's client movement (`adminghost.lua`), paired with server `camerateleport.lua`, `ghostroles.lua` and `features/adminghost.lua`.
- `Lua/client/station/` — station console client UI (`cargo.lua`, `communications.lua`, `idconsole.lua`, `nuclear.lua`), paired with `Lua/gamemodes/station/` on the server.
- `Lua/extensions/` — client/pack extensions (`enhanced_husks_optimization.lua`, `headset_stun.lua`, `nt_surgery_access_fix.lua`).
- `Lua/language/` — client localization (`russian.lua`, `welcome_russian.lua`).
- Pack XML content (items, texts) lives in `the void traitor pack/` and is registered in `filelist.xml` (both copies).

## Sources/Git & Token Protection
- **Token-Burn Exclusions (NEVER read, grep, or index unless explicitly requested for the current task):** `Submarines/**` (`*.sub` blobs), `Lua/data/**` (runtime dumps), `.serena/cache/**` (symbol caches). Every search must exclude them.
- **Source Verification & Session Reuse:** inspect the relevant local C#/Lua/XML files BEFORE making claims or edits; vanilla `Content`/`Map` are separate sources and must be searched for vanilla behavior. Within the SAME session, reuse already-verified file excerpts/declarations unless those files were edited or a new question requires checking uninspected lines. One outdated local file does not invalidate the other sources.
- Use GitHub (`gh`, logged in) freely for reading: upstream LuaCs/Barotrauma code, commits, issues and docs, and VoidTraitor refs, PRs and CI. GitHub writes (push, PR, comments) follow the branch rules below and need the user's consent.
- Repository: `https://github.com/sashagavrilyuk/barotrauma-voidtraitor`. `Ai-temp` = ALL development; `Ai` = ONLY accepted stable releases. NEVER push development directly to `Ai`. Local sources for analysis; GitHub HEAD/files govern writes. Fetch current `Ai-temp` target files/HEAD before edits; if changed, re-fetch/reapply. Never overwrite newer work or create branches without permission.

## Workflow
- Before code: for a touched git checkout run `git status --short --branch` and `git fetch`/targeted `git ls-remote` (skip for questions and read-only work); inspect uncommitted work, local source, working patterns, evidence/API gates and current `Ai-temp` files/HEAD; define the smallest fix and regression cases. Task edits go in a git worktree `wt\<task>`, not in the main checkout. Keep unrelated local modifications; never reset, stash, clean, switch branches, discard work or modify the user's installed game outside the approved task to make a patch convenient.
- Sources: prefer the local clones; use GitHub for anything missing locally. Record the source commit used and whether it matches the deployed build. Unverified memory is not evidence; never invent an installation path, checkout state, game version or available executable.
- After code: Lua syntax with MoonSharpCheck (the game's MoonSharp) on every changed `.lua`, XML parsing, builder/package sync and asset/build outputs. `git diff --check`, `git diff`, `git diff --cached` over every changed path: no unrelated edits, dead patches or unchecked large changes. Check exact APIs, interactions, modes, permissions, cross-mode/network effects and real client/server logs. In-game testing only after the required research approval; a tool's presence, CI or a mock never replaces it, and unrun game tests are never marked passed. If access, source, privileges or executables are missing, state exactly what is missing.
- Large tasks: implement one part, VERIFY, commit, THEN continue; avoid huge uncommitted changes/excess planning. Before any authorized push recheck remote HEAD, re-fetch/reapply if changed and preserve concurrent changes; verify remote commits/diffs and CI afterwards.
- Commit author: `kotofey51 <38777263+sashagavrilyuk@users.noreply.github.com>`, never the user's real email.
- Release only on explicit user request, through the `voidtraitor-release` skill.
- When context or limits require a checkpoint, keep **one concise current status**: task scope, current commit/branch, changed files, verified tests, outstanding defects, and next action.
