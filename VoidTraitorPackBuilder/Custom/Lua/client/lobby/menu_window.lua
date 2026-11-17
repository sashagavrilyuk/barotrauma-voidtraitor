local P = ...
local S = P.State

local function runEntry(entry)
    if entry.Open ~= nil then
        entry.Open()
    elseif tostring(entry.ConfirmText or "") ~= "" then
        P.ShowConfirm(entry.ConfirmTitle ~= "" and entry.ConfirmTitle or P.UiText.DefaultConfirmTitle, entry.ConfirmText,
            function() P.SendCommand(entry.Command) end)
    else
        P.SendCommand(entry.Command)
    end
end

local function getLabel(entry)
    return entry.Label or entry.Command or P.UiText.GenericCommand
end

-- The player's commands in two columns under their headings. One that takes a value gets a row of its own, and one
-- that asks for confirmation (suicide) cannot be undone, so it stands apart at the bottom.
local function buildCommands(parent, entries)
    local groups, separate = {}, {}
    for _, entry in ipairs(entries) do
        local item = { Label = getLabel(entry), ToolTip = tostring(entry.Hint or ""), Enabled = entry.Enabled ~= false,
            OnClicked = function() runEntry(entry) end }
        if tostring(entry.ConfirmText or "") ~= "" then
            separate[#separate + 1] = item
        else
            local category = tostring(entry.Category or "")
            local group = groups[#groups]
            if group == nil or group.Category ~= category then
                group = { Category = category, Buttons = {}, Inputs = {} }
                groups[#groups + 1] = group
            end
            if tostring(entry.InputType or "") ~= "" then
                table.insert(group.Inputs, entry)
            else
                table.insert(group.Buttons, item)
            end
        end
    end

    for index, group in ipairs(groups) do
        if index > 1 then P.CreateDivider(parent) end
        if group.Category ~= "" then P.CreateCategoryHeader(parent, group.Category) end
        P.CreateButtonGrid(parent, 2, group.Buttons)
        for _, entry in ipairs(group.Inputs) do
            P.CreateTextInputRow(parent, getLabel(entry), entry.InputHint or "",
                function(value) P.SendCommand(entry.Command or "", value) end, entry.Enabled ~= false, tostring(entry.Hint or ""))
        end
    end
    if #separate > 0 then
        P.CreateDivider(parent)
        for _, button in pairs(P.CreateButtonGrid(parent, 1, separate)) do P.SetDangerButton(button) end
    end
end

P.ShowVoidTraitorMenu = function()
    if S.currentMenu ~= nil then
        P.CloseMenu()
        return
    end

    if S.menuEntries == nil then
        P.RequestMenuSnapshot(true)
        return
    end

    if S.vtActiveTab == "admin" and not P.Admin.IsAvailable() then S.vtActiveTab = "main" end
    local adminTabActive = S.vtActiveTab == "admin"

    local screenWidth, screenHeight = P.GetScreenSize()
    local margin = P.SafeIntScale(P.VT_MENU_MARGIN_PIXELS)
    local minHeight = P.GetVoidTraitorMenuMinHeight()
    local maxHeight = math.max(minHeight, screenHeight - margin * 2)
    local width = P.Common.FitWindowWidth(P.SafeIntScale(adminTabActive and P.VT_ADMIN_MENU_WIDTH_PIXELS or P.VT_MENU_WIDTH_PIXELS),
        440, margin)
    local height = P.Clamp(S.vtMenuHeight or P.SafeIntScale(P.VT_MENU_DEFAULT_HEIGHT_PIXELS), minHeight, maxHeight)
    local x = S.vtMenuX or math.floor((screenWidth - width) / 2)
    local y = S.vtMenuY or math.floor((screenHeight - height) / 2)
    x = P.Clamp(x, margin, math.max(margin, screenWidth - width - margin))
    y = P.Clamp(y, margin, math.max(margin, screenHeight - height - margin))

    local rootRect = P.CreatePixelRect(width, height, S.guiRoot, GUI.Anchor.TopLeft)
    rootRect.AbsoluteOffset = Point(x, y)
    local root = GUI.Frame(rootRect, nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false
    root.IgnoreLayoutGroups = true
    S.currentMenu = root
    S.currentMenuKind = "vt"
    S.sharedState.CurrentMenu = root
    S.sharedState.CurrentMenuKind = S.currentMenuKind

    local panel = GUI.Frame(P.CreateRect(1, 1, root, GUI.Anchor.TopLeft), "GUIFrame")
    panel.CanBeFocused = false

    local content = P.Common.CreateWindowContent(panel)

    P.Common.CreateWindowHeader(content, root, P.UiText.Title, P.UiText.Cancel, function()
        if S.currentMenu == root then
            P.CloseMenu()
        else
            P.Common.RemoveGuiComponent(root)
        end
        return true
    end)

    if P.Admin.IsAvailable() then
        local tabs = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
        P.Common.SetFixedHeight(tabs, P.Common.GetStyleHeight("GUIButton"))
        tabs.Color = Color(0, 0, 0, 0)
        tabs.CanBeFocused = false
        local mainTab = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterLeft), P.Admin.GetMainTabText(), GUI.Alignment.Center, "GUITabButton")
        local adminTab = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterRight), P.Admin.GetAdminTabText(), GUI.Alignment.Center, "GUITabButton")
        P.SetButtonTextScale(mainTab, 0.82)
        P.SetButtonTextScale(adminTab, 0.82)
        mainTab.Selected = not adminTabActive
        adminTab.Selected = adminTabActive
        -- the admin tab is wider, so the window is built again for the other tab
        local function switchTo(tab)
            if S.vtActiveTab ~= tab then
                S.vtActiveTab = tab
                P.CloseMenu()
                P.ShowVoidTraitorMenu()
            end
            return true
        end
        mainTab.OnClicked = function() return switchTo("main") end
        adminTab.OnClicked = function() return switchTo("admin") end
    end

    -- The only row without a fixed height: it takes the space left when the window is resized.
    local listHost = GUI.Frame(P.CreateRect(1, 1, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false

    if adminTabActive then
        P.Admin.RefreshData()
        P.Admin.WhenDataReady(function()
            if S.currentMenu ~= root then return end
            P.Admin.Build(listHost)
            listHost.ForceLayoutRecalculation()
        end)
    else
        S.vtMainListFrame, S.vtMainList = P.CreateMenuList(listHost)
        S.vtMenuList = S.vtMainList
        local entries = S.menuEntries or {}
        if #entries == 0 then
            P.CreateText(S.vtMainListFrame, 0.90, 0.24, GUI.Anchor.Center, P.UiText.NoCommands, GUI.Alignment.Center, 0.90, Color(195, 195, 185, 255), true)
        end
        buildCommands(S.vtMainList.Content, entries)
        S.vtMainList.BarScroll = S.vtMenuScroll
        S.vtMainList:RecalculateChildren()
        S.vtMainList:UpdateScrollBarSize()
    end

    P.AddVoidTraitorResizeHandles(panel)
    -- Laid out now rather than in its first update: a list box picks the rows it updates and draws from its size at
    -- that moment (GUIListBox.AddToGUIUpdateList), so for one frame rows would show below the window or unplaced.
    root.ForceLayoutRecalculation()
    P.SaveVoidTraitorMenuGeometry()
end
