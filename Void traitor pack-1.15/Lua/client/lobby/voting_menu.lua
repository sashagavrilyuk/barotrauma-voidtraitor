local P = ...
local S = P.State
local Common = P.Common
local text = P.VoteUiText

-- SS14's call vote menu: the votes a player may start, from the lobby's vote button (panel.lua) or the VT menu in a
-- round. Mode and map votes show when they can be started again; an admin also gets their own vote, which opens its
-- editor. The server checks every start again (voting.lua).

-- in 1920x1080 pixels
local MENU_WIDTH = 360
local CUSTOM_WIDTH = 460
local CUSTOM_HEIGHT = 560
local WINDOW_MARGIN = 10
-- the editor's limits in characters; the server's are in bytes (voting.lua)
local TITLE_LENGTH = 100
local OPTION_LENGTH = 60
local MAX_OPTIONS = 10

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- a window in the middle of the screen, in the lobby's frame or the menu's root as the votes' popups are
local function openWindow(kind, width, height, title)
    local parent = P.GetVoteParent()
    if parent == nil then return nil end
    P.CloseMenu()

    local root = GUI.Frame(P.CreatePixelRect(width, height, parent, GUI.Anchor.Center), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    P.SafeSetAsLastChild(root)
    S.currentMenu = root
    S.currentMenuKind = kind
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = kind
    S.voteWindowInLobby = parent ~= S.guiRoot

    local panel = GUI.Frame(P.CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    local content, outer = Common.CreateWindowContent(panel)
    Common.CreateWindowHeader(content, root, title, text.Close, function()
        P.CloseMenu()
        return true
    end)
    return root, content, outer
end

function P.ShowVoteMenu()
    local root, content, outer = openWindow("votes", Common.FitWindowWidth(P.SafeIntScale(MENU_WIDTH), 300,
        P.SafeIntScale(WINDOW_MARGIN)), 1, text.MenuTitle)
    if root == nil then return end

    local ui = { Shown = {} }
    ui.Mode = P.CreateMenuButton(content, text.StartMode)
    ui.Mode.OnClicked = function()
        P.SendVoteStart("game")
        P.CloseMenu()
        return true
    end
    ui.Map = P.CreateMenuButton(content, text.StartMap)
    ui.Map.OnClicked = function()
        P.SendVoteStart("map")
        P.CloseMenu()
        return true
    end
    if P.Admin.IsAvailable() then
        local custom = P.CreateMenuButton(content, text.StartCustom)
        custom.ToolTip = text.CustomTooltip
        custom.OnClicked = function()
            P.ShowCustomVoteWindow()
            return true
        end
    end
    S.voteMenuUi = ui

    root.RectTransform.Resize(Point(root.Rect.Width, Common.GetMinimumHeight(outer)), true)
    root.ForceLayoutRecalculation()
    P.RefreshVoteMenu()
    -- the cooldowns may have changed since the last snapshot
    P.RequestVoteSnapshot()
end

-- on each snapshot and from the menu's tick, for the cooldowns' time
function P.RefreshVoteMenu()
    if S.currentMenuKind ~= "votes" then return end
    local snapshot, ui, now = S.voteSnapshot, S.voteMenuUi, P.GetTime()
    local canStart = snapshot ~= nil and snapshot.CanStart

    local function refresh(button, label, cooldownEndTime)
        local left = math.ceil(cooldownEndTime - now)
        button.Enabled = canStart and left <= 0
        button.ToolTip = (snapshot ~= nil and not canStart) and text.Busy or ""
        local shown = left > 0 and string.format(text.Cooldown, label, P.FormatVoteTime(left)) or label
        if ui.Shown[button] ~= shown then
            ui.Shown[button] = shown
            button.Text = shown
        end
    end
    refresh(ui.Mode, text.StartMode, snapshot ~= nil and snapshot.GameCooldownEndTime or 0)
    refresh(ui.Map, snapshot ~= nil and snapshot.StationMap and text.StartStation or text.StartMap,
        snapshot ~= nil and snapshot.MapCooldownEndTime or 0)
end

-- The editor of an admin's own vote: a title and two to ten options. It is built again when an option is added or
-- removed; the draft keeps what was typed until the vote is started.
function P.ShowCustomVoteWindow()
    local draft = S.customVoteDraft or { Title = "", Options = { "", "" } }
    S.customVoteDraft = draft
    local margin = P.SafeIntScale(WINDOW_MARGIN)
    local root, content = openWindow("customvote", Common.FitWindowWidth(P.SafeIntScale(CUSTOM_WIDTH), 320, margin),
        Common.FitWindowHeight(P.SafeIntScale(CUSTOM_HEIGHT), 320, margin), text.CustomTitle)
    if root == nil then return end

    local start
    local function refreshStart()
        local filled = 0
        for _, option in ipairs(draft.Options) do
            if trim(option) ~= "" then filled = filled + 1 end
        end
        start.Enabled = trim(draft.Title) ~= "" and filled >= 2
    end

    local rowHeight = Common.GetStyleHeight("GUIButton")
    local function addLabel(value)
        local label = Common.CreateText(content, 1, 1, nil, value, GUI.Alignment.CenterLeft, 1, nil, false)
        Common.FitHeightToText(label)
        label.CanBeFocused = false
    end

    addLabel(text.Question)
    local title = GUI.TextBox(Common.CreateRect(1, 1, content), draft.Title)
    Common.SetFixedHeight(title, rowHeight)
    title.MaxTextLength = TITLE_LENGTH
    title.OnTextChangedDelegate = function(_, value)
        draft.Title = value
        refreshStart()
        return true
    end

    addLabel(text.Options)
    -- the only row without a fixed height: it takes the rest of the window
    local listHost = GUI.Frame(Common.CreateRect(1, 1, content), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false
    local _, list = P.CreateMenuList(listHost)
    for index, option in ipairs(draft.Options) do
        local row = GUI.LayoutGroup(Common.CreateRect(1, 1, list.Content), true, GUI.Anchor.CenterLeft)
        Common.SetFixedHeight(row, rowHeight)
        row.Stretch = true
        row.AbsoluteSpacing = Common.GetGap()
        row.CanBeFocused = false
        local number = Common.CreateText(row, 0.08, 1, nil, tostring(index), GUI.Alignment.Center, 1, nil, false)
        number.CanBeFocused = false
        local box = GUI.TextBox(Common.CreateRect(0.8, 1, row), option)
        box.MaxTextLength = OPTION_LENGTH
        box.OnTextChangedDelegate = function(_, value)
            draft.Options[index] = value
            refreshStart()
            return true
        end
        local remove = GUI.Button(GUI.RectTransform(Point(rowHeight, rowHeight), row.RectTransform), "", GUI.Alignment.Center,
            "GUICancelButton")
        remove.RectTransform.IsFixedSize = true
        remove.ToolTip = text.RemoveOption
        remove.Enabled = #draft.Options > 2
        remove.OnClicked = function()
            table.remove(draft.Options, index)
            P.ShowCustomVoteWindow()
            return true
        end
    end

    local add = P.CreateMenuButton(content, text.AddOption, #draft.Options < MAX_OPTIONS)
    add.OnClicked = function()
        table.insert(draft.Options, "")
        P.ShowCustomVoteWindow()
        return true
    end

    start = P.CreateMenuButton(content, text.Start)
    start.OnClicked = function()
        local options = {}
        for _, option in ipairs(draft.Options) do
            if trim(option) ~= "" then options[#options + 1] = trim(option) end
        end
        P.SendCustomVote(trim(draft.Title), options)
        S.customVoteDraft = nil
        P.CloseMenu()
        return true
    end
    refreshStart()

    -- laid out now, or the rows show unplaced for a frame (menu_window.lua)
    root.ForceLayoutRecalculation()
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
end
