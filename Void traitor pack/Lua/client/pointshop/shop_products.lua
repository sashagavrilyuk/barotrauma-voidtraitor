local P = ...
local S = P.State

function P.GetProductRowSubText(product)
    local cooldownRemaining = P.GetCooldownRemaining(product)
    if cooldownRemaining > 0 then
        return P.GetText("Cooldown") .. ": " .. P.FormatSeconds(cooldownRemaining)
    elseif P.IsClassProduct(product) and P.GetProductLimitText(product) ~= "" then
        return P.GetProductLimitText(product)
    elseif product.Stock ~= nil and product.Limit ~= nil and product.Limit < 999 then
        return P.GetText("Stock") .. ": " .. tostring(product.Stock) .. " / " .. tostring(product.Limit)
    end

    local disabledReason = P.GetProductDisabledReason(product)
    if disabledReason ~= "" then return disabledReason end
    return product.Type or ""
end

function P.AddProductButton(list, product)
    local disabledReason = P.GetProductDisabledReason(product)
    local enabled = disabledReason == ""
    local showPrice = P.ShouldShowProductPrice(product)
    -- The entire vanilla-style list row is the details button. This restores
    -- the original large hit area and removes the visible text-only overlay.
    local row = P.CreateButton(list.Content, 1, P.ITEM_ROW_HEIGHT, GUI.Anchor.TopLeft, "", true, S.selectedProductId == product.Id, "ListBoxElement")
    if row.TextBlock ~= nil then row.TextBlock.Text = "" end

    local inner = P.CreateRowInner(row, 0.968, 0.90)
    inner.RelativeSpacing = 0.003
    inner.Stretch = true

    local iconHolder = GUI.Frame(P.CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    iconHolder.RectTransform.IsFixedSize = true
    iconHolder.RectTransform.MinSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)
    iconHolder.RectTransform.MaxSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)
    local icon, iconColor = P.CreateProductIcon(iconHolder, product.IconIdentifier, enabled)

    -- Give the name back the price column when the original PointShop would
    -- hide a zero price (notably Attack Defend classes).
    local textGroup = GUI.Frame(P.CreateRect(showPrice and 0.500 or 0.625, 0.90, inner, nil), nil)
    textGroup.Color = Color(0, 0, 0, 0)
    textGroup.CanBeFocused = false

    local nameText = string.upper(tostring(product.Name or ""))
    local name = P.CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, nameText, GUI.Alignment.Left, 0.88, enabled and Color(235, 235, 225, 255) or Color(130, 130, 130, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    name.AutoScaleHorizontal = false
    name.AutoScaleVertical = false

    local cooldownRemaining = P.GetCooldownRemaining(product)
    local details = P.CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, P.Utf8Truncate(P.GetProductRowSubText(product), 46), GUI.Alignment.Left, 0.80, enabled and Color(190, 205, 190, 235) or Color(120, 120, 120, 220), false)
    details.AutoScaleHorizontal = false
    details.AutoScaleVertical = false
    if cooldownRemaining > 0 then
        P.RegisterCooldownText("shop", details, function()
            local remaining = P.GetCooldownRemaining(product)
            if remaining <= 0 then return "", false end
            return P.GetText("Cooldown") .. ": " .. P.FormatSeconds(remaining), true
        end)
    elseif P.IsClassProduct(product) then
        P.RegisterClassLimitText("shop", details, function()
            return P.GetProductLimitText(product)
        end)
    end

    local price = nil
    if showPrice then
        price = P.CreateText(inner, 0.125, 0.72, nil, tostring(product.Price or 0) .. " pt", GUI.Alignment.Right, 0.96, enabled and Color(255, 245, 210, 255) or Color(125, 125, 125, 255), false)
        price.Font = GUI.Style.SubHeadingFont
        price.AutoScaleHorizontal = true
    end

    local cartButton = P.CreateStoreActionButton(inner, 0.165, "StoreAddToCrateButton", enabled)
    table.insert(S.productRows, {
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
        S.selectedProductId = product.Id
        P.UpdateProductRowSelection()
        local currentDisabledReason = P.GetProductDisabledReason(product)
        if currentDisabledReason == "" then
            if S.shopMode == "ghost" or P.IsClassProduct(product) then
                S.pendingProductId = product.Id
            else
                S.pendingProductId = nil
                P.AddToCart(product)
            end
            P.RefreshCartOnly()
        else
            S.lastMessage = currentDisabledReason
            P.RefreshCartOnly()
        end
        return true
    end

    cartButton.OnClicked = addProduct
    row.OnClicked = function()
        S.selectedProductId = product.Id
        P.UpdateProductRowSelection()
        P.RefreshCartOnly()
        return true
    end
end

function P.RefreshProductRows()
    for _, entry in ipairs(S.productRows) do
        local product = entry.Product
        local enabled = P.GetProductDisabledReason(product) == ""

        entry.Row.Selected = product.Id == S.selectedProductId
        entry.CartButton.Enabled = enabled
        entry.Name.TextColor = enabled and Color(235, 235, 225, 255) or Color(130, 130, 130, 255)
        entry.Details.Text = P.Utf8Truncate(P.GetProductRowSubText(product), 46)
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
