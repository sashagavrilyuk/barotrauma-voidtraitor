local P = ...
local S = P.State
local Common = P.Common
local text = P.VoteUiText

-- SS14's call vote menu as a list under the vote button, in the lobby (panel.lua) and in a round's VT menu: the votes a
-- player may start, a mode or map vote with the time until it can be started again, and for an admin their own vote,
-- which opens its editor. The server checks every start again (voting.lua).

-- in 1920x1080 pixels; the vote list is at least this wide
local LIST_WIDTH = 190
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

-- the votes the player may start now: one of each kind runs at a time
local function getVoteChoices()
    local snapshot = S.voteSnapshot or {}
    local choices = {
        { Type = "game", Label = text.StartMode, CanStart = snapshot.CanStartGame, CooldownEndTime = snapshot.GameCooldownEndTime },
        { Type = "map", Label = snapshot.StationMap and text.StartStation or text.StartMap, CanStart = snapshot.CanStartMap,
            CooldownEndTime = snapshot.MapCooldownEndTime },
    }
    if P.Admin.IsAvailable() then
        choices[3] = { Type = "custom", Label = text.StartCustom, ToolTip = text.CustomTooltip, CanStart = snapshot.CanStartCustom }
    end
    return choices
end

-- The open list's labels and which of them can be picked, on each snapshot and from the menu's tick for the
-- cooldowns' time.
function P.RefreshVoteList()
    local ui, now = S.voteList, P.GetTime()
    if ui == nil then return end
    for index, choice in ipairs(getVoteChoices()) do
        local button = ui.Buttons[index]
        if button == nil then break end
        local left = math.ceil((choice.CooldownEndTime or 0) - now)
        button.Enabled = choice.CanStart == true and left <= 0
        button.ToolTip = choice.CanStart == false and text.Busy or choice.ToolTip or ""
        local shown = left > 0 and string.format(text.Cooldown, choice.Label, P.FormatVoteTime(left)) or choice.Label
        if ui.Shown[index] ~= shown then
            ui.Shown[index] = shown
            button.Text = shown
        end
    end
end

function P.CloseVoteList()
    if S.voteList == nil then return end
    Common.RemoveGuiComponent(S.voteList.Panel)
    S.voteList = nil
end

-- The list of votes to start, as before the lobby's rework: small buttons in a frame right under the vote button, in
-- the lobby's frame or the VT menu's window (host). The vote button opens and closes it, and so do picking a vote and
-- closing the menu's window (P.CloseMenu).
function P.ToggleVoteList(button, host)
    local own = S.voteList ~= nil and S.voteList.Button == button
    P.CloseVoteList()
    if own or host == nil then return end

    local ui, choices = { Button = button, Buttons = {}, Shown = {} }, getVoteChoices()
    local rowHeight, gap = Common.GetStyleHeight("GUIButtonSmall"), Common.GetButtonSpacing()
    local width = math.max(button.Rect.Width, P.SafeIntScale(LIST_WIDTH))
    local height = #choices * rowHeight + (#choices + 1) * gap
    -- right edge on the button's, so it stays on the screen beside the lobby's right edge
    local rect = GUI.RectTransform(Point(width, height), host.RectTransform, GUI.Anchor.TopLeft)
    rect.AbsoluteOffset = Point(button.Rect.Right - width - host.Rect.X, button.Rect.Bottom + gap - host.Rect.Y)
    ui.Panel = GUI.Frame(rect, "GUIFrame")
    ui.Panel.IgnoreLayoutGroups = true
    for index, choice in ipairs(choices) do
        local optionRect = GUI.RectTransform(Point(width - gap * 2, rowHeight), ui.Panel.RectTransform, GUI.Anchor.TopCenter)
        optionRect.AbsoluteOffset = Point(0, gap + (index - 1) * (rowHeight + gap))
        local option = GUI.Button(optionRect, choice.Label, GUI.Alignment.Center, "GUIButtonSmall")
        Common.SetAutoScaleText(option.TextBlock, 1)
        option.OnClicked = function()
            P.CloseVoteList()
            if choice.Type == "custom" then P.ShowCustomVoteWindow() else P.SendVoteStart(choice.Type) end
            return true
        end
        ui.Buttons[index] = option
    end
    S.voteList = ui
    P.RefreshVoteList()
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
