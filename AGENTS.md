# VoidTraitor — Codex AGENTS.md

The user-approved rules below are authoritative. They are copied from the supplied final prompt, with only instructions about source ZIP inspection adapted for a locally accessible source tree. The existing detailed AGENTS.md rules are retained afterward; they may add checks but must not weaken or override the authoritative rules.

## User-approved rules

Maintain LuaCsForBarotrauma mods, primarily VoidTraitor. Correct, minimal, readable code outranks speed.

## Core
- Never invent APIs, causes, facts, tests, commits or game success. Declare impossibility/unsuitability ONLY with cited source proof; distinguish facts from hypotheses.
- Preserve exact requested scope/behavior: no extra features, reinterpretations or unrelated edits/explanations.
- Resolve ambiguity from code/logs/source BEFORE coding. State assumptions, uncertainty, interpretations, trade-offs; never treat assumptions as engine facts. Ask only about unresolved material decisions.
- For EVERY engine-dependent claim/change, inspect relevant C#/Lua/XML source FIRST; cite exact file path, symbol, line/code excerpt for decisive claims, limitations and mode behavior. Record source version; flag unknown deployed version. If absent after searching locally available source trees and relevant upstream sources, identify missing evidence; never guess, declare impossibility or patch from memory.
- Analyze FULL relevant subsystem, dependencies, paths and affected modes before edits; skip unrelated code. Compare working equivalents/other modes END TO END before rejecting a method.

## Simplicity
Write the smallest clear solution. NO speculative features/flexibility, needless abstractions/wrappers or unjustified one-use helpers, impossible-case guards, redundant checks or symptom-masking “protection”. Search existing working patterns first. Share logic ONLY if semantics match and it truly simplifies; never merge superficially similar behavior.

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
- Mode/PvP/spawn/sub/level claims: inspect relevant BarotraumaShared C# (SubmarineInfo, GameMode, LevelGenerationParams), vanilla Content/Map XML AND working modes before technical conclusions.
- “Checked” without cited source evidence is invalid. Separately mark SOURCE VERIFIED / STATICALLY CHECKED / GAME TESTED / USER CONFIRMED / NOT TESTED. Syntax/CI/mocks ≠ game/crash safety. Never release unaccepted or unverified crash-prone changes to Ai.

## Structure
Keep code, localization, roles, objectives, settings, assets and persistence with actual owners. Mode rules belong to their own game mode only.

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

## Sources
- `LuaCsForBarotrauma` — LuaCs/C# source, engine API.
- `traitormod-voidtraitor-ai` — main Lua mod.
- `Void traitor pack` — XML/Lua, items, afflictions, assets, submarines/client.
- `VoidTraitorPackBuilder` — builder.
- `Content`, `Map` — vanilla XML/maps; locate the available vanilla source/content trees locally.

## Sources/Git
For EACH source-dependent question, search the actual local workspace/source tree again, not only once/session. Locate the first FOUR source sets above; inspect `Content` and `Map` separately for vanilla behavior. Use filesystem searches, not remembered paths. Never bulk-search GitHub; check actual current Ai-temp/Ai files, refs and HEAD before writes. If a required local source is absent, identify it and obtain an authoritative source before claiming verified behavior.
Repository: `https://github.com/sashagavrilyuk/barotrauma-voidtraitor`
`Ai-temp` = ALL development; `Ai` = ONLY accepted stable releases. NEVER push development directly to Ai. Local source files for analysis; current remote GitHub HEAD/files govern writes. Fetch current `Ai-temp` target files/HEAD before edits; if changed, re-fetch/reapply. Never overwrite newer work or create branches without permission.

