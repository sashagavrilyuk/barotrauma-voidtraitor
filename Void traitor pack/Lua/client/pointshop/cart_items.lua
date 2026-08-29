local P = ...
local S = P.State

function P.AddCartButton(list, entry)
    local product = S.productById[entry.Id]
    if product == nil then return end
    local showPrice = P.ShouldShowProductPrice(product)

    local row = GUI.Frame(P.CreateRect(1, P.ITEM_ROW_HEIGHT, list.Content, GUI.Anchor.TopLeft), nil)
    row.Color = Color(0, 0, 0, 0)
    row.CanBeFocused = false

    local inner = P.CreateRowInner(row, 0.968, 0.90)
    inner.RelativeSpacing = 0.003
    inner.Stretch = true

    local iconHolder = GUI.Frame(P.CreateRect(0.168, 1, inner, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    iconHolder.RectTransform.IsFixedSize = true
    iconHolder.RectTransform.MinSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)
    iconHolder.RectTransform.MaxSize = Point(P.ITEM_ICON_PIXELS, P.ITEM_ICON_PIXELS)
    P.CreateProductIcon(iconHolder, product.IconIdentifier, true)

    local qty = entry.Quantity or 1

    local textGroup = GUI.Frame(P.CreateRect(showPrice and 0.500 or 0.625, 0.90, inner, nil), nil)
    textGroup.Color = Color(0, 0, 0, 0)
    textGroup.CanBeFocused = false

    local name = P.CreateText(textGroup, 1, 0.66, GUI.Anchor.TopLeft, tostring(product.Name or ""), GUI.Alignment.Left, 0.88, nil, true)
    name.Font = GUI.Style.SubHeadingFont
    name.AutoScaleHorizontal = false
    name.AutoScaleVertical = false

    local quantityText = P.GetText("Quantity") .. ": " .. tostring(qty)
    local quantity = P.CreateText(textGroup, 1, 0.24, GUI.Anchor.BottomLeft, quantityText, GUI.Alignment.Left, 0.92, Color(190, 205, 190, 235), false)
    quantity.AutoScaleHorizontal = true

    if showPrice then
        local price = P.CreateText(inner, 0.125, 0.72, nil, tostring((product.Price or 0) * qty) .. " pt", GUI.Alignment.Right, 0.96, Color(255, 245, 210, 255), false)
        price.Font = GUI.Style.SubHeadingFont
        price.AutoScaleHorizontal = true
    end

    local removeButton = P.CreateStoreActionButton(inner, 0.165, "StoreRemoveFromCrateButton", true)
    local removeProduct = function()
        P.RemoveFromCart(entry.Id)
        P.RefreshCartOnly()
        return true
    end

    removeButton.OnClicked = removeProduct
end

function P.BuildPurchaseSummary(parent, total)
    -- The outer holder occupies the normal layout row. The actual summary is
    -- a compact right-aligned group, so GUILayout cannot stretch the three
    -- columns over the whole cart width.
    local holder = GUI.Frame(P.CreateRect(1, 0.054, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local summary = GUI.LayoutGroup(P.CreateRect(0.58, 1, holder, GUI.Anchor.TopRight), true, GUI.Anchor.TopRight)
    summary.Stretch = true
    summary.RelativeSpacing = 0.005

    local function addColumn(label, value)
        local column = P.CreateLayout(summary, 0.333, 1, nil, false, GUI.Anchor.TopRight)
        column.RelativeSpacing = 0.005
        local labelBlock = P.CreateText(column, 1, 0.50, nil, label, GUI.Alignment.BottomCenter, 1.00, Color(235, 225, 180, 255), false)
        local valueBlock = P.CreateText(column, 1, 0.50, nil, tostring(value) .. " pt", GUI.Alignment.TopCenter, 1.10, Color(255, 255, 255, 255), false)
        labelBlock.Font = GUI.Style.Font
        labelBlock.AutoScaleVertical = true
        labelBlock.CanBeFocused = false
        valueBlock.Font = GUI.Style.SubHeadingFont
        valueBlock.AutoScaleVertical = true
        valueBlock.CanBeFocused = false
    end

    -- A TopRight GUILayoutGroup fills from right to left, like vanilla.
    addColumn(P.GetText("After"), S.currentPoints - total)
    addColumn(P.GetText("Total"), total)
    addColumn(P.GetText("Points"), S.currentPoints)
end

function P.CreateProductDetails(parent, product, height)
    if product == nil then return nil end

    local card = GUI.Frame(P.CreateRect(1, height or 0.30, parent, GUI.Anchor.TopLeft), nil)
    card.Color = Color(0, 0, 0, 0)
    card.CanBeFocused = false

    local details = P.CreateLayout(card, 0.94, 0.92, GUI.Anchor.Center, false, GUI.Anchor.TopLeft)
    details.RelativeSpacing = 0.008
    details.Stretch = true

    local header = P.CreateLayout(details, 1, 0.54, nil, true, GUI.Anchor.CenterLeft)
    header.RelativeSpacing = 0.012
    local iconHolder = GUI.Frame(P.CreateRect(0.23, 1, header, nil), nil)
    iconHolder.Color = Color(0, 0, 0, 0)
    iconHolder.CanBeFocused = false
    P.CreateProductIcon(iconHolder, product.IconIdentifier, P.GetProductDisabledReason(product) == "")

    local heading = P.CreateLayout(header, 0.77, 1, nil, false, GUI.Anchor.TopLeft)
    heading.RelativeSpacing = 0.006
    local name = P.CreateText(heading, 1, 0.30, nil, string.upper(tostring(product.Name or "")), GUI.Alignment.Left, 1.00, Color(255, 245, 210, 255), true)
    name.Font = GUI.Style.SubHeadingFont
    local description = P.GetProductDescriptionText(product)
    local descriptionBlock = P.CreateText(heading, 1, 0.70, nil, description, GUI.Alignment.Left, 0.84, Color(210, 220, 205, 230), true)
    if P.IsClassProduct(product) then
        P.RegisterClassLimitText("cart", descriptionBlock, function() return P.GetProductDescriptionText(product) end)
    end

    local infoLines = {}
    if P.ShouldShowProductPrice(product) then
        table.insert(infoLines, string.format("%s:  %d pt", P.GetText("Price"), tonumber(product.Price) or 0))
    end
    if P.ShouldShowProductStock(product) then
        table.insert(infoLines, P.GetText("Remaining") .. ":  " .. P.GetProductStockDisplay(product))
    end
    table.insert(infoLines, P.GetText("Category") .. ":  " .. tostring(product.Category or ""))
    local info = table.concat(infoLines, "\n")
    P.CreateText(details, 1, 0.29, nil, info, GUI.Alignment.Left, 0.88, Color(225, 225, 205, 255), true)

    local cooldown = P.GetCooldownRemaining(product)
    local reason = P.GetProductDisabledReason(product)
    if cooldown > 0 or reason ~= "" then
        local function getStatusText()
            local remaining = P.GetCooldownRemaining(product)
            if remaining > 0 then
                return P.GetText("Cooldown") .. ": " .. P.FormatSeconds(remaining), true
            end
            local currentReason = P.GetProductDisabledReason(product)
            if currentReason ~= "" then
                return P.GetText("Unavailable") .. ":\n" .. currentReason, false
            end
            return "", false
        end
        local status = P.CreateText(details, 1, 0.17, nil, getStatusText(), GUI.Alignment.Left, 0.86, Color(255, 210, 145, 255), true)
        if cooldown > 0 then P.RegisterCooldownText("cart", status, getStatusText) end
    end

    return card
end
