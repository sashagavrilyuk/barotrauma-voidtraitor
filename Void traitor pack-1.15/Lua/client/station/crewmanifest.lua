if SERVER then return end

-- The crew tab of the Tab menu in Station, as SS14's crew manifest on the PDA: the station's crew by department, heads
-- first, each with the role it was given and that role's icon. It shows no one else (ghost roles, creatures,
-- spectators) and no state such as death. Beside it, what the whole station knows: the shift's time, the alert code,
-- the evacuation shuttle, the crew's size and the seats each role has left. The server sends it all (traitormod
-- Lua/gamemodes/station/station.lua, gm:SendCrew) when it changes and to a player who joins; outside Station the tab
-- stays the game's own.
local _, Common = ...
local text = Common.Language.Lobby

local NET_CREW = "VoidTraitor_StationCrew"
local PATCH_ID = "VoidTraitor.CrewManifest"
local ROW_HEIGHT_PIXELS = 33
-- the list keeps the left part of the tab and the station panel the right, with a gap between them
local LIST_WIDTH, PANEL_WIDTH = 0.6, 0.38
-- the share of the list's width the names take; the role follows them
local NAME_COLUMN = 0.4
local MUTED_COLOR = Color(170, 168, 155, 255)
local TRANSPARENT = Color(0, 0, 0, 0)

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.TabMenu"], "crewListArray")

-- { { Id, Members = { { Name, Role, Job } } } } during a Station round; Common.StationCrew tells other modules that the
-- round is Station's
Common.StationCrew = nil
-- { Crew, StartTime, Alert, AlertColor, Evacuation, Free = { { Role, Job, Seats } } } from the same message
local station = nil
-- the crew list and the station panel of the open Tab menu, filled again when the server sends a new list
local shownList, shownPanel = nil, nil

-- long names and roles shrink to their column rather than lose their end
local function createLabel(parent, size, value, color, font, alignment)
    local label = GUI.TextBlock(GUI.RectTransform(size, parent.RectTransform), value, color, font, alignment)
    label.CanBeFocused = false
    Common.SetAutoScaleText(label, 1)
    return label
end

