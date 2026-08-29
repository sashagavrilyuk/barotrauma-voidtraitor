local P = ...
local S = P.State

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

    local screenWidth, screenHeight = P.GetScreenSize()
    local margin = P.SafeIntScale(P.VT_MENU_MARGIN_PIXELS)
    local minHeight = P.SafeIntScale(P.VT_MENU_MIN_HEIGHT_PIXELS)
    local maxHeight = math.max(minHeight, screenHeight - margin * 2)
    local width = math.min(P.SafeIntScale(P.VT_MENU_WIDTH_PIXELS), math.max(1, screenWidth - margin * 2))
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

    local content = GUI.LayoutGroup(P.CreateRect(0.965, 0.965, panel, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    content.Stretch = true
    content.RelativeSpacing = 0.003

    local header = GUI.Frame(P.CreateRect(1, 0.062, content, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    local dragArea = GUI.DragHandle(P.CreateRect(0.86, 1, header, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    dragArea.Color = transparent
    dragArea.HoverColor = transparent
    dragArea.SelectedColor = transparent
    dragArea.PressedColor = transparent

    local dragIndicator = GUI.Image(P.CreateRect(0.07, 0.72, dragArea, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    dragIndicator.CanBeFocused = false
    local title = P.CreateText(dragArea, 0.90, 1, GUI.Anchor.CenterRight, P.UiText.Title, GUI.Alignment.Left, 1.00, Color(235, 205, 145, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    local close = GUI.Button(P.CreateRect(0.10, 0.82, header, GUI.Anchor.TopRight), "", GUI.Alignment.Center, "GUICancelButton")
    close.ToolTip = P.UiText.Cancel
    close.OnClicked = function()
        P.CloseMenu()
        return true
    end

    GUI.Image(P.CreateRect(1, 0.006, content, nil), "HorizontalLine")

    local hasAdmin = P.Admin.IsAvailable()
    local listHeight = hasAdmin and 0.845 or 0.91
    local mainTab = nil
    local adminTab = nil

    if hasAdmin then
        local tabs = GUI.Frame(P.CreateRect(1, 0.06, content, nil), nil)
        tabs.Color = Color(0, 0, 0, 0)
        tabs.CanBeFocused = false
        mainTab = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterLeft), P.Admin.GetMainTabText(), GUI.Alignment.Center, "GUITabButton")
        adminTab = GUI.Button(P.CreateRect(0.5, 1, tabs, GUI.Anchor.CenterRight), P.Admin.GetAdminTabText(), GUI.Alignment.Center, "GUITabButton")
        P.SetButtonTextScale(mainTab, 0.82)
        P.SetButtonTextScale(adminTab, 0.82)
    end

    local listHost = GUI.Frame(P.CreateRect(1, listHeight, content, nil), nil)
    listHost.Color = Color(0, 0, 0, 0)
    listHost.CanBeFocused = false

    S.vtMainListFrame, S.vtMainList = P.CreateMenuList(listHost)
    S.vtMenuList = S.vtMainList

    local entries = S.menuEntries or {}
    if #entries == 0 then
        P.CreateText(S.vtMainListFrame, 0.90, 0.24, GUI.Anchor.Center, P.UiText.NoCommands, GUI.Alignment.Center, 0.90, Color(195, 195, 185, 255), true)
    end

    local lastCategory = nil
    for _, entry in ipairs(entries) do
        local category = tostring(entry.Category or "")
        if category ~= "" and category ~= lastCategory then
            if lastCategory ~= nil then P.CreateDivider(S.vtMainList.Content) end
            P.CreateCategoryHeader(S.vtMainList.Content, category)
            lastCategory = category
        end

        local enabled = entry.Enabled ~= false
        local tooltip = tostring(entry.Hint or "")
        if tostring(entry.InputType or "") ~= "" then
            P.CreateTextInputRow(S.vtMainList.Content, entry.Label or entry.Command or P.UiText.GenericCommand, entry.InputHint or "", entry.Command or "", enabled, tooltip)
        else
            local button = P.CreateMenuButton(S.vtMainList.Content, entry.Label or entry.Command or P.UiText.GenericCommand, enabled)
            button.ToolTip = tooltip
            button.OnClicked = function()
                if tostring(entry.ConfirmText or "") ~= "" then
                    P.ShowConfirm(entry.ConfirmTitle ~= "" and entry.ConfirmTitle or P.UiText.DefaultConfirmTitle, entry.ConfirmText, entry.Command)
                else
                    P.SendCommand(entry.Command)
                end
                return true
            end
        end
    end
    S.vtMainList.BarScroll = S.vtMenuScroll
    S.vtMainList:RecalculateChildren()
    S.vtMainList:UpdateScrollBarSize()

    local function showMainTab()
        S.vtActiveTab = "main"
        S.vtMenuList = S.vtMainList
        S.vtMainListFrame.Visible = true
        if S.vtAdminListFrame ~= nil then S.vtAdminListFrame.Visible = false end
        if mainTab ~= nil then mainTab.Selected = true end
        if adminTab ~= nil then adminTab.Selected = false end
    end

    local function showAdminTab()
        if S.vtAdminList == nil then P.Admin.RefreshData() end
        P.Admin.WhenDataReady(function()
            if S.currentMenuKind ~= "vt" then return end
            if S.vtAdminList == nil then
                S.vtAdminListFrame, S.vtAdminList = P.CreateMenuList(listHost)
                P.Admin.Build(S.vtAdminList.Content)
                S.vtAdminList.BarScroll = S.vtAdminScroll
                S.vtAdminList:RecalculateChildren()
                S.vtAdminList:UpdateScrollBarSize()
            end

            S.vtActiveTab = "admin"
            S.vtMenuList = S.vtAdminList
            S.vtMainListFrame.Visible = false
            S.vtAdminListFrame.Visible = true
            mainTab.Selected = false
            adminTab.Selected = true
        end)
    end

    if hasAdmin then
        mainTab.OnClicked = function()
            showMainTab()
            return true
        end
        adminTab.OnClicked = function()
            showAdminTab()
            return true
        end

        if S.vtActiveTab == "admin" then showAdminTab() else showMainTab() end
    else
        showMainTab()
    end

    P.AddVoidTraitorResizeHandles(panel)
    P.SaveVoidTraitorMenuGeometry()
end
