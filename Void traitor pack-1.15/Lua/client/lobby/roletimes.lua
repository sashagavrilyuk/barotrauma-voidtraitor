local P = ...
local S = P.State

-- Admin window with a player's total time and time on each Station role, which the role timers of the jobs window
-- ask for, by department as in the jobs window. A time is typed in hours and minutes and saved with Enter; "Open" gives
-- a role the time it still lacks. The server checks the admin, changes the time and sends the times back
-- (traitormod Lua/gamemodes/station/jobpreferences.lua).
local NET_TIMES_REQUEST = "VoidTraitor_StationRoleTimesRequest"
local NET_TIME_SET = "VoidTraitor_StationRoleTimeSet"
local NET_ROLE_UNLOCK = "VoidTraitor_StationRoleUnlock"
local NET_TIMES = "VoidTraitor_StationRoleTimes"
local WIDTH_PIXELS = 560
local HEIGHT_PIXELS = 640
-- the most the server takes is 60000 minutes (jobpreferences.lua)
local MAX_HOURS = 999

local text = P.Common.Language.AdminMenu
local lobbyText = P.Common.Language.Lobby
local view = nil

local function send(name, id, minutes)
    P.SendNetMessage(name, function(message)
        message.WriteString(view.Key)
        message.WriteString(id)
        if minutes ~= nil then message.WriteInt32(minutes) end
    end)
end

-- a number box without the game's pen icon, which would cover the digits of so narrow a box
local function createNumberBox(row, width, value)
    return GUI.TextBox(P.CreateRect(width, 1, row, nil), tostring(value), nil, nil, GUI.Alignment.Center, false, "", nil, false, false)
end

local function createLabel(row, width, value)
    local label = P.Common.CreateText(row, width, 1, nil, value, GUI.Alignment.CenterLeft, 1, nil, false)
    P.Common.SetAutoScaleText(label, 1)
    label.CanBeFocused = false
    return label
end

-- "" is the total time; role is nil for it
local function createRow(id, role, name, seconds)
    -- as tall as a text box, whose style sets its least height
    local height = P.Common.GetStyleHeight("GUITextBox")
    local row = GUI.LayoutGroup(P.CreateRect(1, 1, view.List.Content, nil), true, GUI.Anchor.CenterLeft)
    P.Common.SetFixedHeight(row, height)
    row.Stretch = true
    row.AbsoluteSpacing = P.Common.GetGap()
    -- every row keeps the icon's place, so the names line up
    local iconRect = GUI.RectTransform(Point(height, height), row.RectTransform)
    iconRect.IsFixedSize = true
    local sprite = role ~= nil and P.Common.GetRoleIcon(id, role.Job, true) or nil
    if sprite ~= nil then
        local icon = GUI.Image(iconRect, sprite, true)
        icon.Color = JobPrefab.Get(role.Job).UIColor
        icon.CanBeFocused = false
    else
        local blank = GUI.Frame(iconRect, nil)
        blank.Color = Color(0, 0, 0, 0)
        blank.CanBeFocused = false
    end
    createLabel(row, 0.4, name)

    local minutes = math.floor(seconds / 60)
    local hours = createNumberBox(row, 0.11, math.floor(minutes / 60))
    createLabel(row, 0.06, text.RoleTimeHours)
    local rest = createNumberBox(row, 0.11, minutes % 60)
    createLabel(row, 0.08, text.RoleTimeMinutes)
    local function save()
        local h, m = tonumber(hours.Text), tonumber(rest.Text)
        if h == nil or m == nil or h < 0 or m < 0 or h % 1 ~= 0 or m % 1 ~= 0 or h > MAX_HOURS or m > 59 then
            hours.Text, rest.Text = tostring(math.floor(minutes / 60)), tostring(minutes % 60)
        elseif h * 60 + m ~= minutes then
            send(NET_TIME_SET, id, h * 60 + m)
        end
        return true
    end
    for _, box in ipairs({ hours, rest }) do
        box.MaxTextLength = 3
        box.ToolTip = text.RoleTimeTooltip
        box.OnEnterPressed = save
    end

    local unlock = GUI.Button(P.CreateRect(0.2, 1, row, nil), text.RoleUnlock, GUI.Alignment.Center, "GUIButtonSmall")
    unlock.ToolTip = text.RoleUnlockTooltip
    unlock.Visible = id ~= ""
    unlock.OnClicked = function()
        send(NET_ROLE_UNLOCK, id)
        return true
    end
