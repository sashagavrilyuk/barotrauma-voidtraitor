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
    local layout = GUI.LayoutGroup(Common.CreateRect(0.94, 0.92, root, GUI.Anchor.Center), false)
    layout.RelativeSpacing = 0.012
    Common.CreateWindowHeader(layout, root, text.Title, text.Close, function()
        UI.CloseMenu()
        return true
    end, { titleScale = 0.9 })
    local firstPanel = GUI.Frame(Common.CreateRect(1, 0.10, layout), "GUIFrameListBox")
    local first = Common.CreateText(firstPanel, 0.94, 1, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 1, Color(120, 230, 120, 255))
    local secondPanel = GUI.Frame(Common.CreateRect(1, 0.10, layout), "GUIFrameListBox")
    local second = Common.CreateText(secondPanel, 0.94, 1, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 1, Color(120, 230, 120, 255))
    local body = GUI.LayoutGroup(Common.CreateRect(1, 0.55, layout), true)
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
    UI.ResizeTop, UI.ResizeBottom, UI.ResizeSides = {}, {}, { left = {}, right = {}, minimumWidthPixels = 280, minimumHeightPixels = 225 }
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
    local item = Common.UpdateSelectedItemMenu(UI, "vt_nuclear_bomb", function(selected)
        local message = Networking.Start("VoidTraitor_NuclearOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
    if item == nil then return end
    if UI.MenuRoot ~= nil then
        UI.ResizeState = Common.UpdateMenuInteraction(UI.MenuRoot, UI.ResizeState, UI.ResizeTop, UI.ResizeBottom, 225, nil, nil, nil, nil, UI.ResizeSides)
    end
end)

-- TEMPORARY AUDIO DIAGNOSTICS: automatically logs network state and actual sound-channel ownership.
-- These logs require client LuaCs; ordinary clients can still join without it.
local audioDebugNames = { "running_out", "countdown", "sound_station_14", "blatantly_nuclear", "level", "nuke_alarm" }
local audioDebugLast, audioDebugNext = {}, 0
local function logNuclearAudio(item, source)
    local states = {}
    local index = 0
    for component in item.Components do
        if component.Name == "LightComponent" and component.Range == 0 then
            index = index + 1
            states[#states + 1] = index .. "=" .. (audioDebugNames[index] or "unknown")
                .. ":on=" .. tostring(component.IsOn) .. ":active=" .. tostring(component.IsActive)
                .. ":channel=" .. tostring(component.NeedsSoundUpdate())
        end
    end
    local state = table.concat(states, ",")
    if source == "sample" and audioDebugLast[item] == state then return end
    audioDebugLast[item] = state
    print(string.format("[VT/NukeAudio/client] t=%.3f id=%s source=%s count=%d [%s]",
        Timer.GetTime(), tostring(item.ID), source, index, state))
end
Hook.Patch("VoidTraitor.Nuclear.AudioDebug.Receive", "Barotrauma.Items.Components.LightComponent", "ClientEventRead",
    function(component)
        if not UI.Disabled and component.Item.Prefab.Identifier == "vt_nuclear_bomb" then
            logNuclearAudio(component.Item, "received LightComponent.ClientEventRead")
        end
    end, Hook.HookMethodType.After)
Hook.Add("think", "VoidTraitor.Nuclear.AudioDebug.Sample", function()
    if UI.Disabled or not Game.RoundStarted then return end
    local now = Timer.GetTime()
    if now < audioDebugNext then return end
    audioDebugNext = now + 0.05
    for item in Item.ItemList do
        if not item.Removed and item.Prefab.Identifier == "vt_nuclear_bomb" then
            logNuclearAudio(item, "sample")
        end
    end
end)
Hook.Add("roundEnd", "VoidTraitor.Nuclear.AudioDebug.End", function()
    audioDebugLast, audioDebugNext = {}, 0
end)
-- END TEMPORARY AUDIO DIAGNOSTICS.
