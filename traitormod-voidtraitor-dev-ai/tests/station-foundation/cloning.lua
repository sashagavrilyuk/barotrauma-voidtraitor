local hooks, patches, spawned, removed, chat = {}, {}, {}, {}, {}
Hook = { Add = function(_, id, fn) hooks[id] = fn end, Patch = function(id, _, _, fn) patches[id] = fn end, HookMethodType = { Before = 1 } }
LuaUserData = { RegisterType = function() end, CreateStatic = function() return { __new = function(_, xml) return xml end } end }
local prompt
require = function() return { Prompt = function(_, _, client, fn) prompt = { Client = client, Answer = fn } end } end
local function iterable(values)
    return function(_, previous) for index, value in ipairs(values) do if previous == nil or values[index - 1] == previous then return value end end end
end
local function vector(x, y)
    return setmetatable({ X = x, Y = y }, { __add = function(a, b) return vector(a.X + b.X, a.Y + b.Y) end })
end
Vector2, UShort = vector, function(value) return value end
local power = { HasPower = true }
local body = { IsDead = true, IsHuman = true, Mass = 80, TeamID = 1, SpeciesName = { Value = 'human' }, Info = { Save = function() return { Name = 'Original', Job = 'engineer' } end } }
local material = { GetComponentString = function() return { Character = body } end }
local scanner = { Prefab = { Identifier = 'vt_cloning_scanner' }, OwnInventory = { GetItemAt = function() return material end } }
local biomass = {}
local pod = { Prefab = { Identifier = 'vt_cloning_pod' }, Rect = { Width = 100 }, Condition = 100, WorldPosition = vector(0, 0), OwnInventory = { AllItems = iterable(biomass) } }
local light, controller = { IsOn = false }, {}
controller.Select = function(clone) controller.User = clone return true end
pod.GetComponentString = function(name) return ({ Powered = power, Controller = controller, LightComponent = light })[name] end
local terminal = { SyncCount = 0 }
terminal.SyncHistory = function() terminal.SyncCount = terminal.SyncCount + 1 end
local connections = {
    { Name = 'scanner', Recipients = iterable({ { Item = scanner } }) },
    { Name = 'pod', Recipients = iterable({ { Item = pod } }) },
}
local console = { Prefab = { Identifier = 'vt_cloning_console' }, Connections = iterable(connections) }
console.GetComponentString = function(name) return name == 'Powered' and power or terminal end
console.CanClientAccess = function() return true end
local operator = { Account = 'doctor', Character = { SelectedItem = console, Inventory = {} } }
local owner = { Account = 'patient', Character = body }
owner.SetClientCharacter = function(clone) owner.Character = clone end
Client = { ClientList = { operator, owner } }
Item = { ItemList = iterable({ scanner, pod, console }) }
Game, ActionType, CauseOfDeathType = { RoundStarted = true }, { OnDeconstructed = 1 }, { Unknown = 1 }
CharacterInfo = function(xml) return { Name = xml.Name, Job = xml.Job } end
Character = { Create = function(species, _, _, info, _, remote, hasAi, _, _, _, initialItems)
    assert(not remote and hasAi, 'ownerless body must use native AICharacter physics')
    assert(initialItems == false, 'cloning duplicated starting equipment')
    local clone = { Species = species, IsHuman = species == 'human', Info = info, Enabled = false, Unkillable = false, CharacterHealth = { Stun = 0 }, AIController = { Enabled = true } }
    clone.LoadTalents = function() clone.TalentsLoaded = true end
    clone.TeleportTo = function(position) clone.Position = position end
    clone.Kill = function() clone.IsDead = true end
    spawned[#spawned + 1] = clone
    return clone
end }
ItemPrefab = { GetItemPrefab = function(id) return id end }
Entity = { Spawner = { AddEntityToRemoveQueue = function(item) removed[#removed + 1] = item end,
    AddItemToSpawnQueue = function(prefab, inventory) spawned[#spawned + 1] = { Prefab = prefab, Inventory = inventory } end } }
local role = { Character = body, Objectives = { { Character = body, Progress = 77 } }, Greet = function() return 'same role' end, IsAntagonist = true }
local roles = { [body] = role }
Traitormod = { Config = { Cloning = { Time = 30, HumanBiomassCost = 50, HumanBiomassYield = 28 } }, GhostRoles = { ExcludedCharacters = {} }, Pointshop = { GuiClients = { [owner] = true } },
    IsRoundFinalizing = function() return false end, GetText = function(key) return key end,
    FormatText = function(key, value) return key .. ' ' .. value end,
    GetClientAccountKey = function(client) return client.Account end,
    FindClientCharacter = function(char) return char == owner.Character and owner or nil end,
    SendChatMessage = function(client, text) chat[#chat + 1] = { Client = client, Text = text } end,
    RoleManager = { GetRole = function(char) return roles[char] end, RemoveRole = function(char) roles[char] = nil end,
    AssignRole = function(char, value) value.Character = char roles[char] = value end, TransferRole = function(char, value)
        roles[value.Character], value.Character = nil, char roles[char] = value
        for _, obj in ipairs(value.Objectives) do obj.Character = char end
    end }, ObjectiveHud = { SyncRole = function() end },
    UpdateVanillaTraitor = function(client, enabled) client.Character.IsTraitor = enabled end,
    MidRoundSpawn = { SetSpawnedClient = function(client, char) client.SpawnedBody = char end },
}
local cloning = dofile(modpath .. '/Lua/features/cloning.lua')
assert(not cloning.Begin(operator, console), 'cloner active outside Station lifecycle')
cloning.Start()
local frozenLimb = { body = { PhysEnabled = true } }
local scannedBody = { IsDead = true, AnimController = { Frozen = false, Limbs = iterable({ frozenLimb }) } }
local scanControl = { User = scannedBody }
scanControl.Select = function(user)
    assert(user == scanControl.User)
    scanControl.User = nil
end
scanner.GetComponentString = function() return scanControl end
cloning.Update(0.75)
assert(not scannedBody.AnimController.Frozen and frozenLimb.body.PhysEnabled,
    'scanner overrode the native controller with unsynchronized ragdoll freezing')
local living = { IsDead = false, SelectedCharacter = { IsDead = false } }
living.DeselectCharacter = function() living.SelectedCharacter = nil end
scanControl.User = living
cloning.Update(0)
assert(scanControl.User == nil, 'living character remained inside cloning scanner')
hooks['Traitormod.Cloning.Owner'](body)
assert(cloning.Status(console) == 'CloneNoBiomass' and not cloning.Begin(operator, console))
for _ = 1, 49 do biomass[#biomass + 1] = { Prefab = { Identifier = 'vt_biomass' } } end
cloning.Update(0)
assert(cloning.Status(console) == 'CloneNoBiomass', 'human cloning allowed below 50 biomass')
for _ = 1, 111 do biomass[#biomass + 1] = { Prefab = { Identifier = 'vt_biomass' } } end
cloning.Update(0)
assert(#removed == 160 and cloning.Status(console) == 'CloneReady')
cloning.Update(0)
assert(#removed == 160, 'queued biomass consumed twice')
operator.Character.SelectedItem = nil
assert(not cloning.Begin(operator, console))
operator.Character.SelectedItem = console
assert(cloning.Begin(operator, console) and not cloning.Begin(operator, console), 'duplicate clone from active scanner')
local clone = spawned[1]
assert(clone ~= body and clone.Info.Name == 'Original' and clone.TalentsLoaded and clone.TeamID == 1 and light.IsOn)
assert(not clone.AIController.Enabled and prompt.Client == owner)
assert(clone.Enabled and clone.Unkillable and clone.CharacterHealth.Stun > 0 and clone.SelectedItem == pod)
assert(Traitormod.GhostRoles.ExcludedCharacters[clone], 'growing clone exposed as a ghost role')
cloning.Update(15)
local status, percent = cloning.Status(console)
assert(status == 'CloneGrowing' and percent == 50)
local syncs = terminal.SyncCount
cloning.Update(0)
assert(terminal.SyncCount == syncs, 'unchanged status resent')
power.HasPower = false
cloning.Update(100)
assert(select(2, cloning.Status(console)) == 0, 'unpowered terminal should show no power')
power.HasPower = true
assert(select(2, cloning.Status(console)) == 50, 'growth continued without power')
-- Moving the original corpse after the DNA scan must not cancel growth.
material = nil
prompt.Answer(1, owner)
assert(owner.Character == clone and roles[clone] == role and role.Objectives[1].Progress == 77 and clone.IsTraitor)
cloning.Update(15)
assert(not clone.Unkillable and clone.CharacterHealth.Stun == 0 and clone.SelectedItem == nil and not light.IsOn)
-- Rejection still produces an uncontrolled living organism of the original species.
body = { IsDead = true, Mass = 80, TeamID = 1, SpeciesName = { Value = 'mudraptor' } }
owner.Character = body
material = { GetComponentString = function() return { Character = body } end }
hooks['Traitormod.Cloning.Owner'](body)
Traitormod.Pointshop.GuiClients[owner] = nil
assert(cloning.Begin(operator, console) and chat[#chat].Text == 'CloneConsentChat')
local creature = spawned[2]
assert(creature.Species == 'mudraptor' and not creature.AIController.Enabled)
assert(cloning.Answer(owner, false) and not cloning.Answer(owner, true))
cloning.Update(30)
assert(owner.Character == body and creature.Enabled and not creature.Unkillable and not creature.IsDead)
-- Disconnect ownership survives delayed death; broken pods abort and release consent.
body = { IsDead = true, Mass = 1, TeamID = 1, SpeciesName = { Value = 'human' } }
owner.Character = body
hooks['Traitormod.Cloning.Disconnect'](owner)
owner.Character = nil
material = { GetComponentString = function() return { Character = body } end }
for _ = 1, 3 do biomass[#biomass + 1] = { Prefab = { Identifier = 'vt_biomass' } } end
cloning.Update(0)
assert(cloning.Begin(operator, console))
local cancelled = spawned[3]
pod.Condition = 0
cloning.Update(0)
assert(cancelled.IsDead and not cancelled.Unkillable and not cloning.Answer(owner, true))
assert(not cloning.Begin(operator, console), 'broken pod started a new cycle')
pod.Condition = 100
-- SS14 consent is valid only while the body is growing.
assert(cloning.Begin(operator, console))
cloning.Update(30)
assert(not cloning.Answer(owner, true), 'released body retained stale consent')
assert(cloning.Begin(operator, console))
local doctor = operator.Character
operator.Character = spawned[5]
assert(not cloning.Answer(owner, true) and owner.Character == nil, 'controlled body was stolen')
operator.Character = doctor
cloning.Update(30)
-- Wire removal blocks new cycles; native input accepts only the one clone boolean.
connections[1].Recipients = iterable({})
assert(cloning.Status(console) == 'CloneDisconnected' and not cloning.Begin(operator, console))
local params = { c = operator, msg = { ReadBoolean = function() return true end } }
patches['Traitormod.Cloning.Terminal']({ Item = console }, params)
assert(params.PreventExecution)
local ejected = false
local held = { IsDead = true }
local scannerController = { User = held }
scannerController.Select = function() ejected, scannerController.User = true, nil end
scanner.GetComponentString = function() return scannerController end
scanner.CanClientAccess = function() return true end
operator.Character.DeselectCharacter = function() operator.Character.SelectedCharacter = nil end
operator.Character.SelectedItem = scanner
local eject = { c = operator, msg = { ReadBoolean = function() return true end } }
patches['Traitormod.Cloning.Terminal']({ Item = scanner }, eject)
assert(eject.PreventExecution and ejected, 'scanner eject button did not release corpse')
operator.Character.SelectedItem = console
local output = {}
local deconstructor = { Item = { Prefab = { Identifier = 'vt_biomass_reclaimer' } }, OutputContainer = { Inventory = output } }
local victim = { Mass = 250, IsDead = true, IsHuman = false }
local wrapped = { GetComponentString = function() return { Character = victim } end }
local count = #spawned
patches['Traitormod.Cloning.Biomass']({ Item = { Prefab = { Identifier = 'deconstructor' } }, OutputContainer = { Inventory = output } },
    { type = ActionType.OnDeconstructed, targetItem = wrapped })
assert(#spawned == count, 'ordinary deconstructor produced station biomass')
patches['Traitormod.Cloning.Biomass'](deconstructor, { type = ActionType.OnDeconstructed, targetItem = wrapped })
assert(#spawned - count == 58 and spawned[#spawned].Inventory == output, 'biomass not proportional to native corpse mass/output')
patches['Traitormod.Cloning.Biomass'](deconstructor, { type = ActionType.OnDeconstructed, targetItem = wrapped })
assert(#spawned - count == 58, 'duplicate reclamation')
victim.IsDead = false
victim = { Mass = 250 }
patches['Traitormod.Cloning.Biomass'](deconstructor, { type = ActionType.OnDeconstructed, targetItem = wrapped })
assert(#spawned - count == 58, 'living body produced corpse biomass')
victim = { Mass = 80, IsDead = true, IsHuman = true }
patches['Traitormod.Cloning.Biomass'](deconstructor, { type = ActionType.OnDeconstructed, targetItem = wrapped })
assert(#spawned - count == 86, 'human corpse must yield 28 biomass')
local dragged = { IsDead = false }
local activator = { SelectedCharacter = dragged }
activator.DeselectCharacter = function() activator.SelectedCharacter = nil end
local scannerController = { Item = { Prefab = { Identifier = 'vt_cloning_scanner' } }, User = nil }
local selectArgs = { activator = activator }
patches['Traitormod.Cloning.DeadOnly'](scannerController, selectArgs)
assert(selectArgs.PreventExecution, 'living patient entered cloning scanner')
selectArgs.PreventExecution = nil
dragged.IsDead = true
scannerController.User = dragged
patches['Traitormod.Cloning.DeadOnly'](scannerController, selectArgs)
assert(not selectArgs.PreventExecution and activator.SelectedCharacter == nil, 'grabbed corpse cannot be released from machine')
activator.SelectedCharacter = { IsDead = false }
selectArgs.PreventExecution = nil
patches['Traitormod.Cloning.DeadOnly']({ Item = deconstructor.Item }, selectArgs)
assert(selectArgs.PreventExecution, 'living body entered biomass reclaimer')
connections[1].Recipients = iterable({ { Item = scanner } })
material = { GetComponentString = function() return { Character = body } end }
Traitormod.RoleManager.Roles = { Crew = { new = function() return { Name = 'Crew', IsAntagonist = false, Objectives = {} } end } }
roles[body] = { Name = 'HuskServant' }
assert(cloning.Begin(operator, console))
hooks['Traitormod.Cloning.Disconnect'](owner)
Client.ClientList = { operator }
cloning.Update(1)
local rejoined = { Account = 'patient', InGame = true }
rejoined.SetClientCharacter = function(character) rejoined.Character = character end
Client.ClientList = { operator, rejoined }
cloning.Update(1)
assert(cloning.Answer(rejoined, true), 'reconnected dead player never received cloning consent')
assert(roles[body] == nil and roles[rejoined.Character].Name == 'Crew' and not rejoined.Character.IsTraitor, 'parasite role survived a clean clone')
cloning.Update(28)
for _ = 1, 4 do biomass[#biomass + 1] = { Prefab = { Identifier = 'vt_biomass' } } end
cloning.Update(0)
biomass[#biomass + 1] = { Prefab = { Identifier = 'vt_biomass' } }
pod.CanClientAccess = function() return true end
operator.Character.SelectedItem = pod
local beforeWithdrawal = #spawned
local withdraw = { c = operator, msg = { ReadBoolean = function() return true end } }
patches['Traitormod.Cloning.Terminal']({ Item = pod }, withdraw)
assert(withdraw.PreventExecution and #spawned - beforeWithdrawal >= 5,
    'withdrawal did not return stored biomass')
for index = beforeWithdrawal + 1, #spawned do
    assert(spawned[index].Prefab == 'vt_biomass' and spawned[index].Inventory == operator.Character.Inventory,
        'biomass withdrawal sent the wrong item or destination')
end
local afterWithdrawal = #spawned
operator.Character.SelectedItem = nil
patches['Traitormod.Cloning.Terminal']({ Item = pod }, withdraw)
assert(#spawned == afterWithdrawal, 'unselected user withdrew biomass')
operator.Character.SelectedItem = pod
patches['Traitormod.Cloning.Terminal']({ Item = pod }, withdraw)
assert(#spawned == afterWithdrawal, 'repeated withdrawal duplicated biomass')
operator.Character.SelectedItem = nil
hooks['Traitormod.Cloning.End']()
assert(not cloning.Answer(owner, true))
-- Real objective transfer must resume healing without resetting earned progress.
Traitormod.RoleManager.Objectives = { Objective = { new = function() return {} end } }
Traitormod.Language = { ObjectiveHealCharacters = 'Heal %d/%d' }
local heal = dofile(modpath .. '/Lua/objectives/crew/healcharacters.lua')
heal.Static()
local medical = setmetatable({ Character = { IsDead = true }, Progress = 77, Amount = 500 }, { __index = heal })
heal.ActiveObjectives[medical] = true
hooks['Traitormod.Objective.HealCharacters.HealingTracked']({}, medical.Character, 1)
assert(heal.ActiveObjectives[medical] == nil)
local baseRole = dofile(modpath .. '/Lua/roles/role.lua')
local restored = {}
baseRole.Transfer({ Objectives = { medical } }, restored)
hooks['Traitormod.Objective.HealCharacters.HealingTracked']({}, restored, 3)
assert(medical.Progress == 80 and medical.Character == restored, 'medical goal lost progress or remained inactive after cloning')
Int32 = function(value) return value end
AbilityFlags = { IgnoredByEnemyAI = 1 }
Traitormod.RoleManager.Roles = { Role = baseRole, Antagonist = { new = function() return {} end } }
local cultist = dofile(modpath .. '/Lua/roles/cultist.lua')
local ignored = false
restored.AddAbilityFlag = function(flag) ignored = flag == AbilityFlags.IgnoredByEnemyAI end
cultist.Transfer({ Objectives = {} }, restored)
assert(ignored, 'cultist passive ability not restored in new body')
return 'PASS cloning: wired devices, biomass/reservation, independent new body/DNA, growth/power, original role/objectives, native/Lua consent, any species dummy, native packet and mass-scaled deconstruction'
