local P = ...
local S = P.State
local Common = P.Common
local text = P.VoteUiText

-- The running votes as SS14's vote popups, stacked at the top left: in the lobby under the server banner, in a round
-- under the SHOP and VT buttons. Each tells who started it, its title, its options as buttons with their votes and the
-- time left, and stays until the vote ends.

-- in 1920x1080 pixels; SS14's popups are 300 to 500 pixels wide
local POPUP_WIDTH = 300
-- a map vote can have many options; more than this many scroll
local VISIBLE_OPTIONS = 6
local CALLER_COLOR = Color(170, 175, 165, 255)
local TITLE_COLOR = Color(235, 205, 145, 255)
local BAR_COLOR = Color(120, 170, 130, 255)

function P.FormatVoteTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getVoteTitle(vote)
    if vote.Type == "custom" then return vote.Title end
    if vote.Type == "station" then return text.StationTitle end
    if vote.Type == "map" then return text.MapTitle end
    return text.GameTitle
end

-- the popups' top left corner within their parent
local function getPopupOrigin(parent)
    if parent == S.guiRoot then
        if S.buttonRoot == nil then return nil end
        local spacing = P.GetTopButtonSpacing()
        return spacing, S.buttonRoot.Rect.Y + S.buttonRoot.Rect.Height + spacing
    end
    local banner = S.lobbyPanel ~= nil and S.lobbyPanel.Banner or nil
    if banner == nil then return nil end
    return banner.Rect.X - parent.Rect.X, banner.Rect.Y + banner.Rect.Height - parent.Rect.Y + Common.GetGap()
end

