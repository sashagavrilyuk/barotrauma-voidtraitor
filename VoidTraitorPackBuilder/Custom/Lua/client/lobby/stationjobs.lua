local P = ...
local S = P.State
local Common = P.Common
local text = Common.Language.Lobby

-- The lobby's Station jobs window, as SS14's job preferences: the roles by department, a level for each and its
-- outfit. The server keeps the choice and sends it with the roles on joining and after every change
-- (gamemodes/station/jobpreferences.lua); each button sends one change and shows what the server stored.

local HIGH = 3
-- what a role's missing time is for, after OVERALL = 0 (gamemodes/station/jobpreferences.lua)
local ROLE = 1
local HINT_COLOR = Color(170, 180, 180, 255)
local LOCKED_COLOR = Color(130, 135, 135, 255)
-- the chosen level stands out as in SS14; the button style's own selected look is barely visible
local LEVEL_SELECTED_COLOR = Color(170, 50, 40, 255)
local LEVEL_SELECTED_TEXT_COLOR = Color(255, 255, 255, 255)
local DIVIDER_WIDTH = 2 -- width of the vanilla VerticalLine style

S.stationJobs = nil
-- the level buttons of the open jobs window by role: a head has a row in Command and one in its department
S.stationJobRows = {}
S.stationOutfitWindow = nil
S.stationOutfitRole = nil
S.stationOutfitTiles = {}
S.stationOutfitFigures = {}

local function sendChange(name, id, value)
    P.SendNetMessage(name, function(message)
        message.WriteString(id)
        message.WriteByte(value)
    end)
end

-- a role's texts are jobname.<role> and jobdescription.<role> (StationText.xml), as the ID card shows them; a role
-- named after its job uses the job's own
local function roleText(prefix, id, role)
    local key = TextManager.ContainsTag(prefix .. id) and prefix .. id or prefix .. role.Job
    return TextManager.Get(key).Value
end

local function roleName(id, role)
    return roleText("jobname.", id, role)
end

local function duration(minutes)
    local hours = math.floor(minutes / 60)
    if hours == 0 then return string.format(text.StationMinutes, minutes) end
    if minutes % 60 == 0 then return string.format(text.StationHours, hours) end
    return string.format(text.StationHoursMinutes, hours, minutes % 60)
end

-- for the admin's role time window (roletimes.lua)
function P.GetStationRoleName(id)
    return roleName(id, S.stationJobs.Roles[id])
end

local function roleTooltip(id, role)
    local description = roleText("jobdescription.", id, role)
    if role.Karma > 0 then description = description .. "\n" .. string.format(text.StationNeedKarma, role.Karma) end
    for _, need in ipairs(role.Missing) do
        local target = need.Kind == ROLE and roleName(need.Id, S.stationJobs.Roles[need.Id]) or text.StationDepartments[need.Id]
        description = description .. "\n" .. string.format(text.StationNeedTime[need.Kind + 1], duration(need.Minutes), target)
    end
    return description
end

-- the role with the high level, or the passenger, in the outfit chosen for it
function P.GetStationCardRole()
    local jobs = S.stationJobs
    if jobs == nil then return nil end
    local id = "passenger"
    for roleId, role in pairs(jobs.Roles) do
        if role.Level == HIGH then id = roleId end
    end
    local role = jobs.Roles[id]
    if role == nil then return nil end
    return JobVariant.__new(JobPrefab.Get(role.Job), role.Outfit), roleName(id, role)
end

