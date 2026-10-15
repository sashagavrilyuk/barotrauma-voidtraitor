if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorCargoGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
end
local UI = {}
_G.VoidTraitorCargoGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")

local P = { Common = Common, State = {}, GUI_DRAW_ORDER = 120, PANEL_WIDTH = 1, CATEGORY_ROW_MIN_HEIGHT = Common.SafeIntScale(40), FILTER_BAR_HEIGHT = 0.18,
    FILTER_BAR_MIN_HEIGHT = Common.SafeIntScale(48), PRODUCT_ROW_MIN_HEIGHT = Common.SafeIntScale(54),
    FILTER_LABEL_SCALE = 0.95, PRODUCT_LIST_HEIGHT = 0.68,
    ITEM_ROW_HEIGHT = 0.27, ITEM_ICON_PIXELS = Common.SafeIntScale(40), ACTION_BUTTON_PIXELS = Common.SafeIntScale(42), NET_INT32_MAX = 2147483647 }
local S = P.State
S.products, S.productById, S.cart, S.expandedFolders = {}, {}, {}, {}
S.cooldownTextBlocks, S.classLimitTextBlocks = { shop = {}, cart = {} }, { shop = {}, cart = {} }
S.classLimitValues, S.productRows = {}, {}
S.currentView, S.shopMode, S.selectedFilter = "categories", "shop", "all"
S.searchText, S.normalizedSearchText, S.lastMessage, S.shopListScroll, S.currentPoints = "", "", "", 0, 0
local modulePath = packPath .. "/Lua/client/pointshop/"
for _, name in ipairs({ "model_text", "model_state", "model_folders", "widgets", "shop_categories", "shop_products", "shop_filters", "shop_panel" }) do
    assert(loadfile(modulePath .. name .. ".lua"))(P)
end
-- Requests may be drafted before the station can afford their approval.
P.GetProductDisabledReason = function(product)
    if UI.SubmitPending then return UI.Data.Text.Pending end
    return P.GetProductStateDisabledReason(product)
end

function UI.Send(action, payload)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_CargoAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
    message.WriteString(json.serialize(payload or {}))
    Networking.Send(message)
end

function UI.CloseMenu()
    UI.Send("close")
    P.CloseFilterPopup()
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Data = nil, nil, nil, nil
    UI.AwaitingOpen, UI.SubmitPending, UI.ResizeState = false, false, nil
    UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides = nil, nil, nil
    S.currentMenu, S.guiRoot, S.catalogHost, S.shopList, S.rebuildProductList = nil, nil, nil, nil, nil
    S.productRows, S.cart = {}, {}
    S.currentView, S.selectedCategory, S.selectedPath, S.selectedProductId = "categories", nil, nil, nil
    S.searchText, S.normalizedSearchText, S.lastMessage, S.shopListScroll = "", "", "", 0
end

function UI.Money(value)
    return tostring(value or 0) .. " " .. tostring(S.products[1] ~= nil and S.products[1].Currency or "")
end

function P.BuildHeader(parent)
    local tabs = P.CreateLayout(parent, 1, 0.10, nil, true, GUI.Anchor.CenterLeft)
    local categories = P.CreateButton(tabs, 0.5, 1, nil, P.GetText("Categories"), true, S.currentView == "categories", "GUITabButton")
    categories.OnClicked = function() S.currentView = "categories" P.ShowMenu() return true end
    local products = P.CreateButton(tabs, 0.5, 1, nil, P.GetText("BuyTab"), true, S.currentView == "products", "GUITabButton")
    products.OnClicked = function()
        if S.selectedCategory == nil and S.products[1] ~= nil then
            S.selectedCategory, S.selectedPath = S.products[1].Category, S.products[1].Path or ""
        end
        S.currentView, S.shopListScroll = "products", 0
        P.ShowMenu()
        return true
    end
end

