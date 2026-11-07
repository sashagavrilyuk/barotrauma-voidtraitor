if SERVER then return end
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorCloningGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
    Common.RemoveGuiComponent(previous.ConsentRoot)
end
local UI = {}
_G.VoidTraitorCloningGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
local mutedColor = Color(160, 160, 150, 255)

function UI.Send(action)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_CloningAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
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
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update = nil, nil, nil, nil
    UI.SelectedItem = nil
end

local function createLine(parent, scale, color)
    local block = Common.CreateText(parent, 1, 1, nil, "", GUI.Alignment.Left, scale, color, false)
    Common.SetAutoScaleText(block, scale)
    Common.FitHeightToText(block)
    return block
end

local function createHeading(parent, label)
    local block = createLine(parent, 1, Color(235, 205, 145, 255))
    block.Font = GUI.Style.SubHeadingFont
    Common.FitHeightToText(block)
    block.Text = label
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.ItemId = itemId
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.min(Common.SafeIntScale(420), screenWidth * 0.9)
    local root = GUI.Frame(GUI.RectTransform(Point(math.floor(width), Common.SafeIntScale(300)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout, frame = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, text.CloneTitle, text.CloneClose, function()
        UI.CloseMenu()
        return true
    end)
    createHeading(layout, text.CloneScanner)
    local scannerLink = createLine(layout, 1)
    local body = createLine(layout, 1)
    local eject = Common.CreateButton(layout, 1, text.CloneEject)
    eject.OnClicked = function() UI.Send("eject") return true end
    Common.CreateDivider(layout)
    createHeading(layout, text.ClonePod)
    local podLink = createLine(layout, 1)
    local biomass = createLine(layout, 1)
    local progress = GUI.ProgressBar(Common.CreateRect(1, 1, layout), 0, Color(80, 210, 240, 255))
    Common.SetFixedHeight(progress, Common.GetTextHeight(GUI.Style.Font))
    Common.CreateDivider(layout)
    local status = createLine(layout, 1, Color(235, 235, 225, 255))
    local clone = Common.CreateButton(layout, 1, text.CloneStart)
    clone.OnClicked = function() UI.Send("clone") return true end
    local minimumHeight = Common.GetMinimumHeight(frame)
    root.RectTransform:Resize(Point(root.Rect.Width, math.min(minimumHeight, screenHeight)), true)
    UI.Update = function(state)
        scannerLink.Text = state.ScannerLinked and text.CloneLinked or text.CloneNotLinked
        scannerLink.TextColor = state.ScannerLinked and Color(230, 230, 220, 255) or mutedColor
        body.Text = state.Body ~= nil and string.format(text.CloneBody, state.Body) .. (state.BodyDead and "" or " " .. text.CloneBodyAlive) or text.CloneNoBody
        eject.Enabled = state.Body ~= nil
        podLink.Text = (state.PodLinked and text.CloneLinked or text.CloneNotLinked) .. " · " .. (state.PodPowered and text.ClonePower or text.CloneNoPowerShort)
        podLink.TextColor = state.PodLinked and state.PodPowered and Color(230, 230, 220, 255) or mutedColor
        biomass.Text = string.format(text.CloneBiomassLine, state.Biomass, state.Cost ~= nil and tostring(state.Cost) or "—")
        progress.BarSize = state.Growing and state.Progress / 100 or 0
        status.Text = state.Status
        clone.Enabled = state.CanClone
    end
    UI.Update(snapshot)
end

function UI.CloseConsent()
    Common.RemoveGuiComponent(UI.ConsentRoot)
    UI.ConsentRoot = nil
end

local function answerConsent(accept)
    local message = Networking.Start("VoidTraitor_CloneConsentAnswer")
    message.WriteBoolean(accept)
    Networking.Send(message)
    UI.CloseConsent()
    return true
end

function UI.ShowConsent(title, question, acceptText, declineText)
    UI.CloseConsent()
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.min(Common.SafeIntScale(400), screenWidth * 0.9)
    local root = GUI.Frame(GUI.RectTransform(Point(math.floor(width), Common.SafeIntScale(200)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.ConsentRoot = root
    local layout, frame = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, title, nil, function() return answerConsent(false) end)
    local questionText = Common.CreateText(layout, 1, 1, nil, question, GUI.Alignment.Center, 1, nil, true)
    questionText.CalculateHeightFromText()
    Common.SetFixedHeight(questionText, questionText.Rect.Height)
    local buttons = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
    buttons.Stretch = true
    buttons.AbsoluteSpacing = Common.GetGap()
    Common.SetFixedHeight(buttons, Common.GetStyleHeight("GUIButton"))
    Common.CreateButton(buttons, 0.5, acceptText).OnClicked = function() return answerConsent(true) end
    Common.CreateButton(buttons, 0.5, declineText).OnClicked = function() return answerConsent(false) end
    root.RectTransform:Resize(Point(root.Rect.Width, math.min(Common.GetMinimumHeight(frame), screenHeight)), true)
end

Networking.Receive("VoidTraitor_CloningSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.SelectedItem ~= nil and UI.SelectedItem.ID == itemId
        and character.SelectedItem == UI.SelectedItem then UI.Show(itemId, snapshot) end
end)
Networking.Receive("VoidTraitor_CloneConsent", function(message)
    if not message.ReadBoolean() then UI.CloseConsent() return end
    UI.ShowConsent(message.ReadString(), message.ReadString(), message.ReadString(), message.ReadString())
end)
Hook.Patch("VoidTraitor.Cloning.Hud", "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if UI.Disabled or GUI.DisableHUD then return end
    if UI.MenuRoot ~= nil then UI.MenuRoot:AddToGUIUpdateList(false, 120) end
    if UI.ConsentRoot ~= nil then UI.ConsentRoot:AddToGUIUpdateList(false, 125) end
end)
Common.InstallPausePatch("VoidTraitor.Cloning.Pause", "VoidTraitorCloningGuiState")
Hook.Patch("VoidTraitor.Cloning.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.Cloning.End", function() UI.CloseMenu() UI.CloseConsent() end)
Hook.Add("think", "VoidTraitor.Cloning.Selection", function()
    Common.UpdateSelectedItemMenu(UI, "vt_cloning_console", function(selected)
        local message = Networking.Start("VoidTraitor_CloningOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
end)