local function createRow(list, id, role, height, labels)
    local row = GUI.LayoutGroup(Common.CreateRect(1, 1, list.Content), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(row, height)
    row.Stretch = true
    row.AbsoluteSpacing = Common.GetGap()

    local job = JobPrefab.Get(role.Job)
    local sprite = Common.GetRoleIcon(id, role.Job, true)
    if sprite ~= nil then
        local icon = GUI.Image(GUI.RectTransform(Point(height, height), row.RectTransform), sprite, true)
        icon.Color = job.UIColor
        icon.CanBeFocused = false
    end

    local locked = role.Karma > 0 or #role.Missing > 0
    local name = Common.CreateText(row, 0.3, 1, nil, roleName(id, role), GUI.Alignment.CenterLeft, 1,
        locked and LOCKED_COLOR or nil, false)
    Common.SetAutoScaleText(name, 1)
    name.ToolTip = roleTooltip(id, role)

    local help = GUI.Button(GUI.RectTransform(Point(height, height), row.RectTransform), "?", GUI.Alignment.Center, "GUIButtonSmall")
    help.ToolTip = roleTooltip(id, role)

    local buttons = {}
    for level = 0, HIGH do
        local button = GUI.Button(Common.CreateRect(0.11, 1, row), text.StationLevels[level + 1], GUI.Alignment.Center, "GUIButtonSmall")
        button.SelectedColor = LEVEL_SELECTED_COLOR
        button.SelectedTextColor = LEVEL_SELECTED_TEXT_COLOR
        button.Selected = role.Level == level
        button.Enabled = not locked
        button.OnClicked = function()
            sendChange(P.NET_STATION_JOB_SET, id, level)
            return true
        end
        buttons[level] = button
        labels[#labels + 1] = button.TextBlock
    end
    S.stationJobRows[id] = S.stationJobRows[id] or {}
    table.insert(S.stationJobRows[id], buttons)

    -- the outfit button is not one of the levels; a fixed size keeps the line from stretching with the row
    local lineRect = GUI.RectTransform(Point(DIVIDER_WIDTH, height), row.RectTransform)
    lineRect.IsFixedSize = true
    GUI.Image(lineRect, "VerticalLine").CanBeFocused = false

    local outfit = GUI.Button(Common.CreateRect(0.16, 1, row), text.StationLoadout, GUI.Alignment.Center, "GUIButtonSmall")
    outfit.OnClicked = function()
        P.ShowStationOutfitWindow(id)
        return true
    end
    labels[#labels + 1] = outfit.TextBlock
end

function P.ShowStationJobsWindow()
    local content = P.OpenCardWindow("stationjobs", text.Jobs, true)
    for _, hint in ipairs({ text.StationPassengerHint, text.StationHighHint }) do
        local block = Common.CreateText(content, 1, 1, nil, hint, GUI.Alignment.CenterLeft, 1, HINT_COLOR, false)
        block.CanBeFocused = false
        Common.SetAutoScaleText(block, 1)
        Common.FitHeightToText(block)
    end
    local list = GUI.ListBox(Common.CreateRect(1, 1, content), false)
    list.Spacing = math.floor(Common.GetGap() / 2)
    -- the outfit buttons end the rows; keep them off the list's frame
    local padding = list.Padding
    list.Padding = Vector4(padding.X, padding.Y, padding.Z + Common.GetGap(), padding.W)
    S.stationJobRows = {}
    local jobs = S.stationJobs
    if jobs == nil then return end

    local height = Common.GetStyleHeight("GUIButtonSmall")
    local labels = {}
    for _, department in ipairs(jobs.Departments) do
        local header = Common.CreateText(list.Content, 1, 1, nil, text.StationDepartments[department.Id] or department.Id,
            GUI.Alignment.CenterLeft, 1, Common.StationDepartmentColors[department.Id], false)
        header.Font = GUI.Style.SubHeadingFont
        header.CanBeFocused = false
        Common.FitHeightToText(header)
        for _, id in ipairs(department.Roles) do
            local role = jobs.Roles[id]
            if role ~= nil then createRow(list, id, role, height, labels) end
        end
    end
    -- once the rows have their width: one text size for all buttons, the one the longest label needs
    list.RecalculateChildren()
    GUI.TextBlock.AutoScaleAndNormalize(table.unpack(labels))
end

-- marks the chosen variant's tile and number button
local function showOutfit(role)
    for variant, parts in pairs(S.stationOutfitTiles) do
        for _, part in ipairs(parts) do part.Selected = role ~= nil and role.Outfit == variant end
    end
end

function P.RemoveStationOutfitWindow()
    if S.stationOutfitWindow == nil then return end
    for _, figure in ipairs(S.stationOutfitFigures) do
        P.RemoveCharacterFigure(figure)
    end
    Common.RemoveGuiComponent(S.stationOutfitWindow)
    Game.NetLobbyScreen.playerInfoContent.Parent.Visible = true
    S.stationOutfitWindow, S.stationOutfitRole = nil, nil
    S.stationOutfitFigures, S.stationOutfitTiles = {}, {}
end

-- The role's outfit variants drawn on the player's character, in a small window in place of the player card, which
-- hides behind it, while the jobs window stays open. Each has the game's numbered variant button: the lobby shows the
-- variant's starting items while the cursor is on it (NetLobbyScreen.UpdateJobVariantSelectionIfNeeded), above the
-- button's parent.
function P.ShowStationOutfitWindow(id)
    local role = S.stationJobs ~= nil and S.stationJobs.Roles[id] or nil
    if role == nil or S.currentMenuKind ~= "stationjobs" then return end
    P.RemoveStationOutfitWindow()
    S.stationOutfitRole = id

    local column = Game.NetLobbyScreen.playerInfoContent.Parent
    column.Visible = false
    local root, cardRect = S.currentMenu, column.Parent.Rect
    local rect = GUI.RectTransform(Point(cardRect.Width, cardRect.Height), root.RectTransform, GUI.Anchor.TopLeft)
    rect.AbsoluteOffset = Point(cardRect.X - root.Rect.X, cardRect.Y - root.Rect.Y)
    local window = GUI.Frame(rect, "GUIFrame")
    S.stationOutfitWindow = window
    local content = Common.CreateWindowContent(window)
    Common.CreateWindowHeader(content, window, string.format(text.StationOutfit, roleName(id, role)), P.UiText.Cancel, function()
        P.RemoveStationOutfitWindow()
        return true
    end)

    local tiles = GUI.LayoutGroup(Common.CreateRect(1, 1, content), true)
    tiles.Stretch = true
    tiles.AbsoluteSpacing = Common.GetGap()
    local info = S.card ~= nil and S.card.Figure.Info or nil
    local job = JobPrefab.Get(role.Job)
    local buttonSize = Common.GetStyleHeight("GUIButton")
    for variant = 0, role.Variants - 1 do
        local tile = GUI.Button(Common.CreateRect(1 / role.Variants, 1, tiles), "", GUI.Alignment.Center, "ListBoxElement")
        local function choose()
            sendChange(P.NET_STATION_OUTFIT_SET, id, variant)
            return true
        end
        tile.OnClicked = choose
        if info ~= nil then
            local figure = P.CreateCharacterFigure(GUI.RectTransform(Vector2(1, 0.85), tile.RectTransform, GUI.Anchor.TopCenter), info)
            P.SetFigureJob(figure, JobVariant.__new(job, variant))
            S.stationOutfitFigures[#S.stationOutfitFigures + 1] = figure
        end
        local caption = GUI.Frame(GUI.RectTransform(Vector2(1, 0.15), tile.RectTransform, GUI.Anchor.BottomCenter), nil)
        caption.Color = Color(0, 0, 0, 0)
        caption.CanBeFocused = false
        local button = GUI.Button(GUI.RectTransform(Point(buttonSize, buttonSize), caption.RectTransform, GUI.Anchor.Center),
            tostring(variant + 1), GUI.Alignment.Center, "JobVariantButton")
        button.UserData = JobVariant.__new(job, variant)
        button.OnClicked = choose
        S.stationOutfitTiles[variant] = { tile, button }
    end
    showOutfit(role)
end

Networking.Receive(P.NET_STATION_JOBS, function(message)
    if S.sharedState.Disabled then return end

    local jobs = { Departments = {}, Roles = {} }
    for _ = 1, message.ReadByte() do
        local department = { Id = message.ReadString(), Roles = {} }
        for _ = 1, message.ReadByte() do
            department.Roles[#department.Roles + 1] = message.ReadString()
        end
        jobs.Departments[#jobs.Departments + 1] = department
    end
    for _ = 1, message.ReadByte() do
        local id = message.ReadString()
        local job = message.ReadString()
        local variants = message.ReadByte()
        local karma = message.ReadUInt16()
        local level = message.ReadByte()
        local outfit = message.ReadByte()
        local missing = {}
        for _ = 1, message.ReadByte() do
            missing[#missing + 1] = { Kind = message.ReadByte(), Id = message.ReadString(), Minutes = message.ReadUInt16() }
        end
        jobs.Roles[id] = { Job = job, Variants = variants, Karma = karma, Level = level, Outfit = outfit, Missing = missing }
    end
    S.stationJobs = jobs

    -- the open windows show what the server stored, in place, so the list keeps its scroll
    for id, rows in pairs(S.stationJobRows) do
        local role = jobs.Roles[id]
        for _, buttons in ipairs(rows) do
            for level, button in pairs(buttons) do
                button.Selected = role ~= nil and role.Level == level
            end
        end
    end
    showOutfit(S.stationOutfitRole ~= nil and jobs.Roles[S.stationOutfitRole] or nil)
    P.RefreshCardJob()
end)