## Workflow
Before code: inspect local source files, working patterns, evidence/API gates, `Ai-temp` files/HEAD; define smallest fix and regression cases.
After code: check Lua/XML syntax, exact APIs, interactions, modes, permissions and regressions; FULL diff: no unrelated edits/dead patches/unchecked large changes. Recheck HEAD before push, re-fetch/reapply if changed. Large tasks: implement one part, VERIFY, commit/push, THEN continue; avoid huge uncommitted changes/excess planning. Verify remote commits/diffs.
Release: inspect BOTH HEADs, merge-base, tree/file diff, reverts/restores/cherry-picks, independent Ai commits (counts are insufficient). Select ONLY user-accepted/tested changes + dependencies; if unsafe to isolate, STOP. Review against current Ai + assets/builder. NEVER mass-merge Ai-temp. Release one/several coherent commits to current Ai through required protection/PR, no force-push/reset/history rewrite. Recheck HEAD before writing; preserve independent changes. Verify CI, remote commits/diff; reconcile release to Ai-temp safely. ZIP ONLY changed production files with original paths; no temp tests/backups. On upload failure send ZIP, NEVER split files.
Barotrauma itself may contain engine bugs; verify its source before masking faults in VoidTraitor.

## Codex local workspace and tools (additional rules)

- Start by inspecting the real workspace and repository state using locally available tools: `pwd`, `git rev-parse --show-toplevel`, `git status --short --branch`, `git branch --show-current`, and targeted `rg --files` / `rg -n` searches. On Windows use the equivalent supported shell commands. Never invent an installation path, checkout state, game version, or available executable.
- Read the full relevant files and their callers, dependencies, C#/Lua/XML declarations, prefab assets, client/server paths and working mode equivalents directly from accessible local source directories. Repeat searches for each question; do not treat earlier snippets or remembered APIs as current evidence. Use targeted upstream retrieval only if required source is genuinely absent locally; record the exact source commit/version and unresolved deployed-version mismatch.
- For each decisive engine-dependent conclusion, include repository-relative or locally verified file path, symbol, line reference or actual code excerpt. Cite working counterparts and `BarotraumaShared`/vanilla Content/Map declarations for mode/submarine claims. Missing evidence prevents an implementation claim; it does not authorize guesses or an unfounded impossibility statement.
- If local tools permit, run relevant Lua syntax checks, XML parsing, builder/package synchronization checks, targeted scripts/tests, and inspect real client/server logs. If the game or dedicated server executable is installed and executing it is permitted, use it for focused in-game testing after the required research approval. A tool's presence, passing CI, or local mock is not a substitute for actually exercising gameplay.
- Before changing tracked files, inspect uncommitted work and compare current local and remote refs (`git fetch`/targeted `git ls-remote` where available). Keep unrelated local modifications untouched. Do not reset, stash, clean, switch branches, discard work, or modify the user's installed game outside the approved task just to make a patch convenient.
- After edits, use `git diff --check`, `git diff`, `git diff --cached`, and precise checks suited to the modified files. Review all changed paths and lines, compare asset/build outputs, check cross-mode/network effects, and never mark unrun game tests as passed. Verify remote HEAD again before any authorized push; preserve remote and local concurrent changes.
- Use Codex's actual local file editing and command execution capability when available; no requirement to work through source ZIPs. For GitHub releases, follow the branch/PR constraints above. If local access, source, privileges, or test executables are unavailable, state exactly what is missing instead of claiming local verification.

## Existing detailed Codex rules — retained

# VoidTraitor development rules

Your task is to maintain LuaCsForBarotrauma mods, primarily VoidTraitor. Correct behavior, compatibility, and maintainable code take priority over speed or the amount of code produced.

## 1. Scope and decisions

- Work on **one user-approved task at a time**. Do not start the next feature, expand the scope, or make adjacent improvements without being asked.
- Follow the user's stated behavior and constraints. Do not replace them with an easier interpretation. If a decision materially changes the design and cannot be resolved from the project or source, ask before implementing it.
- Be precise about uncertainty. Never claim an API, fix, test, commit, or game behavior is verified when it is not.
- Before modifying code, thoroughly analyze the **entire relevant VoidTraitor subsystem**, its full interaction path, shared dependencies, and affected modes. Understand the surrounding project structure, but do not repeatedly inspect unrelated files just to satisfy a checklist.
- Resolve unclear behavior from current code, prior working implementations, logs, LuaCsForBarotrauma, and Barotrauma source before asking the user or guessing.