end

function P.ShowRoleTimesWindow(key)
    P.CloseMenu()

    local screenWidth, screenHeight = P.GetScreenSize()
    local margin = P.SafeIntScale(10)
    local width = P.Common.FitWindowWidth(P.SafeIntScale(WIDTH_PIXELS), 380, margin)
    local height = P.Common.FitWindowHeight(P.SafeIntScale(HEIGHT_PIXELS), 320, margin)
    local rootRect = P.CreatePixelRect(width, height, S.guiRoot, GUI.Anchor.TopLeft)
    rootRect.AbsoluteOffset = Point(math.floor((screenWidth - width) / 2), math.floor((screenHeight - height) / 2))
    local root = GUI.Frame(rootRect, nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    S.currentMenu = root
    S.currentMenuKind = "roletimes"
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = S.currentMenuKind

    local panel = GUI.Frame(P.CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false
    local content = P.Common.CreateWindowContent(panel)
    -- opened from the admin tab, so closing it goes back there
    P.Common.CreateWindowHeader(content, root, text.RoleTimes, P.UiText.Cancel, function()
        P.CloseMenu()
        P.ShowVoidTraitorMenu()
        return true
    end)
    local player = P.CreateText(content, 1, 1, nil, "", GUI.Alignment.Left, 0.86, Color(225, 220, 195, 255), false)
    P.Common.FitHeightToText(player)

    -- the only row without a fixed height: it takes the rest of the window
    local listHost = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false
    local _, list = P.CreateMenuList(listHost)
    view = { Root = root, Key = key, List = list, Player = player }

    P.SendNetMessage(NET_TIMES_REQUEST, function(message) message.WriteString(key) end)
end

Networking.Receive(NET_TIMES, function(message)
    if S.sharedState.Disabled then return end
    local key, name, total = message.ReadString(), message.ReadString(), message.ReadUInt32()
    local times = {}
    for _ = 1, message.ReadByte() do
        local id = message.ReadString()
        times[id] = message.ReadUInt32()
    end
    if view == nil or S.currentMenu ~= view.Root or view.Key ~= key then return end

    view.Player.Text = string.format(text.SelectedPlayer, name)
    local scroll = view.List.BarScroll
    view.List.Content.ClearChildren()
    createRow("", nil, text.TotalTime, total)
    -- each role once, under the first department of the jobs window that lists it: the heads under Command
    local jobs, shown = S.stationJobs, {}
    for _, department in ipairs(jobs ~= nil and jobs.Departments or {}) do
        local header
        for _, id in ipairs(department.Roles) do
            if not shown[id] and jobs.Roles[id] ~= nil then
                shown[id] = true
                if header == nil then
                    header = P.Common.CreateText(view.List.Content, 1, 1, nil, lobbyText.StationDepartments[department.Id] or department.Id,
                        GUI.Alignment.CenterLeft, 1, P.Common.StationDepartmentColors[department.Id], false)
                    header.Font = GUI.Style.SubHeadingFont
                    header.CanBeFocused = false
                    P.Common.FitHeightToText(header)
                end
                createRow(id, jobs.Roles[id], P.GetStationRoleName(id), times[id] or 0)
            end
        end
    end
    view.List.RecalculateChildren()
    view.List.UpdateScrollBarSize()
    view.List.BarScroll = scroll
    -- the list draws its new rows this frame, before their own update would lay them out (GUIListBox.Draw)
    view.List.ForceLayoutRecalculation()
end)
