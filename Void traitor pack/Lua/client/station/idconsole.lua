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
    local width = math.floor(Common.FitWindowWidth(screenWidth * 0.58, 1050, screenWidth * 0.04))
    local height = math.floor(Common.FitWindowHeight(screenHeight * 0.70, 620, screenHeight * 0.04))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu, UI.Popups = root, root, {}
    local layout = GUI.LayoutGroup(Common.CreateRect(0.95, 0.98, root, GUI.Anchor.Center), false)
    layout.RelativeSpacing = 0.008
    Common.CreateWindowHeader(layout, root, text.Title, text.Close, function()
        UI.CloseMenu()
        if Character.Controlled ~= nil then
            Character.Controlled.EmulateInput(inputTypes.Deselect)
            Character.Controlled.SelectedItem = nil
        end
        return true
    end)
    local cards = GUI.LayoutGroup(Common.CreateRect(1, 0.23, layout), true)
    cards.RelativeSpacing = 0.02
    local slots = {}
    local current, revision, confirming, pending, savedField = snapshot, nil, false, false, nil
    for index = 1, 2 do
        local frame = GUI.Frame(Common.CreateRect(0.49, 1, cards), "GUIFrameListBox")
        local content = GUI.LayoutGroup(Common.CreateRect(0.94, 0.92, frame, GUI.Anchor.Center), false)
        content.RelativeSpacing = 0.02
        GUI.TextBlock(Common.CreateRect(1, 0.19, content), index == 1 and text.Auth or text.Target)
        local details = GUI.TextBlock(Common.CreateRect(1, 0.31, content), "")
        details.Wrap = true
        details.AutoScaleVertical = true
        local row = GUI.LayoutGroup(Common.CreateRect(1, 0.40, content), true)
        row.RelativeSpacing = 0.02
        local picker = GUI.DropDown(Common.CreateRect(0.60, 1, row), text.Choose, 5)
        UI.Popups[#UI.Popups + 1] = picker
        local transfer = Common.CreateFlexibleButton(Common.CreateRect(0.38, 1, row), text.Insert)
        transfer.TextBlock.AutoScaleHorizontal = true
        transfer.OnClicked = function()
            local slot = current.Slots[index]
            if slot.Id ~= 0 then UI.Send("eject", { Slot = slot.Slot, Card = slot.Id })
            elseif picker.SelectedData ~= nil then UI.Send("insert", { Slot = slot.Slot, Card = tonumber(picker.SelectedData) }) end
            return true
        end
        slots[index] = { Details = details, Picker = picker, Transfer = transfer }
    end
    local identity = GUI.LayoutGroup(Common.CreateRect(1, 0.17, layout), false)
    identity.RelativeSpacing = 0.02
    local nameRow = GUI.LayoutGroup(Common.CreateRect(1, 0.48, identity), true)
    local nameLabel = GUI.TextBlock(Common.CreateRect(0.24, 1, nameRow), text.Name)
    Common.SetAutoScaleText(nameLabel, 1)
    local name = GUI.TextBox(Common.CreateRect(0.54, 1, nameRow), "")
    name.MaxTextLength = 64
    local saveName = Common.CreateFlexibleButton(Common.CreateRect(0.21, 1, nameRow), text.Save)
    local jobRow = GUI.LayoutGroup(Common.CreateRect(1, 0.48, identity), true)
    local jobLabel = GUI.TextBlock(Common.CreateRect(0.24, 1, jobRow), text.Job)
    Common.SetAutoScaleText(jobLabel, 1)
    local job = GUI.TextBox(Common.CreateRect(0.54, 1, jobRow), "")
    job.MaxTextLength = 64
    local saveJob = Common.CreateFlexibleButton(Common.CreateRect(0.21, 1, jobRow), text.Save)
    saveName.TextBlock.AutoScaleHorizontal = true
    saveJob.TextBlock.AutoScaleHorizontal = true
    local presetRow = GUI.LayoutGroup(Common.CreateRect(1, 0.075, layout), true)
    local presetLabel = GUI.TextBlock(Common.CreateRect(0.24, 1, presetRow), text.Preset)
    Common.SetAutoScaleText(presetLabel, 1)
    local preset = GUI.DropDown(Common.CreateRect(0.54, 1, presetRow), text.Preset, 6)
    UI.Popups[#UI.Popups + 1] = preset
    for _, entry in ipairs(snapshot.Presets) do preset.AddItem(entry.Name, entry.Id) end
    local rights = GUI.ListBox(Common.CreateRect(1, 0.295, layout), false)
    UI.Rights = rights
    local checks = {}
    for index = 1, #snapshot.Access, 4 do
        local row = GUI.LayoutGroup(Common.CreateRect(1, 0.16, rights.Content), true)
        row.RectTransform.MinSize = Point(0, Common.SafeIntScale(38))
        row.RelativeSpacing = 0.02
        for offset = 0, 3 do
            local entry = snapshot.Access[index + offset]
            if entry ~= nil then
                local checkbox = GUI.TickBox(Common.CreateRect(0.235, 1, row), entry.Name)
                Common.SetAutoScaleText(checkbox.TextBlock, 1)
                checks[entry.Tag] = checkbox
            end
        end
    end
    rights:RecalculateChildren()
    rights:UpdateScrollBarSize()
    UI.ResizeTop, UI.ResizeBottom = {}, {}
    UI.ResizeSides = { left = {}, right = {}, minimumWidthPixels = 1050, minimumHeightPixels = 620 }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
    local actions = GUI.LayoutGroup(Common.CreateRect(1, 0.085, layout), true)
    actions.RelativeSpacing = 0.01
    local all = Common.CreateFlexibleButton(Common.CreateRect(0.2425, 1, actions), text.All)
    local clear = Common.CreateFlexibleButton(Common.CreateRect(0.2425, 1, actions), text.Clear)
    local reset = Common.CreateFlexibleButton(Common.CreateRect(0.2425, 1, actions), text.Reset)
    local apply = Common.CreateFlexibleButton(Common.CreateRect(0.2425, 1, actions), text.Apply)
    for _, button in ipairs({ all, clear, reset, apply }) do button.TextBlock.AutoScaleHorizontal = true end
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
    UI.MenuRoot:AddToGUIUpdateList(false, 98)
    for _, popup in ipairs(UI.Popups) do if popup.Visible and popup.Dropped then popup.ListBox:AddToGUIUpdateList(false, 99) end end
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
            650, UI.Rights, nil, nil, nil, UI.ResizeSides)
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
