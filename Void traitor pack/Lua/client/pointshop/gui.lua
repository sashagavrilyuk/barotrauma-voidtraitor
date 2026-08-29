if SERVER then return end

local _, Common = ...

-- Void Traitor Pointshop GUI.
-- Client-side visual shell only. The server is still authoritative for prices,
-- limits, stock, cooldowns and actual purchases.

local NET_READY = "VoidTraitor_PointshopGuiReady"
local NET_REQUEST = "VoidTraitor_PointshopRequest"
local NET_SNAPSHOT = "VoidTraitor_PointshopSnapshot"
local NET_STATE = "VoidTraitor_PointshopState"
local NET_BALANCE = "VoidTraitor_PointshopBalance"
local NET_PRODUCT_STATE = "VoidTraitor_PointshopProductState"
local NET_BUY_CART = "VoidTraitor_PointshopBuyCart"
local NET_PROBE = "VoidTraitor_PointshopProbe"
local NET_PURCHASE_SOUND = "VoidTraitor_PointshopPurchaseSound"
local NET_CLASS_LIMITS = "VoidTraitor_PointshopClassLimits"

local currentMenu = nil
local cartPanelRoot = nil
local shopList = nil
local shopListScroll = 0
local escapeClosePending = false

local products = {}
local productById = {}
local cart = {}

local selectedCategory = nil
local selectedPath = nil
local selectedProductId = nil
local currentView = "categories"
local currentPoints = 0
local lastMessage = ""
local shopMode = "shop"
local pendingProductId = nil
local closeMenuAfterSnapshot = false
local expandedFolders = {}
local cooldownTextBlocks = { shop = {}, cart = {} }
local classLimitTextBlocks = { shop = {}, cart = {} }
local classLimitValues = {}
local nextCooldownTextUpdateTime = 0
local cooldownSnapshotRequested = false
local buyRequestPending = false
local searchText = ""
local normalizedSearchText = ""
local selectedFilter = "all"
local productRows = {}
local rebuildProductList = nil
local filterPopup = nil
local filterButton = nil
local CloseFilterPopup
local ShowMenu
local RefreshCartOnly

local GUI_DRAW_ORDER = 120
local PANEL_WIDTH = 0.290
local ITEM_ROW_HEIGHT = 0.124
local ITEM_ICON_PIXELS = 86
local ACTION_BUTTON_PIXELS = 102
local NET_INT32_MAX = 2147483647


-- Keep a single live GUI root between Lua reloads.
local GLOBAL_STATE_KEY = "VoidTraitorPointshopGuiState"
local HUD_PATCH_ID = "VoidTraitor.PointshopGui.Hud"
local PAUSE_PATCH_ID = "VoidTraitor.PointshopGui.Pause"
local previousState = rawget(_G, GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then pcall(previousState.CloseMenu) end
    if previousState.GuiRoot ~= nil then
        pcall(function() previousState.GuiRoot:RemoveFromGUIUpdateList(true) end)
        pcall(function()
            previousState.GuiRoot.Visible = false
            if previousState.GuiRoot.RectTransform ~= nil then
                previousState.GuiRoot.RectTransform.Parent = nil
            end
        end)
    end
end
local sharedState = { Disabled = false }
_G[GLOBAL_STATE_KEY] = sharedState

local textKeys = {
    "Categories",
    "BuyTab",
    "Shop",
    "Cart",
    "Points",
    "Total",
    "After",
    "Buy",
    "Clear",
    "EmptyCart",
    "EmptyProducts",
    "EmptyCategories",
    "ClickProduct",
    "Stock",
    "NoCategory",
    "SinglePurchase",
    "StockLimit",
    "Balance",
    "Quantity",
    "ConfirmTitle",
    "ConfirmQuestion",
    "ConfirmClassQuestion",
    "Cancel",
    "Cooldown",
    "SelectGhostAction",
    "SelectClassAction",
    "Filter",
    "Search",
    "FilterAll",
    "FilterAvailable",
    "FilterAffordable",
    "Price",
    "Remaining",
    "Unlimited",
    "Category",
    "Unavailable",
    "NotEnoughPoints",
}

local text = {}
for _, key in ipairs(textKeys) do
    text[key] = ""
end

local function GetText(key)
    return text[key] or ""
end

local function SendReady()
    local msg = Networking.Start(NET_READY)
    Networking.Send(msg)
end

local function RequestSnapshot()
    local msg = Networking.Start(NET_REQUEST)
    Networking.Send(msg)
end

SendReady()
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 2000)
Timer.Wait(function() if not sharedState.Disabled then SendReady() end end, 6000)

local function GetParentRect(parent)
    if parent == nil or parent == GUI.Canvas then
        return nil
    end

    local ok, rectTransform = pcall(function()
        return parent.RectTransform
    end)

    if ok and rectTransform ~= nil then
        return rectTransform
    end

    return parent
end

local function CreateRect(width, height, parent, anchor)
    return GUI.RectTransform(Vector2(width, height), GetParentRect(parent), anchor)
end

local function PlayPurchaseSound()
    SoundPlayer.PlayUISound(GUI.SoundType.ConfirmTransaction)
end
local guiRoot = GUI.Frame(CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
guiRoot.Color = Color(0, 0, 0, 0)
guiRoot.CanBeFocused = false
guiRoot.IgnoreLayoutGroups = true
sharedState.GuiRoot = guiRoot
guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER)

-- Reinsert the root when Barotrauma rebuilds the GUI update list.
Hook.Patch(HUD_PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state ~= nil and state.GuiRoot ~= nil and not state.Disabled then
        state.GuiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER)
    end
end)

-- ESC guard: close the shop instead of opening the vanilla pause menu.
Hook.Patch(PAUSE_PATCH_ID, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, params)
    local state = rawget(_G, GLOBAL_STATE_KEY)
    if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
        if state.CurrentMenu ~= nil and state.CloseMenu ~= nil then
            state.CloseMenu()
        end
        if params ~= nil then params.PreventExecution = true end
        return false
    end
end, Hook.HookMethodType.Before)

local CloseMenu

local function IsEscapeHit()
    local ok, hit = pcall(function()
        if Keys ~= nil and Keys.Escape ~= nil then
            return PlayerInput.KeyHit(Keys.Escape)
        end
        return false
    end)
    if ok and hit then return true end

    ok, hit = pcall(function()
        return PlayerInput.KeyHit(Microsoft.Xna.Framework.Input.Keys.Escape)
    end)
    return ok and hit == true
end

local function RequestEscapeClose()
    if currentMenu == nil or escapeClosePending then return end
    escapeClosePending = true
    sharedState.BlockPauseMenu = true
    CloseMenu()
    Timer.Wait(function()
        sharedState.BlockPauseMenu = false
    end, 250)
end

pcall(function() Hook.Remove("think", "VoidTraitor.PointshopGui.CooldownClock") end)
pcall(function() Hook.Remove("keyUpdate", "VoidTraitor.PointshopGui.PauseGuard") end)

-- keyUpdate fires before the game's ESC handler.
Hook.Add("keyUpdate", "VoidTraitor.PointshopGui.PauseGuard", function()
    if sharedState.Disabled then return end
    if currentMenu ~= nil and IsEscapeHit() then
        RequestEscapeClose()
    end
end)


local function SetButtonStyle(button, enabled, selected)
    if button == nil then return end
    button.Enabled = enabled ~= false
    button.Selected = selected == true
    pcall(function()
        button.ForceUpperCase = true
    end)
