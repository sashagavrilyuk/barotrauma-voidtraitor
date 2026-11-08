local P = ...
local S = P.State

P.Text = P.Common.Language.Pointshop

function P.GetText(key)
    return P.Text[key] or ""
end

function P.Utf8Truncate(value, maxChars)
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

P.NormalizeSearchText = P.Common.NormalizeSearchText

function P.GetCartEntry(productId)
    for _, entry in ipairs(S.cart) do
        if entry.Id == productId then return entry end
    end
    return nil
end

function P.GetCartTotal()
    local total = 0
    for _, entry in ipairs(S.cart) do
        local product = S.productById[entry.Id]
        if product ~= nil then
            total = total + (product.Price or 0) * (entry.Quantity or 1)
        end
    end
    return total
end

function P.GetPendingProduct()
    if S.pendingProductId == nil then return nil end
    return S.productById[S.pendingProductId]
end

function P.GetSelectedProduct()
    if S.selectedProductId == nil then return nil end
    return S.productById[S.selectedProductId]
end

function P.IsClassProduct(product)
    return product ~= nil and product.Type == "class"
end

function P.GetClassSelectText()
    local value = P.GetText("SelectClassAction")
    if value ~= nil and value ~= "" then return value end
    return P.GetText("SelectGhostAction")
end

function P.FormatSeconds(seconds)
    seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
    local minutes = math.floor(seconds / 60)
    local rest = seconds - minutes * 60
    return string.format("%02d:%02d", minutes, rest)
end

function P.GetClientTime()
    return Timer.GetTime()
end

function P.GetCooldownRemaining(source)
    if source == nil then return 0 end

    if source.CooldownEndTime ~= nil then
        return math.max(math.ceil(source.CooldownEndTime - P.GetClientTime()), 0)
    end

    return math.max(math.floor(tonumber(source.CooldownRemaining) or 0), 0)
end

function P.GetProductStateDisabledReason(product)
    if product == nil then return "" end
    local cooldown = P.GetCooldownRemaining(product)
    if cooldown > 0 then
        return P.GetText("Cooldown") .. ": " .. P.FormatSeconds(cooldown)
    end
    return tostring(product.DisabledReason or "")
end

function P.GetProductDisabledReason(product)
    local reason = P.GetProductStateDisabledReason(product)
    if reason ~= "" then return reason end
    if (tonumber(product.Price) or 0) > S.currentPoints then
        return P.GetText("NotEnoughPoints")
    end
    return ""
end

function P.IsProductAvailable(product)
    return P.GetProductStateDisabledReason(product) == ""
end

function P.CanBuyProduct(product)
    return P.IsProductAvailable(product) and (tonumber(product.Price) or 0) <= S.currentPoints
end

function P.IsUnlimitedProductStock(product)
    if product == nil then return false end
    return (tonumber(product.Stock) or 0) >= P.NET_INT32_MAX
        or (tonumber(product.Limit) or 0) >= P.NET_INT32_MAX
end

function P.ShouldShowProductPrice(product)
    return product ~= nil and (tonumber(product.Price) or 0) ~= 0
end

function P.ShouldShowProductStock(product)
    return product ~= nil and not P.IsUnlimitedProductStock(product)
end

function P.GetProductStockDisplay(product)
    if P.IsUnlimitedProductStock(product) then
        return P.GetText("Unlimited")
    end

    local stock = math.max(math.floor(tonumber(product.Stock) or 0), 0)
    local limit = math.max(math.floor(tonumber(product.Limit) or 0), 0)
    return tostring(stock) .. " / " .. tostring(limit)
end

function P.ProductMatchesSearchAndFilter(product)
    if product == nil then return false end
    if S.selectedFilter == "available" and not P.IsProductAvailable(product) then
        return false
    elseif S.selectedFilter == "affordable" and not P.CanBuyProduct(product) then
        return false
    end

    local query = S.normalizedSearchText
    if query == "" then return true end
    return string.find(product.SearchText or "", query, 1, true) ~= nil
end
