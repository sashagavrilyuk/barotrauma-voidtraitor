local NET_RESPAWNS = "VoidTraitor_AttackDefendRespawns"
local ATTACK_DEFEND_MISSION = Identifier("AttackDefenceV2")
local language = table.pack(...)[2].Language.AttackDefendRespawn

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
	local endTime = respawnEnds[infoId]
	if endTime == nil then
		entry.TimerBlock.Text = ""
		return
	end

	local remaining = math.max(0, math.ceil(endTime - now))
	entry.TimerBlock.Text = string.format(language.Timer, remaining)
end

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

			if GameSession.IsTabMenuOpen and TabMenu.SelectedTab == TabMenu.InfoFrameTab.Crew then
				GameSession.TabMenuInstance.SelectInfoFrameTab(TabMenu.InfoFrameTab.Crew)
			end
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

		local layoutGroup = nameBlock.Parent
		local extraIcons = assert(row.FindChild("extraicons", true), "AttackDefend respawn: crew row has no extra icon frame")
		local orderGroup = nil
		local previous = nil
		for component in layoutGroup.Children do
			if component == extraIcons then
				orderGroup = previous
				break
			end
			previous = component
		end
		assert(orderGroup ~= nil, "AttackDefend respawn: crew row has no order group")
		for component in orderGroup.Children do
			component.Visible = false
		end

		local timerBlock = GUI.TextBlock(
			GUI.RectTransform(Vector2.One, orderGroup.RectTransform),
			"",
			nil,
			GUI.GUIStyle.SmallFont,
			GUI.Alignment.CenterLeft,
			false
		)
		timerBlock.CanBeFocused = false
		timerBlock.IgnoreLayoutGroups = true
		timerBlock.TextScale = 0.9
		timerBlock.TextColor = Color(255, 170, 170, 255)

		local infoId = character.Info.ID
		local entry = {
			Character = character,
			TimerBlock = timerBlock,
			Row = row,
			CrewArea = row.Parent.Parent.Parent.Parent,
		}
		deadRows[infoId] = entry

		entry.Row.Color = Color.DarkRed
		entry.Row.HoverColor = Color.DarkRed
		entry.Row.PressedColor = Color.DarkRed
		entry.Row.SelectedColor = Color.DarkRed
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
