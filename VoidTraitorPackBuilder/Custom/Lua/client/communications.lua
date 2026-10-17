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
    local layout = GUI.LayoutGroup(Common.CreateRect(0.94, 0.94, root, GUI.Anchor.Center), false)
    layout.RelativeSpacing = 0.012
    local heading = GUI.LayoutGroup(Common.CreateRect(1, 0.10, layout), true)
    local drag = GUI.DragHandle(Common.CreateRect(0.76, 1, heading), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    drag.Color, drag.HoverColor, drag.SelectedColor, drag.PressedColor = transparent, transparent, transparent, transparent
    Common.CreateText(drag, 1, 1, GUI.Anchor.Center, text.Title, GUI.Alignment.CenterLeft, 0.9)
    local close = GUI.Button(Common.CreateRect(0.24, 1, heading), text.Close, GUI.Alignment.Center, "GUIButtonSmall")
    close.OnClicked = function() UI.CloseMenu() return true end
    local input = GUI.TextBox(Common.CreateRect(1, 0.36, layout), "", nil, nil, GUI.Alignment.TopLeft, true, "", nil, false, false)
    -- The vanilla textbox style fixes its height to one line, including the inner frame.
    input.RectTransform.MinSize, input.RectTransform.MaxSize = Point(0, 0), Point(100000, 100000)
    input.Frame.RectTransform.MinSize, input.Frame.RectTransform.MaxSize = Point(0, 0), Point(100000, 100000)
    input.MaxTextLength = snapshot.MaxLength
    local announce = GUI.Button(Common.CreateRect(1, 0.09, layout), text.Announce, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    announce.OnClicked = function() input.Deselect() UI.Send("announce", input.Text) return true end
    local voice = GUI.Button(Common.CreateRect(1, 0.09, layout), text.Voice, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    voice.OnClicked = function() input.Deselect() UI.Send("voice") return true end
    local picker = GUI.DropDown(Common.CreateRect(1, 0.09, layout), "", 5)
    UI.Picker = picker
    for _, code in ipairs(codes) do picker.AddItem(text[code], code) end
    picker.OnSelected = function(_, code) UI.Send("code", code) return true end
    local evacuationStatus = Common.CreateText(layout, 1, 0.10, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 0.9)
    local evacuation = GUI.Button(Common.CreateRect(1, 0.09, layout), "", GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    evacuation.OnClicked = function()
        input.Deselect()
        UI.Send("evacuation")
        return true
    end
    UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides = {}, {}, { left = {}, right = {}, minimumWidth = 380 }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
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
    UI.MenuRoot:AddToGUIUpdateList(false, 98)
    if UI.Picker.Dropped then UI.Picker.ListBox:AddToGUIUpdateList(false, 99) end
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
    if UI.Disabled then return end
    local character = Character.Controlled
    local item = character ~= nil and not character.IsDead and not character.IsIncapacitated and character.SelectedItem or nil
    if not Networking.IsActive or item == nil or item.Removed or item.Prefab.Identifier ~= "vt_communications_console" or not character.CanInteractWith(item) then
        if UI.SelectedItem ~= nil then UI.CloseMenu() end
        return
    end
    if UI.SelectedItem ~= item then
        UI.SelectedItem = item
        local message = Networking.Start("VoidTraitor_CommunicationsOpen")
        message.WriteUInt16(UShort(item.ID))
        Networking.Send(message)
    end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom, 380, nil, nil, nil, nil, UI.ResizeSides)
    end
end)
