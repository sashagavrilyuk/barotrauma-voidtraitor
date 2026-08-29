local P = ...
local S = P.State

function P.UpdateProductRowSelection()
    for _, entry in ipairs(S.productRows) do
        entry.Row.Selected = entry.Product.Id == S.selectedProductId
    end
end

function P.CreateFolderIcon(parent, folder, selected)
    local holder = GUI.Frame(P.CreateRect(0.070, 0.88, parent, nil), nil)
    holder.Color = Color(0, 0, 0, 0)
    holder.CanBeFocused = false

    local sprite, spriteColor = P.Common.GetPrefabIconData(folder.IconIdentifier)
    if sprite ~= nil then
        local image = GUI.Image(P.CreateRect(0.82, 0.82, holder, GUI.Anchor.Center), sprite, true)
        image.Color = spriteColor
        return holder
    end

    local marker = folder.Depth == 0 and "■" or ">"
    if folder.HasChildren then
        marker = P.IsFolderExpanded(folder.Key) and "v" or ">"
    end
    local color = selected and Color(255, 245, 190, 255) or (folder.Depth == 0 and Color(160, 210, 180, 255) or Color(120, 230, 190, 255))
    P.CreateText(holder, 1, 1, GUI.Anchor.Center, marker, GUI.Alignment.Center, folder.Depth == 0 and 0.95 or 1.18, color, false)
    return holder
end

function P.AddCategoryButton(list, folder)
    local selected = folder.Category == S.selectedCategory and folder.Path == (S.selectedPath or "")
    local rowHeight = folder.Depth == 0 and 0.073 or 0.061
    local row = P.CreateButton(list.Content, 1, rowHeight, GUI.Anchor.TopLeft, "", true, selected, "ListBoxElement")

    local inner = GUI.LayoutGroup(P.CreateRect(0.94, 0.92, row, GUI.Anchor.Center), true, GUI.Anchor.CenterLeft)
    inner.Stretch = true
    inner.RelativeSpacing = 0.004

    local indentWidth = math.min(0.035 * folder.Depth, 0.12)
    if indentWidth > 0 then
        local indent = GUI.Frame(P.CreateRect(indentWidth, 1, inner, nil), nil)
        indent.Color = Color(0, 0, 0, 0)
        indent.CanBeFocused = false
    end

    P.CreateFolderIcon(inner, folder, selected)

    local function getFolderInfoText()
        if folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
            return S.classLimitValues[folder.ClassLimitKey] or ""
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

        local folderCooldown = P.GetCooldownRemaining(folder)
        local active = S.shopMode == "ghost" and folderCooldown > 0 and (folder.DirectCount or 0) > 0
        if active then
            label = label .. "  - " .. P.GetText("Cooldown") .. ": " .. P.FormatSeconds(folderCooldown)
        end
        return label, active
    end

    local nameScale = folder.Depth == 0 and 0.95 or 0.90
    local nameColor = selected and Color(255, 245, 190, 255) or (folder.Depth == 0 and Color(225, 230, 215, 255) or Color(210, 235, 220, 255))
    local name = P.CreateText(inner, 0.86 - indentWidth, 0.88, nil, getLabelText(), GUI.Alignment.Left, nameScale, nameColor, false)
    name.AutoScaleHorizontal = true
    name.Font = GUI.Style.SubHeadingFont
    if S.shopMode == "ghost" and (folder.DirectCount or 0) > 0 and P.GetCooldownRemaining(folder) > 0 then
        P.RegisterCooldownText("shop", name, getLabelText)
    end
    if S.shopMode == "attackdefend" and folder.ClassLimitKey ~= nil and folder.ClassLimitKey ~= "" then
        P.RegisterClassLimitText("shop", name, getLabelText)
    end

    row.OnClicked = function()
        if folder.HasChildren and (folder.DirectCount or 0) == 0 then
            P.ToggleFolder(folder.Key)
            S.currentView = "categories"
        else
            S.selectedCategory = folder.Category
            S.selectedPath = folder.Path
            P.ClearPendingIfOutsideSelectedFolder()
            S.currentView = "products"
        end
        S.shopListScroll = 0
        P.ShowMenu()
        return true
    end
end


function P.BuildHeader(parent)
    P.CreatePanelTitle(parent, P.GetText("Shop"), "StoreTradingIcon", false)

    local balance = P.CreateText(parent, 1, 0.070, nil, P.GetText("Balance") .. "\n" .. tostring(S.currentPoints) .. " pt", GUI.Alignment.Left, 1.12, Color(235, 230, 185, 255))
    balance.AutoScaleVertical = true

    local tabs = P.CreateLayout(parent, 1, 0.030, nil, true, GUI.Anchor.CenterLeft)
    tabs.RelativeSpacing = 0

    local categoryTab = P.CreateButton(tabs, 0.50, 1, nil, P.GetText("Categories"), true, S.currentView == "categories", "GUITabButton")
    categoryTab.OnClicked = function()
        S.currentView = "categories"
        P.ShowMenu()
        return true
    end

    local buyTab = P.CreateButton(tabs, 0.50, 1, nil, P.GetText("BuyTab"), true, S.currentView == "products", "GUITabButton")
    buyTab.OnClicked = function()
        if S.selectedCategory == nil and S.products[1] ~= nil then
            S.selectedCategory = S.products[1].Category
            S.selectedPath = S.products[1].Path or ""
        end
        S.currentView = "products"
        S.shopListScroll = 0
        P.ShowMenu()
        return true
    end

    P.CreateDivider(parent, 0.018)
end
