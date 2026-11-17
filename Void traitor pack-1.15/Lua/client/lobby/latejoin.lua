local P = ...
local S = P.State
local Common = P.Common
local text = Common.Language.Lobby

-- Station's late join, as SS14's: during a Station round the lobby's join button first asks the server (traitormod
-- Lua/gamemodes/station/station.lua). A player who has already been on the station this round joins straight away and
-- the game gives them back their character. A newcomer gets a small window with every role and the seats it has left
-- (the crew list, station/crewmanifest.lua), and a button to join as an observer. A role is taken only once the server
-- has checked it; the player then joins as the game's own button would and arrives with it on the shuttle.

local NET_CHOOSE = "VoidTraitor_StationLateJoin"
local NET_RESULT = "VoidTraitor_StationLateJoinResult"
local WIDTH_PIXELS = 420
local HEIGHT_PIXELS = 600
-- as the jobs window shows a role the player can't take yet
local LOCKED_COLOR = Color(130, 135, 135, 255)

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.NetLobbyScreen"], "joinOnGoingRoundButton")

S.lateJoinList = nil
-- the role sent to the server and not yet answered, "" for the join button's question; the window waits with its
-- buttons off
S.lateJoinPending = nil
-- set while this file joins the round itself, so the patch below lets the request through
local joining = false

local function stationRunning()
    return S.lobbyInfo ~= nil and S.lobbyInfo.Running and S.lobbyInfo.Station
end

-- The game's own join request; it tells the server whether the player only watches (GameClient.WriteCharacterInfo).
local function join(spectate)
    local screen = Game.NetLobbyScreen
    if screen.Spectating ~= spectate then screen.SetSpectate(spectate) end
    joining = true
    Game.Client.SendJoinOngoingRequest(screen.joinOnGoingRoundButton)
    joining = false
end

