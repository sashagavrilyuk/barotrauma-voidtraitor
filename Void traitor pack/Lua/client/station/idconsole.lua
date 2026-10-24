if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorIdConsoleGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
end
local UI = {}
_G.VoidTraitorIdConsoleGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")

function UI.Send(action, payload)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_IdConsoleAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
    message.WriteString(json.serialize(payload or {}))
    Networking.Send(message)
end

function UI.CloseMenu()
    UI.Send("close")
    UI.AwaitingOpen = false
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update = nil, nil, nil, nil
    UI.Popups = {}
    UI.ResizeState, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides, UI.Rights = nil, nil, nil, nil, nil
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    UI.CloseMenu()
    UI.ItemId = itemId
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(Common.FitWindowWidth(screenWidth * 0.58, 760, screenWidth * 0.04))
    local height = math.floor(Common.FitWindowHeight(screenHeight * 0.70, 460, screenHeight * 0.04))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu, UI.Popups = root, root, {}
    local layout, frame = Common.CreateWindowContent(root)
    local gap, buttonHeight = Common.GetGap(), Common.GetStyleHeight("GUIButton")
    -- Rows with the vanilla button height: labels stay centred on their text boxes.
    local function createRow(parent)
        local row = GUI.LayoutGroup(Common.CreateRect(1, 1, parent), true, GUI.Anchor.CenterLeft)
        Common.SetFixedHeight(row, buttonHeight)
        row.Stretch = true
        row.AbsoluteSpacing = gap
        return row
    end
    local function createSpacer(parent, width)
        local spacer = GUI.Frame(Common.CreateRect(width, 1, parent), nil)
        spacer.Color = Color(0, 0, 0, 0)
        spacer.CanBeFocused = false
    end
    Common.CreateWindowHeader(layout, root, text.Title, text.Close, function()
        UI.CloseMenu()
        if Character.Controlled ~= nil then
            Character.Controlled.EmulateInput(inputTypes.Deselect)
            Character.Controlled.SelectedItem = nil
        end
        return true
    end)
    local cards = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
    cards.Stretch = true
    cards.AbsoluteSpacing = gap
    local cardHeight = 0
    local slots = {}
    local current, revision, confirming, pending, savedField = snapshot, nil, false, false, nil
    for index = 1, 2 do
        local card = GUI.Frame(Common.CreateRect(0.5, 1, cards), "GUIFrameListBox")
        local content, cardLayout = Common.CreateWindowContent(card)
        Common.FitHeightToText(GUI.TextBlock(Common.CreateRect(1, 1, content), index == 1 and text.Auth or text.Target))
        local details = GUI.TextBlock(Common.CreateRect(1, 1, content), "")
        details.Wrap = true
        details.AutoScaleVertical = true
        Common.SetFixedHeight(details, Common.GetTextHeight(details.Font) * 2)
        local row = createRow(content)
        local picker = GUI.DropDown(Common.CreateRect(0.60, 1, row), text.Choose, 5)
        Common.SetFixedHeight(picker, Common.GetStyleHeight("GUIDropDown"))
        UI.Popups[#UI.Popups + 1] = picker
        local transfer = Common.CreateButton(row, 0.38, text.Insert)
        cardHeight = math.max(cardHeight, Common.GetMinimumHeight(cardLayout))
        transfer.OnClicked = function()
            local slot = current.Slots[index]
            if slot.Id ~= 0 then UI.Send("eject", { Slot = slot.Slot, Card = slot.Id })
            elseif picker.SelectedData ~= nil then UI.Send("insert", { Slot = slot.Slot, Card = tonumber(picker.SelectedData) }) end
            return true
        end
        slots[index] = { Details = details, Picker = picker, Transfer = transfer }
    end
    Common.SetFixedHeight(cards, cardHeight)
    local function createLabel(row, value)
        Common.SetAutoScaleText(GUI.TextBlock(Common.CreateRect(0.24, 1, row), value), 1)
    end
    local nameRow = createRow(layout)
    createLabel(nameRow, text.Name)
    local name = GUI.TextBox(Common.CreateRect(0.54, 1, nameRow), "")
    name.MaxTextLength = 64
    local saveName = Common.CreateButton(nameRow, 0.21, text.Save)
    local jobRow = createRow(layout)
    createLabel(jobRow, text.Job)
    local job = GUI.TextBox(Common.CreateRect(0.54, 1, jobRow), "")
    job.MaxTextLength = 64
    local saveJob = Common.CreateButton(jobRow, 0.21, text.Save)
    local presetRow = createRow(layout)
    createLabel(presetRow, text.Preset)
    local preset = GUI.DropDown(Common.CreateRect(0.54, 1, presetRow), text.Preset, 6)
    Common.SetFixedHeight(preset, Common.GetStyleHeight("GUIDropDown"))
    createSpacer(presetRow, 0.21)
    UI.Popups[#UI.Popups + 1] = preset
    for _, entry in ipairs(snapshot.Presets) do preset.AddItem(entry.Name, entry.Id) end
    -- The access list is the only row that grows. Columns are as wide as the longest label needs,
    -- so labels keep full size, and as many fit as the window width allows.
    local rights = GUI.ListBox(Common.CreateRect(1, 1, layout), false)
    rights.Spacing = gap
    UI.Rights = rights
    local checks, cells, rows, columns = {}, {}, {}, 0
    local tickHeight, widestLabel = Common.GetStyleHeight("GUITickBox"), 0
    for _, entry in ipairs(snapshot.Access) do
        local checkbox = GUI.TickBox(Common.CreateRect(1, 1, rights.Content), entry.Name)
        local label = checkbox.TextBlock
        Common.SetAutoScaleText(label, 1)
        widestLabel = math.max(widestLabel, label.TextSize.X + label.Padding.X + label.Padding.Z)
        checks[entry.Tag] = checkbox
        cells[#cells + 1] = checkbox
    end
    local columnWidth = tickHeight + widestLabel
    local listExtras = rights.ScrollBar.Rect.Width + rights.Padding.X + rights.Padding.Z
    local function GetColumns(listWidth)
        return math.max(1, math.floor((listWidth - listExtras + gap) / (columnWidth + gap)))
    end
    -- Moves the same tickboxes into new rows, so their state is kept.
    local function ArrangeRights(count)
        if count == columns then return end
        columns = count
        local previous = rows
        rows = {}
        for index = 1, #cells, columns do
            local row = GUI.LayoutGroup(Common.CreateRect(1, 1, rights.Content), true, GUI.Anchor.CenterLeft)
            Common.SetFixedHeight(row, tickHeight)
            row.Stretch = true
            row.AbsoluteSpacing = gap
            -- Equal starting widths: the stretch pass then gives every column the same width.
            for offset = 0, columns - 1 do
                local cell = cells[index + offset]
                if cell ~= nil then
                    cell.RectTransform.Parent = row.RectTransform
                    cell.RectTransform.RelativeSize = Vector2(1 / columns, 1)
                else
                    createSpacer(row, 1 / columns)
                end
            end
            rows[#rows + 1] = row
        end
        for _, row in ipairs(previous) do Common.RemoveGuiComponent(row) end
        -- Labels shrunk while their columns were too narrow get their full size back.
        Common.RestoreAutoScaledText(rights)
        rights:RecalculateChildren()
        rights:UpdateScrollBarSize()
    end
    UI.UpdateRights = function() ArrangeRights(GetColumns(rights.Rect.Width)) end
    local minimumWidth = math.max(Common.SafeIntScale(650), columnWidth + listExtras + Common.GetWindowPadding() * 2)
    width = math.min(math.max(width, minimumWidth), screenWidth)
    ArrangeRights(GetColumns(width - Common.GetWindowPadding() * 2))
    local rowCount = #rows
    local listPadding = rights.Padding.Y + rights.Padding.W
    local minimumRows = math.min(rowCount, 2)
    Common.SetMinimumHeight(rights, minimumRows * tickHeight + (minimumRows - 1) * gap + listPadding)
    UI.ResizeTop, UI.ResizeBottom = {}, {}
    UI.ResizeSides = { left = {}, right = {}, minimumWidth = minimumWidth }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
    local actions = createRow(layout)
    local all = Common.CreateButton(actions, 0.25, text.All)
    local clear = Common.CreateButton(actions, 0.25, text.Clear)
    local reset = Common.CreateButton(actions, 0.25, text.Reset)
    local apply = Common.CreateButton(actions, 0.25, text.Apply)
    -- Opens with every access row visible, like an SS14 window sized to its content.
    UI.MinimumHeight = Common.GetMinimumHeight(frame)
    local contentHeight = UI.MinimumHeight + math.max(0, rowCount - 2) * (tickHeight + gap)
    root.RectTransform:Resize(Point(width, math.min(contentHeight, screenHeight)), true)
    local selectedJob
    local function tags()
        local result = {}
        for _, entry in ipairs(current.Access) do if checks[entry.Tag].Selected then result[#result + 1] = entry.Tag end end
        return result
    end
    local function write(payload)
        if pending then return true end
        payload.Tags, payload.Revision = tags(), revision
        pending = true
        savedField = payload.Name ~= nil and "name" or payload.Title ~= nil and "job" or nil
        UI.Send("apply", payload)
        return true
    end
    saveName.OnClicked = function() return write({ Name = tostring(name.Text) }) end
    saveJob.OnClicked = function() return write({ Title = tostring(job.Text) }) end
    apply.OnClicked = function() return write({ Job = selectedJob, Title = selectedJob ~= nil and tostring(job.Text) or nil }) end
    preset.OnSelected = function(_, id)
        for _, entry in ipairs(current.Presets) do
            if entry.Id == id then
                local desired = {}
                for _, tag in ipairs(entry.Tags) do desired[tag] = true end
                for _, access in ipairs(current.Access) do if access.Allowed then checks[access.Tag].SetSelected(desired[access.Tag] == true, false) end end
                selectedJob, job.Text = id, entry.Name
                break
            end
        end
        return true
    end
    all.OnClicked = function()
        for _, entry in ipairs(current.Access) do if entry.Allowed then checks[entry.Tag].SetSelected(true, false) end end
        return true
    end
    clear.OnClicked = function()
        if pending then return true end
        if confirming then
            for _, entry in ipairs(current.Access) do if entry.Allowed then checks[entry.Tag].SetSelected(false, false) end end
            confirming, clear.Text = false, text.Clear
        else confirming, clear.Text = true, text.Confirm end
        return true
    end
    local function resetDraft()
        for _, entry in ipairs(current.Access) do
            checks[entry.Tag].SetSelected(entry.Granted, false)
            checks[entry.Tag].Enabled = current.CanEdit and entry.Allowed
            checks[entry.Tag].ToolTip = entry.Allowed and text.Ready or text.Forbidden
        end
        name.Text, job.Text, selectedJob, confirming = current.Slots[2].Name, current.Slots[2].Title, nil, false
        clear.Text = text.Clear
        preset.Dropped = false
    end
    reset.OnClicked = function() resetDraft() return true end
    local heldSignature
    UI.Update = function(updated)
        local previousId, previousName, previousJob = current.Slots[2].Id, tostring(name.Text), tostring(job.Text)
        current, pending = updated, false
        local ids = {}
        for _, card in ipairs(updated.HeldCards) do ids[#ids + 1] = tostring(card.Id) .. ":" .. card.Name end
        local signature = table.concat(ids, ";")
        for index, slot in ipairs(updated.Slots) do
            local controls = slots[index]
            controls.Details.Text = slot.Name .. "\n" .. slot.Title
            controls.Details.ToolTip = slot.Access ~= "" and slot.Access or text.NoRights
            controls.Picker.Visible = slot.Id == 0
            controls.Picker.Button.Visible = controls.Picker.Visible
            if slot.Id ~= 0 then controls.Picker.Dropped = false end
            if signature ~= heldSignature then
                local selected = controls.Picker.SelectedData
                controls.Picker.ClearChildren()
                for _, card in ipairs(updated.HeldCards) do controls.Picker.AddItem(card.Name, card.Id) end
                local found = false
                for _, card in ipairs(updated.HeldCards) do if card.Id == selected then found = true end end
                if #updated.HeldCards > 0 then controls.Picker.SelectItem(found and selected or updated.HeldCards[1].Id) end
            end
            controls.Picker.Enabled = slot.Id == 0 and #updated.HeldCards > 0
            controls.Picker.ButtonEnabled = controls.Picker.Enabled
            controls.Transfer.Text = slot.Id == 0 and text.Insert or text.Eject
            controls.Transfer.Enabled = slot.Id ~= 0 or #updated.HeldCards > 0
        end
        heldSignature = signature
        if revision ~= updated.Revision then
            local hadRevision = revision ~= nil
            revision = updated.Revision
            resetDraft()
            if hadRevision and previousId ~= 0 and previousId == updated.Slots[2].Id then
                if savedField ~= "name" then name.Text = previousName end
                if savedField ~= "job" then job.Text = previousJob end
            end
        end
        savedField = nil
        for _, control in ipairs({ name, job, saveName, saveJob, all, clear, reset, apply, preset }) do control.Enabled = updated.CanEdit end
        preset.ButtonEnabled = updated.CanEdit
    end
    UI.Update(snapshot)
end

Networking.Receive("VoidTraitor_IdConsoleSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and character.SelectedItem ~= nil and character.SelectedItem.ID == itemId
        and (UI.AwaitingOpen or UI.ItemId == itemId) then UI.Show(itemId, snapshot) end
end)

-- The stock drop-down adds its popup at order 1. Our modal is higher; add popups after it.
Hook.Patch("VoidTraitor.IdConsole.Hud", "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if UI.Disabled or UI.MenuRoot == nil or GUI.DisableHUD then return end
    UI.MenuRoot:AddToGUIUpdateList(false, 120)
    for _, popup in ipairs(UI.Popups) do if popup.Visible and popup.Dropped then popup.ListBox:AddToGUIUpdateList(false, 121) end end
end)
Common.InstallPausePatch("VoidTraitor.IdConsole.Pause", "VoidTraitorIdConsoleGuiState")
Hook.Patch("VoidTraitor.IdConsole.NativeHud", "Barotrauma.Item", "AddToGUIUpdateList", { "System.Int32" }, function(item, parameters)
    if not UI.Disabled and Game.RoundStarted and item.Prefab.Identifier == "vt_station_access" then parameters.PreventExecution = true end
end, Hook.HookMethodType.Before)
Hook.Patch("VoidTraitor.IdConsole.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.IdConsole.End", function() UI.CloseMenu() UI.SelectedItem = nil end)
local elapsed = 0
Hook.Add("think", "VoidTraitor.IdConsole.Selection", function(deltaTime)
    if UI.Disabled then return end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom,
            UI.MinimumHeight, UI.Rights, nil, nil, nil, UI.ResizeSides)
        UI.UpdateRights()
    end
    local item = Common.UpdateSelectedItemMenu(UI, "vt_station_access", function()
        UI.AwaitingOpen, elapsed = true, 0.05
    end)
    if item == nil then return end
    elapsed = elapsed + deltaTime
    if UI.AwaitingOpen and elapsed >= 0.05 then
        elapsed = 0
        local message = Networking.Start("VoidTraitor_IdConsoleOpen")
        message.WriteUInt16(UShort(item.ID))
        Networking.Send(message)
    elseif UI.MenuRoot ~= nil and elapsed >= 1 then
        elapsed = 0
        UI.Send("view", { View = "main" })
    end
end)