## 2. Existing code is the first reference

- **Search for an existing working mechanism before designing a new one.** Trace how it opens, receives events, authorizes actions, updates state, and closes or cleans up. Reuse existing functions and conventions when their semantics match.
- If one implementation works and a similar one fails, **compare both end to end before changing anything**. For example, compare cargo-console interaction with the working ID console, and use existing Pointshop or GhostRole GUI mechanisms where applicable.
- Understand *why* the working implementation works. Do not copy just its appearance or one callback while retaining a different, faulty lifecycle.
- **Do not rule out an approach without evidence.** Compare relevant working mechanics across affected modes, vanilla Barotrauma and LuaCs/engine source end to end before declaring a method impossible or unsuitable. Distinguish verified limitations from assumptions; if not established, report it as unknown and investigate rather than rejecting the approach.
- Do not add a second event handler, UI manager, state machine, polling loop, or helper if the current system can correctly handle the feature.
- Common code belongs in existing shared modules only when genuinely shared. Do not merge superficially similar but behaviorally different features.

## 3. Mandatory root-cause analysis — fix causes, not symptoms

**Do not start editing merely because suspicious code has been found.** An appealing explanation, valid API name, plausible state transition, or passing static check does not establish a root cause.

For every bug, before implementing a fix:
1. **Define the failure.** Establish expected behavior, observed behavior, reproduction steps and triggering state from the user's report, logs or a test. Do not substitute a simpler scenario.
2. **Trace the complete relevant path.** Identify callers and handlers, lifecycle, event order, authoritative state, ownership, cleanup, and client → network → server → Barotrauma engine interactions as applicable. Trace Lua, XML and C# together when they interact. Do not stop at the first suspicious function.
3. **Compare alternatives.** Find an existing working equivalent where possible and compare the full path. Identify at least the materially plausible competing causes, then check which are supported or contradicted by code, source, logs or observed behavior. Do not invent extra hypotheses solely to fill a checklist.
4. **Verify engine assumptions.** Inspect relevant LuaCsForBarotrauma/Barotrauma source for unknown hooks, API semantics, inventory/physics behavior, selection, UI lifecycle, networking and authority. Decide whether the fault lies in VoidTraitor, the pack/XML, LuaCs, vanilla engine, or their interaction.
5. **State the conclusion.** Separate confirmed findings from assumptions and untested hypotheses. Identify the root cause and its evidence. If multiple causes remain possible, use targeted diagnostics or explicitly state the uncertainty; do not label a speculative fix as proven.
6. **Plan a minimal correction.** Explain why the change addresses the cause rather than the symptom, what other paths it affects, and which original and regression scenarios must pass.

Before editing, give a **brief evidence-based diagnosis**, not a long plan: observed failure → execution path → confirmed facts → alternatives checked → root cause or uncertainty → minimal change → verification. Keep this proportionate to the task.

- Do not introduce arbitrary delays, retries, periodic refreshes, cached selections, extra state flags, global hooks, or redundant guards merely to suppress a symptom. Such mechanisms are allowed only when justified by verified lifecycle/network behavior.
- Do not weaken server-side permission, interaction, distance, inventory, or role checks to make a GUI appear reliable. Separate display/read access from actions only if the game design and engine permit it safely.
- If a root cause cannot be established, collect focused logs/traces or propose an explicitly labeled diagnostic experiment; avoid accumulating unverified production patches.
- **When a fix fails in the actual game, the preceding diagnosis must be reconsidered.** Confirm the changed code loaded and executed; compare predicted vs. observed behavior; discard unsupported premises, investigate remaining causes, and obtain new evidence **before writing another fix**. Do not keep patching the same spot or stacking workarounds.
- Barotrauma itself may be responsible. Investigate the relevant game/LuaCs source before hiding an engine fault behind VoidTraitor-specific logic.

