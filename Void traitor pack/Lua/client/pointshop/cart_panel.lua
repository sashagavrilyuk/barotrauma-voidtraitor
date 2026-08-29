local P = ...
local S = P.State

function P.BuildConfirmPanel(overlay)
    local root = GUI.Frame(P.CreateRect(P.PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomRight), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = P.CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    P.CreatePanelTitle(content, P.GetText("ConfirmTitle"), "StoreShoppingCrateIcon", true)

    local product = P.GetPendingProduct() or P.GetSelectedProduct()
    local total = product ~= nil and (product.Price or 0) or 0
    P.BuildPurchaseSummary(content, total)

    P.CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(P.CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = P.CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    local listFrame = GUI.Frame(P.CreateRect(1, 0.805, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local box = GUI.Frame(P.CreateRect(1, 1, listFrame, GUI.Anchor.Center), nil)
    box.Color = Color(0, 0, 0, 0)
    box.CanBeFocused = false

    if product == nil then
        local placeholder = S.shopMode == "attackdefend" and P.GetClassSelectText() or P.GetText("SelectGhostAction")
        P.CreateText(box, 0.90, 0.16, GUI.Anchor.Center, placeholder, GUI.Alignment.Center, 1.10)
    else
        P.CreateProductDetails(box, product, 0.46)

        local question = P.IsClassProduct(product) and P.GetText("ConfirmClassQuestion") or P.GetText("ConfirmQuestion")
        if question ~= "" then
            P.CreateText(box, 0.90, 0.10, GUI.Anchor.BottomCenter, question, GUI.Alignment.Center, 0.98, Color(230, 230, 215, 255), true)
        end
    end

    local buttons = P.CreateLayout(menuContent, 1, 0.085, nil, true, GUI.Anchor.CenterRight)
    buttons.RelativeSpacing = 0.012

    local cancelButton = P.CreateButton(buttons, 0.47, 1, nil, P.GetText("Cancel"), product ~= nil, false)
    cancelButton.OnClicked = function()
        S.pendingProductId = nil
        S.selectedProductId = nil
        P.RefreshCartOnly()
        return true
    end

    local buyButton = P.CreateButton(buttons, 0.47, 1, nil, P.GetText("Buy"), product ~= nil and P.GetProductDisabledReason(product) == "", false)
    buyButton.OnClicked = function()
        if product ~= nil then
            P.SendBuyRequest({ { Id = product.Id, Quantity = 1 } })
        end
        return true
    end

    if S.lastMessage ~= nil and S.lastMessage ~= "" then
        P.CreateText(menuContent, 1, 0.045, nil, S.lastMessage, GUI.Alignment.Center, 0.98, Color(255, 220, 120, 255))
    end

    return root
end

function P.BuildCartPanel(overlay)
    if S.shopMode == "ghost" or P.IsClassProduct(P.GetPendingProduct()) or (S.shopMode == "attackdefend" and P.SelectedFolderHasClassProducts()) then
        return P.BuildConfirmPanel(overlay)
    end

    local root = GUI.Frame(P.CreateRect(P.PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomRight), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = P.CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    P.CreatePanelTitle(content, P.GetText("Cart"), "StoreShoppingCrateIcon", true)

    local total = P.GetCartTotal()
    P.BuildPurchaseSummary(content, total)

    P.CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(P.CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = P.CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    local listFrame = GUI.Frame(P.CreateRect(1, 0.835, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(P.CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    list.ContentBackground.Color = Color(0, 0, 0, 0)
    list.KeepSpaceForScrollBar = false
    list.CanBeFocused = false

    local selectedProduct = P.GetSelectedProduct()
    if selectedProduct ~= nil then
        P.CreateProductDetails(list.Content, selectedProduct, 0.30)
        P.CreateDivider(list.Content, 0.015)
    end

    if #S.cart == 0 then
        P.CreateText(list.Content, 0.95, 0.15, GUI.Anchor.TopCenter, P.GetText("EmptyCart"), GUI.Alignment.Center, 1.10)
    else
        for _, entry in ipairs(S.cart) do
            P.AddCartButton(list, entry)
        end
    end

    local buttons = P.CreateLayout(menuContent, 1, 0.085, nil, true, GUI.Anchor.CenterRight)
    buttons.RelativeSpacing = 0.012

    local clearButton = P.CreateButton(buttons, 0.47, 1, nil, P.GetText("Clear"), #S.cart > 0, false)
    clearButton.OnClicked = function()
        P.ClearCart()
        P.RefreshCartOnly()
        return true
    end

    local buyButton = P.CreateButton(buttons, 0.47, 1, nil, P.GetText("Buy"), #S.cart > 0 and total <= S.currentPoints, false)
    buyButton.OnClicked = function()
        P.SendBuyRequest(S.cart)
        return true
    end

    if S.lastMessage ~= nil and S.lastMessage ~= "" then
        P.CreateText(menuContent, 1, 0.045, nil, S.lastMessage, GUI.Alignment.Center, 0.98, Color(255, 220, 120, 255))
    end

    return root
end

P.RefreshCartOnly = function()
    if S.currentMenu == nil then return end

    S.cooldownTextBlocks.cart = {}
    S.classLimitTextBlocks.cart = {}

    P.Common.RemoveGuiComponent(S.cartPanelRoot)

    S.cartPanelRoot = P.BuildCartPanel(S.currentMenu)
    S.guiRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)
end