-- a role as one button, as in SS14: its icon, its name and the seats it has left
local function createRow(list, id, role, height, seats)
    local locked = role.Karma > 0 or #role.Missing > 0
    local free = seats ~= nil and seats > 0
    local button = GUI.Button(Common.CreateRect(1, 1, list.Content), "", GUI.Alignment.Left, "ListBoxElement")
    Common.SetFixedHeight(button, height)
    button.Enabled = free and not locked and S.lateJoinPending == nil
    button.ToolTip = P.GetStationRoleTooltip(id)
    button.OnClicked = function()
        S.lateJoinPending = id
        P.SendNetMessage(NET_CHOOSE, function(message) message.WriteString(id) end)
        P.FillLateJoinList()
        return true
    end

    local row = GUI.LayoutGroup(Common.CreateRect(0.96, 1, button, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    row.Stretch = true
    row.AbsoluteSpacing = Common.GetGap()
    row.CanBeFocused = false
    local job = JobPrefab.Get(role.Job)
    local sprite = Common.GetRoleIcon(id, role.Job, true)
    if sprite ~= nil then
        local iconRect = GUI.RectTransform(Point(height, height), row.RectTransform)
        iconRect.IsFixedSize = true
        local icon = GUI.Image(iconRect, sprite, true)
        icon.Color = job.UIColor
        icon.CanBeFocused = false
    end

    local color = (locked or not free) and LOCKED_COLOR or nil
    local name = Common.CreateText(row, 0.75, 1, nil, P.GetStationRoleName(id), GUI.Alignment.CenterLeft, 1, color,
        false)
    name.CanBeFocused = false
    Common.SetAutoScaleText(name, 1)
    local seatsText = tostring(seats)
    if not free then
        seatsText = text.LateJoinNoSeats
    elseif seats == Common.NO_SEAT_LIMIT then
        seatsText = text.LateJoinUnlimited
    end
    local count = Common.CreateText(row, 0.25, 1, nil, seatsText, GUI.Alignment.CenterRight, 1, color, false)
    count.CanBeFocused = false
    Common.SetAutoScaleText(count, 1)
end

-- each role once, under the first department that lists it: the heads under Command
function P.FillLateJoinList()
    local list, jobs, seats = S.lateJoinList, S.stationJobs, Common.StationFreeSeats or {}
    list.Content.ClearChildren()
    local height = Common.GetStyleHeight("GUIButtonSmall")
    local shown = {}
    for _, department in ipairs(jobs.Departments) do
        local header
        for _, id in ipairs(department.Roles) do
            local role = jobs.Roles[id]
            if role ~= nil and not shown[id] then
                shown[id] = true
                if header == nil then
                    local title = text.StationDepartments[department.Id] or department.Id
                    header = Common.CreateText(list.Content, 1, 1, nil, title, GUI.Alignment.CenterLeft, 1,
                        Common.StationDepartmentColors[department.Id], false)
                    header.Font = GUI.Style.SubHeadingFont
                    header.CanBeFocused = false
                    Common.FitHeightToText(header)
                end
                createRow(list, id, role, height, seats[id])
            end
        end
    end
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
    -- the list draws its new rows this frame, before their own update would lay them out (GUIListBox.Draw)
    list.ForceLayoutRecalculation()
end

-- A window in the middle of the screen, as SS14's late join. It lives in the lobby's own frame, as the card's windows
-- do (panel.lua): the menu's root is not drawn in the lobby.
function P.ShowLateJoinWindow()
    P.CloseMenu()
    local margin = P.SafeIntScale(10)
    local width = Common.FitWindowWidth(P.SafeIntScale(WIDTH_PIXELS), 320, margin)
    local height = Common.FitWindowHeight(P.SafeIntScale(HEIGHT_PIXELS), 320, margin)
    local root = GUI.Frame(P.CreatePixelRect(width, height, P.GetLobbyGuiFrame(), GUI.Anchor.Center), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    P.SafeSetAsLastChild(root)
    S.currentMenu = root
    S.currentMenuKind = "latejoin"
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = S.currentMenuKind

    local panel = GUI.Frame(P.CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    local content = Common.CreateWindowContent(panel)
    Common.CreateWindowHeader(content, root, text.LateJoinTitle, P.UiText.Cancel, function()
        P.CloseMenu()
        return true
    end)
    -- the only row without a fixed height: it takes the rest of the window
    local listHost = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false
    local _, list = P.CreateMenuList(listHost)
    S.lateJoinList = list
    S.lateJoinPending = nil

    local observe = P.CreateMenuButton(content, text.LateJoinObserve, true)
    observe.ToolTip = text.LateJoinObserveTooltip
    observe.OnClicked = function()
        P.CloseMenu()
        join(true)
        return true
    end

    -- laid out first, so the rows get the list's width
    root.ForceLayoutRecalculation()
    if S.stationJobs ~= nil then P.FillLateJoinList() end
end

-- a new crew list changes the seats left
Common.OnStationCrew = function()
    if S.sharedState.Disabled or S.currentMenuKind ~= "latejoin" or S.stationJobs == nil then return end
    P.FillLateJoinList()
end

-- called from the lobby's tick: the window closes once the round is over
function P.UpdateLateJoin()
    if S.currentMenuKind == "latejoin" and not stationRunning() then P.CloseMenu() end
end

Networking.Receive(NET_RESULT, function(message)
    if S.sharedState.Disabled then return end
    local accepted = message.ReadBoolean()
    local asked = S.lateJoinPending
    S.lateJoinPending = nil
    if asked == "" then
        if accepted then join(false) else P.ShowLateJoinWindow() end
    elseif S.currentMenuKind ~= "latejoin" then
        return
    elseif accepted then
        P.CloseMenu()
        join(false)
    elseif S.stationJobs ~= nil then
        P.FillLateJoinList()
    end
end)

-- The game's join button asks the server during a Station round; the window's buttons join themselves.
local clientType = "Barotrauma.Networking.GameClient"
Hook.Patch("VoidTraitor.Lobby.LateJoin", clientType, "SendJoinOngoingRequest", function(_, ptable)
    if joining or S.sharedState.Disabled or not stationRunning()
        or ptable["joinButton"] ~= Game.NetLobbyScreen.joinOnGoingRoundButton then return end
    if S.lateJoinPending == nil then
        S.lateJoinPending = ""
        P.SendNetMessage(NET_CHOOSE, function(message) message.WriteString("") end)
    end
    ptable.ReturnValue = false
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)
