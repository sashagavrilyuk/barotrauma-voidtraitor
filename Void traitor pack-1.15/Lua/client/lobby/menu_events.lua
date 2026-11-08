local P = ...
local S = P.State

-- Admin window with the events of one tab (Station or Secret): search, sections, why an event can't start now and the
-- start button. Names and descriptions come from the pack language; the server checks the admin and starts the event
-- (traitormod Lua/clientmenu.lua and the !triggerevent command).
local DEFAULT_WIDTH_PIXELS = 620
local DEFAULT_HEIGHT_PIXELS = 720
local MIN_WIDTH_PIXELS = 420
local MIN_HEIGHT_PIXELS = 400
local CATEGORY_ORDER = { "Help", "Bonuses", "Repairs", "Breakdowns", "Threats", "Pirates", "Sabotage", "Other" }

local text = P.Common.Language.AdminMenu
local searchTextById = {}
local view = nil

S.eventsTab = "station"
S.eventsSearch = ""
S.eventsSelected = nil

local function getEntry(eventId)
    return text.Events[eventId] or { Name = eventId, Description = "" }
end

local function matchesSearch(event, query)
    if query == "" then return true end
    local searchText = searchTextById[event.Id]
    if searchText == nil then
        local entry = getEntry(event.Id)
        searchText = P.Common.NormalizeSearchText(entry.Name .. " " .. entry.Description .. " " .. event.Id)
        searchTextById[event.Id] = searchText
    end
    return string.find(searchText, query, 1, true) ~= nil
end

