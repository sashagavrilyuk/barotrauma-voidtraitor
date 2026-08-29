local P = ...
local S = P.State

function P.ReadSnapshot(message)
    S.lastMessage = message.ReadString()
    S.currentPoints = message.ReadInt32()
    S.shopMode = message.ReadString()
    if S.shopMode == nil or S.shopMode == "" then S.shopMode = "shop" end
    local count = message.ReadInt32()

    S.products = {}
    S.productById = {}
    S.classLimitValues = {}

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
            product.CooldownEndTime = P.GetClientTime() + product.CooldownRemaining
        else
            product.CooldownEndTime = nil
        end

        if product.LimitText ~= nil and product.LimitText ~= "" then
            S.classLimitValues[P.GetProductClassLimitKey(product)] = product.LimitText
        end

        product.SearchText = P.NormalizeSearchText(table.concat({
            tostring(product.Name or ""),
            tostring(product.Description or ""),
            tostring(product.Category or ""),
            tostring(product.Path or ""),
            tostring(product.IconIdentifier or ""),
            tostring(product.CategoryIdentifier or ""),
            tostring(product.PathIdentifiers or ""),
            tostring(product.Type or ""),
        }, " "))

        if product.Id ~= nil and product.Id ~= "" then
            table.insert(S.products, product)
            S.productById[product.Id] = product
        end
    end

    local textCount = message.ReadInt32()

    for i = 1, textCount do
        local key = message.ReadString()
        local value = message.ReadString()
        if key ~= nil and key ~= "" then
            P.Text[key] = value or ""
        end
    end

    local purchaseCompleted = message.ReadBoolean()

    S.cooldownSnapshotRequested = false
    S.buyRequestPending = false

    S.closeMenuAfterSnapshot = message.ReadBoolean()

    if purchaseCompleted then
        P.ClearCart()
        S.pendingProductId = nil
    end

    for index = #S.cart, 1, -1 do
        local entry = S.cart[index]
        local product = S.productById[entry.Id]
        if product == nil or P.GetProductDisabledReason(product) ~= "" or product.Stock <= 0 then
            table.remove(S.cart, index)
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

    if S.pendingProductId ~= nil and S.productById[S.pendingProductId] == nil then
        S.pendingProductId = nil
    end
    if S.selectedProductId ~= nil and S.productById[S.selectedProductId] == nil then
        S.selectedProductId = nil
    end

    local selectedStillExists = false
    for _, product in ipairs(S.products) do
        if product.Category == S.selectedCategory and (product.Path or "") == (S.selectedPath or "") then
            selectedStillExists = true
            break
        end
    end

    if not selectedStillExists and S.products[1] ~= nil then
        S.selectedCategory = S.products[1].Category
        S.selectedPath = S.products[1].Path or ""
    end
end

function P.ReadProductState(message)
    local productId = message.ReadString()
    local price = message.ReadInt32()
    local stock = message.ReadInt32()
    local disabledReason = message.ReadString()
    local maxQuantity = message.ReadInt32()
    local cooldownRemaining = math.max(message.ReadInt32(), 0)
    local product = S.productById[productId]
    if product == nil then return false end

    local matchedFilter = P.ProductMatchesSearchAndFilter(product)
    local showedPrice = P.ShouldShowProductPrice(product)
    local hadCooldown = P.GetCooldownRemaining(product) > 0

    product.Price = price
    product.Stock = stock
    product.DisabledReason = disabledReason or ""
    product.MaxQuantity = maxQuantity
    product.CooldownRemaining = cooldownRemaining
    product.CooldownEndTime = cooldownRemaining > 0 and (P.GetClientTime() + cooldownRemaining) or nil
    return true,
        matchedFilter ~= P.ProductMatchesSearchAndFilter(product)
        or showedPrice ~= P.ShouldShowProductPrice(product)
        or hadCooldown ~= (P.GetCooldownRemaining(product) > 0)
end

function P.ReconcileProductState(purchaseCompleted)
    if purchaseCompleted then
        P.ClearCart()
        S.pendingProductId = nil
    end

    for index = #S.cart, 1, -1 do
        local entry = S.cart[index]
        local product = S.productById[entry.Id]
        if product == nil or P.GetProductDisabledReason(product) ~= "" or product.Stock <= 0 then
            table.remove(S.cart, index)
        else
            local maxQuantity = math.max(tonumber(product.MaxQuantity) or tonumber(product.Stock) or 1, 1)
            if product.AllowQuantity ~= true then maxQuantity = 1 end
            entry.Quantity = math.min(entry.Quantity or 1, maxQuantity)
        end
    end


    local selected = P.GetSelectedProduct()
    if selected ~= nil and selected.Stock <= 0 then S.selectedProductId = nil end
    local pending = P.GetPendingProduct()
    if pending ~= nil and P.GetProductDisabledReason(pending) ~= "" then S.pendingProductId = nil end
end

function P.ReadState(message)
    S.lastMessage = message.ReadString()
    S.currentPoints = message.ReadInt32()
    S.shopMode = message.ReadString()
    if S.shopMode == nil or S.shopMode == "" then S.shopMode = "shop" end

    local count = message.ReadInt32()
    local complete = true
    for i = 1, count do
        if not P.ReadProductState(message) then complete = false end
    end

    local purchaseCompleted = message.ReadBoolean()
    S.closeMenuAfterSnapshot = message.ReadBoolean()
    S.cooldownSnapshotRequested = false
    S.buyRequestPending = false
    P.ReconcileProductState(purchaseCompleted)
    return complete
end