local function createPopup(column, vote, width)
    local frame = GUI.Frame(GUI.RectTransform(Point(width, 1), column.RectTransform), "GUIFrame")
    local content, outer = Common.CreateWindowContent(frame)

    local caller = Common.CreateText(content, 1, 1, nil, string.format(text.StartedBy, vote.StartedBy),
        GUI.Alignment.Left, 1, CALLER_COLOR, false)
    caller.Font = GUI.Style.SmallFont
    Common.FitHeightToText(caller)
    Common.SetAutoScaleText(caller, 1)
    caller.CanBeFocused = false

    local title = Common.CreateText(content, 1, 1, nil, getVoteTitle(vote), GUI.Alignment.Left, 1, TITLE_COLOR, true)
    title.CanBeFocused = false

    -- the small buttons of the lobby's round lines (panel.lua)
    local buttonHeight, spacing = Common.GetStyleHeight("GUIButtonSmall"), Common.GetButtonSpacing()
    local rows = math.min(#vote.Options, VISIBLE_OPTIONS)
    local list = GUI.ListBox(Common.CreateRect(1, 1, content), false, nil, "GUIListBoxNoBorder")
    -- The list style pads its content; the rows get no spacing after the last one, so the list's black is as wide
    -- below them as above. The list counts that spacing too (GUIListBox.TotalSize) and would scroll by it, so it scrolls
    -- only when there are more rows than it shows.
    Common.SetFixedHeight(list, rows * buttonHeight + (rows - 1) * spacing + math.ceil(list.Padding.Y + list.Padding.W))
    list.Spacing = spacing
    list.KeepSpaceForScrollBar = #vote.Options > VISIBLE_OPTIONS
    list.ScrollBarEnabled = #vote.Options > VISIBLE_OPTIONS
    local buttons = {}
    for index, option in ipairs(vote.Options) do
        local button = GUI.Button(Common.CreateRect(1, 1, list.Content),
            string.format(text.OptionVotes, option.Text, option.Votes), GUI.Alignment.Center, "GUIButtonSmall")
        Common.SetAutoScaleText(button.TextBlock, 1)
        -- the player's choice stays selected, as SS14 keeps its button pressed; the vanilla fonts have no check mark
        button.Selected = option.Selected
        button.TextBlock.SelectedTextColor = TITLE_COLOR
        button.TextBlock.HoverSelectedTextColor = TITLE_COLOR
        button.OnClicked = function()
            P.SendVoteCast(vote.Id, index)
            -- the choice moves at once; the server's snapshot with the new counts follows
            for other, otherButton in ipairs(buttons) do otherButton.Selected = other == index end
            return true
        end
        buttons[index] = button
    end

    local timeRow = GUI.LayoutGroup(Common.CreateRect(1, 1, content), true, GUI.Anchor.CenterLeft)
    timeRow.Stretch = true
    timeRow.AbsoluteSpacing = Common.GetGap()
    timeRow.CanBeFocused = false
    Common.SetFixedHeight(timeRow, Common.GetTextHeight(GUI.Style.Font))
    local bar = GUI.ProgressBar(Common.CreateRect(0.8, 1, timeRow), 1, BAR_COLOR)
    local time = Common.CreateText(timeRow, 0.2, 1, nil, "", GUI.Alignment.CenterRight, 1, nil, false)
    time.CanBeFocused = false

    -- laid out first, so the title wraps at the popup's width and the frame can take the rows' height
    frame.ForceLayoutRecalculation()
    title.CalculateHeightFromText()
    Common.SetFixedHeight(title, title.Rect.Height)
    frame.RectTransform.Resize(Point(width, Common.GetMinimumHeight(outer)), true)
    frame.ForceLayoutRecalculation()
    list.RecalculateChildren()
    list.UpdateScrollBarSize()
    return { Frame = frame, Bar = bar, Time = time, EndTime = vote.EndTime, Duration = vote.Duration,
        Shown = "" }
end

function P.RemoveVotePopups()
    Common.RemoveGuiComponent(S.votePopups)
    S.votePopups = nil
    S.sharedState.VotePopupRoot = nil
end

-- rebuilt on each snapshot, which comes only when a vote starts, ends or gets a vote
function P.BuildVotePopups()
    P.RemoveVotePopups()
    local votes = S.voteSnapshot ~= nil and S.voteSnapshot.Votes or {}
    local parent = P.GetVoteParent()
    if #votes == 0 or parent == nil then return end
    local x, y = getPopupOrigin(parent)
    if x == nil then return end

    local width = P.SafeIntScale(POPUP_WIDTH)
    local column = GUI.LayoutGroup(GUI.RectTransform(Point(width, 1), parent.RectTransform, GUI.Anchor.TopLeft), false)
    column.RectTransform.AbsoluteOffset = Point(math.floor(x), math.floor(y))
    column.AbsoluteSpacing = Common.GetGap()
    column.IgnoreLayoutGroups = true
    column.CanBeFocused = false

    local popups = {}
    local height = 0
    for index, vote in ipairs(votes) do
        popups[index] = createPopup(column, vote, width)
        height = height + popups[index].Frame.Rect.Height + (index > 1 and column.AbsoluteSpacing or 0)
    end
    -- the popups keep their own size: resizing children would scale them from the column's first height
    column.RectTransform.Resize(Point(width, height), false)
    P.SafeSetAsLastChild(column)

    S.votePopups = column
    S.votePopupParent = parent
    S.votePopupScreenWidth, S.votePopupScreenHeight = P.GetScreenSize()
    S.votePopupRows = popups
    S.sharedState.VotePopupRoot = column
    P.UpdateVotePopups()
end

-- called from the menu's tick: the time left, and the popups move along when the screen or its size changes
function P.UpdateVotePopups()
    local votes = S.voteSnapshot ~= nil and S.voteSnapshot.Votes or {}
    local width, height = P.GetScreenSize()
    if (S.votePopups == nil and #votes > 0) or (S.votePopups ~= nil and (S.votePopupParent ~= P.GetVoteParent()
        or S.votePopupScreenWidth ~= width or S.votePopupScreenHeight ~= height)) then
        P.BuildVotePopups()
        return
    end
    if S.votePopups == nil then return end

    local now = P.GetTime()
    for _, popup in ipairs(S.votePopupRows) do
        local left = popup.EndTime - now
        popup.Bar.BarSize = math.max(0, math.min(1, left / popup.Duration))
        local shown = P.FormatVoteTime(left)
        if popup.Shown ~= shown then
            popup.Shown = shown
            popup.Time.Text = shown
        end
    end
end