end

local function CreateButton(parent, width, height, anchor, label, enabled, selected, style)
    local button = GUI.Button(CreateRect(width, height, parent, anchor), label or "", GUI.Alignment.Center, style or "GUIButton")
    SetButtonStyle(button, enabled ~= false, selected == true)

    if button.TextBlock ~= nil then
        if label ~= nil and string.len(label) > 54 then
            button.TextBlock.TextScale = 0.76
        elseif label ~= nil and string.len(label) > 38 then
            button.TextBlock.TextScale = 0.86
        else
            button.TextBlock.TextScale = 0.98
        end
    end

    return button
end

local function CreateText(parent, width, height, anchor, label, alignment, scale, color, wrap)
    if wrap == nil then wrap = true end
    local block = GUI.TextBlock(CreateRect(width, height, parent, anchor), label or "", nil, nil, alignment or GUI.Alignment.Left, wrap)
    block.TextColor = color or Color(230, 230, 220, 255)
    block.TextScale = scale or 1
    return block
end

local function Utf8Truncate(value, maxChars)
    value = tostring(value or "")
    maxChars = maxChars or 36

    local count = 0
    local result = ""
    for char in string.gmatch(value, "[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > maxChars then
            return result .. "..."
        end
        result = result .. char
    end

    return value
end

local utf8Lower = {
    ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г", ["Д"] = "д", ["Е"] = "е", ["Ё"] = "ё",
    ["Ж"] = "ж", ["З"] = "з", ["И"] = "и", ["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м",
    ["Н"] = "н", ["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т", ["У"] = "у",
    ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч", ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ",
    ["Ы"] = "ы", ["Ь"] = "ь", ["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

local function NormalizeSearchText(value)
    -- Lua patterns are byte-based: iterating UTF-8 characters with a pattern
    -- silently produced an empty string for Cyrillic input on some LuaCs
    -- builds. Keep the UTF-8 bytes intact and replace only known uppercase
    -- Russian letters, then apply the regular ASCII lowercase conversion.
    local result = tostring(value or "")
    for upper, lower in pairs(utf8Lower) do
        result = string.gsub(result, upper, lower)
    end
    result = string.lower(result)
    return string.gsub(string.gsub(result, "^%s+", ""), "%s+$", "")
end

CloseMenu = function()
    if CloseFilterPopup ~= nil then CloseFilterPopup() end

    if shopList ~= nil then
        shopListScroll = shopList.BarScroll
    end
    shopList = nil

    if currentMenu ~= nil then
        currentMenu:RemoveFromGUIUpdateList(true)
        currentMenu.RectTransform.Parent = nil
        currentMenu.Visible = false
    end


    currentMenu = nil
    sharedState.CurrentMenu = nil
    cartPanelRoot = nil
    filterButton = nil
    rebuildProductList = nil
    productRows = {}
    cooldownTextBlocks.shop = {}
    cooldownTextBlocks.cart = {}
    classLimitTextBlocks.shop = {}
    classLimitTextBlocks.cart = {}
    escapeClosePending = false
    buyRequestPending = false

    if sharedState.BlockPauseMenu ~= true then
        sharedState.BlockPauseMenu = false
    end
end
sharedState.CloseMenu = CloseMenu

local function CreateLayout(parent, width, height, anchor, horizontal, childAnchor)
    local group = GUI.LayoutGroup(CreateRect(width, height, parent, anchor), horizontal == true, childAnchor or GUI.Anchor.TopLeft)
    group.Stretch = true
    group.RelativeSpacing = 0.006
    return group
end

local function CreateDivider(parent, height)
    local divider = GUI.Frame(CreateRect(1, height or 0.012, parent, nil), "HorizontalLine")
    divider.CanBeFocused = false
    return divider
end

local function CreatePanelTitle(parent, title, iconStyle, showLabel)
    local frame = GUI.Frame(CreateRect(1, 0.095, parent, nil), "GUIFrame")
    frame.CanBeFocused = false

    local row = CreateLayout(frame, 0.95, 0.88, GUI.Anchor.Center, true, GUI.Anchor.CenterLeft)
    row.RelativeSpacing = 0.012
    row.Stretch = true

    if iconStyle ~= nil then
        local iconFrame = GUI.Frame(CreateRect(0.14, 1, row, nil), nil)
        iconFrame.Color = Color(0, 0, 0, 0)
        iconFrame.CanBeFocused = false
        local icon = GUI.Image(CreateRect(0.90, 0.90, iconFrame, GUI.Anchor.Center), iconStyle)
        icon.CanBeFocused = false
    end

    if showLabel ~= false then
        local titleBlock = CreateText(row, 0.72, 1, nil, string.upper(tostring(title or "")), GUI.Alignment.CenterLeft, 1.20, Color(245, 240, 215, 255))
        titleBlock.AutoScaleHorizontal = true
        titleBlock.AutoScaleVertical = true
        return titleBlock
    end

    return nil
end

local function GetClientTime()
    if Timer ~= nil and Timer.GetTime ~= nil then
        return Timer.GetTime()
    end
    return 0
end

local function FormatSeconds(seconds)
    seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local remainder = seconds % 60
    if minutes > 0 then
        return tostring(minutes) .. ":" .. string.format("%02d", remainder)
    end
    return tostring(seconds) .. "s"
end

local function GetCooldownRemaining(product)
    if product == nil then return 0 end
    if product.CooldownEndTime ~= nil then
        return math.max(0, product.CooldownEndTime - GetClientTime())
    end
    return math.max(0, tonumber(product.CooldownRemaining) or 0)
end

local function RegisterCooldownText(groupName, block, getText)
    if block == nil or getText == nil then return end
    local group = cooldownTextBlocks[groupName or "shop"]
    if group == nil then
        group = {}
        cooldownTextBlocks[groupName or "shop"] = group
    end
    table.insert(group, { Block = block, GetText = getText })
end

local function UpdateCooldownTextBlocks()
    local hadActive = false
    for _, group in pairs(cooldownTextBlocks) do
        for index = #group, 1, -1 do
            local entry = group[index]
            local ok, value, active = pcall(entry.GetText)
            if not ok or entry.Block == nil then
                table.remove(group, index)
            else
                entry.Block.Text = value or ""
                if active then hadActive = true end
            end
        end
    end

    if not hadActive and currentMenu ~= nil and not cooldownSnapshotRequested then
        cooldownSnapshotRequested = true
        Timer.Wait(function()
            cooldownSnapshotRequested = false
            if currentMenu ~= nil and not sharedState.Disabled then
                RequestSnapshot()
            end
        end, 350)
    end
end

local function GetClassLimitKey(categoryIdentifier, pathIdentifiers)
    categoryIdentifier = tostring(categoryIdentifier or "")
    pathIdentifiers = tostring(pathIdentifiers or "")
    return categoryIdentifier .. "\31" .. pathIdentifiers
end

local function GetClassLimitText(categoryIdentifier, pathIdentifiers)
    return classLimitValues[GetClassLimitKey(categoryIdentifier, pathIdentifiers)] or ""
end

local function IsClassProduct(product)
    if product == nil then return false end
    return product.IsClassProduct == true or product.Type == "class"
end

local function GetProductLimitText(product)
    if not IsClassProduct(product) then return "" end
    if product.ClassLimitKey ~= nil and product.ClassLimitKey ~= "" then
        return GetClassLimitText(product.CategoryIdentifier, product.ClassLimitKey)
    end
    return GetClassLimitText(product.CategoryIdentifier, product.PathIdentifiers)
end

local function GetProductDisabledReason(product)
    if product == nil then return GetText("Unavailable") end

    local reason = tostring(product.DisabledReason or "")
    if reason ~= "" then return reason end

    if product.Price ~= nil and product.Price > currentPoints then
        return GetText("NotEnoughPoints")
    end

    return ""
end

local function GetProductDescriptionText(product)
    if product == nil then return "" end

    local limitText = GetProductLimitText(product)
    if limitText == "" then return tostring(product.Description or "") end

    local description = tostring(product.Description or "")
    if description ~= "" then
        return description .. "\n\n" .. limitText
    end
    return limitText
end

local function RegisterClassLimitText(groupName, block, getText)
    if block == nil or getText == nil then return end

    local group = classLimitTextBlocks[groupName or "shop"]
    if group == nil then
        group = {}
        classLimitTextBlocks[groupName or "shop"] = group
    end

    table.insert(group, { Block = block, GetText = getText })
end

local function UpdateClassLimitTextBlocks()
    for _, group in pairs(classLimitTextBlocks) do
        for index = #group, 1, -1 do
            local entry = group[index]
            local ok, value = pcall(entry.GetText)
            if not ok or entry.Block == nil then
                table.remove(group, index)
            else
                entry.Block.Text = value or ""
            end
        end
    end
end

local function ProductMatchesSelectedFolder(product)
    if product == nil then return false end
    if selectedCategory == nil then return true end
    if product.CategoryIdentifier ~= selectedCategory then return false end

    if selectedPath == nil or selectedPath == "" then
        return true
    end

    local productPath = tostring(product.PathIdentifiers or "")
    if productPath == selectedPath then return true end
    return string.sub(productPath, 1, string.len(selectedPath) + 1) == selectedPath .. "/"
end

local function ProductMatchesSearchAndFilter(product)
    if not ProductMatchesSelectedFolder(product) then return false end

    if normalizedSearchText ~= "" then
        local haystack = NormalizeSearchText(
            tostring(product.Name or "") .. " " ..
            tostring(product.Description or "") .. " " ..
            tostring(product.Id or "") .. " " ..
            tostring(product.Type or "")
        )
        if not string.find(haystack, normalizedSearchText, 1, true) then
            return false
        end
    end

    if selectedFilter == "available" and GetProductDisabledReason(product) ~= "" then
        return false
    elseif selectedFilter == "affordable" and (tonumber(product.Price) or 0) > currentPoints then
        return false
    end

    return true
end

local function ShouldShowProductPrice(product)
    if product == nil then return false end
    if IsClassProduct(product) and (tonumber(product.Price) or 0) <= 0 then return false end
    return true
end

local function ReadProduct(message)
    local product = {}
    product.Id = message.ReadString()
    product.Name = message.ReadString()
    product.Description = message.ReadString()
    product.Type = message.ReadString()
    product.IconIdentifier = message.ReadString()
    product.Price = message.ReadInt32()
    product.CategoryIdentifier = message.ReadString()
    product.CategoryName = message.ReadString()
    product.CategoryIconIdentifier = message.ReadString()
    product.PathIdentifiers = message.ReadString()
    product.PathNames = message.ReadString()
    product.PathIcons = message.ReadString()
    product.Limit = message.ReadInt32()
    product.Stock = message.ReadInt32()
    product.DisabledReason = message.ReadString()
    product.MaxQuantity = message.ReadInt32()
    product.CooldownRemaining = message.ReadSingle()
    product.CooldownEndTime = product.CooldownRemaining > 0 and (GetClientTime() + product.CooldownRemaining) or nil
    product.IsClassProduct = message.ReadBoolean()
    product.ClassLimitKey = message.ReadString()
    return product
end

local function IndexProducts()
    productById = {}
    for _, product in ipairs(products) do
        productById[product.Id] = product
    end
end

local function ReadCart(message)
    cart = {}
    local count = message.ReadInt32()
    for i = 1, count do
        table.insert(cart, {
            Id = message.ReadString(),
            Quantity = message.ReadInt32(),
        })
    end
end

local function ReadText(message)
    for _, key in ipairs(textKeys) do
        text[key] = message.ReadString()
    end
end

local function ReadState(message)
    currentPoints = message.ReadInt32()
    lastMessage = message.ReadString()
    selectedCategory = message.ReadString()
    if selectedCategory == "" then selectedCategory = nil end
    selectedPath = message.ReadString()
    if selectedPath == "" then selectedPath = nil end
    selectedProductId = message.ReadString()
    if selectedProductId == "" then selectedProductId = nil end
    currentView = message.ReadString()
    shopMode = message.ReadString()
    pendingProductId = message.ReadString()
    if pendingProductId == "" then pendingProductId = nil end
    closeMenuAfterSnapshot = message.ReadBoolean()
    ReadCart(message)
    return true
end

local function ReadSnapshot(message)
    ReadState(message)

    local productCount = message.ReadInt32()
    products = {}
    for i = 1, productCount do
        table.insert(products, ReadProduct(message))
    end
    IndexProducts()

    ReadText(message)
end

local function ReadProductState(message)
    local productId = message.ReadString()
    local price = message.ReadInt32()
    local stock = message.ReadInt32()
    local disabledReason = message.ReadString()
    local maxQuantity = message.ReadInt32()
    local cooldownRemaining = message.ReadSingle()

    local product = productById[productId]
    if product == nil then return false end

    local matchedFilter = ProductMatchesSearchAndFilter(product)
    local showedPrice = ShouldShowProductPrice(product)
    local hadCooldown = GetCooldownRemaining(product) > 0

    product.Price = price
    product.Stock = stock
    product.DisabledReason = disabledReason or ""
    product.MaxQuantity = maxQuantity
    product.CooldownRemaining = cooldownRemaining
    product.CooldownEndTime = cooldownRemaining > 0 and (GetClientTime() + cooldownRemaining) or nil
    return true,
        matchedFilter ~= ProductMatchesSearchAndFilter(product)
        or showedPrice ~= ShouldShowProductPrice(product)
        or hadCooldown ~= (GetCooldownRemaining(product) > 0)
end

local function ReconcileProductState(purchaseCompleted)
    local newCart = {}
    for _, entry in ipairs(cart) do
        local product = productById[entry.Id]
        if product ~= nil then
            local quantity = math.max(1, math.min(entry.Quantity or 1, math.max(1, product.MaxQuantity or 1)))
            if product.Stock ~= nil and product.Stock >= 0 then
                quantity = math.min(quantity, product.Stock)
            end
            if quantity > 0 then
                table.insert(newCart, { Id = entry.Id, Quantity = quantity })
            end
        end
    end
    cart = newCart

    if purchaseCompleted then
        selectedProductId = nil
        pendingProductId = nil
    elseif selectedProductId ~= nil and productById[selectedProductId] == nil then
        selectedProductId = nil
    end

    if pendingProductId ~= nil and productById[pendingProductId] == nil then
        pendingProductId = nil
    end
end

local function SplitSlash(value)
    local result = {}
    value = tostring(value or "")
    if value == "" then return result end
    for part in string.gmatch(value, "[^/]+") do
        table.insert(result, part)
    end
    return result
end

local function GetSelectedProduct()
    if selectedProductId == nil then return nil end
    return productById[selectedProductId]
end

local function GetPendingProduct()
    if pendingProductId == nil then return nil end
    return productById[pendingProductId]
end

local function GetCartEntry(productId)
    for _, entry in ipairs(cart) do
        if entry.Id == productId then return entry end
    end
    return nil
end

local function GetCartTotal()
    local total = 0
    for _, entry in ipairs(cart) do
        local product = productById[entry.Id]
        if product ~= nil then
            total = total + (product.Price or 0) * math.max(1, entry.Quantity or 1)
        end
    end
    return total
end

local function AddToCart(product)
    if product == nil then return end

    local entry = GetCartEntry(product.Id)
    if entry == nil then
        entry = { Id = product.Id, Quantity = 0 }
        table.insert(cart, entry)
    end

    local maxQuantity = math.max(1, tonumber(product.MaxQuantity) or 1)
    local nextQuantity = math.min(entry.Quantity + 1, maxQuantity)
    if product.Stock ~= nil and product.Stock >= 0 then
        nextQuantity = math.min(nextQuantity, product.Stock)
    end
    entry.Quantity = math.max(1, nextQuantity)
end

local function RemoveFromCart(productId)
    for index, entry in ipairs(cart) do
        if entry.Id == productId then
            if entry.Quantity > 1 then
                entry.Quantity = entry.Quantity - 1
            else
                table.remove(cart, index)
            end
            return
        end
    end
end

local function ClearCart()
    cart = {}
    selectedProductId = nil
end

local function SendBuyRequest(entries)
    if buyRequestPending then return end
    buyRequestPending = true

    local ok = pcall(function()
        local msg = Networking.Start(NET_BUY_CART)
        msg.WriteInt32(#entries)
        for _, entry in ipairs(entries) do
            msg.WriteString(entry.Id)
            msg.WriteInt32(entry.Quantity or 1)
        end
        Networking.Send(msg)
    end)

    if not ok then
        buyRequestPending = false
    end
end

local function BuyCart()
    if #cart == 0 then return end
    SendBuyRequest(cart)
end

local function GetFolderTree()
    local categories = {}
    local categoryByIdentifier = {}

    for _, product in ipairs(products) do
        local categoryIdentifier = tostring(product.CategoryIdentifier or "")
        local categoryName = tostring(product.CategoryName or categoryIdentifier)
        local categoryIconIdentifier = tostring(product.CategoryIconIdentifier or "")

        local category = categoryByIdentifier[categoryIdentifier]
        if category == nil then
            category = {
                Identifier = categoryIdentifier,
                Name = categoryName,
                IconIdentifier = categoryIconIdentifier,
                Children = {},
                ChildByIdentifier = {},
                Products = {},
                PathIdentifiers = "",
                PathNames = "",
                Parent = nil,
            }
            categoryByIdentifier[categoryIdentifier] = category
            table.insert(categories, category)
        end

        local identifiers = SplitSlash(product.PathIdentifiers)
        local names = SplitSlash(product.PathNames)
        local icons = SplitSlash(product.PathIcons)
        local node = category
        local idPath = {}
        local namePath = {}

        for index, identifier in ipairs(identifiers) do
            table.insert(idPath, identifier)
            table.insert(namePath, names[index] or identifier)

            local child = node.ChildByIdentifier[identifier]
            if child == nil then
                child = {
                    Identifier = identifier,
                    Name = names[index] or identifier,
                    IconIdentifier = icons[index] or "",
                    Children = {},
                    ChildByIdentifier = {},
                    Products = {},
                    PathIdentifiers = table.concat(idPath, "/"),
                    PathNames = table.concat(namePath, "/"),
                    Parent = node,
                }
                node.ChildByIdentifier[identifier] = child
                table.insert(node.Children, child)
            end
            node = child
        end

        table.insert(node.Products, product)
    end

    return categories
end

local function SortFolders(folders)
    table.sort(folders, function(a, b)
        return string.lower(tostring(a.Name or "")) < string.lower(tostring(b.Name or ""))
    end)
    for _, folder in ipairs(folders) do
        SortFolders(folder.Children)
    end
end

local function GetFolderDisplayCount(folder)
    local count = #folder.Products
    for _, child in ipairs(folder.Children) do
        count = count + GetFolderDisplayCount(child)
    end
    return count
end

local function GetFolderByPath(category, path)
    if category == nil then return nil end
    if path == nil or path == "" then return category end

    local node = category
    for _, identifier in ipairs(SplitSlash(path)) do
        node = node.ChildByIdentifier[identifier]
        if node == nil then return nil end
    end
    return node
end

local function GetSelectedFolder()
    if selectedCategory == nil then return nil end
    local categories = GetFolderTree()
    SortFolders(categories)
    for _, category in ipairs(categories) do
        if category.Identifier == selectedCategory then
            return GetFolderByPath(category, selectedPath)
        end
    end
    return nil
end

local function GetSelectedFolderName()
    local folder = GetSelectedFolder()
    if folder == nil then return GetText("Categories") end
    return folder.Name or GetText("Categories")
end

local function GetClassSelectText()
    local value = GetText("SelectClassAction")
    if value == "" then value = GetText("SelectGhostAction") end
    return value
end

local function SelectedFolderHasClassProducts()
    if shopMode ~= "attackdefend" then return false end
    for _, product in ipairs(products) do
        if ProductMatchesSelectedFolder(product) and IsClassProduct(product) then
            return true
        end
    end
    return false
end

local function CreateRowInner(row, width, height)
    return CreateLayout(row, width, height, GUI.Anchor.Center, true, GUI.Anchor.CenterLeft)
end

local function CreateProductIcon(parent, iconIdentifier, enabled)
    local box = GUI.Frame(CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    box.CanBeFocused = false
    box.RectTransform.IsFixedSize = true
    box.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    box.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)

    local sprite, spriteColor = Common.GetPrefabIconData(iconIdentifier)
    if sprite == nil then return end

    local image = GUI.Image(CreateRect(0.82, 0.82, box, GUI.Anchor.Center), sprite, true)
    if image ~= nil then
        image.Color = enabled == false and Color(105, 105, 105, 190) or spriteColor
        return image, spriteColor
    end

    return nil, nil
end

local function UpdateProductRowSelection()
    for _, entry in ipairs(productRows) do
        if entry.Row ~= nil and entry.Product ~= nil then
            entry.Row.Selected = entry.Product.Id == selectedProductId
        end
    end
end

local function GetProductRowSubText(product)
    local cooldownRemaining = GetCooldownRemaining(product)
    if cooldownRemaining > 0 then
        return GetText("Cooldown") .. ": " .. FormatSeconds(cooldownRemaining)
    elseif IsClassProduct(product) and GetProductLimitText(product) ~= "" then
        return GetProductLimitText(product)
    elseif product.Stock ~= nil and product.Limit ~= nil and product.Limit < 999 then
        return GetText("Stock") .. ": " .. tostring(product.Stock) .. " / " .. tostring(product.Limit)
    end

    local disabledReason = GetProductDisabledReason(product)
    if disabledReason ~= "" then return disabledReason end
    return product.Type or ""
end

local function CreateStoreActionButton(parent, width, style, enabled)
    local holder = GUI.Frame(CreateRect(width, 1, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local button = GUI.Button(CreateRect(0.92, 0.92, holder, GUI.Anchor.Center), "", GUI.Alignment.Center, style)
    button.Enabled = enabled ~= false
    button.RectTransform.IsFixedSize = true
    button.RectTransform.MinSize = Point(ACTION_BUTTON_PIXELS, ACTION_BUTTON_PIXELS)
    button.RectTransform.MaxSize = Point(math.floor(ACTION_BUTTON_PIXELS * 1.12), math.floor(ACTION_BUTTON_PIXELS * 1.12))
    if button.TextBlock ~= nil then
        button.TextBlock.Text = ""
    end

    return button
end

local function AddProductButton(list, product)
    local disabledReason = GetProductDisabledReason(product)
    local enabled = disabledReason == ""

    local row = CreateButton(list.Content, 1, ITEM_ROW_HEIGHT, GUI.Anchor.TopLeft, "", true, selectedProductId == product.Id, "ListBoxElement")
    if row.TextBlock ~= nil then row.TextBlock.Text = "" end

    local inner = CreateRowInner(row, 0.968, 0.90)
    inner.RelativeSpacing = 0.003
    inner.Stretch = true

    local iconHolder = GUI.Frame(CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    iconHolder.RectTransform.IsFixedSize = true
    iconHolder.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    iconHolder.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    local icon, iconColor = CreateProductIcon(iconHolder, product.IconIdentifier, enabled)

    local showPrice = ShouldShowProductPrice(product)
    local textGroup = CreateLayout(inner, showPrice and 0.535 or 0.66, 0.95, nil, false, GUI.Anchor.CenterLeft)
    textGroup.RelativeSpacing = 0
    textGroup.Stretch = true

    local nameText = string.upper(tostring(product.Name or ""))
    local name = CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, nameText, GUI.Alignment.Left, 0.88, enabled and Color(235, 235, 225, 255) or Color(130, 130, 130, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    name.AutoScaleHorizontal = false
    name.AutoScaleVertical = false

    local cooldownRemaining = GetCooldownRemaining(product)
    local details = CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, Utf8Truncate(GetProductRowSubText(product), 46), GUI.Alignment.Left, 0.80, enabled and Color(190, 205, 190, 235) or Color(120, 120, 120, 220), false)
    details.AutoScaleHorizontal = false
    details.AutoScaleVertical = false
    if cooldownRemaining > 0 then
        RegisterCooldownText("shop", details, function()
            local remaining = GetCooldownRemaining(product)
            if remaining <= 0 then return "", false end
            return GetText("Cooldown") .. ": " .. FormatSeconds(remaining), true
        end)
    elseif IsClassProduct(product) then
        RegisterClassLimitText("shop", details, function()
            return GetProductLimitText(product)
        end)
    end

    local price = nil
    if showPrice then
        price = CreateText(inner, 0.125, 0.72, nil, tostring(product.Price or 0) .. " pt", GUI.Alignment.Right, 0.96, enabled and Color(255, 245, 210, 255) or Color(125, 125, 125, 255), false)
        price.Font = GUI.Style.SubHeadingFont
        price.AutoScaleHorizontal = true
    end

    local cartButton = CreateStoreActionButton(inner, 0.165, "StoreAddToCrateButton", enabled)
    table.insert(productRows, {
        Row = row,
        Product = product,
        Icon = icon,
        IconColor = iconColor,
        Name = name,
        Details = details,
        Price = price,
        CartButton = cartButton,
    })
    local addProduct = function()
        selectedProductId = product.Id
        UpdateProductRowSelection()
        local currentDisabledReason = GetProductDisabledReason(product)
        if currentDisabledReason == "" then
            if shopMode == "ghost" or IsClassProduct(product) then
                pendingProductId = product.Id
            else
                AddToCart(product)
            end
            RefreshCartOnly()
        else
            lastMessage = currentDisabledReason
            RefreshCartOnly()
        end
        return true
    end
    row.OnClicked = addProduct
    cartButton.OnClicked = addProduct
end

local function RefreshProductRows()
    for _, entry in ipairs(productRows) do
        local product = entry.Product
        local enabled = GetProductDisabledReason(product) == ""

        entry.Row.Selected = product.Id == selectedProductId
        entry.CartButton.Enabled = enabled
        entry.Name.TextColor = enabled and Color(235, 235, 225, 255) or Color(130, 130, 130, 255)
        entry.Details.Text = Utf8Truncate(GetProductRowSubText(product), 46)
        entry.Details.TextColor = enabled and Color(190, 205, 190, 235) or Color(120, 120, 120, 220)

        if entry.Price ~= nil then
            entry.Price.Text = tostring(product.Price or 0) .. " pt"
            entry.Price.TextColor = enabled and Color(255, 245, 210, 255) or Color(125, 125, 125, 255)
        end
        if entry.Icon ~= nil then
            entry.Icon.Color = enabled and entry.IconColor or Color(105, 105, 105, 190)
        end
    end
end

local function AddCartButton(list, entry)
    local product = productById[entry.Id]
    if product == nil then return end

    local row = GUI.Frame(CreateRect(1, ITEM_ROW_HEIGHT, list.Content, GUI.Anchor.TopLeft), "ListBoxElement")
    row.CanBeFocused = false

    local inner = CreateRowInner(row, 0.968, 0.90)
    inner.RelativeSpacing = 0.003
    inner.Stretch = true

    local iconHolder = GUI.Frame(CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    iconHolder.RectTransform.IsFixedSize = true
    iconHolder.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    iconHolder.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    CreateProductIcon(iconHolder, product.IconIdentifier, true)

    local textGroup = CreateLayout(inner, 0.46, 0.95, nil, false, GUI.Anchor.CenterLeft)
    textGroup.RelativeSpacing = 0
    textGroup.Stretch = true

    local nameText = string.upper(tostring(product.Name or ""))
    local name = CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, nameText, GUI.Alignment.Left, 0.88, Color(235, 235, 225, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    name.AutoScaleHorizontal = false
    name.AutoScaleVertical = false

    local details = CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, GetText("Quantity") .. ": " .. tostring(entry.Quantity or 1), GUI.Alignment.Left, 0.80, Color(190, 205, 190, 235), false)
    details.AutoScaleHorizontal = false
    details.AutoScaleVertical = false

    local price = CreateText(inner, 0.14, 0.72, nil, tostring((product.Price or 0) * (entry.Quantity or 1)) .. " pt", GUI.Alignment.Right, 0.96, Color(255, 245, 210, 255), false)
    price.Font = GUI.Style.SubHeadingFont
    price.AutoScaleHorizontal = true

    local removeButton = CreateStoreActionButton(inner, 0.165, "StoreRemoveFromCrateButton", true)
    removeButton.OnClicked = function()
        RemoveFromCart(product.Id)
        RefreshCartOnly()
        return true
    end
end

local function BuildPurchaseSummary(parent, total)
    local summary = GUI.Frame(CreateRect(1, 0.12, parent, nil), "GUIFrame")
    summary.CanBeFocused = false

    local row = CreateLayout(summary, 0.95, 0.82, GUI.Anchor.Center, true, GUI.Anchor.CenterLeft)
    row.RelativeSpacing = 0.008
    row.Stretch = true

    local left = CreateLayout(row, 0.53, 1, nil, false, GUI.Anchor.TopLeft)
    left.RelativeSpacing = 0.001
    left.Stretch = true
    CreateText(left, 1, 0.44, nil, GetText("Points"), GUI.Alignment.Left, 0.78, Color(190, 200, 185, 255))
    local points = CreateText(left, 1, 0.56, nil, tostring(currentPoints), GUI.Alignment.Left, 1.12, Color(255, 245, 210, 255))
    points.Font = GUI.Style.SubHeadingFont

    local right = CreateLayout(row, 0.45, 1, nil, false, GUI.Anchor.TopLeft)
    right.RelativeSpacing = 0.001
    right.Stretch = true
    CreateText(right, 1, 0.44, nil, GetText("After"), GUI.Alignment.Right, 0.78, Color(190, 200, 185, 255))
    local after = CreateText(right, 1, 0.56, nil, tostring(currentPoints - (total or 0)), GUI.Alignment.Right, 1.12, Color(255, 245, 210, 255))
    after.Font = GUI.Style.SubHeadingFont
end

local function CreateProductDetails(parent, product, height)
    if product == nil then return nil end
    height = height or 0.36

    local frame = GUI.Frame(CreateRect(1, height, parent, nil), "GUIFrame")
    frame.CanBeFocused = false

    local content = CreateLayout(frame, 0.94, 0.88, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.005
    content.Stretch = true

    local top = CreateLayout(content, 1, 0.42, nil, true, GUI.Anchor.CenterLeft)
    top.RelativeSpacing = 0.012
    top.Stretch = true

    local iconHolder = GUI.Frame(CreateRect(0.23, 1, top, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    CreateProductIcon(iconHolder, product.IconIdentifier, true)

    local info = CreateLayout(top, 0.75, 0.94, nil, false, GUI.Anchor.TopLeft)
    info.RelativeSpacing = 0.004
    info.Stretch = true

    local name = CreateText(info, 1, 0.60, nil, string.upper(tostring(product.Name or "")), GUI.Alignment.Left, 1.05, Color(245, 240, 215, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    name.AutoScaleHorizontal = true
    local price = ShouldShowProductPrice(product) and (tostring(product.Price or 0) .. " pt") or ""
    if price ~= "" then
        CreateText(info, 1, 0.34, nil, price, GUI.Alignment.Left, 0.90, Color(255, 235, 190, 255))
    end

    local description = GetProductDescriptionText(product)
    if description ~= "" then
        local descriptionBlock = CreateText(content, 1, 0.42, nil, description, GUI.Alignment.TopLeft, 0.78, Color(205, 210, 195, 255), true)
        descriptionBlock.AutoScaleVertical = true
        if IsClassProduct(product) then
            RegisterClassLimitText("cart", descriptionBlock, function()
                return GetProductDescriptionText(product)
            end)
        end
    end

    return frame
end

local function SetFilterButtonLabel()
    if filterButton == nil then return end

    local label = GetText("FilterAll")
    if selectedFilter == "available" then
        label = GetText("FilterAvailable")
    elseif selectedFilter == "affordable" then
        label = GetText("FilterAffordable")
    end

    filterButton.Text = label
end

CloseFilterPopup = function()
    if filterPopup == nil then return end
    filterPopup:RemoveFromGUIUpdateList(true)
    filterPopup.RectTransform.Parent = nil
    filterPopup.Visible = false
    filterPopup = nil
end

local function SelectFilter(value)
    selectedFilter = value
    SetFilterButtonLabel()
    CloseFilterPopup()
    if rebuildProductList ~= nil then rebuildProductList(false) end
end

local function ToggleFilterPopup(parent)
    if filterPopup ~= nil then
        CloseFilterPopup()
        return
    end

    filterPopup = GUI.Frame(CreateRect(0.46, 0.30, parent, GUI.Anchor.BottomRight), "GUIFrame")
    filterPopup.CanBeFocused = true
    filterPopup.RectTransform.AbsoluteOffset = Point(0, 6)

    local list = CreateLayout(filterPopup, 0.94, 0.90, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    list.RelativeSpacing = 0.01
    list.Stretch = true

    local options = {
        { "all", GetText("FilterAll") },
        { "available", GetText("FilterAvailable") },
        { "affordable", GetText("FilterAffordable") },
    }

    for _, option in ipairs(options) do
        local button = CreateButton(list, 1, 0.30, nil, option[2], true, selectedFilter == option[1])
        local value = option[1]
        button.OnClicked = function()
            SelectFilter(value)
            return true
        end
    end

    guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER + 1)
end

local function BuildSearchAndFilter(parent, rebuild)
    local row = CreateLayout(parent, 1, 0.10, nil, true, GUI.Anchor.CenterLeft)
    row.RelativeSpacing = 0.008
    row.Stretch = true

    local searchBox = GUI.TextBox(CreateRect(0.66, 0.90, row, nil), searchText or "", nil, GUI.Alignment.Left, "GUITextBox")
    searchBox.PlaceholderText = GetText("Search")
    searchBox.OnTextChanged = function(_, value)
        searchText = tostring(value or "")
        normalizedSearchText = NormalizeSearchText(searchText)
        rebuild(false)
    end

    filterButton = CreateButton(row, 0.32, 0.90, nil, "", true, false)
    SetFilterButtonLabel()
    filterButton.OnClicked = function()
        ToggleFilterPopup(parent)
        return true
    end
end

local function GetFolderIconIdentifier(folder)
    if folder == nil then return "" end
    if folder.IconIdentifier ~= nil and folder.IconIdentifier ~= "" then return folder.IconIdentifier end
    return ""
end

local function AddCategoryButton(list, folder)
    local count = GetFolderDisplayCount(folder)
    local label = tostring(folder.Name or "")
    if count > 0 then label = label .. "  (" .. tostring(count) .. ")" end

    local row = CreateButton(list.Content, 1, ITEM_ROW_HEIGHT, GUI.Anchor.TopLeft, label, true, false, "ListBoxElement")
    row.TextBlock.TextAlignment = GUI.Alignment.Left

    local getLabelText = function()
        local value = tostring(folder.Name or "")
        local folderCount = GetFolderDisplayCount(folder)
        if folderCount > 0 then value = value .. "  (" .. tostring(folderCount) .. ")" end

        if shopMode == "attackdefend" and folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
            local limitText = GetClassLimitText(folder.CategoryIdentifier, folder.ClassLimitKey)
            if limitText ~= "" then value = value .. "  " .. limitText end
        end

        return value
    end

    if folder.CooldownProduct ~= nil then
        RegisterCooldownText("shop", row.TextBlock, function()
            local remaining = GetCooldownRemaining(folder.CooldownProduct)
            if remaining <= 0 then return getLabelText(), false end
            return getLabelText() .. "  " .. GetText("Cooldown") .. ": " .. FormatSeconds(remaining), true
        end)
    end
    if shopMode == "attackdefend" and folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
        RegisterClassLimitText("shop", row.TextBlock, getLabelText)
    end

    row.OnClicked = function()
        selectedCategory = folder.CategoryIdentifier or folder.Identifier
        selectedPath = folder.PathIdentifiers ~= "" and folder.PathIdentifiers or nil
        selectedProductId = nil
        currentView = "products"
        if rebuildProductList ~= nil then rebuildProductList(true) end
        RefreshCartOnly()
        return true
    end
end

local function AddFolderButton(list, folder, categoryIdentifier)
    local row = CreateButton(list.Content, 1, ITEM_ROW_HEIGHT, GUI.Anchor.TopLeft, tostring(folder.Name or ""), true, false, "ListBoxElement")
    row.TextBlock.TextAlignment = GUI.Alignment.Left
    row.OnClicked = function()
        selectedCategory = categoryIdentifier
        selectedPath = folder.PathIdentifiers ~= "" and folder.PathIdentifiers or nil
        selectedProductId = nil
        if rebuildProductList ~= nil then rebuildProductList(true) end
        RefreshCartOnly()
        return true
    end
end

local function BuildFolderMetadata(categories)
    for _, category in ipairs(categories) do
        category.CategoryIdentifier = category.Identifier
        category.ClassLimitKey = category.PathIdentifiers
        for _, child in ipairs(category.Children) do
            local stack = { child }
            while #stack > 0 do
                local node = table.remove(stack)
                node.CategoryIdentifier = category.Identifier
                node.ClassLimitKey = node.PathIdentifiers
                for _, nested in ipairs(node.Children) do
                    table.insert(stack, nested)
                end
            end
        end
    end
end

local function GetCategoryByIdentifier(categories, identifier)
    for _, category in ipairs(categories) do
        if category.Identifier == identifier then return category end
    end
    return nil
end

local function BuildBreadcrumb(parent, categories, rebuild)
    local row = CreateLayout(parent, 1, 0.085, nil, true, GUI.Anchor.CenterLeft)
    row.RelativeSpacing = 0.005
    row.Stretch = true

    local rootButton = CreateButton(row, 0.30, 0.94, nil, GetText("Categories"), true, selectedCategory == nil)
    rootButton.OnClicked = function()
        selectedCategory = nil
        selectedPath = nil
        selectedProductId = nil
        currentView = "categories"
        rebuild(true)
        RefreshCartOnly()
        return true
    end

    if selectedCategory == nil then return end

    local category = GetCategoryByIdentifier(categories, selectedCategory)
    if category == nil then return end

    local categoryButton = CreateButton(row, 0.30, 0.94, nil, category.Name or selectedCategory, true, selectedPath == nil)
    categoryButton.OnClicked = function()
        selectedPath = nil
        selectedProductId = nil
        currentView = "products"
        rebuild(true)
        RefreshCartOnly()
        return true
    end

    if selectedPath ~= nil and selectedPath ~= "" then
        local pathNames = SplitSlash(category.PathNames)
        local pathIdentifiers = SplitSlash(selectedPath)
        local label = pathNames[#pathIdentifiers] or pathIdentifiers[#pathIdentifiers] or ""
        CreateButton(row, 0.38, 0.94, nil, label, false, true)
    end
end

local function PopulateFolders(list, categories)
    local folder
    if selectedCategory == nil then
        for _, category in ipairs(categories) do
            AddCategoryButton(list, category)
        end
        return
    end

    local category = GetCategoryByIdentifier(categories, selectedCategory)
    if category == nil then return end
    folder = GetFolderByPath(category, selectedPath)
    if folder == nil then return end

    for _, child in ipairs(folder.Children) do
        AddFolderButton(list, child, category.Identifier)
    end
end

local function GetProductsForCurrentFolder()
    local result = {}
    for _, product in ipairs(products) do
        if ProductMatchesSearchAndFilter(product) then
            table.insert(result, product)
        end
    end

    table.sort(result, function(a, b)
        local nameA = string.lower(tostring(a.Name or ""))
        local nameB = string.lower(tostring(b.Name or ""))
        if nameA == nameB then return tostring(a.Id or "") < tostring(b.Id or "") end
        return nameA < nameB
    end)

    return result
end

local function BuildShopPanel(overlay)
    local root = GUI.Frame(CreateRect(PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomLeft), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    CreatePanelTitle(content, GetText("Shop"), "StoreShoppingCartIcon", true)

    local categories = GetFolderTree()
    SortFolders(categories)
    BuildFolderMetadata(categories)

    local menuFrame = GUI.Frame(CreateRect(1, 0.86, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    local breadcrumbHost = GUI.Frame(CreateRect(1, 0.085, menuContent, nil), nil)
    breadcrumbHost.Color = Color(0, 0, 0, 0)
    breadcrumbHost.CanBeFocused = false

    local searchHost = GUI.Frame(CreateRect(1, 0.10, menuContent, nil), nil)
    searchHost.Color = Color(0, 0, 0, 0)
    searchHost.CanBeFocused = false

    local listFrame = GUI.Frame(CreateRect(1, 0.70, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    list.ContentBackground.Color = Color(0, 0, 0, 0)
    list.KeepSpaceForScrollBar = false
    list.CanBeFocused = false
    shopList = list

    local function populateProductList(resetScroll)
        if resetScroll then shopListScroll = 0 end
        shopListScroll = shopList ~= nil and shopList.BarScroll or shopListScroll
        list.Content:ClearChildren()
        productRows = {}
        cooldownTextBlocks.shop = {}
        classLimitTextBlocks.shop = {}

        BuildBreadcrumb(breadcrumbHost, categories, populateProductList)
        BuildSearchAndFilter(searchHost, populateProductList)

        local hasFolders = false
        if normalizedSearchText == "" and selectedFilter == "all" then
            local folder = GetSelectedFolder()
            hasFolders = selectedCategory == nil or (folder ~= nil and #folder.Children > 0)
            PopulateFolders(list, categories)
        end

        local displayedProducts = GetProductsForCurrentFolder()
        if #displayedProducts > 0 then
            for _, product in ipairs(displayedProducts) do
                AddProductButton(list, product)
            end
        elseif not hasFolders then
            local emptyText = selectedCategory == nil and GetText("EmptyCategories") or GetText("EmptyProducts")
            CreateText(list.Content, 0.95, 0.15, GUI.Anchor.TopCenter, emptyText, GUI.Alignment.Center, 1.10)
        end

        if shopList ~= nil then
            shopList.BarScroll = math.max(0, math.min(1, shopListScroll or 0))
        end
        guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER)
    end

    list.BarScroll = shopListScroll or 0
    rebuildProductList = populateProductList
    populateProductList()

    local hintText = GetText("ClickProduct")
    if shopMode == "ghost" then
        hintText = GetText("SelectGhostAction")
    elseif shopMode == "attackdefend" then
        for _, product in ipairs(products) do
            if ProductMatchesSelectedFolder(product) and IsClassProduct(product) then
                hintText = GetClassSelectText()
                break
            end
        end
    end

    local hint = CreateText(menuContent, 1, 0.070, nil, hintText, GUI.Alignment.Left, 0.78, Color(210, 210, 190, 185))
    hint.AutoScaleVertical = true
end

local function BuySingleProduct(product)
    if product == nil then return end
    SendBuyRequest({ { Id = product.Id, Quantity = 1 } })
end

local function BuildConfirmPanel(overlay)
    local root = GUI.Frame(CreateRect(PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomRight), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    CreatePanelTitle(content, GetText("ConfirmTitle"), "StoreShoppingCrateIcon", true)

    local product = GetPendingProduct() or GetSelectedProduct()
    local total = product ~= nil and (product.Price or 0) or 0
    BuildPurchaseSummary(content, total)

    CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    local listFrame = GUI.Frame(CreateRect(1, 0.805, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local box = GUI.Frame(CreateRect(1, 1, listFrame, GUI.Anchor.Center), nil)
    box.Color = Color(0, 0, 0, 0)
    box.CanBeFocused = false

    if product == nil then
        local placeholder = shopMode == "attackdefend" and GetClassSelectText() or GetText("SelectGhostAction")
        CreateText(box, 0.90, 0.16, GUI.Anchor.Center, placeholder, GUI.Alignment.Center, 1.10)
    else
        CreateProductDetails(box, product, 0.46)

        local question = IsClassProduct(product) and GetText("ConfirmClassQuestion") or GetText("ConfirmQuestion")
        if question ~= "" then
            CreateText(box, 0.90, 0.10, GUI.Anchor.BottomCenter, question, GUI.Alignment.Center, 0.98, Color(230, 230, 215, 255), true)
        end
    end

    local buttons = CreateLayout(menuContent, 1, 0.085, nil, true, GUI.Anchor.CenterRight)
    buttons.RelativeSpacing = 0.012

    local cancelButton = CreateButton(buttons, 0.47, 1, nil, GetText("Cancel"), product ~= nil, false)
    cancelButton.OnClicked = function()
        pendingProductId = nil
        selectedProductId = nil
        RefreshCartOnly()
        return true
    end

    local buyButton = CreateButton(buttons, 0.47, 1, nil, GetText("Buy"), product ~= nil and GetProductDisabledReason(product) == "", false)
    buyButton.OnClicked = function()
        BuySingleProduct(product)
        return true
    end

    if lastMessage ~= nil and lastMessage ~= "" then
        CreateText(menuContent, 1, 0.045, nil, lastMessage, GUI.Alignment.Center, 0.98, Color(255, 220, 120, 255))
    end

    return root
end

local function BuildCartPanel(overlay)
    if shopMode == "ghost" or IsClassProduct(GetPendingProduct()) or (shopMode == "attackdefend" and SelectedFolderHasClassProducts()) then
        return BuildConfirmPanel(overlay)
    end

    local root = GUI.Frame(CreateRect(PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomRight), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    content.RelativeSpacing = 0.007
    content.Stretch = true

    CreatePanelTitle(content, GetText("Cart"), "StoreShoppingCrateIcon", true)

    local total = GetCartTotal()
    BuildPurchaseSummary(content, total)

    CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    menuContent.RelativeSpacing = 0.006
    menuContent.Stretch = true

    local listFrame = GUI.Frame(CreateRect(1, 0.835, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    list.ContentBackground.Color = Color(0, 0, 0, 0)
    list.KeepSpaceForScrollBar = false
    list.CanBeFocused = false

    local selectedProduct = GetSelectedProduct()
    if selectedProduct ~= nil then
        CreateProductDetails(list.Content, selectedProduct, 0.30)
        CreateDivider(list.Content, 0.015)
    end

    if #cart == 0 then
        CreateText(list.Content, 0.95, 0.15, GUI.Anchor.TopCenter, GetText("EmptyCart"), GUI.Alignment.Center, 1.10)
    else
        for _, entry in ipairs(cart) do
            AddCartButton(list, entry)
        end
    end

    local buttons = CreateLayout(menuContent, 1, 0.085, nil, true, GUI.Anchor.CenterRight)
    buttons.RelativeSpacing = 0.012

    local clearButton = CreateButton(buttons, 0.47, 1, nil, GetText("Clear"), #cart > 0, false)
    clearButton.OnClicked = function()
        ClearCart()
        RefreshCartOnly()
        return true
    end

    local buyButton = CreateButton(buttons, 0.47, 1, nil, GetText("Buy"), #cart > 0 and total <= currentPoints, false)
    buyButton.OnClicked = function()
        BuyCart()
        return true
    end

    if lastMessage ~= nil and lastMessage ~= "" then
        CreateText(menuContent, 1, 0.045, nil, lastMessage, GUI.Alignment.Center, 0.98, Color(255, 220, 120, 255))
    end

    return root
end

RefreshCartOnly = function()
    if currentMenu == nil then return end

    cooldownTextBlocks.cart = {}
    classLimitTextBlocks.cart = {}

    if cartPanelRoot ~= nil then
        cartPanelRoot:RemoveFromGUIUpdateList(true)
        cartPanelRoot.RectTransform.Parent = nil
        cartPanelRoot.Visible = false
    end

    cartPanelRoot = BuildCartPanel(currentMenu)
    guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER)
end

ShowMenu = function()
    CloseMenu()
    cooldownTextBlocks.shop = {}
    cooldownTextBlocks.cart = {}
    classLimitTextBlocks.shop = {}
    classLimitTextBlocks.cart = {}
    nextCooldownTextUpdateTime = 0

    local overlay = GUI.Frame(CreateRect(1, 1, guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 191)
    overlay.CanBeFocused = false
    overlay.IgnoreLayoutGroups = true
    currentMenu = overlay
    sharedState.CurrentMenu = overlay

    BuildShopPanel(overlay)
    cartPanelRoot = BuildCartPanel(overlay)
    guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER)
end

Hook.Add("think", "VoidTraitor.PointshopGui.CooldownClock", function()
    if sharedState.Disabled or currentMenu == nil then return end
    if #cooldownTextBlocks.shop == 0 and #cooldownTextBlocks.cart == 0 then return end

    local now = GetClientTime()
    if now < nextCooldownTextUpdateTime then return end
    nextCooldownTextUpdateTime = now + 1

    UpdateCooldownTextBlocks()
end)

Networking.Receive(NET_PROBE, function(message)
    if sharedState.Disabled then return end
    SendReady()
    RequestSnapshot()
end)

Networking.Receive(NET_PURCHASE_SOUND, function(message)
    if sharedState.Disabled then return end
    PlayPurchaseSound()
end)

Networking.Receive(NET_CLASS_LIMITS, function(message)
    if sharedState.Disabled then return end

    local count = message.ReadInt32()
    classLimitValues = {}
    for i = 1, count do
        local categoryIdentifier = message.ReadString()
        local pathIdentifiers = message.ReadString()
        local limitText = message.ReadString()
        classLimitValues[GetClassLimitKey(categoryIdentifier, pathIdentifiers)] = limitText or ""
    end

    UpdateClassLimitTextBlocks()
end)

Networking.Receive(NET_SNAPSHOT, function(message)
    if sharedState.Disabled then return end
    ReadSnapshot(message)
    if closeMenuAfterSnapshot then
        CloseMenu()
        return
    end
    ShowMenu()
end)

Networking.Receive(NET_STATE, function(message)
    if sharedState.Disabled then return end
    if not ReadState(message) then
        RequestSnapshot()
        return
    end
    if closeMenuAfterSnapshot then
        CloseMenu()
        return
    end
    ShowMenu()
end)

Networking.Receive(NET_BALANCE, function(message)
    if sharedState.Disabled then return end
    currentPoints = message.ReadInt32()
    ReconcileProductState(false)
    if currentMenu ~= nil then
        if rebuildProductList ~= nil and selectedFilter == "affordable" then
            rebuildProductList(false)
        else
            RefreshProductRows()
        end
        RefreshCartOnly()
    end
end)

Networking.Receive(NET_PRODUCT_STATE, function(message)
    if sharedState.Disabled then return end
    local count = message.ReadInt32()
    local complete = true
    local rebuildRows = false
    for i = 1, count do
        local ok, needsRebuild = ReadProductState(message)
        if not ok then
            complete = false
        elseif needsRebuild then
            rebuildRows = true
        end
    end
    if not complete then
        RequestSnapshot()
        return
    end
    ReconcileProductState(false)
    if currentMenu ~= nil then
        if rebuildProductList ~= nil and rebuildRows then
            rebuildProductList(false)
        else
            RefreshProductRows()
        end
        RefreshCartOnly()
    end
end)
