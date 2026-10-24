if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorCommunicationsGuiState")
if previous ~= nil then previous.Disabled = true Common.RemoveGuiComponent(previous.MenuRoot) end
local UI = {}
_G.VoidTraitorCommunicationsGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
local codes = { "green", "blue", "violet", "yellow", "red" }

function UI.Send(action, value)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_CommunicationsAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
    message.WriteString(value or "")
    Networking.Send(message)
end

function UI.CloseMenu()
    UI.Send("close")
    local character = Character.Controlled
    if character ~= nil and character.SelectedItem ~= nil and character.SelectedItem.ID == UI.ItemId then
        character.EmulateInput(inputTypes.Deselect)
        character.SelectedItem = nil
    end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update, UI.Picker = nil, nil, nil, nil, nil
    UI.ResizeState, UI.SelectedItem = nil, nil
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.ItemId = itemId
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width, height = math.min(Common.SafeIntScale(460), screenWidth * 0.9), math.min(Common.SafeIntScale(460), screenHeight * 0.9)
    local root = GUI.Frame(GUI.RectTransform(Point(math.floor(width), math.floor(height)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout, frame = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, text.Title, text.Close, function()
        UI.CloseMenu()
        return true
    end)
    -- The message is the only row that grows with the window, like the SS14 console.
    local input = GUI.TextBox(Common.CreateRect(1, 1, layout), "", nil, nil, GUI.Alignment.TopLeft, true, "", nil, false, false)
    -- The vanilla textbox style fixes its height to one line, including the inner frame.
    input.RectTransform.MinSize, input.RectTransform.MaxSize = Point(0, 0), Point(100000, 100000)
    Common.SetMinimumHeight(input, Common.GetTextHeight(GUI.Style.Font) * 3)
    input.Frame.RectTransform.MinSize, input.Frame.RectTransform.MaxSize = Point(0, 0), Point(100000, 100000)
    input.MaxTextLength = snapshot.MaxLength
    local announce = Common.CreateButton(layout, 1, text.Announce)
    announce.OnClicked = function() input.Deselect() UI.Send("announce", input.Text) return true end
    local voice = Common.CreateButton(layout, 1, text.Voice)
    voice.OnClicked = function() input.Deselect() UI.Send("voice") return true end
    Common.CreateDivider(layout)
    local picker = GUI.DropDown(Common.CreateRect(1, 1, layout), "", 5)
    Common.SetFixedHeight(picker, Common.GetStyleHeight("GUIDropDown"))
    UI.Picker = picker
    for _, code in ipairs(codes) do picker.AddItem(text[code], code) end
    picker.OnSelected = function(_, code) UI.Send("code", code) return true end
    Common.CreateDivider(layout)
    local evacuationStatus = Common.CreateText(layout, 1, 1, nil, "", GUI.Alignment.Left, 1, nil, false)
    Common.SetAutoScaleText(evacuationStatus, 1)
    Common.FitHeightToText(evacuationStatus)
    local evacuation = Common.CreateButton(layout, 1, "")
    evacuation.OnClicked = function()
        input.Deselect()
        UI.Send("evacuation")
        return true
    end
    UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides = {}, {}, { left = {}, right = {}, minimumWidth = Common.SafeIntScale(280) }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
    UI.MinimumHeight = Common.GetMinimumHeight(frame)
    if root.Rect.Height < UI.MinimumHeight then
        root.RectTransform:Resize(Point(root.Rect.Width, math.min(UI.MinimumHeight, screenHeight)), true)
    end
    UI.Update = function(state)
        announce.Enabled = state.Powered and state.AnnouncementCooldown == 0
        announce.Text = text.Announce .. (state.AnnouncementCooldown > 0 and " (" .. state.AnnouncementCooldown .. ")" or "")
        if state.Voice then voice.Text = state.Mine and string.format(text.Stop, state.Remaining) or text.Busy
        elseif state.VoiceCooldown > 0 then voice.Text = string.format(text.Cooldown, state.VoiceCooldown)
        else voice.Text = text.Voice end
        voice.Enabled = state.Powered and (state.Mine or not state.Voice and state.VoiceCooldown == 0)
        voice.Selected = state.Voice and state.Mine
        picker.Button.Text = string.format(text.Code, text[state.Alert])
        local selectable = false
        for _, code in ipairs(codes) do if state.Alert == code then selectable = true end end
        picker.Enabled, picker.ButtonEnabled = state.Powered and selectable, state.Powered and selectable
        if not picker.Enabled then picker.Dropped = false end
        evacuationStatus.Text = state.Evacuation.Status
        evacuation.Text = state.Evacuation.Action
        evacuation.Enabled = state.Powered and state.Evacuation.Enabled
        input.Enabled = state.Powered
    end
    UI.Update(snapshot)
end

Networking.Receive("VoidTraitor_CommunicationsSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.SelectedItem ~= nil and UI.SelectedItem.ID == itemId
        and character.SelectedItem == UI.SelectedItem then UI.Show(itemId, snapshot) end
end)
Hook.Patch("VoidTraitor.Communications.Hud", "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if UI.Disabled or UI.MenuRoot == nil or GUI.DisableHUD then return end
    UI.MenuRoot:AddToGUIUpdateList(false, 120)
    if UI.Picker.Dropped then UI.Picker.ListBox:AddToGUIUpdateList(false, 121) end
end)
Common.InstallPausePatch("VoidTraitor.Communications.Pause", "VoidTraitorCommunicationsGuiState")
Hook.Patch("VoidTraitor.Communications.NativeHud", "Barotrauma.Item", "AddToGUIUpdateList", { "System.Int32" }, function(item, parameters)
    if not UI.Disabled and Game.RoundStarted and item.Prefab.Identifier == "vt_communications_console" then parameters.PreventExecution = true end
end, Hook.HookMethodType.Before)
Hook.Patch("VoidTraitor.Communications.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.Communications.End", function() UI.CloseMenu() end)
Hook.Add("think", "VoidTraitor.Communications.Selection", function()
    local item = Common.UpdateSelectedItemMenu(UI, "vt_communications_console", function(selected)
        local message = Networking.Start("VoidTraitor_CommunicationsOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
    if item == nil then return end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom, UI.MinimumHeight, nil, nil, nil, nil, UI.ResizeSides)
    end
end)
