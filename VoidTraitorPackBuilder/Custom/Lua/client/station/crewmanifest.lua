if SERVER then return end

-- The crew tab of the Tab menu in Station, as SS14's crew manifest on the PDA: the station's crew by department, each
-- with the role it was given and that role's icon. It shows no one else (ghost roles, creatures, spectators) and no
-- state such as death. The server sends the list (traitormod Lua/gamemodes/station/station.lua, gm:SendCrew) when it
-- changes and to a player who joins; outside Station the tab stays the game's own.
local _, Common = ...
local text = Common.Language.Lobby

local NET_CREW = "VoidTraitor_StationCrew"
local PATCH_ID = "VoidTraitor.CrewManifest"
local ROW_HEIGHT_PIXELS = 33
-- the game's crew tab columns (TabMenu.CreateMultiPlayerListContentHolder): job, name; the role takes the rest
local JOB_COLUMN, NAME_COLUMN = 0.138, 0.45

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.TabMenu"], "crewListArray")
local forceUpperCase = LuaUserData.CreateEnumTable("Barotrauma.ForceUpperCase")

-- { { Id, Members = { { Name, Role, Job } } } } during a Station round; Common.StationCrew tells other modules that the
-- round is Station's
Common.StationCrew = nil
-- the crew list of the open Tab menu, filled again when the server sends a new list
local shownList = nil

local function addMember(list, member, height)
    local frame = GUI.Frame(GUI.RectTransform(Point(list.Content.Rect.Width, height), list.Content.RectTransform), "ListBoxElement")
    frame.Color = Color(0, 0, 0, 0)
    -- not selectable: the game's character card would show the real job
    frame.CanBeFocused = false
    local row = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.9), frame.RectTransform, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    row.Stretch = true
    row.AbsoluteSpacing = 2
    row.CanBeFocused = false
    local jobWidth = math.floor(list.Content.Rect.Width * JOB_COLUMN)
    local job = JobPrefab.Prefabs.ContainsKey(member.Job) and JobPrefab.Get(member.Job) or nil
    local sprite = Common.GetRoleIcon(member.Role, member.Job, true)
    local iconHolder = GUI.Frame(GUI.RectTransform(Point(jobWidth, row.Rect.Height), row.RectTransform), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    if sprite ~= nil then
        local icon = GUI.Image(GUI.RectTransform(Point(row.Rect.Height, row.Rect.Height), iconHolder.RectTransform, GUI.Anchor.Center), sprite, true)
        icon.Color = job ~= nil and job.UIColor or Color(255, 255, 255, 255)
        icon.CanBeFocused = false
    end
    local name = GUI.TextBlock(GUI.RectTransform(Point(math.floor(list.Content.Rect.Width * NAME_COLUMN), row.Rect.Height), row.RectTransform),
        member.Name, job ~= nil and job.UIColor or nil, nil, GUI.Alignment.Center)
    name.OverflowClip = true
    name.CanBeFocused = false
    local role = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), row.RectTransform), TextManager.Get("jobname." .. member.Role).Value,
        nil, nil, GUI.Alignment.Center)
    role.OverflowClip = true
    role.CanBeFocused = false
end

local function fill(list)
    list.Content.ClearChildren()
    local height = Common.SafeIntScale(ROW_HEIGHT_PIXELS)
    for _, department in ipairs(Common.StationCrew) do
        local header = GUI.TextBlock(GUI.RectTransform(Point(list.Content.Rect.Width, height), list.Content.RectTransform),
            text.StationDepartments[department.Id] or department.Id, Common.StationDepartmentColors[department.Id], GUI.Style.SubHeadingFont, GUI.Alignment.CenterLeft)
        header.CanBeFocused = false
        for _, member in ipairs(department.Members) do addMember(list, member, height) end
    end
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
end

-- the column headers above the list, as the game's: job and name, then the role instead of the ping
Hook.Patch(PATCH_ID, "Barotrauma.TabMenu", "CreateMultiPlayerListContentHolder", function(instance, ptable)
    if Common.StationCrew == nil then return end
    local headerFrame = ptable["headerFrame"]
    local labels = { { TextManager.Get("tabmenu.job"), JOB_COLUMN }, { TextManager.Get("name"), NAME_COLUMN }, { text.StationCrewRole, 1 - JOB_COLUMN - NAME_COLUMN } }
    for _, label in ipairs(labels) do
        local button = GUI.Button(GUI.RectTransform(Vector2(label[2], 1), headerFrame.RectTransform), label[1], GUI.Alignment.Center, "GUIButtonSmallFreeScale")
        button.TextBlock.Font = GUI.Style.HotkeyFont
        button.CanBeFocused = false
        button.ForceUpperCase = forceUpperCase.Yes
    end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- The game's list would show every character and spectator with their state; it also keeps no linked rows then, so
-- the tab's update has nothing to refresh.
Hook.Patch(PATCH_ID, "Barotrauma.TabMenu", "CreateMultiPlayerList", function(instance, ptable)
    if Common.StationCrew == nil then return end
    -- Station has one team, so one list
    for list in instance.crewListArray do
        shownList = list
        break
    end
    fill(shownList)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Networking.Receive(NET_CREW, function(message)
    local crew = {}
    for _ = 1, message.ReadByte() do
        local department = { Id = message.ReadString(), Members = {} }
        for _ = 1, message.ReadByte() do
            department.Members[#department.Members + 1] = { Name = message.ReadString(), Role = message.ReadString(), Job = message.ReadString() }
        end
        crew[#crew + 1] = department
    end
    Common.StationCrew = crew
    if shownList ~= nil then fill(shownList) end
end)

Hook.Add("roundEnd", PATCH_ID, function()
    Common.StationCrew = nil
    shownList = nil
end)