-- A row as wide as the list, which sizes its content only in its update, so the row is relative; it starts with the
-- role's icon in its job's color. Returns the row and the color.
local function addRow(list, height, roleId, jobId)
    local job = JobPrefab.Prefabs.ContainsKey(jobId) and JobPrefab.Get(jobId) or nil
    local color = job ~= nil and job.UIColor or nil
    local row = GUI.LayoutGroup(Common.CreateRect(1, 1, list.Content), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(row, height)
    row.Stretch = true
    row.AbsoluteSpacing = Common.GetGap()
    local iconRect = GUI.RectTransform(Point(height, height), row.RectTransform)
    iconRect.IsFixedSize = true
    local iconHolder = GUI.Frame(iconRect, nil)
    iconHolder.Color = TRANSPARENT
    iconHolder.CanBeFocused = false
    local sprite = Common.GetRoleIcon(roleId, jobId, true)
    if sprite ~= nil then
        local icon = GUI.Image(GUI.RectTransform(Vector2(0.9, 0.9), iconHolder.RectTransform, GUI.Anchor.Center), sprite, true)
        icon.Color = color or Color(255, 255, 255, 255)
        icon.CanBeFocused = false
    end
    return row, color
end

-- the name in the job's color, then the role in a column after it
local function addMember(list, height, member)
    local row, color = addRow(list, height, member.Role, member.Job)
    createLabel(row, Vector2(NAME_COLUMN, 1), member.Name, color, nil, GUI.Alignment.CenterLeft)
    createLabel(row, Vector2(1 - NAME_COLUMN, 1), TextManager.Get("jobname." .. member.Role).Value, MUTED_COLOR, nil, GUI.Alignment.CenterLeft)
end

-- the role in its job's color and the seats it has left at the right edge, in the small font of a side list
local function addFreeSeat(list, height, entry)
    local row, color = addRow(list, height, entry.Role, entry.Job)
    local font = GUI.Style.SmallFont
    createLabel(row, Vector2(0.8, 1), TextManager.Get("jobname." .. entry.Role).Value, color, font, GUI.Alignment.CenterLeft)
    local count = createLabel(row, Vector2(0.2, 1), tostring(entry.Seats), nil, font, GUI.Alignment.CenterRight)
    Common.SetFixedWidth(count, Common.GetTextHeight(font) * 2)
end

local function fillList(list)
    list.Content.ClearChildren()
    local height = Common.SafeIntScale(ROW_HEIGHT_PIXELS)
    for _, department in ipairs(Common.StationCrew) do
        local color = Common.StationDepartmentColors[department.Id]
        local header = GUI.Frame(Common.CreateRect(1, 1, list.Content), nil)
        Common.SetFixedHeight(header, height)
        header.Color = TRANSPARENT
        header.CanBeFocused = false
        createLabel(header, Vector2(1, 1), text.StationDepartments[department.Id] or department.Id, color, GUI.Style.SubHeadingFont, GUI.Alignment.CenterLeft)
        createLabel(header, Vector2(1, 1), tostring(#department.Members), color, GUI.Style.SubHeadingFont, GUI.Alignment.CenterRight)
        Common.CreateDivider(list.Content).CanBeFocused = false
        for _, member in ipairs(department.Members) do addMember(list, height, member) end
    end
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
end

-- the station panel takes the list's height to its right
local function createPanel(list)
    local rect = GUI.RectTransform(Vector2(PANEL_WIDTH, list.RectTransform.RelativeSize.Y), list.Parent.RectTransform, GUI.Anchor.BottomRight)
    local frame = GUI.Frame(rect, "GUIFrameListBox")
    frame.IgnoreLayoutGroups = true
    frame.CanBeFocused = false
    local content = Common.CreateWindowContent(frame)
    local panel = { Frame = frame }
    local function addTitle(value)
        local title = Common.CreateText(content, 1, 1, nil, value, GUI.Alignment.CenterLeft, 1, nil, false)
        title.Font = GUI.Style.SubHeadingFont
        title.CanBeFocused = false
        Common.FitHeightToText(title)
    end
    -- a label on the left and its value on the right
    local function addLine(label)
        local line = GUI.Frame(Common.CreateRect(1, 1, content), nil)
        line.Color = TRANSPARENT
        line.CanBeFocused = false
        Common.SetFixedHeight(line, Common.GetTextHeight(GUI.Style.Font))
        createLabel(line, Vector2(1, 1), label, MUTED_COLOR, nil, GUI.Alignment.CenterLeft)
        return createLabel(line, Vector2(1, 1), "", nil, nil, GUI.Alignment.CenterRight)
    end
    addTitle(text.StationInfo)
    panel.Shift = addLine(text.StationShift)
    panel.Alert = addLine(text.StationAlert)
    panel.Evacuation = addLine(text.StationEvacuation)
    panel.Crew = addLine(text.StationCrewSize)
    Common.CreateDivider(content)
    addTitle(text.StationFreeSeats)
    panel.Free = GUI.ListBox(Common.CreateRect(1, 1, content), false, nil, "GUIListBoxNoBorder")
    panel.Free.Color = TRANSPARENT
    panel.Free.ContentBackground.Color = TRANSPARENT
    return panel
end

local function fillPanel(panel)
    panel.Shift.Text = Common.FormatMinutes(math.floor((Timer.GetTime() - station.StartTime) / 60))
    panel.Alert.Text = station.Alert
    panel.Alert.TextColor = station.AlertColor
    panel.Evacuation.Text = text.StationEvacuationStates[station.Evacuation] or station.Evacuation
    panel.Crew.Text = tostring(station.Crew)
    local list = panel.Free
    list.Content.ClearChildren()
    local height = Common.GetTextHeight(GUI.Style.Font)
    for _, entry in ipairs(station.Free) do addFreeSeat(list, height, entry) end
    if #station.Free == 0 then
        Common.FitHeightToText(Common.CreateText(list.Content, 1, 1, nil, text.StationNoFreeSeats, GUI.Alignment.CenterLeft, 1, MUTED_COLOR, false))
    end
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
end

-- Built in the Tab menu's own update and in a network message, and drawn this frame: laid out now, or the rows would
-- show unplaced for a frame (lobby/menu_window.lua).
local function fill()
    fillList(shownList)
    fillPanel(shownPanel)
    shownList.ForceLayoutRecalculation()
    shownPanel.Frame.ForceLayoutRecalculation()
end

-- no column headers above the list, as in SS14's manifest
Hook.Patch(PATCH_ID, "Barotrauma.TabMenu", "CreateMultiPlayerListContentHolder", function(instance, ptable)
    if Common.StationCrew == nil then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- The game's list would show every character and spectator with their state; it also keeps no linked rows then, so
-- the tab's update has nothing to refresh.
Hook.Patch(PATCH_ID, "Barotrauma.TabMenu", "CreateMultiPlayerList", function(instance, ptable)
    if Common.StationCrew == nil then return end
    -- Station has one team, so one list
    local list
    for teamList in instance.crewListArray do
        list = teamList
        break
    end
    if list ~= shownList then
        shownList = list
        -- the list box sizes its content only in its update, as the game's own crew tab does after a resize
        list.RectTransform.RelativeSize = Vector2(LIST_WIDTH, list.RectTransform.RelativeSize.Y)
        list.UpdateDimensions()
        shownPanel = createPanel(list)
    end
    fill()
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
    station = { Crew = message.ReadUInt16(), StartTime = Timer.GetTime() - message.ReadInt32(), Alert = message.ReadString(),
        AlertColor = Color(message.ReadByte(), message.ReadByte(), message.ReadByte(), 255), Evacuation = message.ReadString(), Free = {} }
    for _ = 1, message.ReadByte() do
        station.Free[#station.Free + 1] = { Role = message.ReadString(), Job = message.ReadString(), Seats = message.ReadByte() }
    end
    Common.StationCrew = crew
    if shownList ~= nil then fill() end
end)

Hook.Add("roundEnd", PATCH_ID, function()
    Common.StationCrew = nil
    station = nil
    shownList, shownPanel = nil, nil
end)
