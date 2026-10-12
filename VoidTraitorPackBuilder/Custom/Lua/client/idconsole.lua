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
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    UI.CloseMenu()
    UI.ItemId = itemId
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(math.min(screenWidth * 0.92, math.max(800, Common.SafeIntScale(800))))
    local height = math.floor(math.min(screenHeight * 0.92, math.max(590, Common.SafeIntScale(590))))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu, UI.Popups = root, root, {}
    local layout = GUI.LayoutGroup(Common.CreateRect(0.95, 0.98, root, GUI.Anchor.Center), false)
    layout.RelativeSpacing = 0.008
    local heading = GUI.LayoutGroup(Common.CreateRect(1, 0.065, layout), true)
    local title = GUI.TextBlock(Common.CreateRect(0.87, 1, heading), text.Title)
    title.Font = GUI.Style.SubHeadingFont
    title.AutoScaleHorizontal = true
    local close = GUI.Button(Common.CreateRect(0.12, 1, heading), text.Close)
    close.TextBlock.AutoScaleHorizontal = true
    close.OnClicked = function()
        UI.CloseMenu()
        if Character.Controlled ~= nil then
            Character.Controlled.EmulateInput(inputTypes.Deselect)
            Character.Controlled.SelectedItem = nil
        end
        return true
    end
    local cards = GUI.LayoutGroup(Common.CreateRect(1, 0.21, layout), true)
    cards.RelativeSpacing = 0.02
    local slots = {}
    local current, revision, confirming, pending = snapshot, nil, false, false
    for index = 1, 2 do
        local frame = GUI.Frame(Common.CreateRect(0.49, 1, cards), "GUIFrameListBox")
        local content = GUI.LayoutGroup(Common.CreateRect(0.94, 0.92, frame, GUI.Anchor.Center), false)
        content.RelativeSpacing = 0.02
        GUI.TextBlock(Common.CreateRect(1, 0.16, content), index == 1 and text.Auth or text.Target)
        local details = GUI.TextBlock(Common.CreateRect(1, 0.42, content), "")
        details.Wrap = true
        details.AutoScaleVertical = true
        local row = GUI.LayoutGroup(Common.CreateRect(1, 0.32, content), true)
        row.RelativeSpacing = 0.02
        local picker = GUI.DropDown(Common.CreateRect(0.60, 1, row), text.Choose, 5)
        UI.Popups[#UI.Popups + 1] = picker
        local transfer = GUI.Button(Common.CreateRect(0.38, 1, row), text.Insert)
        transfer.TextBlock.AutoScaleHorizontal = true
        transfer.OnClicked = function()
            local slot = current.Slots[index]
            if slot.Id ~= 0 then UI.Send("eject", { Slot = slot.Slot, Card = slot.Id })
            elseif picker.SelectedData ~= nil then UI.Send("insert", { Slot = slot.Slot, Card = tonumber(picker.SelectedData) }) end
            return true
        end
        slots[index] = { Details = details, Picker = picker, Transfer = transfer }
    end
    local identity = GUI.LayoutGroup(Common.CreateRect(1, 0.14, layout), false)
    identity.RelativeSpacing = 0.05
    local nameRow = GUI.LayoutGroup(Common.CreateRect(1, 0.48, identity), true)
    GUI.TextBlock(Common.CreateRect(0.24, 1, nameRow), text.Name)
    local name = GUI.TextBox(Common.CreateRect(0.54, 1, nameRow), "")
    name.MaxTextLength = 64
    local saveName = GUI.Button(Common.CreateRect(0.21, 1, nameRow), text.Save)
    local jobRow = GUI.LayoutGroup(Common.CreateRect(1, 0.48, identity), true)
    GUI.TextBlock(Common.CreateRect(0.24, 1, jobRow), text.Job)
    local job = GUI.TextBox(Common.CreateRect(0.54, 1, jobRow), "")
    job.MaxTextLength = 64
    local saveJob = GUI.Button(Common.CreateRect(0.21, 1, jobRow), text.Save)
    saveName.TextBlock.AutoScaleHorizontal = true
    saveJob.TextBlock.AutoScaleHorizontal = true
    local presetRow = GUI.LayoutGroup(Common.CreateRect(1, 0.065, layout), true)
    GUI.TextBlock(Common.CreateRect(0.24, 1, presetRow), text.Preset)
    local preset = GUI.DropDown(Common.CreateRect(0.54, 1, presetRow), text.Preset, 6)
    UI.Popups[#UI.Popups + 1] = preset
    for _, entry in ipairs(snapshot.Presets) do preset.AddItem(entry.Name, entry.Id) end
    local rights = GUI.ListBox(Common.CreateRect(1, 0.335, layout), false)
    local checks = {}
    local columns = width < math.max(710, Common.SafeIntScale(710)) and 2 or 4
    for index = 1, #snapshot.Access, columns do
        local row = GUI.LayoutGroup(Common.CreateRect(1, 0.16, rights.Content), true)
        row.RectTransform.MinSize = Point(0, Common.SafeIntScale(30))
        row.RelativeSpacing = 0.02
        for offset = 0, columns - 1 do
            local entry = snapshot.Access[index + offset]
            if entry ~= nil then
                local checkbox = GUI.TickBox(Common.CreateRect((1 - 0.02 * (columns - 1)) / columns, 1, row), entry.Name)
                checkbox.TextBlock.AutoScaleHorizontal = true
                checks[entry.Tag] = checkbox
            end
        end
    end
    rights:RecalculateChildren()
    rights:UpdateScrollBarSize()
    local actions = GUI.LayoutGroup(Common.CreateRect(1, 0.07, layout), true)
    actions.RelativeSpacing = 0.01
    local all = GUI.Button(Common.CreateRect(0.2425, 1, actions), text.All)
    local clear = GUI.Button(Common.CreateRect(0.2425, 1, actions), text.Clear)
    local reset = GUI.Button(Common.CreateRect(0.2425, 1, actions), text.Reset)
    local apply = GUI.Button(Common.CreateRect(0.2425, 1, actions), text.Apply)
    for _, button in ipairs({ all, clear, reset, apply }) do button.TextBlock.AutoScaleHorizontal = true end
    local status = GUI.TextBlock(Common.CreateRect(1, 0.06, layout), "")
    status.Wrap = true
    status.AutoScaleHorizontal = true
    status.AutoScaleVertical = true
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
        if revision ~= updated.Revision then revision = updated.Revision resetDraft() end
        for _, control in ipairs({ name, job, saveName, saveJob, all, clear, reset, apply, preset }) do control.Enabled = updated.CanEdit end
        preset.ButtonEnabled = updated.CanEdit
        status.Text = updated.CanEdit and text.Ready or text.Missing
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
    if not Networking.IsActive then UI.CloseMenu() UI.SelectedItem = nil return end
    local character = Character.Controlled
    local item = character ~= nil and not character.IsDead and not character.IsIncapacitated and character.SelectedItem or nil
    if item == nil or item.Prefab.Identifier ~= "vt_station_access" then
        if UI.SelectedItem ~= nil then UI.CloseMenu() end
        UI.SelectedItem = nil
        return
    end
    if UI.SelectedItem ~= item then
        UI.SelectedItem = item
        UI.AwaitingOpen, elapsed = true, 0.05
    end
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
