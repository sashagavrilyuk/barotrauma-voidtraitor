local P = ...
local S = P.State

function P.BuildShopPanel(overlay)
    -- Keep the outer panel transparent; only the item/category selection area
    -- uses the vanilla list frame, closer to the vanilla store layout.
    local root = GUI.Frame(P.CreateRect(P.PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomLeft), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = P.CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    P.BuildHeader(content)

    local menuFrame = GUI.Frame(P.CreateRect(1, 0.835, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = P.CreateLayout(menuFrame, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    P.CloseFilterPopup()
    S.filterButton = nil
    S.rebuildProductList = nil
    if S.currentView == "products" then P.BuildFilterBar(menuContent) end

    local listHeight = S.currentView == "products" and 0.768 or 0.855
    -- One vanilla green list frame. The list's own background below is kept
    -- transparent so a second nested outline is not drawn.
    local listFrame = GUI.Frame(P.CreateRect(1, listHeight, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(P.CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    S.shopList = list
    list.Color = Color(0, 0, 0, 0)
    list.ContentBackground.Color = Color(0, 0, 0, 0)
    list.KeepSpaceForScrollBar = false
    list.CanBeFocused = false

    if S.currentView == "categories" then
        local folders = P.BuildFolderList()
        if #folders == 0 then
            P.CreateText(list.Content, 0.95, 0.13, GUI.Anchor.TopCenter, P.GetText("EmptyCategories"), GUI.Alignment.Center, 1.10)
        else
            for _, folder in ipairs(folders) do
                P.AddCategoryButton(list, folder)
            end
        end
    else
        local function populateProductList(resetScroll)
            local previousScroll = list.BarScroll
            list.Content:ClearChildren()
            S.productRows = {}
            S.cooldownTextBlocks.shop = {}
            S.classLimitTextBlocks.shop = {}

            local breadcrumb = P.CreateText(list.Content, 0.96, 0.075, GUI.Anchor.TopLeft, P.GetSelectedFolderLabel(), GUI.Alignment.Left, 1.08, Color(180, 220, 190, 255))
            breadcrumb.RectTransform.MinSize = Point(0, 28)

            local hasProducts = false
            for _, product in ipairs(S.products) do
                if P.ProductMatchesSelectedFolder(product) and P.ProductMatchesSearchAndFilter(product) then
                    hasProducts = true
                    P.AddProductButton(list, product)
                end
            end

            if not hasProducts then
                P.CreateText(list.Content, 0.95, 0.13, GUI.Anchor.TopCenter, P.GetText("EmptyProducts"), GUI.Alignment.Center, 1.10)
            end

            S.shopListScroll = resetScroll == false and previousScroll or 0
            list.BarScroll = S.shopListScroll
            list:RecalculateChildren()
            list:UpdateScrollBarSize()
            S.guiRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)
        end
        S.rebuildProductList = populateProductList
        populateProductList()
    end

    list.BarScroll = S.shopListScroll or 0

    local hintText = P.GetText("ClickProduct")
    if S.shopMode == "ghost" then
        hintText = P.GetText("SelectGhostAction")
    elseif S.shopMode == "attackdefend" then
        for _, product in ipairs(S.products) do
            if P.ProductMatchesSelectedFolder(product) and P.IsClassProduct(product) then
                hintText = P.GetClassSelectText()
                break
            end
        end
    end

    local hint = P.CreateText(menuContent, 1, 0.070, nil, hintText, GUI.Alignment.Left, 0.78, Color(210, 210, 190, 185))
    hint.AutoScaleVertical = true
end