function P.ShowMenu()
    if S.catalogHost == nil then return end
    P.CloseFilterPopup()
    S.catalogHost:ClearChildren()
    S.productRows = {}
    S.cooldownTextBlocks.shop, S.classLimitTextBlocks.shop = {}, {}
    P.BuildShopPanel(S.catalogHost)
    P.RefreshCartOnly()
end

function P.RefreshCartOnly()
    if UI.CartList == nil then return end
    local scroll = UI.CartList.BarScroll
    UI.CartList.Content:ClearChildren()
    for _, entry in ipairs(S.cart) do
        local product = S.productById[entry.Id]
        if product ~= nil then
            local row = P.CreateLayout(UI.CartList.Content, 1, 0.34, nil, true, GUI.Anchor.CenterLeft)
            row.RectTransform.MinSize = Point(0, Common.SafeIntScale(38))
            local name = P.CreateText(row, 0.61, 1, nil, product.Name .. " ×" .. tostring(entry.Quantity) .. "\n" .. UI.Money(product.Price * entry.Quantity), GUI.Alignment.Left, 0.85)
            name.ToolTip = product.Name
            local remove = P.CreateButton(row, 0.18, 0.85, nil, "−", not UI.SubmitPending)
            remove.OnClicked = function() P.RemoveFromCart(entry.Id) P.RefreshCartOnly() return true end
            local add = P.CreateButton(row, 0.18, 0.85, nil, "+", P.GetProductDisabledReason(product) == "")
            add.OnClicked = function() P.AddToCart(product) P.RefreshCartOnly() return true end
        end
    end
    UI.CartList:RecalculateChildren()
    UI.CartList:UpdateScrollBarSize()
    UI.CartList.BarScroll = scroll
    UI.Total.Text = P.GetText("Total") .. ": " .. UI.Money(P.GetCartTotal())
    local selected = P.GetSelectedProduct()
    UI.Details.Text = S.lastMessage ~= "" and S.lastMessage or (selected ~= nil and P.Utf8Truncate(selected.Name .. "\n" .. P.GetProductDescriptionText(selected), 58) or "")
    UI.Details.ToolTip = selected ~= nil and P.GetProductDescriptionText(selected) or ""
    UI.Reason.Enabled = not UI.SubmitPending
    UI.Submit.Enabled = not UI.SubmitPending and #S.cart > 0 and string.find(tostring(UI.Reason.Text), "%S") ~= nil
end

function UI.UpdateOrders()
    local snapshot, list = UI.Data, UI.OrderList
    local scroll = list.BarScroll
    list.Content:ClearChildren()
    for _, order in ipairs(snapshot.Orders) do
        local row = P.CreateLayout(list.Content, 1, 0.40, nil, true, GUI.Anchor.CenterLeft)
        row.RectTransform.MinSize = Point(0, Common.SafeIntScale(50))
        local icon = GUI.Frame(P.CreateRect(0.07, 1, row), nil)
        icon.Color = Color(0, 0, 0, 0)
        icon.CanBeFocused = false
        P.CreateProductIcon(icon, order.IconIdentifier)
        local status = snapshot.Text[order.Status] or snapshot.Text[string.gsub(order.Status, "^%l", string.upper)] or ""
        local details = P.CreateText(row, 0.54, 1, nil,
            order.Name .. " ×" .. tostring(order.Quantity) .. "  ·  " .. UI.Money(order.Price) .. "  ·  " .. status .. "\n"
            .. order.Author .. "  ·  " .. order.Reason, GUI.Alignment.Left, 0.88)
        details.Wrap = false
        details.AutoScaleHorizontal = true
        details.AutoScaleVertical = true
        details.ToolTip = order.Name .. "\n" .. order.Author .. "\n" .. order.Reason
        local canManage = snapshot.CanManage and (order.Status == "pending" or order.Status == "accepted" or order.Status == "Pending" or order.Status == "Accepted")
        local approve = P.CreateButton(row, 0.14, 0.65, nil, snapshot.Text.Approve, canManage and (order.Status == "pending" or order.Status == "Pending"))
        local reject = P.CreateButton(row, 0.14, 0.65, nil, snapshot.Text.Reject, canManage)
        approve.OnClicked = function() UI.Send("approve", { OrderId = order.Id }) return true end
        reject.OnClicked = function() UI.Send("reject", { OrderId = order.Id }) return true end
        approve.TextBlock.AutoScaleHorizontal = true
        reject.TextBlock.AutoScaleHorizontal = true
    end
    if #snapshot.Orders == 0 then P.CreateText(list.Content, 1, 0.3, nil, snapshot.Text.Empty, GUI.Alignment.Center) end
    list:RecalculateChildren()
    list:UpdateScrollBarSize()
    list.BarScroll = scroll
