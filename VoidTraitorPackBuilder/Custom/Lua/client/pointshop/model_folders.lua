local P = ...
local S = P.State

function P.SplitGuiPath(value, separatorPattern)
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

function P.SplitIconList(value)
    local result = {}
    value = tostring(value or "")
    if value == "" then return result end

    for part in string.gmatch(value, "[^\31]+") do
        table.insert(result, part)
    end

    return result
end

function P.GetFolderKey(category, path)
    return tostring(category or "") .. "\30" .. tostring(path or "")
end

function P.BuildFolderList()
    local folders = {}
    local lookup = {}
    local directCounts = {}
    local totalCounts = {}

    for _, product in ipairs(S.products) do
        local directKey = P.GetFolderKey(product.Category, product.Path or "")
        directCounts[directKey] = (directCounts[directKey] or 0) + 1

        local rootKey = P.GetFolderKey(product.Category, "")
        totalCounts[rootKey] = (totalCounts[rootKey] or 0) + 1

        local currentPath = ""
        for _, part in ipairs(P.SplitGuiPath(product.Path or "")) do
            if part ~= "" then
                if currentPath == "" then
                    currentPath = part
                else
                    currentPath = currentPath .. " > " .. part
                end
                local key = P.GetFolderKey(product.Category, currentPath)
                totalCounts[key] = (totalCounts[key] or 0) + 1
            end
        end
    end

    local function addFolder(category, path, label, depth, iconIdentifier, fallbackIconIdentifier, cooldownRemaining, cooldownEndTime, infoText, classLimitKey)
        local key = P.GetFolderKey(category, path)
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

    for _, product in ipairs(S.products) do
        addFolder(product.Category, "", product.Category, 0, product.CategoryIconIdentifier, product.IconIdentifier, P.GetCooldownRemaining(product), product.CooldownEndTime, "", "")

        local currentPath = ""
        local parentPath = ""
        local depth = 1
        local pathLabels = P.SplitGuiPath(product.Path or "")
        local pathIdentifiers = P.SplitGuiPath(product.PathIdentifiers or "")
        local currentPathIdentifier = ""
        local pathIcons = P.SplitIconList(product.PathIconIdentifiers or "")
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

                local parentFolder = lookup[P.GetFolderKey(product.Category, parentPath)]
                if parentFolder ~= nil then
                    parentFolder.HasChildren = true
                end

                local infoText = depth == #pathLabels and P.GetProductLimitText(product) or ""
                local classLimitKey = depth == #pathLabels and P.GetProductClassLimitKey(product) or ""
                addFolder(product.Category, currentPath, part, depth, pathIcons[depth], product.IconIdentifier, P.GetCooldownRemaining(product), product.CooldownEndTime, infoText, classLimitKey)
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
            if not P.IsFolderExpanded(P.GetFolderKey(folder.Category, "")) then
                visible = false
            end

            local parts = P.SplitGuiPath(folder.Path or "")
            for index = 1, #parts - 1 do
                if parentPath == "" then
                    parentPath = parts[index]
                else
                    parentPath = parentPath .. " > " .. parts[index]
                end

                if not P.IsFolderExpanded(P.GetFolderKey(folder.Category, parentPath)) then
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
