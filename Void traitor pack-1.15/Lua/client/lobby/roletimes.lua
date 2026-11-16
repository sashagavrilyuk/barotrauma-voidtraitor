local P = ...
local S = P.State

-- Admin window with a player's total time and time on each Station role, which the role timers of the jobs window
-- ask for. Each row adds or takes an hour; the server checks the admin, changes the time and sends the times back
-- (traitormod Lua/gamemodes/station/jobpreferences.lua).
local NET_TIMES_REQUEST = "VoidTraitor_StationRoleTimesRequest"
local NET_TIME_CHANGE = "VoidTraitor_StationRoleTimeChange"
local NET_TIMES = "VoidTraitor_StationRoleTimes"
local WIDTH_PIXELS = 560
local HEIGHT_PIXELS = 640
local STEP_MINUTES = 60

local text = P.Common.Language.AdminMenu
local view = nil

local function sendChange(id, minutes)
    P.SendNetMessage(NET_TIME_CHANGE, function(message)
        message.WriteString(view.Key)
        message.WriteString(id)
        message.WriteInt32(minutes)
    end)
end

-- the roles of the jobs window in its order, each once
local function stationRoles()
    local roles, seen = {}, {}
    for _, department in ipairs(S.stationJobs.Departments) do
        for _, id in ipairs(department.Roles) do
            if not seen[id] then
                seen[id] = true
                roles[#roles + 1] = id
            end
        end
    end
    return roles
end

-- "" is the total time
local function createRow(id, name, seconds)
    local row = GUI.LayoutGroup(P.CreateRect(1, 1, view.List.Content, nil), true, GUI.Anchor.CenterLeft)
    P.Common.SetFixedHeight(row, P.Common.GetStyleHeight("GUIButtonSmall"))
    row.Stretch = true
    row.AbsoluteSpacing = P.Common.GetGap()
    local label = P.Common.CreateText(row, 0.46, 1, nil, name, GUI.Alignment.CenterLeft, 1, nil, false)
    P.Common.SetAutoScaleText(label, 1)
    local time = P.Common.CreateText(row, 0.26, 1, nil, P.FormatStationDuration(math.floor(seconds / 60)), GUI.Alignment.CenterRight, 1, nil, false)
    P.Common.SetAutoScaleText(time, 1)
    for _, step in ipairs({ -STEP_MINUTES, STEP_MINUTES }) do
        local button = GUI.Button(P.CreateRect(0.14, 1, row, nil), step < 0 and text.TakeHour or text.AddHour, GUI.Alignment.Center, "GUIButtonSmall")
        button.OnClicked = function()
            sendChange(id, step)
            return true
        end
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
    createRow("", text.TotalTime, total)
    if S.stationJobs ~= nil then
        for _, id in ipairs(stationRoles()) do createRow(id, P.GetStationRoleName(id), times[id] or 0) end
    end
    view.List.RecalculateChildren()
    view.List.UpdateScrollBarSize()
    view.List.BarScroll = scroll
end)