end

function UI.Update(snapshot)
    UI.Data, UI.AwaitingOpen = snapshot, false
    if snapshot.Result ~= nil then
        S.lastMessage = snapshot.Result.Message or ""
        if snapshot.Result.Action == "submit" then
            UI.SubmitPending = false
            if snapshot.SubmitAccepted then P.ClearCart() UI.Reason.Text = "" end
        end
    end
    P.Text = {}
    for key, value in pairs(Common.Language.Pointshop) do P.Text[key] = value end
    for key, value in pairs(snapshot.Text) do P.Text[key] = value end
    S.currentPoints = math.max(snapshot.Budget - snapshot.Reserved, 0)
    local changed = false
    if snapshot.Products ~= nil then
        local products, productById = {}, {}
        changed = #snapshot.Products ~= #S.products
        for index, received in ipairs(snapshot.Products) do
            local product = S.productById[received.Id]
            if product == nil or S.products[index] ~= product or product.Name ~= received.Name or product.Category ~= received.Category or product.Path ~= received.Path then
                changed = true
            end
            product = product or {}
            for key, value in pairs(received) do product[key] = value end
            product.SearchText = P.NormalizeSearchText(table.concat({ product.Name or "", product.Description or "", product.Category or "", product.Path or "", product.IconIdentifier or "", product.Type or "" }, " "))
            products[#products + 1], productById[product.Id] = product, product
        end
        S.products, S.productById = products, productById
    elseif snapshot.ProductStates ~= nil then
        for _, state in ipairs(snapshot.ProductStates) do
            local product = S.productById[state.Id]
            if product ~= nil then
                product.Price, product.Stock, product.MaxQuantity = state.Price, state.Stock, state.MaxQuantity
            end
        end
    end
    for index = #S.cart, 1, -1 do
        local entry = S.cart[index]
        local product = S.productById[entry.Id]
        if product == nil then table.remove(S.cart, index)
        else entry.Quantity = math.min(entry.Quantity, math.max(product.AllowQuantity and (product.MaxQuantity or product.Stock or 1) or 1, 1)) end
    end
    if changed then P.ShowMenu() else P.RefreshProductRows() P.RefreshCartOnly() end
    local ship = snapshot.Ship
    local shipState = snapshot.Text[ship.State] or snapshot.Text[string.gsub(ship.State, "^%l", string.upper)] or ""
    UI.Budget.Text = snapshot.Text.Budget .. ": " .. UI.Money(snapshot.Budget) .. "  ·  " .. snapshot.Text.Reserved .. ": " .. UI.Money(snapshot.Reserved)
        .. "  ·  " .. snapshot.Text.Ship .. ": " .. shipState .. "\n"
        .. snapshot.Text.Capacity .. ": " .. tostring(ship.SlotsFree) .. "/" .. tostring(ship.SlotsTotal)
        .. "  ·  " .. snapshot.Text.Large .. ": " .. tostring(ship.LargeFree) .. "/" .. tostring(ship.LargeTotal)
    UI.UpdateOrders()
end

function UI.Show(itemId, snapshot)
    if UI.MenuRoot ~= nil then UI.Update(snapshot) return end
    UI.ItemId = itemId
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(math.min(screenWidth * 0.92, math.max(Common.SafeIntScale(800), screenWidth * 0.55)))
    local height = math.floor(math.min(screenHeight * 0.92, math.max(Common.SafeIntScale(580), screenHeight * 0.65)))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    root.RectTransform.ScreenSpaceOffset = Point(0, -Common.SafeIntScale(25))
    UI.MenuRoot, UI.CurrentMenu, S.currentMenu, S.guiRoot = root, root, root, root
    local layout = P.CreateLayout(root, 0.965, 0.955, GUI.Anchor.Center, false)
    layout.RelativeSpacing = 0.007
    local heading = P.CreateLayout(layout, 1, 0.055, nil, true)
    local drag = GUI.DragHandle(P.CreateRect(0.87, 1, heading, GUI.Anchor.TopLeft), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    drag.Color, drag.HoverColor, drag.SelectedColor, drag.PressedColor = transparent, transparent, transparent, transparent
    local indicator = GUI.Image(P.CreateRect(0.07, 0.72, drag, GUI.Anchor.CenterLeft), "GUIDragIndicator")
    indicator.CanBeFocused = false
    local title = P.CreateText(drag, 0.90, 1, GUI.Anchor.CenterRight, snapshot.Text.Title, GUI.Alignment.Left, 1.15)
    title.Font = GUI.Style.SubHeadingFont
    local close = P.CreateButton(heading, 0.12, 1, nil, snapshot.Text.Close)
    close.TextBlock.AutoScaleHorizontal = true
    close.OnClicked = function()
        UI.CloseMenu()
        if Character.Controlled ~= nil then
            Character.Controlled.EmulateInput(inputTypes.Deselect)
            Character.Controlled.SelectedItem = nil
        end
        return true
    end
    UI.Budget = P.CreateText(layout, 1, 0.065, nil, "", GUI.Alignment.Left, 0.85, nil, false)
    UI.Budget.AutoScaleHorizontal = true
    UI.Budget.AutoScaleVertical = true
    local upper = P.CreateLayout(layout, 1, 0.58, nil, true)
    upper.RelativeSpacing = 0.015
    S.catalogHost = GUI.Frame(P.CreateRect(0.66, 1, upper), nil)
    S.catalogHost.Color = Color(0, 0, 0, 0)
    S.catalogHost.CanBeFocused = false
    local cartFrame = GUI.Frame(P.CreateRect(0.325, 1, upper), "GUIFrameListBox")
    local cart = P.CreateLayout(cartFrame, 0.95, 0.94, GUI.Anchor.Center, false)
    cart.RelativeSpacing = 0.007
    P.CreateText(cart, 1, 0.085, nil, snapshot.Text.Cart, GUI.Alignment.Left, 1.0)
    UI.Details = P.CreateText(cart, 1, 0.18, nil, "", GUI.Alignment.Left, 0.75)
    UI.Details.AutoScaleHorizontal = true
    UI.Details.AutoScaleVertical = true
    UI.CartList = GUI.ListBox(P.CreateRect(1, 0.30, cart), false)
    UI.Total = P.CreateText(cart, 1, 0.07, nil, "", GUI.Alignment.Left, 0.95)
    P.CreateText(cart, 1, 0.06, nil, snapshot.Text.Reason, GUI.Alignment.Left, 0.9)
    UI.Reason = GUI.TextBox(P.CreateRect(1, 0.105, cart), "")
    UI.Reason.MaxTextLength = 300
    UI.Reason.OnTextChangedDelegate = function() P.RefreshCartOnly() return true end
    UI.Submit = P.CreateButton(cart, 1, 0.10, nil, snapshot.Text.Submit, false)
    UI.Submit.TextBlock.AutoScaleHorizontal = true
    UI.Submit.OnClicked = function()
        if UI.SubmitPending or #S.cart == 0 or string.find(tostring(UI.Reason.Text), "%S") == nil then return true end
        local entries = {}
        for _, entry in ipairs(S.cart) do entries[#entries + 1] = { Id = entry.Id, Quantity = entry.Quantity } end
        UI.SubmitPending = true
        UI.Send("submit", { Entries = entries, Reason = tostring(UI.Reason.Text) })
        P.RefreshProductRows()
        P.RefreshCartOnly()
        return true
    end
    P.CreateText(layout, 1, 0.04, nil, snapshot.Text.Orders, GUI.Alignment.Left, 1.0)
    UI.OrderList = GUI.ListBox(P.CreateRect(1, 0.225, layout), false)
    UI.ResizeTop, UI.ResizeBottom = {}, {}
    UI.ResizeSides = { left = {}, right = {}, minimumWidth = 720 }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
    UI.Update(snapshot)
    if S.shopList == nil then P.ShowMenu() end
end

Networking.Receive("VoidTraitor_CargoSnapshot", function(message)
    if UI.Disabled then return end
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.ItemId == itemId and (UI.AwaitingOpen or UI.MenuRoot ~= nil) then
        UI.Show(itemId, snapshot)
    end
end)

Hook.Patch("VoidTraitor.Cargo.Hud", "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if UI.Disabled or UI.MenuRoot == nil or GUI.DisableHUD then return end
    UI.MenuRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)
    if S.filterPopup ~= nil then S.filterPopup:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER + 60) end
end)
Common.InstallPausePatch("VoidTraitor.Cargo.Pause", "VoidTraitorCargoGuiState")
Hook.Patch("VoidTraitor.Cargo.NativeHud", "Barotrauma.Item", "AddToGUIUpdateList", { "System.Int32" }, function(item, parameters)
    if not UI.Disabled and Game.RoundStarted and item.Prefab.Identifier == "vt_cargo_console" then parameters.PreventExecution = true end
end, Hook.HookMethodType.Before)
Hook.Patch("VoidTraitor.Cargo.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.Cargo.End", function() UI.CloseMenu() UI.SelectedItem = nil end)
function UI.RequestOpen(item)
    UI.SelectedItem, UI.ItemId, UI.AwaitingOpen = item, item.ID, true
    local message = Networking.Start("VoidTraitor_CargoOpen")
    message.WriteUInt16(UShort(item.ID))
    Networking.Send(message)
end

Hook.Add("item.interact", "VoidTraitor.Cargo.Interact", function(item, character)
    if UI.Disabled or not Networking.IsActive or character ~= Character.Controlled
        or item.Prefab.Identifier ~= "vt_cargo_console" or not character.CanInteractWith(item)
        or UI.SelectedItem == item then return end
    if UI.SelectedItem ~= nil then UI.CloseMenu() end
    UI.RequestOpen(item)
end)

Hook.Add("think", "VoidTraitor.Cargo.Selection", function(deltaTime)
    if UI.Disabled then return end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom,
            480, UI.OrderList, nil, nil, nil, UI.ResizeSides)
    end
    if not Networking.IsActive then UI.CloseMenu() UI.SelectedItem = nil return end
    local character = Character.Controlled
    if character == nil or character.IsDead or character.IsIncapacitated then
        if UI.SelectedItem ~= nil then UI.CloseMenu() end
        UI.SelectedItem = nil
        return
    end
    local item = character.SelectedItem
    if UI.SelectedItem ~= nil and (UI.AwaitingOpen or UI.MenuRoot ~= nil) then
        if (item ~= nil and item ~= UI.SelectedItem) or UI.SelectedItem.Removed
            or not character.CanInteractWith(UI.SelectedItem) then
            UI.CloseMenu()
            UI.SelectedItem = nil
        end
        return
    end
    if item == nil or item.Prefab.Identifier ~= "vt_cargo_console" then
        UI.SelectedItem = nil
        return
    end
    UI.RequestOpen(item)
end)
