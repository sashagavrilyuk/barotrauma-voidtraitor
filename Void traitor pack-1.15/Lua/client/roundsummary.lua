if SERVER then return end

local packPath, Common = ...
local NET_SUMMARY = "VoidTraitor_RoundSummary"
local STATE_KEY = "VoidTraitorRoundSummaryState"
local HUD_PATCH_ID = "VoidTraitor.RoundSummary.Hud"
local LOBBY_PATCH_ID = "VoidTraitor.RoundSummary.Lobby"
local VANILLA_PATCH_ID = "VoidTraitor.RoundSummary.Vanilla"

local previousState = rawget(_G, STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
end

local state = { Disabled = false }
_G[STATE_KEY] = state

local currentMenu = nil
-- the last summary the server sent and its player manifest (Station), which F9 opens again
local lastSummary = nil
local lastManifest = {}
local summaryList = nil
local manifestList = nil
-- the tab shown and how the manifest is sorted, kept while the game runs
local shownTab = "summary"
local sortField = "Type"
local sortDescending = false
local resizeTopTargets = {}
local resizeBottomTargets = {}
local resizeSideTargets = {}
local resizeState = nil
local menuX = nil
local menuY = nil
local menuWidth = nil
local menuHeight = nil

local DEFAULT_WIDTH_PIXELS = 450
-- wide enough for the manifest's columns
local MANIFEST_WIDTH_PIXELS = 660
local DEFAULT_HEIGHT_PIXELS = 630
local MIN_WIDTH_PIXELS = 370
local MIN_HEIGHT_PIXELS = 370
local MENU_DRAW_ORDER = 124
local ANTAGONIST_COLOR = Color(255, 95, 90, 255)
local OBSERVER_COLOR = Color(150, 150, 145, 255)
local PLAYER_COLOR = Color(185, 185, 175, 255)
local COLUMNS = { { Field = "Name", Width = 0.30 }, { Field = "Role", Width = 0.26 }, { Field = "Type", Width = 0.20 }, { Field = "Player", Width = 0.24 } }

local text = Common.Language.RoundSummary

local SafeIntScale = Common.SafeIntScale
local GetScreenSize = Common.GetScreenSize
local CreateRect = Common.CreateRect
local CreateCanvasRect = Common.CreateCanvasRect
local Clamp = Common.Clamp

local function saveGeometry()
    if currentMenu == nil then return end
    menuX = currentMenu.Rect.X
    menuY = currentMenu.Rect.Y
    menuWidth = currentMenu.Rect.Width
    menuHeight = currentMenu.Rect.Height
end

local function closeSummary()
    saveGeometry()
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeSideTargets = {}
    resizeState = nil
    summaryList = nil
    manifestList = nil

    if currentMenu ~= nil then
        Common.RemoveGuiComponent(currentMenu)
        currentMenu = nil
    end

    state.MenuRoot = nil
end

state.CloseMenu = closeSummary

local function addResizeTarget(panel, edge, width, height, anchor)
    local target = GUI.Frame(CreateRect(width, height, panel, anchor), nil)
    target.Color = Color(0, 0, 0, 0)
    target.CanBeFocused = false
    if edge == "top" then
        table.insert(resizeTopTargets, target)
    elseif edge == "bottom" then
        table.insert(resizeBottomTargets, target)
    elseif edge == "left" or edge == "right" then
        table.insert(resizeSideTargets[edge], target)
    else
        table.insert(resizeSideTargets.corners, { Handle = target, Edge = edge })
    end
end

local function addResizeHandles(panel)
    resizeTopTargets = {}
    resizeBottomTargets = {}
    resizeSideTargets = { left = {}, right = {}, corners = {}, minimumWidth = SafeIntScale(MIN_WIDTH_PIXELS) }

    addResizeTarget(panel, "top-left", 0.05, 0.05, GUI.Anchor.TopLeft)
    addResizeTarget(panel, "top-right", 0.05, 0.05, GUI.Anchor.TopRight)
    addResizeTarget(panel, "bottom-left", 0.05, 0.05, GUI.Anchor.BottomLeft)
    addResizeTarget(panel, "bottom-right", 0.05, 0.05, GUI.Anchor.BottomRight)

    addResizeTarget(panel, "top", 0.90, 0.025, GUI.Anchor.TopCenter)
    addResizeTarget(panel, "bottom", 0.90, 0.025, GUI.Anchor.BottomCenter)
    addResizeTarget(panel, "left", 0.025, 0.90, GUI.Anchor.CenterLeft)
    addResizeTarget(panel, "right", 0.025, 0.90, GUI.Anchor.CenterRight)

    local topIndicator = GUI.Image(CreateRect(0.18, 0.018, panel, GUI.Anchor.TopCenter), "GUIDragIndicatorHorizontal")
    topIndicator.CanBeFocused = false
    local bottomIndicator = GUI.Image(CreateRect(0.18, 0.018, panel, GUI.Anchor.BottomCenter), "GUIDragIndicatorHorizontal")
    bottomIndicator.CanBeFocused = false
    local leftIndicator = GUI.Image(CreateRect(0.018, 0.18, panel, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    leftIndicator.CanBeFocused = false
    local rightIndicator = GUI.Image(CreateRect(0.018, 0.18, panel, GUI.Anchor.CenterRight), "GUIDragIndicator")
    rightIndicator.CanBeFocused = false
end

local function updateResize()
    resizeState, menuX, menuY, menuHeight = Common.UpdateMenuInteraction(currentMenu,
        resizeState, resizeTopTargets, resizeBottomTargets, SafeIntScale(MIN_HEIGHT_PIXELS),
        shownTab == "manifest" and manifestList or summaryList, menuX, menuY, menuHeight, resizeSideTargets)
    if currentMenu ~= nil then menuWidth = currentMenu.Rect.Width end
end

-- what a manifest row is, as the server sends it (Traitormod.SendRoundSummary)
local CREW, GHOST, OBSERVER = 0, 1, 2

-- antagonists first, then the crew, ghost roles and observers, as SS14 sorts its manifest by player type
local function typeRank(row)
    if row.Antagonist ~= "" then return 0 end
    return row.Kind + 1
end

local function typeText(row)
    if row.Antagonist ~= "" then return text.Antagonists[row.Antagonist] or row.Antagonist end
    if row.Kind == OBSERVER then return text.Observer end
    return row.Kind == GHOST and text.GhostRole or text.Crew
end

local function sortKey(row, field)
    if field == "Type" then return typeRank(row) end
    return row.Keys[field]
end

local function addManifestRow(row, height)
    local line = GUI.LayoutGroup(CreateRect(1, 1, manifestList.Content), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(line, height)
    line.Stretch = true
    line.AbsoluteSpacing = Common.GetGap()
    line.CanBeFocused = false
    local job = row.Job ~= "" and JobPrefab.Prefabs.ContainsKey(row.Job) and JobPrefab.Get(row.Job) or nil
    local sprite = job ~= nil and (job.IconSmall or job.Icon) or nil
    if sprite ~= nil then
        local icon = GUI.Image(GUI.RectTransform(Point(height, height), line.RectTransform), sprite, true)
        icon.Color = job.UIColor
        icon.CanBeFocused = false
    else
        local blank = GUI.Frame(GUI.RectTransform(Point(height, height), line.RectTransform), nil)
        blank.Color = Color(0, 0, 0, 0)
        blank.CanBeFocused = false
    end
    local antagonist = row.Antagonist ~= ""
    local muted = row.Kind == OBSERVER and OBSERVER_COLOR or nil
    local values = {
        Name = { row.Name, antagonist and ANTAGONIST_COLOR or muted },
        Role = { row.Role ~= "" and row.Role or text.NoRole, muted },
        Type = { typeText(row), antagonist and ANTAGONIST_COLOR or muted },
        Player = { row.Player, muted or PLAYER_COLOR },
    }
    for _, column in ipairs(COLUMNS) do
        local value = values[column.Field]
        -- cut at the column, as SS14's manifest clips; the whole text is in the tooltip
        local block = Common.CreateText(line, column.Width, 1, nil, value[1], GUI.Alignment.CenterLeft, 1, value[2], false)
        block.OverflowClip = true
        block.ToolTip = value[1]
    end
end

-- the rows that match the search, in the chosen order
local function fillManifest(query)
    if manifestList == nil then return end
    manifestList.Content.ClearChildren()
    local rows = {}
    for _, row in ipairs(lastManifest) do
        if query == "" or string.find(row.Search, query, 1, true) then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
        local keyA, keyB = sortKey(a, sortField), sortKey(b, sortField)
        if keyA == keyB then return a.Keys.Name < b.Keys.Name end
        if sortDescending then return keyA > keyB end
        return keyA < keyB
    end)
    local height = Common.GetStyleHeight("GUIButtonSmall")
    for _, row in ipairs(rows) do addManifestRow(row, height) end
    manifestList:RecalculateChildren()
    manifestList:UpdateScrollBarSize()
end

-- SS14's player manifest: search, column headers that sort, one row per character a player controlled
local function createManifest(parent)
    local root = GUI.LayoutGroup(CreateRect(0.985, 0.975, parent, GUI.Anchor.Center), false)
    root.Stretch = true
    root.AbsoluteSpacing = Common.GetGap()
    local height = Common.GetStyleHeight("GUIButtonSmall")

    local searchRow = GUI.LayoutGroup(CreateRect(1, 1, root), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(searchRow, Common.GetStyleHeight("GUITextBox"))
    searchRow.Stretch = true
    searchRow.AbsoluteSpacing = Common.GetGap()
    local searchLabel = Common.CreateText(searchRow, 0.2, 1, nil, text.Search, GUI.Alignment.CenterLeft, 1, nil, false)
    Common.SetFixedWidth(searchLabel, math.ceil(searchLabel.TextSize.X + searchLabel.Padding.X + searchLabel.Padding.Z))
    local search = GUI.TextBox(CreateRect(0.8, 1, searchRow), "")
    local query = ""
    search.OnTextChangedDelegate = function(_, value)
        query = Common.NormalizeSearchText(value)
        fillManifest(query)
        return true
    end

    local header = GUI.LayoutGroup(CreateRect(1, 1, root), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(header, height)
    header.Stretch = true
    header.AbsoluteSpacing = Common.GetGap()
    local spacer = GUI.Frame(GUI.RectTransform(Point(height, height), header.RectTransform), nil)
    spacer.Color = Color(0, 0, 0, 0)
    spacer.CanBeFocused = false
    local headerButtons = {}
    for _, column in ipairs(COLUMNS) do
        local button = GUI.Button(CreateRect(column.Width, 1, header), text[column.Field == "Name" and "Character" or column.Field],
            GUI.Alignment.Center, "GUIButtonSmall")
        button.Selected = sortField == column.Field
        -- a second click on the sorting column turns the order around
        button.OnClicked = function()
            if sortField == column.Field then
                sortDescending = not sortDescending
            else
                sortField, sortDescending = column.Field, false
            end
            for field, other in pairs(headerButtons) do other.Selected = field == sortField end
            fillManifest(query)
            return true
        end
        headerButtons[column.Field] = button
    end

    manifestList = GUI.ListBox(CreateRect(1, 1, root), false, nil, "GUIListBoxNoBorder")
    manifestList.Color = Color(0, 0, 0, 0)
    if manifestList.ContentBackground ~= nil then manifestList.ContentBackground.Color = Color(0, 0, 0, 0) end
    manifestList.KeepSpaceForScrollBar = true
    -- the rows are narrower by the scroll bar; so is the header, so the columns line up
    local tail = GUI.Frame(GUI.RectTransform(Point(math.max(0, manifestList.ScrollBar.Rect.Width), height), header.RectTransform), nil)
    tail.Color = Color(0, 0, 0, 0)
    tail.CanBeFocused = false
    fillManifest(query)
    return root
end

local function showSummary(summary, manifest, closeText)
    closeSummary()

    summary = tostring(summary or "")
    if summary == "" then return end

    local title = summary
    local body = ""
    local lineBreak = string.find(summary, "\n", 1, true)
    if lineBreak ~= nil then
        title = string.sub(summary, 1, lineBreak - 1)
        body = string.sub(summary, lineBreak + 1)
    end

    local screenWidth, screenHeight = GetScreenSize()
    local margin = SafeIntScale(10)
    local minimumWidth = SafeIntScale(MIN_WIDTH_PIXELS)
    local minimumHeight = SafeIntScale(MIN_HEIGHT_PIXELS)
    local maximumWidth = math.max(minimumWidth, screenWidth - margin * 2)
    local maximumHeight = math.max(minimumHeight, screenHeight - margin * 2)
    local width = Clamp(menuWidth or SafeIntScale(#manifest > 0 and MANIFEST_WIDTH_PIXELS or DEFAULT_WIDTH_PIXELS), minimumWidth, maximumWidth)
    local height = Clamp(menuHeight or SafeIntScale(DEFAULT_HEIGHT_PIXELS), minimumHeight, maximumHeight)
    local x = menuX or math.floor((screenWidth - width) / 2)
    local y = menuY or math.floor((screenHeight - height) / 2)
    x = Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = Clamp(y, margin, math.max(margin, screenHeight - height - margin))

    local menuRect = CreateCanvasRect(x, y, width, height)
    if menuRect == nil then return end

    currentMenu = GUI.Frame(menuRect, nil)
    currentMenu.Color = Color(0, 0, 0, 0)
    currentMenu.CanBeFocused = false
    currentMenu.IgnoreLayoutGroups = true
    state.MenuRoot = currentMenu

    local panel = GUI.Frame(CreateRect(1, 1, currentMenu, GUI.Anchor.Center), "GUIFrame")
    panel.CanBeFocused = false

    local content = GUI.LayoutGroup(CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.004

    Common.CreateWindowHeader(content, currentMenu, title, closeText or "Close", function()
        closeSummary()
        return true
    end, { titleScale = 1.15, titleNoFocus = true })

    local tabButtons = nil
    if #manifest > 0 then
        local tabs = GUI.Frame(CreateRect(1, 1, content, nil), nil)
        Common.SetFixedHeight(tabs, Common.GetStyleHeight("GUIButton"))
        tabs.Color = Color(0, 0, 0, 0)
        tabs.CanBeFocused = false
        tabButtons = {
            summary = GUI.Button(CreateRect(0.5, 1, tabs, GUI.Anchor.CenterLeft), text.Summary, GUI.Alignment.Center, "GUITabButton"),
            manifest = GUI.Button(CreateRect(0.5, 1, tabs, GUI.Anchor.CenterRight), text.Manifest, GUI.Alignment.Center, "GUITabButton"),
        }
    else
        shownTab = "summary"
    end

    local listFrame = GUI.Frame(CreateRect(1, 0.90, content, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    summaryList = GUI.ListBox(CreateRect(0.985, 0.975, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    summaryList.CanBeFocused = false
    summaryList.Color = Color(0, 0, 0, 0)
    if summaryList.ContentBackground ~= nil then summaryList.ContentBackground.Color = Color(0, 0, 0, 0) end
    summaryList.KeepSpaceForScrollBar = true

    local bodyText = Common.CreateText(summaryList.Content, 0.975, 0.20, GUI.Anchor.TopLeft, body, GUI.Alignment.TopLeft, 1.25, Color(220, 220, 210, 255), true)
    bodyText.CanBeFocused = false
    bodyText.SetRichText(body)
    bodyText.CalculateHeightFromText()
    summaryList:RecalculateChildren()
    summaryList:UpdateScrollBarSize()

    if tabButtons ~= nil then
        local manifestRoot = createManifest(listFrame)
        local function showTab(id)
            shownTab = id
            summaryList.Visible = id == "summary"
            manifestRoot.Visible = id == "manifest"
            for tab, button in pairs(tabButtons) do button.Selected = tab == id end
        end
        for id, button in pairs(tabButtons) do
            button.OnClicked = function()
                showTab(id)
                return true
            end
        end
        showTab(shownTab)
    end

    addResizeHandles(panel)
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
end

Common.InstallHudPatch(HUD_PATCH_ID, STATE_KEY, MENU_DRAW_ORDER, MENU_DRAW_ORDER)

Networking.Receive(NET_SUMMARY, function(message)
    lastSummary = message.ReadString()
    lastManifest = {}
    for _ = 1, message.ReadUInt16() do
        local row = { Name = message.ReadString(), Role = message.ReadString(), Job = message.ReadString(),
            Antagonist = message.ReadString(), Kind = message.ReadByte(), Player = message.ReadString() }
        row.Keys = { Name = Common.NormalizeSearchText(row.Name), Role = Common.NormalizeSearchText(row.Role),
            Player = Common.NormalizeSearchText(row.Player) }
        row.Search = table.concat({ row.Keys.Name, row.Keys.Role, Common.NormalizeSearchText(typeText(row)), row.Keys.Player }, "\n")
        lastManifest[#lastManifest + 1] = row
    end
    showSummary(lastSummary, lastManifest, Common.Language.Common.Close)
end)

Hook.Add("think", "VoidTraitor.RoundSummary.Think", function()
    if state.Disabled then return end
    updateResize()
    -- F9 opens and closes the last summary, as in SS14; not while typing
    if lastSummary ~= nil and PlayerInput.KeyHit(Keys.F9) and GUI.KeyboardDispatcher.Subscriber == nil then
        if currentMenu ~= nil then closeSummary() else showSummary(lastSummary, lastManifest, Common.Language.Common.Close) end
    end
end)

-- The summary stays open into the lobby until it is closed, as the game's own summary does.
Hook.Patch(LOBBY_PATCH_ID, "Barotrauma.NetLobbyScreen", "AddToGUIUpdateList", function()
    if state.Disabled or currentMenu == nil then return end
    currentMenu:AddToGUIUpdateList(false, MENU_DRAW_ORDER)
end, Hook.HookMethodType.After)

-- This window replaces the game's round summary; a campaign keeps the game's, which shows its money and next level.
Hook.Patch(VANILLA_PATCH_ID, "Barotrauma.GameSession", "EndRound", function(instance, ptable)
    if state.Disabled then return end
    if instance.GameMode ~= nil and LuaUserData.IsTargetType(instance.GameMode, "Barotrauma.CampaignMode") then return end
    ptable["createRoundSummary"] = false
end, Hook.HookMethodType.Before)

Hook.Add("roundStart", "VoidTraitor.RoundSummary.RoundStart", closeSummary)
