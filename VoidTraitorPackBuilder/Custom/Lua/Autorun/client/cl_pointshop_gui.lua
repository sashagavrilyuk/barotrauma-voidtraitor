if SERVER then return end

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
local classLimitTextBlocks = {}
local classLimitValues = {}
local nextCooldownTextUpdateTime = 0
local cooldownSnapshotRequested = false
local buyRequestPending = false
local searchText = ""
local selectedFilter = "all"
local productRows = {}
local emptyProductsText = nil
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
local GLOBAL_PATCH_KEY = "VoidTraitorPointshopGuiAddToGuiUpdateListPatchInstalled"
local GLOBAL_PAUSE_PATCH_KEY = "VoidTraitorPointshopGuiPauseMenuPatchInstalled"
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

local pauseMenuRestoreValue = nil

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
pcall(function() guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER) end)

-- Reinsert the root when Barotrauma rebuilds the GUI update list.
if not rawget(_G, GLOBAL_PATCH_KEY) then
    Hook.Patch("Barotrauma.GameSession", "AddToGUIUpdateList", function()
        local state = rawget(_G, GLOBAL_STATE_KEY)
        if state ~= nil and state.GuiRoot ~= nil and not state.Disabled then
            pcall(function() state.GuiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER) end)
        end
    end)
    _G[GLOBAL_PATCH_KEY] = true
end

-- ESC guard: close the shop instead of opening the vanilla pause menu.
if not rawget(_G, GLOBAL_PAUSE_PATCH_KEY) then
    local ok, err = pcall(function()
        Hook.Patch("Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, p)
            local state = rawget(_G, GLOBAL_STATE_KEY)
            if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
                if state.CurrentMenu ~= nil and state.CloseMenu ~= nil then
                    pcall(state.CloseMenu)
                end
                if p ~= nil then
                    p.PreventExecution = true
                end
                return false
            end
        end, Hook.HookMethodType.Before)
    end)
    if ok then
        _G[GLOBAL_PAUSE_PATCH_KEY] = true
    else
        print("[VoidTraitor.PointshopGui] Failed to install pause-menu patch: " .. tostring(err))
    end
end

local CloseMenu

local function SetPauseMenuBlocked()
    if currentMenu == nil then return end

    -- While the custom shop is open, block the vanilla pause menu toggle.
    pcall(function()
        if GUI ~= nil and GUI.PreventPauseMenuToggle ~= nil then
            if pauseMenuRestoreValue == nil then
                pauseMenuRestoreValue = GUI.PreventPauseMenuToggle
            end
            GUI.PreventPauseMenuToggle = true
        end
    end)
end

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
    SetPauseMenuBlocked()
    CloseMenu()
    Timer.Wait(function()
        sharedState.BlockPauseMenu = false
    end, 250)
end

pcall(function() Hook.Remove("think", "VoidTraitor.PointshopGui.KeepVisible") end)
pcall(function() Hook.Remove("think", "VoidTraitor.PointshopGui.KeepPauseBlocked") end)
pcall(function() Hook.Remove("think", "VoidTraitor.PointshopGui.CooldownClock") end)
pcall(function() Hook.Remove("think", "VoidTraitor.PointshopGui.FilterDropDown") end)
pcall(function() Hook.Remove("keyUpdate", "VoidTraitor.PointshopGui.KeyboardTrap") end)
pcall(function() Hook.Remove("keyUpdate", "VoidTraitor.PointshopGui.PauseGuard") end)

