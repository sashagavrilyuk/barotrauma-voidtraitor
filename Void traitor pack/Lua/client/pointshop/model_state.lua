local P = ...
local S = P.State

function P.GetClassLimitKey(categoryIdentifier, pathIdentifiers)
    return tostring(categoryIdentifier or "") .. "\30" .. tostring(pathIdentifiers or "")
end

function P.GetProductClassLimitKey(product)
    if product == nil then return "" end
    return P.GetClassLimitKey(product.CategoryIdentifier, product.PathIdentifiers)
end

function P.GetProductLimitText(product)
    if product == nil then return "" end
    local key = P.GetProductClassLimitKey(product)
    if P.IsClassProduct(product) and key ~= "" then
        return S.classLimitValues[key] or ""
    end
    return product.LimitText or ""
end

function P.GetProductDescriptionText(product)
    if product == nil then return "" end

    local description = tostring(product.Description or "")
    if not P.IsClassProduct(product) then
        return description
    end

    local limitText = P.GetProductLimitText(product)
    if description ~= "" and limitText ~= "" then
        return description .. "\n\n" .. limitText
    end
    if description ~= "" then return description end
    return limitText
end

function P.IsFolderExpanded(folderKey)
    local value = S.expandedFolders[folderKey]
    if value == nil then return true end
    return value == true
end

function P.ToggleFolder(folderKey)
    S.expandedFolders[folderKey] = not P.IsFolderExpanded(folderKey)
end

function P.AddToCart(product)
    if product == nil or P.GetProductDisabledReason(product) ~= "" then return end

    local maxQuantity = tonumber(product.MaxQuantity) or tonumber(product.Stock) or 1
    maxQuantity = math.max(math.floor(maxQuantity), 1)
    if product.AllowQuantity ~= true then
        maxQuantity = 1
    end

    local entry = P.GetCartEntry(product.Id)
    if entry ~= nil then
        if (entry.Quantity or 1) >= maxQuantity then
            if product.AllowQuantity ~= true then
                S.lastMessage = P.GetText("SinglePurchase")
            else
                S.lastMessage = P.GetText("StockLimit")
            end
            return
        end
        entry.Quantity = math.min((entry.Quantity or 1) + 1, maxQuantity)
    else
        table.insert(S.cart, { Id = product.Id, Quantity = 1 })
    end
end

function P.RemoveFromCart(productId)
    for index, entry in ipairs(S.cart) do
        if entry.Id == productId then
            if (entry.Quantity or 1) > 1 then
                entry.Quantity = entry.Quantity - 1
            else
                table.remove(S.cart, index)
            end
            return
        end
    end
end

function P.ClearCart()
    S.cart = {}
end


function P.ProductMatchesSelectedFolder(product)
    return product.Category == S.selectedCategory and (product.Path or "") == (S.selectedPath or "")
end

function P.SelectedFolderHasClassProducts()
    for _, product in ipairs(S.products) do
        if P.ProductMatchesSelectedFolder(product) and P.IsClassProduct(product) then
            return true
        end
    end

    return false
end

function P.ClearPendingIfOutsideSelectedFolder()
    local pending = P.GetPendingProduct()
    if pending ~= nil and not P.ProductMatchesSelectedFolder(pending) then
        S.pendingProductId = nil
    end
    local selected = P.GetSelectedProduct()
    if selected ~= nil and not P.ProductMatchesSelectedFolder(selected) then
        S.selectedProductId = nil
    end
end

function P.GetSelectedFolderLabel()
    if S.selectedCategory == nil then return P.GetText("NoCategory") end
    if S.selectedPath == nil or S.selectedPath == "" then return S.selectedCategory end
    return S.selectedCategory .. " > " .. S.selectedPath
end