-- the Secret tab is split into sections, the short Station tab is one list
local function getGroups()
    local query = P.Common.NormalizeSearchText(S.eventsSearch)
    local groups, groupById = {}, {}
    for _, event in ipairs(P.Admin.GetEvents()) do
        local inTab = S.eventsTab == "station" and event.Station or S.eventsTab == "secret" and event.Secret
        if inTab and matchesSearch(event, query) then
            local groupId = S.eventsTab == "secret" and (getEntry(event.Id).Category or "Other") or "All"
            if groupById[groupId] == nil then
                groupById[groupId] = {}
                groups[#groups + 1] = groupId
            end
            table.insert(groupById[groupId], event)
        end
    end

    local order = {}
    for index, groupId in ipairs(CATEGORY_ORDER) do order[groupId] = index end
    table.sort(groups, function(a, b) return (order[a] or #CATEGORY_ORDER) < (order[b] or #CATEGORY_ORDER) end)
    local result = {}
    for _, groupId in ipairs(groups) do
        local events = groupById[groupId]
        table.sort(events, function(a, b) return getEntry(a.Id).Name < getEntry(b.Id).Name end)
        result[#result + 1] = { Id = groupId, Events = events }
    end
    return result
end

local function findEvent(eventId)
    for _, event in ipairs(P.Admin.GetEvents()) do
        if event.Id == eventId then return event end
    end
end

-- The description and the details wrap to the width of the list, so the rows get their height again whenever that
-- width changes.
local function layoutRows()
    local gap = P.Common.GetGap()
    for _, row in ipairs(view.Rows) do
        local nameHeight = row.Name.Rect.Height
        local descriptionHeight = math.ceil(row.Description.TextSize.Y)
        local detailsHeight = math.ceil(row.Details.TextSize.Y)
        P.Common.SetFixedHeight(row.Description, descriptionHeight)
        P.Common.SetFixedHeight(row.Details, detailsHeight)
        row.Description.RectTransform.AbsoluteOffset = Point(0, gap + nameHeight)
        row.Details.RectTransform.AbsoluteOffset = Point(0, gap + nameHeight + descriptionHeight)
        P.Common.SetFixedHeight(row.Button, gap * 2 + nameHeight + descriptionHeight + detailsHeight)
    end
    view.LayoutWidth = view.List.Content.Rect.Width
    view.List:RecalculateChildren()
    view.List:UpdateScrollBarSize()
end

local function refreshSelection()
    for _, row in ipairs(view.Rows) do row.Button.Selected = row.Event.Id == S.eventsSelected end

    local event = findEvent(S.eventsSelected)
    local button = view.StartButton
    button.TextBlock.Text = event ~= nil and text.StartEvent .. ": " .. getEntry(event.Id).Name or text.StartEvent
    -- the label shrinks to fit the button and starts from full size for every new label
    button.TextBlock.TextScale = 1
    button.Enabled = event ~= nil and event.State == ""
    button.ToolTip = event ~= nil and text.EventStates[event.State] or ""
end

local function createRow(event)
    local entry = getEntry(event.Id)
    local available = event.State == ""
    local button = GUI.Button(P.CreateRect(1, 0, view.List.Content, nil), "", GUI.Alignment.Left, "ListBoxElement")
    button.OnClicked = function()
        S.eventsSelected = event.Id
        refreshSelection()
        return true
    end

    local name = P.CreateText(button, 0.96, 0, GUI.Anchor.TopCenter, entry.Name, GUI.Alignment.TopLeft, 1,
        available and Color(235, 235, 225, 255) or Color(150, 150, 145, 255), false)
    name.Font = GUI.Style.Font
    P.Common.FitHeightToText(name)
    name.RectTransform.AbsoluteOffset = Point(0, P.Common.GetGap())

    local description = P.CreateText(button, 0.96, 0, GUI.Anchor.TopCenter, entry.Description, GUI.Alignment.TopLeft, 1,
        available and Color(190, 205, 190, 255) or Color(130, 130, 125, 255), true)
    description.Font = GUI.Style.SmallFont

    local details = event.Id
    if not available then details = details .. " — " .. (text.EventStates[event.State] or event.State) end
    local detailsBlock = P.CreateText(button, 0.96, 0, GUI.Anchor.TopCenter, details, GUI.Alignment.TopLeft, 1,
        available and Color(125, 140, 125, 255) or Color(215, 160, 95, 255), true)
    detailsBlock.Font = GUI.Style.SmallFont

    for _, block in ipairs({ name, description, detailsBlock }) do block.CanBeFocused = false end
    table.insert(view.Rows, { Button = button, Name = name, Description = description, Details = detailsBlock, Event = event })
end

local function buildRows(keepScroll)
    local list = view.List
    local scroll = keepScroll and list.BarScroll or 0
    list.Content:ClearChildren()
    view.Rows = {}

    local groups = getGroups()
    for index, group in ipairs(groups) do
        if group.Id ~= "All" then
            if index > 1 then P.CreateDivider(list.Content) end
            P.CreateCategoryHeader(list.Content, text.EventCategories[group.Id] or group.Id).CanBeFocused = false
        end
        for _, event in ipairs(group.Events) do createRow(event) end
    end
    if #groups == 0 then
        local empty = P.CreateText(list.Content, 1, 0, nil, text.NoEventsFound, GUI.Alignment.Center, 1, Color(195, 195, 185, 255), true)
        P.Common.FitHeightToText(empty)
        empty.CanBeFocused = false
    end

    local selectedShown = false
    for _, row in ipairs(view.Rows) do
        if row.Event.Id == S.eventsSelected then selectedShown = true end
    end
    if not selectedShown then S.eventsSelected = nil end

    layoutRows()
    list.BarScroll = scroll
    refreshSelection()
end

local function startEvent(eventId)
    local entry = getEntry(eventId)
    if not entry.Confirm then
        P.Admin.TriggerEvent(eventId)
        return
    end
    P.ShowConfirm(text.ConfirmEventTitle, string.format(text.ConfirmEvent, entry.Name),
        function() P.Admin.TriggerEvent(eventId) end,
        function() P.ShowEventsWindow(S.eventsTab) end)
end

function P.ShowEventsWindow(tab)
    P.CloseMenu()
    S.eventsTab = tab

    local screenWidth, screenHeight = P.GetScreenSize()
    local margin = P.SafeIntScale(10)
    local minimumWidth = P.SafeIntScale(MIN_WIDTH_PIXELS)
    local minimumHeight = P.SafeIntScale(MIN_HEIGHT_PIXELS)
    local width = P.Clamp(S.eventsWidth or P.SafeIntScale(DEFAULT_WIDTH_PIXELS), minimumWidth, math.max(minimumWidth, screenWidth - margin * 2))
    local height = P.Clamp(S.eventsHeight or P.SafeIntScale(DEFAULT_HEIGHT_PIXELS), minimumHeight, math.max(minimumHeight, screenHeight - margin * 2))
    local x = P.Clamp(S.eventsX or math.floor((screenWidth - width) / 2), margin, math.max(margin, screenWidth - width - margin))
    local y = P.Clamp(S.eventsY or math.floor((screenHeight - height) / 2), margin, math.max(margin, screenHeight - height - margin))

    local rootRect = P.CreatePixelRect(width, height, S.guiRoot, GUI.Anchor.TopLeft)
    rootRect.AbsoluteOffset = Point(x, y)
    local root = GUI.Frame(rootRect, nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    S.currentMenu = root
    S.currentMenuKind = "events"
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = S.currentMenuKind
    view = { Root = root, Rows = {}, MinimumHeight = minimumHeight }

    local panel = GUI.Frame(P.CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false
    local content = P.Common.CreateWindowContent(panel)

    -- the window was opened from the admin tab, so closing it goes back there
    P.Common.CreateWindowHeader(content, root, text.EventsTitle, P.UiText.Cancel, function()
        P.CloseMenu()
        P.ShowVoidTraitorMenu()
        return true
    end)

    local tabs = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
    P.Common.SetFixedHeight(tabs, P.Common.GetStyleHeight("GUIButton"))
    tabs.Color = Color(0, 0, 0, 0)
    tabs.CanBeFocused = false
    local tabButtons = {
        station = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterLeft), text.StationEvents, GUI.Alignment.Center, "GUITabButton"),
        secret = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterRight), text.SecretEvents, GUI.Alignment.Center, "GUITabButton"),
    }
    for id, button in pairs(tabButtons) do
        P.SetButtonTextScale(button, 0.82)
        button.Selected = id == S.eventsTab
        button.OnClicked = function()
            if S.eventsTab == id then return true end
            S.eventsTab = id
            for otherId, other in pairs(tabButtons) do other.Selected = otherId == id end
            buildRows(false)
            return true
        end
    end

    local searchRow = GUI.LayoutGroup(P.CreateRect(1, 1, content, nil), true, GUI.Anchor.CenterLeft)
    P.Common.SetFixedHeight(searchRow, P.Common.GetStyleHeight("GUIButton"))
    searchRow.Stretch = true
    searchRow.AbsoluteSpacing = P.Common.GetGap()
    local searchLabel = P.CreateText(searchRow, 0.2, 1, nil, text.Search, GUI.Alignment.Left, 1, Color(210, 220, 200, 255), false)
    P.Common.SetFixedWidth(searchLabel, math.ceil(searchLabel.TextSize.X + searchLabel.Padding.X + searchLabel.Padding.Z))
    local search = GUI.TextBox(P.CreateRect(0.8, 1, searchRow, nil), S.eventsSearch)
    search.OnTextChangedDelegate = function(_, value)
        S.eventsSearch = tostring(value or "")
        buildRows(false)
        return true
    end

    -- the only row without a fixed height: it takes the space left when the window is resized
    local listHost = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false
    local _, list = P.CreateMenuList(listHost)
    view.List = list

    view.StartButton = P.CreateMenuButton(content, text.StartEvent, false)
    view.StartButton.OnClicked = function()
        if S.eventsSelected ~= nil then startEvent(S.eventsSelected) end
        return true
    end

    view.ResizeTop, view.ResizeBottom = {}, {}
    view.ResizeSides = { left = {}, right = {}, minimumWidth = minimumWidth }
    P.Common.AddResizeHandles(panel, view.ResizeTop, view.ResizeBottom, view.ResizeSides)

    buildRows(false)
    -- the states may be old by now; the answer rebuilds the list
    P.Admin.RefreshData()
end

-- called every frame from the menu's think hook; does nothing while the window is closed
function P.UpdateEventsWindowInteraction()
    if view == nil or S.currentMenu ~= view.Root then return end

    view.ResizeState = P.Common.UpdateMenuInteraction(S.currentMenu, view.ResizeState, view.ResizeTop,
        view.ResizeBottom, view.MinimumHeight, view.List, nil, nil, nil, view.ResizeSides)
    local rect = S.currentMenu.Rect
    S.eventsX, S.eventsY, S.eventsWidth, S.eventsHeight = rect.X, rect.Y, rect.Width, rect.Height
    if view.List.Content.Rect.Width ~= view.LayoutWidth then layoutRows() end
end

P.Admin.OnDataChanged = function()
    if view ~= nil and S.currentMenu == view.Root then buildRows(true) end
end
