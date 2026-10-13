if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorNuclearGuiState")
if previous ~= nil then previous.Disabled = true Common.RemoveGuiComponent(previous.MenuRoot) end
local UI = {}
_G.VoidTraitorNuclearGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")

function UI.Send(action, value)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_NuclearAction")
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
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update, UI.Snapshot = nil, nil, nil, nil, nil
    UI.ResizeState = nil
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    UI.CloseMenu()
    UI.ItemId = itemId
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width, height = math.min(Common.SafeIntScale(460), screenWidth * 0.9), math.min(Common.SafeIntScale(370), screenHeight * 0.9)
    local root = GUI.Frame(GUI.RectTransform(Point(math.floor(width), math.floor(height)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout = GUI.LayoutGroup(Common.CreateRect(0.94, 0.94, root, GUI.Anchor.Center), false)
    layout.RelativeSpacing = 0.012
    local heading = GUI.LayoutGroup(Common.CreateRect(1, 0.12, layout), true)
    local drag = GUI.DragHandle(Common.CreateRect(0.75, 1, heading), root.RectTransform, nil)
    local transparent = Color(0, 0, 0, 0)
    drag.Color, drag.HoverColor, drag.SelectedColor, drag.PressedColor = transparent, transparent, transparent, transparent
    Common.CreateText(drag, 1, 1, GUI.Anchor.Center, text.Title, GUI.Alignment.CenterLeft, 0.9)
    local close = GUI.Button(Common.CreateRect(0.25, 1, heading), text.Close, GUI.Alignment.Center, "GUIButtonSmall")
    close.OnClicked = function() UI.CloseMenu() return true end
    local firstPanel = GUI.Frame(Common.CreateRect(1, 0.12, layout), "GUIFrameListBox")
    local first = Common.CreateText(firstPanel, 0.94, 1, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 1, Color(120, 230, 120, 255))
    local secondPanel = GUI.Frame(Common.CreateRect(1, 0.12, layout), "GUIFrameListBox")
    local second = Common.CreateText(secondPanel, 0.94, 1, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 1, Color(120, 230, 120, 255))
    local body = GUI.LayoutGroup(Common.CreateRect(1, 0.59, layout), true)
    body.RelativeSpacing = 0.02
    local keypad = GUI.LayoutGroup(Common.CreateRect(0.49, 1, body), false)
    keypad.RelativeSpacing = 0.025
    local digits = {}
    for _, values in ipairs({ { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { "C", "0", "E" } }) do
        local row = GUI.LayoutGroup(Common.CreateRect(1, 0.23, keypad), true)
        row.RelativeSpacing = 0.025
        for _, value in ipairs(values) do
            local button = GUI.Button(Common.CreateRect(0.316, 1, row), value, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
            button.OnClicked = function()
                UI.Send(value == "C" and "clear" or value == "E" and "enter" or "digit", value)
                return true
            end
            digits[#digits + 1] = button
        end
    end
    local actions = GUI.LayoutGroup(Common.CreateRect(0.49, 1, body), false)
    actions.RelativeSpacing = 0.025
    local eject = GUI.Button(Common.CreateRect(1, 0.23, actions), text.Eject, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    eject.OnClicked = function() UI.Send(UI.Snapshot.Disk and "eject" or "insert") return true end
    local anchor = GUI.Button(Common.CreateRect(1, 0.23, actions), text.Anchor, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    anchor.OnClicked = function() UI.Send("anchor") return true end
    local arm = GUI.Button(Common.CreateRect(1, 0.23, actions), text.Arm, GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    arm.Color = Color(150, 45, 45, 255)
    arm.OnClicked = function() UI.Send("arm") return true end
    UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides = {}, {}, { left = {}, right = {}, minimumWidth = 420 }
    Common.AddResizeHandles(root, UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides)
    UI.Update = function(state)
        UI.Snapshot = state
        first.Text = text[({ locked = "Locked", code = "AwaitCode", ready = "Ready", armed = "Armed", cooldown = "Cooldown", exploded = "Exploded" })[state.Status]]
        second.Text = string.format(text.Time, state.Remaining)
        if state.Status == "locked" then second.Text = text.AwaitDisk
        elseif state.Status == "code" then second.Text = string.rep("*", state.Entered) .. string.rep("_", 6 - state.Entered)
        elseif state.Status == "cooldown" then second.Text = string.format(text.Cooling, state.Cooldown) end
        for _, button in ipairs(digits) do button.Enabled = state.Status == "code" end
        eject.Text = state.Disk and text.Eject or text.Insert
        eject.Enabled = state.Status ~= "armed" and state.Status ~= "exploded" and state.Anchored
        anchor.Text = state.Anchored and text.Detach or text.Anchor
        anchor.Enabled, anchor.Selected = state.Status ~= "armed" and state.Status ~= "exploded", state.Anchored
        arm.Text = text.Arm
        arm.Enabled = state.Disk and state.Anchored and state.Status == "ready"
    end
    UI.Update(snapshot)
end

Networking.Receive("VoidTraitor_NuclearSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and character.SelectedItem ~= nil and character.SelectedItem.ID == itemId and UI.SelectedItem == character.SelectedItem then
        UI.Show(itemId, snapshot)
    end
end)
Hook.Patch("VoidTraitor.Nuclear.Use", "Barotrauma.Items.Components.Holdable", "Use", function(instance, parameters)
    if instance.Item.Prefab.Identifier ~= "vt_nuclear_bomb" then return end
    parameters.PreventExecution = true
    return false
end, Hook.HookMethodType.Before)
Common.InstallHudPatch("VoidTraitor.Nuclear.Hud", "VoidTraitorNuclearGuiState", 98)
Common.InstallPausePatch("VoidTraitor.Nuclear.Pause", "VoidTraitorNuclearGuiState")
Hook.Patch("VoidTraitor.Nuclear.NativeHud", "Barotrauma.Item", "AddToGUIUpdateList", { "System.Int32" }, function(item, parameters)
    if not UI.Disabled and Game.RoundStarted and item.Prefab.Identifier == "vt_nuclear_bomb" then parameters.PreventExecution = true end
end, Hook.HookMethodType.Before)
Hook.Patch("VoidTraitor.Nuclear.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.Nuclear.End", function() UI.CloseMenu() UI.SelectedItem = nil end)
Hook.Add("think", "VoidTraitor.Nuclear.Selection", function()
    if UI.Disabled then return end
    local character = Character.Controlled
    local item = character ~= nil and not character.IsDead and not character.IsIncapacitated and character.SelectedItem or nil
    if not Networking.IsActive or item == nil or item.Removed or item.Prefab.Identifier ~= "vt_nuclear_bomb" or not character.CanInteractWith(item) then
        if UI.SelectedItem ~= nil then UI.CloseMenu() end
        UI.SelectedItem = nil
        return
    end
    if UI.SelectedItem ~= item then
        UI.SelectedItem = item
        local message = Networking.Start("VoidTraitor_NuclearOpen")
        message.WriteUInt16(UShort(item.ID))
        Networking.Send(message)
    end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom, 340, nil, nil, nil, nil, UI.ResizeSides)
    end
end)