### Two-phase research/implementation gate for high-risk bugs

For crash-prone, GUI, multiplayer/network, physics, round-lifecycle, new LuaCs API, or repeatedly failing bugs, use **two separate phases**. The first response is **research-only**: inspect current code and engine source, reproduce or precisely describe the original failure, trace callers/state/client/server, test competing explanations and provide concrete evidence, unresolved questions, the minimal proposed fix, and regression cases. **Do not edit, commit, or release during this research phase.**

Implementation starts **only after the user's subsequent explicit approval** of the research result. Re-check current `Ai-temp` files and HEAD before editing. If the cause remains uncertain, request focused diagnostic data or propose a diagnostic experiment, not a speculative production fix. A general request to "fix this bug" does not waive this checkpoint. The user may explicitly request a combined pass; even then finish the evidence-based diagnosis before writing. Small low-risk changes retain the proportionate one-pass workflow.

### Mandatory crash-prevention compatibility gate

Before implementing or releasing any change that touches Barotrauma/LuaCs APIs, XML-defined objects, UI, physics or network behavior:

1. **Check the exact installed source contract, not an analogous example.** Locate relevant Barotrauma/LuaCs C# declarations and LuaCs exposure for each new or changed engine call, property, constructor, hook or event. Verify method overloads, parameter and return types, enum values, static/instance access, visibility from Lua and client/server availability. A matching name is not proof of a compatible call.
2. **Trace boundary values and object lifetimes.** Verify which actual Lua/C# object reaches the call, Lua-to-C# type conversion, possible nil/null and disposed/removed objects, ownership and when it is valid. Examine callers and subsequent engine consumers, not only the line that creates the object. Avoid adding speculative guards; correct invalid construction or lifecycle at its source.
3. **Audit GUI crash paths through rendering.** When creating/changing a GUI element, trace the widget hierarchy and relevant text/layout/size inputs through initialization, update, `Draw` and removal. Verify APIs and object state against actual GUI source and a working mod example. A successful constructor or visible first frame does not prove later draws or callbacks are safe.
4. **Check cross-file and multiplayer contracts.** Match referenced XML identifiers, prefab/components, afflictions and asset paths to real content. Check client Lua vs server Lua execution, networking and event serialization, native clients without LuaCs where relevant, and compatibility with the actual game and LuaCs versions. Do not assume local or archived sources match deployed versions.
5. **Use a verification gate.** Run syntax/static/API checks first. When runtime is available, smoke-test the specific crash path in a real game client/server, including GUI open → render → interact → close → reopen, repeated use and relevant round/reconnect transitions. Inspect client and server logs for errors; a test that never reaches the changed path proves nothing.
6. **Do not invent a safety guarantee.** If a required signature, contract or crash-prone path cannot be validated, state exactly what is missing and do not claim it is compatible, crash-free or game-tested. Keep such changes out of the stable `Ai` release pending the necessary evidence. Target checks to the changed behavior and its reachable dependencies, not unrelated code.

## 4. Minimal and localized implementation

- Change only what the task requires. Every modified line must have a direct reason.
- Keep code small, readable, and consistent with existing style. No speculative features, decorative abstractions, unnecessary wrappers, one-use helpers without a real benefit, or impossible-case error handling.
- Do not refactor, rename, reformat, rewrite comments, or clean up unrelated code. Mention unrelated defects without modifying them.
- Do not duplicate existing logic or add redundant defensive conditions that hide incorrect state transitions.
- Remove code only when the requested changes make it obsolete; preserve unrelated behavior, persistent data, and backward compatibility.
- **Compatibility requires a real contract.** Preserve documented or deployed supported behavior, modes, settings, persistent data, network contracts and server authorization. The requirement to support clients **with and without client LuaCs** is not a requirement to support obsolete VoidTraitor client builds or historical network protocols. Do not invent versioned messages, parallel legacy handlers, fallback branches, migration code or compatibility flags for hypothetical old clients. Before adding such paths, identify actual affected deployments/consumers and prove the need from source or evidence; obtain user approval if scope changes. Do not remove a verified supported legacy path without approval either.
- Prefer server-side Lua for small features and fixes. Add XML/client-side content only when required for correct behavior or substantially better performance.
- Do not hardcode player-facing text where the project's localization system applies.

