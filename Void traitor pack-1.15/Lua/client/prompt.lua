if SERVER then return end

-- Questions and notices from the server (traitormod Lua/textpromptutils.lua): the text and one button per answer.
-- A prompt that arrives while another one is open waits until that one is answered or closed. Items tagged
-- vt_itemprompt ask the server for their prompt when selected, and it closes when the item is no longer selected.
local _, Common = ...
local STATE_KEY = "VoidTraitorPromptState"
local previous = rawget(_G, STATE_KEY)
if previous ~= nil then previous.Disabled = true Common.RemoveGuiComponent(previous.MenuRoot) end
local UI = { Disabled = false, Queue = {} }
_G[STATE_KEY] = UI

local show
local selectedItemId = 0

-- a waiting item prompt is dropped if its item was put away meanwhile
local function isCurrent(prompt)
    return prompt.ItemId == 0 or prompt.ItemId == selectedItemId
end

function UI.CloseMenu()
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot = nil
    UI.CurrentMenu = nil
    table.remove(UI.Queue, 1)
    while UI.Queue[1] ~= nil and not isCurrent(UI.Queue[1]) do table.remove(UI.Queue, 1) end
    if UI.Queue[1] ~= nil then show(UI.Queue[1]) end
end

local function answer(prompt, option)
    local message = Networking.Start("VoidTraitor_PromptAnswer")
    message.WriteUInt16(UShort(prompt.Id))
    message.WriteByte(Byte(option))
    Networking.Send(message)
    UI.CloseMenu()
    return true
end

show = function(prompt)
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.min(Common.SafeIntScale(460), screenWidth * 0.9)
    local root = GUI.Frame(GUI.RectTransform(Point(math.floor(width), Common.SafeIntScale(200)), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot = root
    UI.CurrentMenu = root
    local layout, frame = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, Common.Language.ClientMenu.Title, nil, function() UI.CloseMenu() return true end)
    local text = Common.CreateText(layout, 1, 1, nil, prompt.Text, GUI.Alignment.Left, 1, nil, true)
    text.CalculateHeightFromText()
    Common.SetFixedHeight(text, text.Rect.Height)
    local buttonHeight = Common.GetStyleHeight("GUIButton")
    for index, option in ipairs(prompt.Options) do
        local button = Common.CreateButton(layout, 1, option)
        Common.SetFixedHeight(button, buttonHeight)
        button.OnClicked = function() return answer(prompt, index) end
    end
    root.RectTransform:Resize(Point(root.Rect.Width, math.min(Common.GetMinimumHeight(frame), screenHeight)), true)
end

Networking.Receive("VoidTraitor_Prompt", function(message)
    local prompt = { Id = message.ReadUInt16(), ItemId = message.ReadUInt16(), Text = message.ReadString(), Options = {} }
    for _ = 1, message.ReadByte() do
        table.insert(prompt.Options, message.ReadString())
    end
    if not isCurrent(prompt) then return end
    table.insert(UI.Queue, prompt)
    if UI.MenuRoot == nil then show(prompt) end
end)

Hook.Add("think", "VoidTraitor.Prompt.Selection", function()
    local character = Character.Controlled
    local item = character ~= nil and character.SelectedItem or nil
    local itemId = item ~= nil and item.ID or 0
    if itemId == selectedItemId then return end
    selectedItemId = itemId
    if UI.MenuRoot ~= nil and not isCurrent(UI.Queue[1]) then UI.CloseMenu() end
    if item ~= nil and item.HasTag("vt_itemprompt") then
        local message = Networking.Start("VoidTraitor_ItemPrompt")
        message.WriteUInt16(UShort(itemId))
        Networking.Send(message)
    end
end)

Common.InstallHudPatch("VoidTraitor.Prompt.Hud", STATE_KEY, 126)
Common.InstallPausePatch("VoidTraitor.Prompt.Pause", STATE_KEY)
Hook.Add("roundEnd", "VoidTraitor.Prompt.End", function()
    UI.Queue = {}
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot = nil
    UI.CurrentMenu = nil
end)
