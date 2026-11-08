if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorNuclearGuiState")
if previous ~= nil then previous.Disabled = true Common.RemoveGuiComponent(previous.MenuRoot) end
local UI = {}
_G.VoidTraitorNuclearGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
-- Layout copied from the SS14 nuke menu (NukeMenu.xaml, 256x256). Sizes are in SS14 button heights (29 px);
-- one SS14 button is drawn as one vanilla GUIButton height.
local SS14_BUTTON, SS14_WINDOW, SS14_LABEL, SS14_KEY_WIDTH, SS14_GRID_GAP, SS14_MARGIN = 29, 256, 23, 40, 4, 5

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
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    UI.CloseMenu()
    UI.ItemId = itemId
    local text = snapshot.Text
    local buttonHeight = Common.GetStyleHeight("GUIButton")
    local unit = buttonHeight / SS14_BUTTON
    local margin, gridGap, keyWidth = math.floor(SS14_MARGIN * unit), math.floor(SS14_GRID_GAP * unit), math.floor(SS14_KEY_WIDTH * unit)
    local screenWidth, screenHeight = Common.GetScreenSize()
    local side = math.floor(math.min(SS14_WINDOW * unit, screenWidth * 0.9, screenHeight * 0.9))
    local root = GUI.Frame(GUI.RectTransform(Point(side, side), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout = Common.CreateWindowContent(root)
    -- no row grows, the space left below stays empty
    layout.Stretch = false
    layout.AbsoluteSpacing = margin
    Common.CreateWindowHeader(layout, root, text.Title, text.Close, function()
        UI.CloseMenu()
        return true
    end, { titleScale = 0.9 })
    local function createStatus()
        local panel = GUI.Frame(Common.CreateRect(1, 1, layout), "GUIFrameListBox")
        Common.SetFixedHeight(panel, math.floor(SS14_LABEL * unit))
        return Common.CreateText(panel, 0.94, 1, GUI.Anchor.Center, "", GUI.Alignment.CenterLeft, 1, Color(120, 230, 120, 255))
    end
    local first, second = createStatus(), createStatus()
    local body = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
    Common.SetFixedHeight(body, 4 * buttonHeight + 3 * gridGap)
    body.AbsoluteSpacing = margin
    local keypadWidth = 3 * keyWidth + 2 * gridGap
    local keypad = GUI.LayoutGroup(Common.CreateRect(1, 1, body), false)
    Common.SetFixedWidth(keypad, keypadWidth)
    keypad.AbsoluteSpacing = gridGap
    local digits = {}
    for _, values in ipairs({ { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { "C", "0", "E" } }) do
        local row = GUI.LayoutGroup(Common.CreateRect(1, 1, keypad), true)
        Common.SetFixedHeight(row, buttonHeight)
        row.AbsoluteSpacing = gridGap
        for _, value in ipairs(values) do
            local button = Common.CreateButton(row, 1, value)
            Common.SetFixedWidth(button, keyWidth)
            button.OnClicked = function()
                UI.Send(value == "C" and "clear" or value == "E" and "enter" or "digit", value)
                return true
            end
            digits[#digits + 1] = button
        end
    end
    -- the button column keeps a margin on both sides
    local actions = GUI.LayoutGroup(Common.CreateRect(1, 1, body), false)
    Common.SetFixedWidth(actions, side - 2 * Common.GetWindowPadding() - keypadWidth - 2 * margin)
    actions.AbsoluteSpacing = margin
    local eject = Common.CreateButton(actions, 1, text.Eject)
    eject.OnClicked = function() UI.Send(UI.Snapshot.Disk and "eject" or "insert") return true end
    local anchor = Common.CreateButton(actions, 1, text.Anchor)
    anchor.OnClicked = function() UI.Send("anchor") return true end
    local arm = Common.CreateButton(actions, 1, text.Arm)
    -- red arm button, as in SS14
    arm.Color, arm.HoverColor, arm.PressedColor = Color(200, 70, 70, 255), Color(235, 100, 100, 255), Color(160, 50, 50, 255)
    arm.OnClicked = function() UI.Send("arm") return true end
    UI.Update = function(state)
        UI.Snapshot = state
        first.Text = text[({ locked = "Locked", code = "AwaitCode", ready = "Ready", armed = "Armed", cooldown = "Cooldown", exploded = "Exploded" })[state.Status]]
        second.Text = string.format(text.Time, state.Remaining)
        if state.Status == "locked" then second.Text = text.AwaitDisk
        elseif state.Status == "code" then second.Text = string.format(text.Code, string.rep("*", state.Entered) .. string.rep("_", 6 - state.Entered))
        elseif state.Status == "cooldown" then second.Text = string.format(text.Cooling, state.Cooldown) end
        for _, button in ipairs(digits) do button.Enabled = state.Status == "code" end
        eject.Text = state.Disk and text.Eject or text.Insert
        -- as in SS14, the disk can't be ejected while the bomb is not anchored
        eject.Enabled = state.Status ~= "armed" and state.Status ~= "exploded" and (state.Anchored or not state.Disk)
        anchor.Text = state.Anchored and text.Detach or text.Anchor
        anchor.Enabled, anchor.Selected = state.Status ~= "armed" and state.Status ~= "exploded", state.Anchored
        arm.Enabled = state.Status == "ready" and state.Disk and state.Anchored
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
Common.InstallHudPatch("VoidTraitor.Nuclear.Hud", "VoidTraitorNuclearGuiState", 120)
Common.InstallPausePatch("VoidTraitor.Nuclear.Pause", "VoidTraitorNuclearGuiState")
Hook.Patch("VoidTraitor.Nuclear.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
-- The countdown song of an armed bomb plays for the whole station; the bomb's own sounds and its final alarm play from
-- the bomb (nuclear.xml). Songs are streamed, so they start at once and hold no samples in memory while silent.
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local SONG_GAIN = 0.75
local song, songChannel
local function stopSong()
    if songChannel ~= nil then songChannel.Dispose() end
    if song ~= nil then song.Dispose() end
    song, songChannel = nil, nil
end
Networking.Receive("VoidTraitor_NuclearMusic", function(message)
    local file = message.ReadString()
    stopSong()
    if file == "" then return end
    song = gameMain.SoundManager.LoadSound(packPath .. "/Sounds/Station/Nuclear/" .. file, true)
    songChannel = song.Play(SONG_GAIN)
end)
Hook.Add("stop", "VoidTraitor.Nuclear.Song", stopSong)
Hook.Add("roundEnd", "VoidTraitor.Nuclear.End", function() UI.CloseMenu() UI.SelectedItem = nil stopSong() end)
Hook.Add("think", "VoidTraitor.Nuclear.Selection", function()
    Common.UpdateSelectedItemMenu(UI, "vt_nuclear_bomb", function(selected)
        local message = Networking.Start("VoidTraitor_NuclearOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
end)