## 5. Architecture and game modes

Keep implementation in the correct location:

- `Lua/` — important/shared core logic.
- `config/` — settings, categories, events, and logic local to them.
- `gamemodes/` — game-mode rules.
- `language/` — localization.
- `objectives/` — traitor/crew objectives and completion logic.
- `roles/` — role definitions/logic.
- `extensions/` — fixes, patches, auxiliary game-related extensions.
- `features/` — standalone runtime features not belonging to core, game modes, roles, objectives, Pointshop, or extensions.
- `config/ghostrole/` — ghost-role descriptions and configuration: categories, parameters, names, descriptions, prices, icons, selection actions.
- `config/pointshop/utility/` — complex Pointshop-local logic only when moving it out improves structure.
- `data/` — permanent saved data.

- **Every game mode is an independent ruleset**, not a collection of exceptions scattered through another mode. Keep mode-specific spawning, lifecycle, win conditions and round behavior in its own `gamemodes/` implementation. Reuse only genuinely common mechanics; do not spread mode-name checks across unrelated/shared modules.
- Roles, objectives, shop logic, and shared features should own their behavior. Introduce mode-specific conditions only where behavior actually differs, in the narrowest appropriate owner.
- Preserve existing mode-selection, generated-level, antagonist, role, objective and shop behavior unless the task explicitly changes it. Check every affected game mode for regressions, including those not directly modified.
- Do not add special editing conveniences to categories, events, Pointshop, or roundevents unless they will genuinely be reused.

## 6. Client UI and multiplayer behavior

- For a terminal or GUI task, inspect the **entire interaction lifecycle**: first click, character movement toward the item, engine selection, opening, server response, repeated use, closing, leaving range, invalidation, and reopening.
- A visible window is not proof of correct functionality. Check buttons, item insertion **and removal**, state updates, authorization, and synchronization using real game objects.
- Do not arbitrarily close a window because of a transient engine selection change if interaction should remain active. Equally, do not keep a window or authorize actions after genuine loss of interaction rights. Verify the intended lifecycle from source and an existing working implementation.
- Reuse established VoidTraitor UI primitives and layouts. Account for resolution and HUD scale; avoid fixed dimensions that clip controls. Use existing drag/resize behavior when asked for it, not a partial imitation.
- Where a feature must support players without client LuaCs, verify native Barotrauma interaction separately from enhanced Lua UI. Server-side authorization applies to **both** paths.
- A Lua parser, language server, mocked unit test, or screenshot cannot by itself prove that live GUI and multiplayer interactions work.

## 7. Sources and workspace availability

- Use the accessible local workspace, checked-out repository, and relevant LuaCsForBarotrauma/Barotrauma C# source. Verify actual availability of local game installations, client/server binaries, logs, and source paths before relying on them or claiming a test was run.
- Search source files in the checked-out local workspace, including separate local repositories or installed vanilla game content when accessible. Never assume a directory exists without checking it.

The local workspace is for direct source inspection and testing; it may be behind the remote. `Ai-temp` is authoritative for ongoing development; `Ai` is the stable/final branch. Never overwrite newer repository work with a local copy. Do not repeatedly query GitHub for material already current locally.

## 8. Work and verification procedure

**Before coding**
1. Inspect relevant project structure, full event/data path, owners of behavior, and dependencies.
2. Find and compare existing working implementations; identify the precise difference that matters.
3. Complete the root-cause analysis from §3. Check uncertain APIs/engine behavior against LuaCsForBarotrauma/Barotrauma and vanilla content.
4. Fetch/compare current target files and HEAD in `Ai-temp`; implement against those versions.
5. Choose the smallest evidence-supported change and establish original-failure and regression test cases.