-- keyUpdate fires before the game's ESC handler.
Hook.Add("keyUpdate", "VoidTraitor.PointshopGui.PauseGuard", function()
    if sharedState.Disabled then return end
    if currentMenu ~= nil then
        SetPauseMenuBlocked()
        if IsEscapeHit() then
            RequestEscapeClose()
        end
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
        pcall(function() shopListScroll = shopList.BarScroll end)
    end
    shopList = nil

    if currentMenu ~= nil then
        pcall(function()
            currentMenu:RemoveFromGUIUpdateList(true)
        end)
        pcall(function()
            if currentMenu.RectTransform ~= nil then
                currentMenu.RectTransform.Parent = nil
            end
            currentMenu.Visible = false
        end)
    end


    currentMenu = nil
    sharedState.CurrentMenu = nil
    cartPanelRoot = nil
    filterButton = nil
    rebuildProductList = nil
    escapeClosePending = false
    buyRequestPending = false

    local restoreValue = pauseMenuRestoreValue
    pauseMenuRestoreValue = nil
    Timer.Wait(function()
        if currentMenu ~= nil then return end
        pcall(function()
            if GUI ~= nil and GUI.PreventPauseMenuToggle ~= nil then
                GUI.PreventPauseMenuToggle = restoreValue == true
            end
        end)
    end, 250)
end

sharedState.CloseMenu = CloseMenu

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
            total = total + (product.Price or 0) * (entry.Quantity or 1)
        end
    end
    return total
end

local function GetPendingProduct()
    if pendingProductId == nil then return nil end
    return productById[pendingProductId]
end

local function GetSelectedProduct()
    if selectedProductId == nil then return nil end
    return productById[selectedProductId]
end

local function IsClassProduct(product)
    return product ~= nil and product.Type == "class"
end

local function GetClassSelectText()
    local value = GetText("SelectClassAction")
    if value ~= nil and value ~= "" then return value end
    return GetText("SelectGhostAction")
end

local function FormatSeconds(seconds)
    seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
    local minutes = math.floor(seconds / 60)
    local rest = seconds - minutes * 60
    return string.format("%02d:%02d", minutes, rest)
end

local function GetClientTime()
    return Timer.GetTime()
end

local function GetCooldownRemaining(source)
    if source == nil then return 0 end

    if source.CooldownEndTime ~= nil then
        return math.max(math.ceil(source.CooldownEndTime - GetClientTime()), 0)
    end

    return math.max(math.floor(tonumber(source.CooldownRemaining) or 0), 0)
end

local function GetProductStateDisabledReason(product)
    if product == nil then return "" end
    local cooldown = GetCooldownRemaining(product)
    if cooldown > 0 then
        return GetText("Cooldown") .. ": " .. FormatSeconds(cooldown)
    end
    return tostring(product.DisabledReason or "")
end

local function GetProductDisabledReason(product)
    local reason = GetProductStateDisabledReason(product)
    if reason ~= "" then return reason end
    if (tonumber(product.Price) or 0) > currentPoints then
        return GetText("NotEnoughPoints")
    end
    return ""
end

local function IsProductAvailable(product)
    return GetProductStateDisabledReason(product) == ""
end

local function CanBuyProduct(product)
    return IsProductAvailable(product) and (tonumber(product.Price) or 0) <= currentPoints
end

local function IsUnlimitedProductStock(product)
    if product == nil then return false end
    return (tonumber(product.Stock) or 0) >= NET_INT32_MAX
        or (tonumber(product.Limit) or 0) >= NET_INT32_MAX
end

-- Match the original text PointShop rules: a zero effective price and an
-- unlimited product limit are presentation details that must not be printed.
local function ShouldShowProductPrice(product)
    return product ~= nil and (tonumber(product.Price) or 0) ~= 0
end

local function ShouldShowProductStock(product)
    return product ~= nil and not IsUnlimitedProductStock(product)
end

local function GetProductStockDisplay(product)
    if IsUnlimitedProductStock(product) then
        return GetText("Unlimited")
    end

    local stock = math.max(math.floor(tonumber(product.Stock) or 0), 0)
    local limit = math.max(math.floor(tonumber(product.Limit) or 0), 0)
    return tostring(stock) .. " / " .. tostring(limit)
end

local function ProductMatchesSearchAndFilter(product)
    if product == nil then return false end
    if selectedFilter == "available" and not IsProductAvailable(product) then
        return false
    elseif selectedFilter == "affordable" and not CanBuyProduct(product) then
        return false
    end

    local query = NormalizeSearchText(searchText)
    if query == "" then return true end
    local searchable = table.concat({
        tostring(product.Name or ""),
        tostring(product.Description or ""),
        tostring(product.Category or ""),
        tostring(product.Path or ""),
        tostring(product.IconIdentifier or ""),
        tostring(product.CategoryIdentifier or ""),
        tostring(product.PathIdentifiers or ""),
        tostring(product.Type or ""),
    }, " ")
    return string.find(NormalizeSearchText(searchable), query, 1, true) ~= nil
end

local function GetClassLimitKey(categoryIdentifier, pathIdentifiers)
    return tostring(categoryIdentifier or "") .. "\30" .. tostring(pathIdentifiers or "")
end

local function GetProductClassLimitKey(product)
    if product == nil then return "" end
    return GetClassLimitKey(product.CategoryIdentifier, product.PathIdentifiers)
end

local function GetProductLimitText(product)
    if product == nil then return "" end
    local key = GetProductClassLimitKey(product)
    if IsClassProduct(product) and key ~= "" then
        return classLimitValues[key] or ""
    end
    return product.LimitText or ""
end

local function GetProductDescriptionText(product)
    if product == nil then return "" end

    local description = tostring(product.Description or "")
    if not IsClassProduct(product) then
        return description
    end

    local limitText = GetProductLimitText(product)
    if description ~= "" and limitText ~= "" then
        return description .. "\n\n" .. limitText
    end
    if description ~= "" then return description end
    return limitText
end

local function RegisterClassLimitText(block, getText)
    if block == nil or getText == nil then return end
    table.insert(classLimitTextBlocks, { Block = block, GetText = getText })
end

local function UpdateClassLimitTextBlocks()
    for index = #classLimitTextBlocks, 1, -1 do
        local entry = classLimitTextBlocks[index]
        local ok, value = pcall(entry.GetText)
        if not ok or entry.Block == nil then
            table.remove(classLimitTextBlocks, index)
        else
            pcall(function() entry.Block.Text = value or "" end)
        end
    end
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
    local anyActive = false
    local needsSnapshot = false

    for _, group in pairs(cooldownTextBlocks) do
        for index = #group, 1, -1 do
            local entry = group[index]
            local ok, value, active = pcall(entry.GetText)
            if not ok or entry.Block == nil then
                table.remove(group, index)
            else
                pcall(function() entry.Block.Text = value or "" end)
                if active == true then
                    anyActive = true
                elseif active == false then
                    needsSnapshot = true
                    table.remove(group, index)
                end
            end
        end
    end

    if needsSnapshot and not cooldownSnapshotRequested then
        cooldownSnapshotRequested = true
        Timer.Wait(function()
            cooldownSnapshotRequested = false
            if currentMenu ~= nil then ShowMenu() end
        end, 1)
    end

    return anyActive
end

local function IsFolderExpanded(folderKey)
    local value = expandedFolders[folderKey]
    if value == nil then return true end
    return value == true
end

local function ToggleFolder(folderKey)
    expandedFolders[folderKey] = not IsFolderExpanded(folderKey)
end

local function AddToCart(product)
    if product == nil or GetProductDisabledReason(product) ~= "" then return end

    local maxQuantity = tonumber(product.MaxQuantity) or tonumber(product.Stock) or 1
    maxQuantity = math.max(math.floor(maxQuantity), 1)
    if product.AllowQuantity ~= true then
        maxQuantity = 1
    end

    local entry = GetCartEntry(product.Id)
    if entry ~= nil then
        if (entry.Quantity or 1) >= maxQuantity then
            if product.AllowQuantity ~= true then
                lastMessage = GetText("SinglePurchase")
            else
                lastMessage = GetText("StockLimit")
            end
            return
        end
        entry.Quantity = math.min((entry.Quantity or 1) + 1, maxQuantity)
    else
        table.insert(cart, { Id = product.Id, Quantity = 1 })
    end
end

local function RemoveFromCart(productId)
    for index, entry in ipairs(cart) do
        if entry.Id == productId then
            if (entry.Quantity or 1) > 1 then
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
end

local function ReadSnapshot(message)
    lastMessage = message.ReadString()
    currentPoints = message.ReadInt32()
    shopMode = message.ReadString()
    if shopMode == nil or shopMode == "" then shopMode = "shop" end
    local count = message.ReadInt32()

    products = {}
    productById = {}
    classLimitValues = {}

    for i = 1, count do
        local product = {
            Id = message.ReadString(),
            Category = message.ReadString(),
            Path = message.ReadString(),
            Name = message.ReadString(),
            Description = message.ReadString(),
            Price = message.ReadInt32(),
            Stock = message.ReadInt32(),
            Limit = message.ReadInt32(),
            Type = message.ReadString(),
            IconIdentifier = message.ReadString(),
            AllowQuantity = message.ReadBoolean(),
            DisabledReason = message.ReadString(),
            CategoryIdentifier = message.ReadString(),
            CategoryIconIdentifier = message.ReadString(),
            PathIdentifiers = message.ReadString(),
            PathIconIdentifiers = message.ReadString(),
            MaxQuantity = message.ReadInt32(),
            CooldownRemaining = message.ReadInt32(),
            CloseAfterPurchase = message.ReadBoolean(),
            LimitText = message.ReadString(),
        }

        product.CooldownRemaining = math.max(math.floor(tonumber(product.CooldownRemaining) or 0), 0)
        if product.CooldownRemaining > 0 then
            product.CooldownEndTime = GetClientTime() + product.CooldownRemaining
        else
            product.CooldownEndTime = nil
        end

        if product.LimitText ~= nil and product.LimitText ~= "" then
            classLimitValues[GetProductClassLimitKey(product)] = product.LimitText
        end

        if product.Id ~= nil and product.Id ~= "" then
            table.insert(products, product)
            productById[product.Id] = product
        end
    end

    local textCount = 0
    pcall(function()
        textCount = message.ReadInt32()
    end)

    for i = 1, textCount do
        local key = message.ReadString()
        local value = message.ReadString()
        if key ~= nil and key ~= "" then
            text[key] = value or ""
        end
    end

    local purchaseCompleted = false
    pcall(function()
        purchaseCompleted = message.ReadBoolean()
    end)

    cooldownSnapshotRequested = false
    buyRequestPending = false

    closeMenuAfterSnapshot = false
    pcall(function()
        closeMenuAfterSnapshot = message.ReadBoolean()
    end)

    if purchaseCompleted then
        ClearCart()
        pendingProductId = nil
    end

    for index = #cart, 1, -1 do
        local entry = cart[index]
        local product = productById[entry.Id]
        if product == nil or GetProductDisabledReason(product) ~= "" or product.Stock <= 0 then
            table.remove(cart, index)
        else
            local maxQuantity = tonumber(product.MaxQuantity) or tonumber(product.Stock) or 1
            maxQuantity = math.max(maxQuantity, 1)
            if product.AllowQuantity ~= true then
                maxQuantity = 1
            end
            if entry.Quantity > maxQuantity then
                entry.Quantity = maxQuantity
            end
        end
    end

    if pendingProductId ~= nil and productById[pendingProductId] == nil then
        pendingProductId = nil
    end
    if selectedProductId ~= nil and productById[selectedProductId] == nil then
        selectedProductId = nil
    end

    local selectedStillExists = false
    for _, product in ipairs(products) do
        if product.Category == selectedCategory and (product.Path or "") == (selectedPath or "") then
            selectedStillExists = true
            break
        end
    end

    if not selectedStillExists and products[1] ~= nil then
        selectedCategory = products[1].Category
        selectedPath = products[1].Path or ""
    end
end

local function ReadProductState(message)
    local productId = message.ReadString()
    local price = message.ReadInt32()
    local stock = message.ReadInt32()
    local disabledReason = message.ReadString()
    local maxQuantity = message.ReadInt32()
    local cooldownRemaining = math.max(message.ReadInt32(), 0)
    local product = productById[productId]
    if product == nil then return false end

    product.Price = price
    product.Stock = stock
    product.DisabledReason = disabledReason or ""
    product.MaxQuantity = maxQuantity
    product.CooldownRemaining = cooldownRemaining
    product.CooldownEndTime = cooldownRemaining > 0 and (GetClientTime() + cooldownRemaining) or nil
    return true
end

local function ReconcileProductState(purchaseCompleted)
    if purchaseCompleted then
        ClearCart()
        pendingProductId = nil
    end

    for index = #cart, 1, -1 do
        local entry = cart[index]
        local product = productById[entry.Id]
        if product == nil or GetProductDisabledReason(product) ~= "" or product.Stock <= 0 then
            table.remove(cart, index)
        else
            local maxQuantity = math.max(tonumber(product.MaxQuantity) or tonumber(product.Stock) or 1, 1)
            if product.AllowQuantity ~= true then maxQuantity = 1 end
            entry.Quantity = math.min(entry.Quantity or 1, maxQuantity)
        end
    end


    local selected = GetSelectedProduct()
    if selected ~= nil and selected.Stock <= 0 then selectedProductId = nil end
    local pending = GetPendingProduct()
    if pending ~= nil and GetProductDisabledReason(pending) ~= "" then pendingProductId = nil end
end

local function ReadState(message)
    lastMessage = message.ReadString()
    currentPoints = message.ReadInt32()
    shopMode = message.ReadString()
    if shopMode == nil or shopMode == "" then shopMode = "shop" end

    local count = message.ReadInt32()
    local complete = true
    for i = 1, count do
        if not ReadProductState(message) then complete = false end
    end

    local purchaseCompleted = message.ReadBoolean()
    closeMenuAfterSnapshot = message.ReadBoolean()
    cooldownSnapshotRequested = false
    buyRequestPending = false
    ReconcileProductState(purchaseCompleted)
    return complete
end


local function SplitGuiPath(value, separatorPattern)
    local result = {}
    value = tostring(value or "")
    if value == "" then return result end

    separatorPattern = separatorPattern or "[^>]+"
    for part in string.gmatch(value, separatorPattern) do
        part = string.gsub(part, "^%s+", "")
        part = string.gsub(part, "%s+$", "")
        table.insert(result, part)
    end

    return result
end

local function SplitIconList(value)
    local result = {}
    value = tostring(value or "")
    if value == "" then return result end

    for part in string.gmatch(value, "[^\31]+") do
        table.insert(result, part)
    end

    return result
end

local function GetFolderKey(category, path)
    return tostring(category or "") .. "\30" .. tostring(path or "")
end

local function BuildFolderList()
    local folders = {}
    local lookup = {}
    local directCounts = {}
    local totalCounts = {}

    for _, product in ipairs(products) do
        local directKey = GetFolderKey(product.Category, product.Path or "")
        directCounts[directKey] = (directCounts[directKey] or 0) + 1

        local rootKey = GetFolderKey(product.Category, "")
        totalCounts[rootKey] = (totalCounts[rootKey] or 0) + 1

        local currentPath = ""
        for _, part in ipairs(SplitGuiPath(product.Path or "")) do
            if part ~= "" then
                if currentPath == "" then
                    currentPath = part
                else
                    currentPath = currentPath .. " > " .. part
                end
                local key = GetFolderKey(product.Category, currentPath)
                totalCounts[key] = (totalCounts[key] or 0) + 1
            end
        end
    end

    local function addFolder(category, path, label, depth, iconIdentifier, fallbackIconIdentifier, cooldownRemaining, cooldownEndTime, infoText, classLimitKey)
        local key = GetFolderKey(category, path)
        local folder = lookup[key]
        if folder == nil then
            folder = {
                Key = key,
                Category = category,
                Path = path or "",
                Label = label,
                Depth = depth or 0,
                DirectCount = directCounts[key] or 0,
                Count = totalCounts[key] or directCounts[key] or 0,
                IconIdentifier = iconIdentifier or fallbackIconIdentifier or "",
                HasConfiguredIcon = iconIdentifier ~= nil and iconIdentifier ~= "",
                InfoText = infoText or "",
                ClassLimitKey = classLimitKey or "",
                CooldownRemaining = math.max(math.floor(tonumber(cooldownRemaining) or 0), 0),
                CooldownEndTime = tonumber(cooldownEndTime),
                HasChildren = false,
            }
            lookup[key] = folder
            table.insert(folders, folder)
            return folder
        end

        if folder.IconIdentifier == "" and fallbackIconIdentifier ~= nil and fallbackIconIdentifier ~= "" then
            folder.IconIdentifier = fallbackIconIdentifier
        end
        if iconIdentifier ~= nil and iconIdentifier ~= "" and not folder.HasConfiguredIcon then
            folder.IconIdentifier = iconIdentifier
            folder.HasConfiguredIcon = true
        end
        if (folder.InfoText == nil or folder.InfoText == "") and infoText ~= nil and infoText ~= "" then
            folder.InfoText = infoText
        end
        if (folder.ClassLimitKey == nil or folder.ClassLimitKey == "") and classLimitKey ~= nil and classLimitKey ~= "" then
            folder.ClassLimitKey = classLimitKey
        end

        local cooldown = math.max(math.floor(tonumber(cooldownRemaining) or 0), 0)
        local endTime = tonumber(cooldownEndTime)
        if endTime ~= nil then
            if folder.CooldownEndTime == nil or endTime > folder.CooldownEndTime then
                folder.CooldownEndTime = endTime
            end
        elseif cooldown > folder.CooldownRemaining then
            folder.CooldownRemaining = cooldown
        end
        return folder
    end

    for _, product in ipairs(products) do
        addFolder(product.Category, "", product.Category, 0, product.CategoryIconIdentifier, product.IconIdentifier, GetCooldownRemaining(product), product.CooldownEndTime, "", "")

        local currentPath = ""
        local parentPath = ""
        local depth = 1
        local pathLabels = SplitGuiPath(product.Path or "")
        local pathIdentifiers = SplitGuiPath(product.PathIdentifiers or "")
        local currentPathIdentifier = ""
        local pathIcons = SplitIconList(product.PathIconIdentifiers or "")
        for depthIndex, part in ipairs(pathLabels) do
            if part ~= "" then
                if currentPath == "" then
                    currentPath = part
                else
                    currentPath = currentPath .. " > " .. part
                end

                local pathIdentifierPart = pathIdentifiers[depthIndex] or part
                if currentPathIdentifier == "" then
                    currentPathIdentifier = pathIdentifierPart
                else
                    currentPathIdentifier = currentPathIdentifier .. " > " .. pathIdentifierPart
                end

                local parentFolder = lookup[GetFolderKey(product.Category, parentPath)]
                if parentFolder ~= nil then
                    parentFolder.HasChildren = true
                end

                local infoText = depth == #pathLabels and GetProductLimitText(product) or ""
                local classLimitKey = depth == #pathLabels and GetProductClassLimitKey(product) or ""
                addFolder(product.Category, currentPath, part, depth, pathIcons[depth], product.IconIdentifier, GetCooldownRemaining(product), product.CooldownEndTime, infoText, classLimitKey)
                parentPath = currentPath
                depth = depth + 1
            end
        end
    end

    local visibleFolders = {}
    for _, folder in ipairs(folders) do
        local visible = true
        if folder.Depth > 0 then
            local parentPath = ""
            if not IsFolderExpanded(GetFolderKey(folder.Category, "")) then
                visible = false
            end

            local parts = SplitGuiPath(folder.Path or "")
            for index = 1, #parts - 1 do
                if parentPath == "" then
                    parentPath = parts[index]
                else
                    parentPath = parentPath .. " > " .. parts[index]
                end

                if not IsFolderExpanded(GetFolderKey(folder.Category, parentPath)) then
                    visible = false
                    break
                end
            end
        end

        if visible then
            table.insert(visibleFolders, folder)
        end
    end

    return visibleFolders
end

local function ProductMatchesSelectedFolder(product)
    return product.Category == selectedCategory and (product.Path or "") == (selectedPath or "")
end

local function UpdateProductRowSelection()
    for _, entry in ipairs(productRows) do
        entry.Row.Selected = entry.Product.Id == selectedProductId
    end
end

local function SelectedFolderHasClassProducts()
    for _, product in ipairs(products) do
        if ProductMatchesSelectedFolder(product) and IsClassProduct(product) then
            return true
        end
    end

    return false
end

local function ClearPendingIfOutsideSelectedFolder()
    local pending = GetPendingProduct()
    if pending ~= nil and not ProductMatchesSelectedFolder(pending) then
        pendingProductId = nil
    end
    local selected = GetSelectedProduct()
    if selected ~= nil and not ProductMatchesSelectedFolder(selected) then
        selectedProductId = nil
    end
end

local function GetSelectedFolderLabel()
    if selectedCategory == nil then return GetText("NoCategory") end
    if selectedPath == nil or selectedPath == "" then return selectedCategory end
    return selectedCategory .. " > " .. selectedPath
end

local function GetJobIconData(jobIdentifier)
    if jobIdentifier == nil or jobIdentifier == "" then return nil, nil end

    local ok, prefab = pcall(function()
        return JobPrefab.Get(jobIdentifier)
    end)
    if not ok or prefab == nil then return nil, nil end

    local color = Color(255, 255, 255, 255)
    pcall(function()
        if prefab.UIColor ~= nil then
            color = prefab.UIColor
        elseif prefab.IconColor ~= nil then
            color = prefab.IconColor
        end
    end)

    local candidates = { "Icon", "JobIcon", "IconSmall", "JobIconSmall" }
    for _, propertyName in ipairs(candidates) do
        local success, sprite = pcall(function()
            return prefab[propertyName]
        end)
        if success and sprite ~= nil then
            return sprite, color
        end
    end

    return nil, nil
end

local function GetItemIconData(iconIdentifier)
    if iconIdentifier == nil or iconIdentifier == "" then return nil, nil end

    if string.sub(tostring(iconIdentifier), 1, 4) == "job:" then
        return GetJobIconData(string.sub(tostring(iconIdentifier), 5))
    end

    local ok, prefab = pcall(function()
        return ItemPrefab.GetItemPrefab(iconIdentifier)
    end)
    if not ok or prefab == nil then return nil, nil end

    local sprite = nil
    local color = Color(255, 255, 255, 255)

    ok = pcall(function()
        sprite = prefab.InventoryIcon
        if sprite ~= nil then
            color = prefab.InventoryIconColor
        end
    end)
    if not ok then sprite = nil end

    if sprite == nil then
        ok = pcall(function()
            sprite = prefab.Sprite
            if sprite ~= nil then
                color = prefab.SpriteColor
            end
        end)
        if not ok then sprite = nil end
    end

    return sprite, color
end

local function CreateProductIcon(parent, iconIdentifier, enabled)
    -- Square vanilla-framed icon slot. The row height is sized around this slot,
    -- otherwise Barotrauma compresses the inventory sprite into a wide rectangle.
    local box = GUI.Frame(CreateRect(1, 1, parent, GUI.Anchor.Center), "GUIFrameListBox")
    box.CanBeFocused = false

    pcall(function()
        box.RectTransform.IsFixedSize = true
        box.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
        box.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    end)

    local sprite, spriteColor = GetItemIconData(iconIdentifier)
    if sprite == nil then return end

    local ok, image = pcall(function()
        return GUI.Image(CreateRect(0.82, 0.82, box, GUI.Anchor.Center), sprite, true)
    end)

    if ok and image ~= nil then
        image.Color = enabled == false and Color(105, 105, 105, 190) or spriteColor
    end
end

local function SendBuyRequest(entries)
    if entries == nil or #entries == 0 then return end
    if buyRequestPending then return end

    buyRequestPending = true
    local ok, err = pcall(function()
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
        print("[VoidTraitor.PointshopGui] Failed to send buy request: " .. tostring(err))
        return
    end

    Timer.Wait(function()
        buyRequestPending = false
    end, 1500)
end

local function BuyCart()
    SendBuyRequest(cart)
end


local function CreateFolderIcon(parent, folder, selected)
    local holder = GUI.Frame(CreateRect(0.070, 0.88, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local sprite, spriteColor = GetItemIconData(folder.IconIdentifier)
    if sprite ~= nil then
        local ok, image = pcall(function()
            return GUI.Image(CreateRect(0.82, 0.82, holder, GUI.Anchor.Center), sprite, true)
        end)
        if ok and image ~= nil then
            image.Color = spriteColor
        end
        return holder
    end

    local marker = folder.Depth == 0 and "■" or ">"
    if folder.HasChildren then
        marker = IsFolderExpanded(folder.Key) and "v" or ">"
    end
    local color = selected and Color(255, 245, 190, 255) or (folder.Depth == 0 and Color(160, 210, 180, 255) or Color(120, 230, 190, 255))
    CreateText(holder, 1, 1, GUI.Anchor.Center, marker, GUI.Alignment.Center, folder.Depth == 0 and 0.95 or 1.18, color, false)
    return holder
end

local function AddCategoryButton(list, folder)
    local selected = folder.Category == selectedCategory and folder.Path == (selectedPath or "")
    local rowHeight = folder.Depth == 0 and 0.073 or 0.061
    local row = CreateButton(list.Content, 1, rowHeight, GUI.Anchor.TopLeft, "", true, selected, "ListBoxElement")

    local inner = GUI.LayoutGroup(CreateRect(0.94, 0.92, row, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    pcall(function()
        inner.Stretch = true
        inner.RelativeSpacing = 0.004
    end)

    local indentWidth = math.min(0.035 * folder.Depth, 0.12)
    if indentWidth > 0 then
        local indent = GUI.Frame(CreateRect(indentWidth, 1, inner, nil), nil)
        indent.Color = Color(0, 0, 0, 0)
        indent.CanBeFocused = false
    end

    CreateFolderIcon(inner, folder, selected)

    local function getFolderInfoText()
        if folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
            return classLimitValues[folder.ClassLimitKey] or ""
        end
        return folder.InfoText or ""
    end

    local function getLabelText()
        local label = folder.Label
        local infoText = getFolderInfoText()
        if infoText ~= nil and infoText ~= "" then
            label = label .. "  - " .. infoText
        elseif folder.Count > 0 then
            label = label .. "  (" .. tostring(folder.Count) .. ")"
        end
        if folder.Depth > 0 then
            label = ">  " .. label
        end

        local folderCooldown = GetCooldownRemaining(folder)
        local active = shopMode == "ghost" and folderCooldown > 0 and (folder.DirectCount or 0) > 0
        if active then
            label = label .. "  - " .. GetText("Cooldown") .. ": " .. FormatSeconds(folderCooldown)
        end
        return label, active
    end

    local nameScale = folder.Depth == 0 and 0.95 or 0.90
    local nameColor = selected and Color(255, 245, 190, 255) or (folder.Depth == 0 and Color(225, 230, 215, 255) or Color(210, 235, 220, 255))
    local name = CreateText(inner, 0.86 - indentWidth, 0.88, nil, getLabelText(), GUI.Alignment.Left, nameScale, nameColor, false)
    pcall(function()
        name.AutoScaleHorizontal = true
        name.Font = GUI.Style.SubHeadingFont
    end)
    if shopMode == "ghost" and (folder.DirectCount or 0) > 0 and GetCooldownRemaining(folder) > 0 then
        RegisterCooldownText("shop", name, getLabelText)
    end
    if shopMode == "attackdefend" and folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
        RegisterClassLimitText(name, getLabelText)
    end

    row.OnClicked = function()
        if folder.HasChildren and (folder.DirectCount or 0) == 0 then
            ToggleFolder(folder.Key)
            currentView = "categories"
        else
            selectedCategory = folder.Category
            selectedPath = folder.Path
            ClearPendingIfOutsideSelectedFolder()
            currentView = "products"
        end
        shopListScroll = 0
        ShowMenu()
        return true
    end
end


local function CreateRowInner(row, width, height)
    local inner = GUI.Frame(CreateRect(width or 0.94, height or 0.90, row, GUI.Anchor.Center), nil)
    inner.Color = Color(0, 0, 0, 0)
    return GUI.LayoutGroup(CreateRect(1, 1, inner, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
end

local function CreateStoreActionButton(parent, width, style, enabled)
    local holder = GUI.Frame(CreateRect(width or 0.155, 1, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local button = GUI.Button(CreateRect(0.92, 0.92, holder, GUI.Anchor.Center), "", GUI.Alignment.Center, style)
    button.Enabled = enabled ~= false
    pcall(function()
        button.RectTransform.IsFixedSize = true
        button.RectTransform.MinSize = Point(ACTION_BUTTON_PIXELS, ACTION_BUTTON_PIXELS)
        button.RectTransform.MaxSize = Point(math.floor(ACTION_BUTTON_PIXELS * 1.12), math.floor(ACTION_BUTTON_PIXELS * 1.12))
        if button.TextBlock ~= nil then
            button.TextBlock.Text = ""
        end
    end)

    return button
end

local function AddProductButton(list, product)
    local disabledReason = GetProductDisabledReason(product)
    local enabled = disabledReason == ""
    local showPrice = ShouldShowProductPrice(product)
    -- The entire vanilla-style list row is the details button. This restores
    -- the original large hit area and removes the visible text-only overlay.
    local row = CreateButton(list.Content, 1, ITEM_ROW_HEIGHT, GUI.Anchor.TopLeft, "", true, selectedProductId == product.Id, "ListBoxElement")
    if row.TextBlock ~= nil then row.TextBlock.Text = "" end
    table.insert(productRows, { Row = row, Product = product })

    local inner = CreateRowInner(row, 0.968, 0.90)
    pcall(function()
        inner.RelativeSpacing = 0.003
        inner.Stretch = true
    end)

    local iconHolder = GUI.Frame(CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    pcall(function()
        iconHolder.RectTransform.IsFixedSize = true
        iconHolder.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
        iconHolder.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    end)
    CreateProductIcon(iconHolder, product.IconIdentifier, enabled)

    -- Give the name back the price column when the original PointShop would
    -- hide a zero price (notably Attack Defend classes).
    local textGroup = GUI.Frame(CreateRect(showPrice and 0.500 or 0.625, 0.90, inner, nil), nil)
    textGroup.Color = Color(0, 0, 0, 0)
    textGroup.CanBeFocused = false

    local nameText = string.upper(tostring(product.Name or ""))
    local name = CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, nameText, GUI.Alignment.Left, 0.88, enabled and Color(235, 235, 225, 255) or Color(130, 130, 130, 255), true)
    pcall(function() name.Font = GUI.Style.SubHeadingFont end)
    pcall(function()
        name.AutoScaleHorizontal = false
        name.AutoScaleVertical = false
    end)

    local sub = ""
    local cooldownRemaining = GetCooldownRemaining(product)
    if cooldownRemaining > 0 then
        sub = GetText("Cooldown") .. ": " .. FormatSeconds(cooldownRemaining)
    elseif IsClassProduct(product) and GetProductLimitText(product) ~= "" then
        sub = GetProductLimitText(product)
    elseif product.Stock ~= nil and product.Limit ~= nil and product.Limit < 999 then
        sub = GetText("Stock") .. ": " .. tostring(product.Stock) .. " / " .. tostring(product.Limit)
    elseif disabledReason ~= "" then
        sub = disabledReason
    else
        sub = product.Type or ""
    end

    local details = CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, Utf8Truncate(sub, 46), GUI.Alignment.Left, 0.80, enabled and Color(190, 205, 190, 235) or Color(120, 120, 120, 220), false)
    pcall(function()
        details.AutoScaleHorizontal = false
        details.AutoScaleVertical = false
    end)
    if cooldownRemaining > 0 then
        RegisterCooldownText("shop", details, function()
            local remaining = GetCooldownRemaining(product)
            if remaining <= 0 then return "", false end
            return GetText("Cooldown") .. ": " .. FormatSeconds(remaining), true
        end)
    elseif IsClassProduct(product) then
        RegisterClassLimitText(details, function()
            return GetProductLimitText(product)
        end)
    end

    if showPrice then
        local price = CreateText(inner, 0.125, 0.72, nil, tostring(product.Price or 0) .. " pt", GUI.Alignment.Right, 0.96, enabled and Color(255, 245, 210, 255) or Color(125, 125, 125, 255), false)
        pcall(function() price.Font = GUI.Style.SubHeadingFont end)
        pcall(function() price.AutoScaleHorizontal = true end)
    end

    local cartButton = CreateStoreActionButton(inner, 0.165, "StoreAddToCrateButton", enabled)
    local addProduct = function()
        selectedProductId = product.Id
        UpdateProductRowSelection()
        if enabled then
            if shopMode == "ghost" or IsClassProduct(product) then
                pendingProductId = product.Id
            else
                pendingProductId = nil
                AddToCart(product)
            end
            RefreshCartOnly()
        else
            lastMessage = disabledReason
            RefreshCartOnly()
        end
        return true
    end

    cartButton.OnClicked = addProduct
    row.OnClicked = function()
        selectedProductId = product.Id
        UpdateProductRowSelection()
        RefreshCartOnly()
        return true
    end
end

local function AddCartButton(list, entry)
    local product = productById[entry.Id]
    if product == nil then return end
    local showPrice = ShouldShowProductPrice(product)

    local row = GUI.Frame(CreateRect(1, ITEM_ROW_HEIGHT, list.Content, GUI.Anchor.TopLeft), nil)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false

    local inner = CreateRowInner(row, 0.968, 0.90)
    pcall(function()
        inner.RelativeSpacing = 0.003
        inner.Stretch = true
    end)

    local iconHolder = GUI.Frame(CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    pcall(function()
        iconHolder.RectTransform.IsFixedSize = true
        iconHolder.RectTransform.MinSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
        iconHolder.RectTransform.MaxSize = Point(ITEM_ICON_PIXELS, ITEM_ICON_PIXELS)
    end)
    CreateProductIcon(iconHolder, product.IconIdentifier, true)

    local qty = entry.Quantity or 1

    local textGroup = GUI.Frame(CreateRect(showPrice and 0.500 or 0.625, 0.90, inner, nil), nil)
    textGroup.Color = Color(0, 0, 0, 0)
    textGroup.CanBeFocused = false

    local name = CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, tostring(product.Name or ""), GUI.Alignment.Left, 0.88, nil, true)
    pcall(function() name.Font = GUI.Style.SubHeadingFont end)
    pcall(function()
        name.AutoScaleHorizontal = false
        name.AutoScaleVertical = false
    end)

    local quantityText = GetText("Quantity") .. ": " .. tostring(qty)
    local quantity = CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, quantityText, GUI.Alignment.Left, 0.92, Color(190, 205, 190, 235), false)
    pcall(function() quantity.AutoScaleHorizontal = true end)

    if showPrice then
        local price = CreateText(inner, 0.125, 0.72, nil, tostring((product.Price or 0) * qty) .. " pt", GUI.Alignment.Right, 0.96, Color(255, 245, 210, 255), false)
        pcall(function() price.Font = GUI.Style.SubHeadingFont end)
        pcall(function() price.AutoScaleHorizontal = true end)
    end

    local removeButton = CreateStoreActionButton(inner, 0.165, "StoreRemoveFromCrateButton", true)
    local removeProduct = function()
        RemoveFromCart(entry.Id)
        RefreshCartOnly()
        return true
    end

    removeButton.OnClicked = removeProduct
end

local function CreateLayout(parent, width, height, anchor, isHorizontal, childAnchor)
    local layout = GUI.LayoutGroup(CreateRect(width, height, parent, anchor), isHorizontal == true, childAnchor or GUI.Anchor.TopLeft)
    pcall(function()
        layout.Stretch = true
        layout.RelativeSpacing = 0.006
    end)
    return layout
end

local function CreateDivider(parent, height)
    local frame = GUI.Frame(CreateRect(1, height or 0.02, parent), nil)
    frame.Color = Color(0, 0, 0, 0)
    pcall(function()
        GUI.Image(CreateRect(1, 0.55, frame, GUI.Anchor.Center), "HorizontalLine")
    end)
    return frame
end

local function CreatePanelTitle(parent, titleText, iconStyle, alignRight)
    local header = GUI.Frame(CreateRect(1, 0.095, parent, nil), nil)
    header.Color = Color(0, 0, 0, 0)
    header.CanBeFocused = false

    if not alignRight then
        local layout = GUI.LayoutGroup(CreateRect(1, 1, header, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
        pcall(function()
            layout.Stretch = true
            layout.RelativeSpacing = 0.010
        end)

        pcall(function()
            GUI.Image(CreateRect(0.087, 0.98, layout, nil), iconStyle or "StoreTradingIcon", true)
        end)

        local title = CreateText(layout, 0.88, 1, nil, titleText, GUI.Alignment.Left, 1.42, Color(255, 245, 190, 255), false)
        pcall(function() title.Font = GUI.Style.LargeFont end)
        return title
    end

    -- Right-anchored horizontal layout fills children from right to left.
    -- Create the icon first, then the title: visually the text goes first,
    -- the icon follows it, and the whole group stays in the right corner.
    local layout = GUI.LayoutGroup(CreateRect(0.82, 1, header, GUI.Anchor.TopRight), true, GUI.Anchor.CenterRight)
    pcall(function()
        layout.Stretch = true
        layout.RelativeSpacing = 0.012
    end)

    pcall(function()
        GUI.Image(CreateRect(0.115, 0.92, layout, nil), iconStyle or "StoreShoppingCrateIcon", true)
    end)

    local title = CreateText(layout, 0.70, 1, nil, titleText, GUI.Alignment.Right, 1.42, Color(255, 245, 190, 255), false)
    pcall(function() title.Font = GUI.Style.LargeFont end)

    return title
end

local function BuildPurchaseSummary(parent, total)
    -- The outer holder occupies the normal layout row. The actual summary is
    -- a compact right-aligned group, so GUILayout cannot stretch the three
    -- columns over the whole cart width.
    local holder = GUI.Frame(CreateRect(1, 0.054, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local summary = GUI.LayoutGroup(CreateRect(0.58, 1, holder, GUI.Anchor.TopRight), true, GUI.Anchor.TopRight)
    pcall(function()
        summary.Stretch = true
        summary.RelativeSpacing = 0.005
    end)

    local function addColumn(label, value)
        local column = CreateLayout(summary, 0.333, 1, nil, false, GUI.Anchor.TopRight)
        pcall(function() column.RelativeSpacing = 0.005 end)
        local labelBlock = CreateText(column, 1, 0.50, nil, label, GUI.Alignment.BottomCenter, 1.00, Color(235, 225, 180, 255), false)
        local valueBlock = CreateText(column, 1, 0.50, nil, tostring(value) .. " pt", GUI.Alignment.TopCenter, 1.10, Color(255, 255, 255, 255), false)
        pcall(function()
            labelBlock.Font = GUI.Style.Font
            labelBlock.AutoScaleVertical = true
            labelBlock.CanBeFocused = false
            valueBlock.Font = GUI.Style.SubHeadingFont
            valueBlock.AutoScaleVertical = true
            valueBlock.CanBeFocused = false
        end)
    end

    -- A TopRight GUILayoutGroup fills from right to left, like vanilla.
    addColumn(GetText("After"), currentPoints - total)
    addColumn(GetText("Total"), total)
    addColumn(GetText("Points"), currentPoints)
end

local function CreateProductDetails(parent, product, height)
    if product == nil then return nil end

    local card = GUI.Frame(CreateRect(1, height or 0.30, parent, GUI.Anchor.TopLeft), nil)
    card.Color = Color(0, 0, 0, 0)
    card.CanBeFocused = false

    local details = CreateLayout(card, 0.94, 0.92, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    pcall(function()
        details.RelativeSpacing = 0.008
        details.Stretch = true
    end)

    local header = CreateLayout(details, 1, 0.54, nil, true, GUI.Anchor.CenterLeft)
    pcall(function() header.RelativeSpacing = 0.012 end)
    local iconHolder = GUI.Frame(CreateRect(0.23, 1, header, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    CreateProductIcon(iconHolder, product.IconIdentifier, GetProductDisabledReason(product) == "")

    local heading = CreateLayout(header, 0.77, 1, nil, false, GUI.Anchor.TopLeft)
    pcall(function() heading.RelativeSpacing = 0.006 end)
    local name = CreateText(heading, 1, 0.30, nil, string.upper(tostring(product.Name or "")), GUI.Alignment.Left, 1.00, Color(255, 245, 210, 255), true)
    pcall(function() name.Font = GUI.Style.SubHeadingFont end)
    local description = GetProductDescriptionText(product)
    local descriptionBlock = CreateText(heading, 1, 0.70, nil, description, GUI.Alignment.Left, 0.84, Color(210, 220, 205, 230), true)
    if IsClassProduct(product) then
        RegisterClassLimitText(descriptionBlock, function() return GetProductDescriptionText(product) end)
    end

    local infoLines = {}
    if ShouldShowProductPrice(product) then
        table.insert(infoLines, string.format("%s:  %d pt", GetText("Price"), tonumber(product.Price) or 0))
    end
    if ShouldShowProductStock(product) then
        table.insert(infoLines, GetText("Remaining") .. ":  " .. GetProductStockDisplay(product))
    end
    table.insert(infoLines, GetText("Category") .. ":  " .. tostring(product.Category or ""))
    local info = table.concat(infoLines, "\n")
    CreateText(details, 1, 0.29, nil, info, GUI.Alignment.Left, 0.88, Color(225, 225, 205, 255), true)

    local cooldown = GetCooldownRemaining(product)
    local reason = GetProductDisabledReason(product)
    if cooldown > 0 or reason ~= "" then
        local function getStatusText()
            local remaining = GetCooldownRemaining(product)
            if remaining > 0 then
                return GetText("Cooldown") .. ": " .. FormatSeconds(remaining), true
            end
            local currentReason = GetProductDisabledReason(product)
            if currentReason ~= "" then
                return GetText("Unavailable") .. ":\n" .. currentReason, false
            end
            return "", false
        end
        local status = CreateText(details, 1, 0.17, nil, getStatusText(), GUI.Alignment.Left, 0.86, Color(255, 210, 145, 255), true)
        if cooldown > 0 then RegisterCooldownText("cart", status, getStatusText) end
    end

    return card
end

local function BuildHeader(parent)
    CreatePanelTitle(parent, GetText("Shop"), "StoreTradingIcon", false)

    local balance = CreateText(parent, 1, 0.070, nil, GetText("Balance") .. "\n" .. tostring(currentPoints) .. " pt", GUI.Alignment.Left, 1.12, Color(235, 230, 185, 255))
    pcall(function() balance.AutoScaleVertical = true end)

    local tabs = CreateLayout(parent, 1, 0.030, nil, true, GUI.Anchor.CenterLeft)
    pcall(function() tabs.RelativeSpacing = 0 end)

    local categoryTab = CreateButton(tabs, 0.50, 1, nil, GetText("Categories"), true, currentView == "categories", "GUITabButton")
    categoryTab.OnClicked = function()
        currentView = "categories"
        ShowMenu()
        return true
    end

    local buyTab = CreateButton(tabs, 0.50, 1, nil, GetText("BuyTab"), true, currentView == "products", "GUITabButton")
    buyTab.OnClicked = function()
        if selectedCategory == nil and products[1] ~= nil then
            selectedCategory = products[1].Category
            selectedPath = products[1].Path or ""
        end
        currentView = "products"
        shopListScroll = 0
        ShowMenu()
        return true
    end

    CreateDivider(parent, 0.018)
end

local function GetSelectedFilterLabel()
    if selectedFilter == "available" then return GetText("FilterAvailable") end
    if selectedFilter == "affordable" then return GetText("FilterAffordable") end
    return GetText("FilterAll")
end

CloseFilterPopup = function()
    if filterPopup == nil then return end
    if filterButton ~= nil then filterButton.Selected = false end
    pcall(function() filterPopup:RemoveFromGUIUpdateList(true) end)
    pcall(function()
        filterPopup.Visible = false
        if filterPopup.RectTransform ~= nil then
            filterPopup.RectTransform.Parent = nil
        end
    end)
    filterPopup = nil
end

local function ToggleFilterPopup(button)
    if filterPopup ~= nil then
        CloseFilterPopup()
        return
    end
    if currentMenu == nil or button == nil then return end

    -- Keep the exact screen geometry of the button, but make the popup the last
    -- child of the menu overlay. If it stays inside the filter button's layout
    -- branch, the product list is added later and gets drawn over the options.
    local menuWidth = math.max(currentMenu.Rect.Width, 1)
    local menuHeight = math.max(currentMenu.Rect.Height, 1)
    local popupWidth = math.max(button.Rect.Width, 1)
    local popupHeight = math.max(button.Rect.Height * 3, 3)
    local popupRect = GUI.RectTransform(
        -- RectTransform truncates relative sizes to whole pixels. The small
        -- subpixel guard prevents an exact button width from becoming 1 px
        -- narrower after the screen-space reparenting.
        Vector2((popupWidth + 0.25) / menuWidth, (popupHeight + 0.25) / menuHeight),
        currentMenu.RectTransform,
        GUI.Anchor.TopLeft,
        GUI.Pivot.TopLeft
    )
    popupRect.ScreenSpaceOffset = Point(
        button.Rect.X - currentMenu.Rect.X,
        button.Rect.Bottom - currentMenu.Rect.Y + 1
    )

    -- Draw the same single frame as the vanilla GUIDropDown list, but keep the
    -- three choices in a plain layout. A GUIListBox would reserve/restore its
    -- scrollbar on the next update even when all three entries fit.
    local popup = GUI.Frame(popupRect, "GUIFrameListBox")
    popup.IgnoreLayoutGroups = true
    popup.CanBeFocused = true
    pcall(function()
        GUI.Style.Apply(popup, "GUIListBox", button)
    end)
    filterPopup = popup
    button.Selected = true

    local options = GUI.LayoutGroup(CreateRect(0.98, 0.96, popup, GUI.Anchor.Center), false, GUI.Anchor.TopLeft)
    pcall(function()
        options.Stretch = true
        options.RelativeSpacing = 0
    end)

    local entries = {
        { Value = "all", Label = GetText("FilterAll") },
        { Value = "available", Label = GetText("FilterAvailable") },
        { Value = "affordable", Label = GetText("FilterAffordable") },
    }
    for _, entry in ipairs(entries) do
        local optionValue = entry.Value
        local optionLabel = entry.Label
        local option = GUI.Button(CreateRect(1, 0.333, options, nil), "", GUI.Alignment.CenterLeft, "ListBoxElement")
        SetButtonStyle(option, true, selectedFilter == optionValue)
        -- The vanilla GUITextBlock style already provides a 10 px padding.
        -- Do not combine it with an additional percentage-based inset.
        local optionText = CreateText(option, 1, 1, GUI.Anchor.Center, optionLabel, GUI.Alignment.CenterLeft, 0.96, Color(235, 225, 180, 255), false)
        optionText.CanBeFocused = false
        option.OnClicked = function()
            selectedFilter = optionValue
            if filterButton ~= nil then
                filterButton.Text = GetSelectedFilterLabel()
            end
            CloseFilterPopup()
            if rebuildProductList ~= nil then rebuildProductList() end
            return true
        end
    end

    -- Keep the popup above the product list in both draw and input order.
    pcall(function() popup:AddToGUIUpdateList(false, GUI_DRAW_ORDER + 60) end)
end

local function BuildFilterBar(parent)
    local bar = CreateLayout(parent, 1, 0.082, nil, true, GUI.Anchor.TopLeft)
    pcall(function() bar.RelativeSpacing = 0.018 end)

    local filterGroup = CreateLayout(bar, 0.40, 1, nil, false, GUI.Anchor.TopLeft)
    pcall(function() filterGroup.RelativeSpacing = 0.002 end)
    local filterLabel = CreateText(filterGroup, 1, 0.38, nil, GetText("Filter"), GUI.Alignment.BottomLeft, 1.70, Color(235, 225, 180, 255), false)
    filterLabel.TextOffset = Vector2(0, -2)
    filterButton = GUI.Button(CreateRect(1, 0.60, filterGroup, nil), GetSelectedFilterLabel(), GUI.Alignment.CenterLeft, "GUIDropDown")
    SetButtonStyle(filterButton, true, false)
    pcall(function()
        filterButton.ForceUpperCase = false
        filterButton.TextBlock.TextScale = 0.98
    end)
    -- DropDownIcon is a child style of GUIDropDown, not a global GUI style.
    -- Constructing GUI.Image with the string "DropDownIcon" logs an error.
    pcall(function()
        local dropDownIcon = GUI.Image(CreateRect(0.12, 0.58, filterButton, GUI.Anchor.CenterRight), nil, true)
        GUI.Style.Apply(dropDownIcon, "DropDownIcon", filterButton)
        dropDownIcon.CanBeFocused = false
        dropDownIcon.IgnoreLayoutGroups = true
        dropDownIcon.RectTransform.AbsoluteOffset = Point(5, 0)
    end)
    filterButton.OnClicked = function(button)
        ToggleFilterPopup(button)
        return true
    end

    local searchGroup = CreateLayout(bar, 0.60, 1, nil, false, GUI.Anchor.TopLeft)
    pcall(function() searchGroup.RelativeSpacing = 0.002 end)
    local searchLabel = CreateText(searchGroup, 1, 0.38, nil, GetText("Search"), GUI.Alignment.BottomLeft, 1.70, Color(235, 225, 180, 255), false)
    searchLabel.TextOffset = Vector2(0, -2)
    local searchBox = GUI.TextBox(CreateRect(1, 0.60, searchGroup, nil), searchText)
    searchBox.OnTextChangedDelegate = function(_, value)
        CloseFilterPopup()
        searchText = tostring(value or "")
        if rebuildProductList ~= nil then rebuildProductList() end
        return true
    end
end

local function BuildShopPanel(overlay)
    -- Keep the outer panel transparent; only the item/category selection area
    -- uses the vanilla list frame, closer to the vanilla store layout.
    local root = GUI.Frame(CreateRect(PANEL_WIDTH, 0.985, overlay, GUI.Anchor.BottomLeft), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = false

    local content = CreateLayout(root, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    pcall(function()
        content.RelativeSpacing = 0.007
        content.Stretch = true
    end)

    BuildHeader(content)

    local menuFrame = GUI.Frame(CreateRect(1, 0.835, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.965, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    pcall(function()
        menuContent.RelativeSpacing = 0.006
        menuContent.Stretch = true
    end)

    CloseFilterPopup()
    filterButton = nil
    rebuildProductList = nil
    if currentView == "products" then BuildFilterBar(menuContent) end

    local listHeight = currentView == "products" and 0.768 or 0.855
    -- One vanilla green list frame. The list's own background below is kept
    -- transparent so a second nested outline is not drawn.
    local listFrame = GUI.Frame(CreateRect(1, listHeight, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    shopList = list
    list.Color = Color(0, 0, 0, 0)
    pcall(function() list.ContentBackground.Color = Color(0, 0, 0, 0) end)
    pcall(function() list.KeepSpaceForScrollBar = false end)
    pcall(function() list.CanBeFocused = false end)

    if currentView == "categories" then
        local folders = BuildFolderList()
        if #folders == 0 then
            CreateText(list.Content, 0.95, 0.13, GUI.Anchor.TopCenter, GetText("EmptyCategories"), GUI.Alignment.Center, 1.10)
        else
            for _, folder in ipairs(folders) do
                AddCategoryButton(list, folder)
            end
        end
    else
        local function populateProductList(resetScroll)
            local previousScroll = 0
            pcall(function() previousScroll = list.BarScroll end)
            pcall(function() list.Content:ClearChildren() end)
            productRows = {}
            emptyProductsText = nil
            cooldownTextBlocks.shop = {}

            local breadcrumb = CreateText(list.Content, 0.96, 0.075, GUI.Anchor.TopLeft, GetSelectedFolderLabel(), GUI.Alignment.Left, 1.08, Color(180, 220, 190, 255))
            pcall(function() breadcrumb.RectTransform.MinSize = Point(0, 28) end)

            local hasProducts = false
            for _, product in ipairs(products) do
                if ProductMatchesSelectedFolder(product) and ProductMatchesSearchAndFilter(product) then
                    hasProducts = true
                    AddProductButton(list, product)
                end
            end

            if not hasProducts then
                emptyProductsText = CreateText(list.Content, 0.95, 0.13, GUI.Anchor.TopCenter, GetText("EmptyProducts"), GUI.Alignment.Center, 1.10)
            end

            shopListScroll = resetScroll == false and previousScroll or 0
            pcall(function()
                list.BarScroll = shopListScroll
                list:RecalculateChildren()
                list:UpdateScrollBarSize()
            end)
            pcall(function() guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER) end)
        end
        rebuildProductList = populateProductList
        populateProductList()
    end

    pcall(function() list.BarScroll = shopListScroll or 0 end)

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
    pcall(function() hint.AutoScaleVertical = true end)
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
    pcall(function()
        content.RelativeSpacing = 0.007
        content.Stretch = true
    end)

    CreatePanelTitle(content, GetText("ConfirmTitle"), "StoreShoppingCrateIcon", true)

    local product = GetPendingProduct() or GetSelectedProduct()
    local total = product ~= nil and (product.Price or 0) or 0
    BuildPurchaseSummary(content, total)

    CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    pcall(function()
        menuContent.RelativeSpacing = 0.006
        menuContent.Stretch = true
    end)

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
    pcall(function() buttons.RelativeSpacing = 0.012 end)

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
    pcall(function()
        content.RelativeSpacing = 0.007
        content.Stretch = true
    end)

    CreatePanelTitle(content, GetText("Cart"), "StoreShoppingCrateIcon", true)

    local total = GetCartTotal()
    BuildPurchaseSummary(content, total)

    CreateDivider(content, 0.018)

    local menuFrame = GUI.Frame(CreateRect(1, 0.815, content, nil), "GUIFrame")
    menuFrame.CanBeFocused = false

    local menuContent = CreateLayout(menuFrame, 0.955, 0.955, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    pcall(function()
        menuContent.RelativeSpacing = 0.006
        menuContent.Stretch = true
    end)

    local listFrame = GUI.Frame(CreateRect(1, 0.835, menuContent, nil), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(CreateRect(1, 1, listFrame, GUI.Anchor.Center), false, nil, "GUIListBoxNoBorder")
    list.Color = Color(0, 0, 0, 0)
    pcall(function() list.ContentBackground.Color = Color(0, 0, 0, 0) end)
    pcall(function() list.KeepSpaceForScrollBar = false end)
    pcall(function() list.CanBeFocused = false end)

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
    pcall(function() buttons.RelativeSpacing = 0.012 end)

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

    if cartPanelRoot ~= nil then
        pcall(function()
            cartPanelRoot:RemoveFromGUIUpdateList(true)
        end)
        pcall(function()
            if cartPanelRoot.RectTransform ~= nil then
                cartPanelRoot.RectTransform.Parent = nil
            end
            cartPanelRoot.Visible = false
        end)
    end

    cartPanelRoot = BuildCartPanel(currentMenu)
    pcall(function() guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER) end)
end

ShowMenu = function()
    CloseMenu()
    cooldownTextBlocks.shop = {}
    cooldownTextBlocks.cart = {}
    classLimitTextBlocks = {}
    nextCooldownTextUpdateTime = 0

    local overlay = GUI.Frame(CreateRect(1, 1, guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 191)
    overlay.CanBeFocused = false
    overlay.IgnoreLayoutGroups = true
    currentMenu = overlay
    sharedState.CurrentMenu = overlay

    SetPauseMenuBlocked()

    BuildShopPanel(overlay)
    cartPanelRoot = BuildCartPanel(overlay)
    pcall(function() guiRoot:AddToGUIUpdateList(false, GUI_DRAW_ORDER) end)
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
        if rebuildProductList ~= nil then rebuildProductList(false) end
        RefreshCartOnly()
    end
end)

Networking.Receive(NET_PRODUCT_STATE, function(message)
    if sharedState.Disabled then return end
    local count = message.ReadInt32()
    local complete = true
    for i = 1, count do
        if not ReadProductState(message) then complete = false end
    end
    if not complete then
        RequestSnapshot()
        return
    end
    ReconcileProductState(false)
    if currentMenu ~= nil then
        if rebuildProductList ~= nil then rebuildProductList(false) end
        RefreshCartOnly()
    end
end)
