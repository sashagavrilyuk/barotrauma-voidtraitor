local NET_RESPAWNS = "VoidTraitor_AttackDefendRespawns"
local ATTACK_DEFEND_MISSION = Identifier("AttackDefenceV2")

local respawnEnds = {}
local deadRows = {}
local nextUpdate = 0

local function IsAttackDefend()
	for mission in Game.GameSession.Missions do
		if mission.Prefab.Type == ATTACK_DEFEND_MISSION then
			return true
		end
	end
	return false
end

local function UpdateDeadRow(infoId, entry, now)
	local timerText = ""
	local endTime = respawnEnds[infoId]
	if endTime ~= nil then
		local remaining = math.max(0, math.ceil(endTime - now))
		timerText = string.format("  %02d:%02d", math.floor(remaining / 60), remaining % 60)
	end

	local nameWidth = math.max(1, math.floor(entry.NameBlock.Rect.Width - entry.NameBlock.Font.MeasureString(timerText).X))
	entry.NameBlock.Text = tostring(ToolBox.LimitString(entry.Name, entry.NameBlock.Font, nameWidth)) .. timerText
end

-- Older hot-loaded versions used these patch IDs with different behavior.
-- Re-registering the same ID and hook type replaces those callbacks in LuaCs.
Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.KeepDeadCrewRow",
	"Barotrauma.CrewManager",
	"KillCharacter",
	function() end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.KeepDeadCharacter",
	"Barotrauma.CrewManager",
	"RemoveCharacter",
	function() end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.TrackCrewRow",
	"Barotrauma.CrewManager",
	"AddCharacterToCrewList",
	function() end,
	Hook.HookMethodType.After
)

Networking.Receive(NET_RESPAWNS, function(message)
	respawnEnds = {}
	local now = Timer.GetTime()
	for _ = 1, message.ReadByte() do
		local infoId = message.ReadUInt16()
		respawnEnds[infoId] = now + message.ReadSingle()
	end
	nextUpdate = 0
end)

Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.ClearDeadCrewRow",
	"Barotrauma.CrewManager",
	"AddCharacterToCrewList",
	function(instance, ptable)
		local character = ptable["character"]
		if character == nil or character.Info == nil then return end

		local infoId = character.Info.ID
		local oldEntry = deadRows[infoId]
		if oldEntry ~= nil and oldEntry.Character ~= character then
			instance.RemoveCharacterFromCrewList(oldEntry.Character)
			deadRows[infoId] = nil
		end
	end,
	Hook.HookMethodType.After
)

Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.KeepDeadCrewRow",
	"Barotrauma.CrewManager",
	"KillCharacter",
	function(instance, ptable)
		if not IsAttackDefend() then return end

		local character = ptable["killedCharacter"]
		local myClient = Game.Client.MyClient
		if myClient == nil then return end

		local isPlayer = character.IsRemotePlayer or Game.Client.Character == character or Game.Client.CharacterInfo == character.Info
		if not isPlayer or character.TeamID ~= myClient.TeamID then return end

		instance.RemoveCharacterFromCrewList(character)
		local row = assert(instance.AddCharacterToCrewList(character), "AttackDefend respawn: failed to create dead crew row for " .. character.Name)
		local nameBlock = assert(row.FindChild("name", true), "AttackDefend respawn: crew row has no name block")

		local infoId = character.Info.ID
		local entry = {
			Character = character,
			Name = character.Name,
			NameBlock = nameBlock,
			Row = row,
			CrewArea = row.Parent.Parent.Parent.Parent,
		}
		deadRows[infoId] = entry

		entry.Row.Color = Color.DarkRed
		for component in entry.Row.GetAllChildren() do
			component.Color = Color.DarkRed
		end
		UpdateDeadRow(infoId, entry, Timer.GetTime())
		nextUpdate = 0
	end,
	Hook.HookMethodType.After
)

Hook.Patch(
	"VoidTraitor.AttackDefendRespawn.KeepCrewRowVisible",
	"Barotrauma.CrewManager",
	"Update",
	function()
		if next(deadRows) == nil then return end

		local now = Timer.GetTime()
		if not GUI.DisableUpperHUD and CharacterHealth.OpenHealthWindow == nil then
			for _, entry in pairs(deadRows) do
				entry.CrewArea.Visible = true
				entry.Row.Visible = true
			end
		end

		if now < nextUpdate then return end
		nextUpdate = now + 1
		for infoId, entry in pairs(deadRows) do
			UpdateDeadRow(infoId, entry, now)
		end
	end,
	Hook.HookMethodType.After
)

Hook.Add("roundEnd", "VoidTraitor.AttackDefendRespawn.RoundEnd", function()
	respawnEnds = {}
	deadRows = {}
	nextUpdate = 0
end)