**After coding**
1. Check Lua/XML syntax and API compatibility; examine complete diff for unrelated changes, unnecessary code, and stale diagnostic workarounds.
2. Check original failure, normal use, repeated interactions, permissions, state transitions, and affected modes. Run actual game/server/client when available and relevant.
3. For client-dependent features, distinguish tests with client LuaCs from tests without it. Check multiplayer/network transitions when they matter.
4. Record what was **source-verified**, **statically checked**, **runtime-tested**, **user-confirmed**, or **NOT TESTED**. Do not conflate these. Source inspection and unit/mock tests cannot prove in-game behavior.
5. If the actual reported bug persists, reopen diagnosis under §3 rather than layering another guessed patch.
6. Verify latest `Ai-temp` state before pushing and confirm resulting GitHub commit/diff after pushing.

Do not declare a task "fixed in-game" solely because code was written, syntax passes, a mock test passes, or GUI opens once. State tests actually performed, remaining uncertainty, and known limitations. Where user acceptance in the game is required, do not promote the unaccepted change as a verified release or start an unrelated task.

## 9. Git, release, and deliverables

Repository: `https://github.com/sashagavrilyuk/barotrauma-voidtraitor`

- **`Ai-temp`** is development/staging. Implement normal changes here first. Prefer small, coherent commits with truthful verification notes; do not mix unrelated features.
- **`Ai`** is stable. Only complete, reviewed, verified and user-accepted changes may be released. Use one **or several meaningful commits** depending on feature boundaries. A single squash commit is **not** mandatory.
- A release is a selected, self-contained set of accepted changes with all required dependencies, **not automatically the entire difference between `Ai-temp` and `Ai`**. Never merge unfinished development into `Ai` merely to release one feature.
- Before any release or history reconciliation, re-check both HEADs, merge-base, actual file/tree differences, relevant commits and earlier reverts/restores/cherry-picks. Ahead/behind numbers alone do not prove missing functionality or identify safe changes. Check `Ai`-only work and preserve it.
- Prepare the smallest complete release diff against **current `Ai`**. Review source/API contracts, pack-builder synchronization, compatibility and all affected modes; run available CI and real multiplayer tests when applicable. A green static check does **not** substitute for game testing or user acceptance.
- Apply only selected changes using reviewed commits/patches or an appropriate PR. Preserve unrelated `Ai` changes. If dependencies or conflicts cannot be resolved safely, **do not release**; report the blocker instead of doing a broad merge.
- After a stable release, reconcile the accepted stable changes into `Ai-temp` without losing ongoing development. If histories diverged, identify the reason first; a history-only merge is acceptable only after verifying that its omitted changes are intentionally preserved or superseded, and that no gameplay/content is accidentally altered.
- Never rewrite shared history via reset/rebase/force-push, bypass protection, silently discard independent changes, or create branches without user approval. If a HEAD changes, re-evaluate the diff and apply on top of the new state.
- Keep release commits narrowly scoped and traceable. Record the stable commit SHA and, where appropriate, a release tag. Do not commit temporary tests, diagnostic artifacts, backups or checkpoint files as production code.
- Deliver an actual ZIP with **only modified production files**, retaining exact repository-relative paths; verify it matches the submitted code. If GitHub upload fails, supply the ZIP instead of splitting files or claiming the upload succeeded.

## 10. Continuity

- When context or limits require a checkpoint, keep **one concise current status**: task scope, current commit/branch, changed files, verified tests, outstanding defects, and next action.
- Treat older plans and logs as historical evidence, not competing live instructions. Reconcile them with current code, `AGENTS.md`, and the user's latest request before continuing.
- Avoid repeatedly producing long plans, skill workflows, or status documents when direct code inspection and a small verified change are sufficient.
