if SERVER then return end

local packPath, Common = ...
local NET_SUMMARY = "VoidTraitor_RoundSummary"
local STATE_KEY = "VoidTraitorRoundSummaryState"

local state = rawget(_G, STATE_KEY) or {}
_G[STATE_KEY] = state
state.Disabled = false

local function closeSummary()
    if state.MenuRoot ~= nil then
        Common.RemoveGuiComponent(state.MenuRoot)
        state.MenuRoot = nil
    end
end

local function showSummary(summary, closeText)
    closeSummary()

    summary = tostring(summary or "")
    if summary == "" then return end

    local title = summary
    local body = ""
    local lineBreak = string.find(summary, "\n", 1, true)
    if lineBreak ~= nil then
        title = string.sub(summary, 1, lineBreak - 1)
        body = string.sub(summary, lineBreak + 1)
    end

    local overlay = GUI.Frame(Common.CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 150)
    overlay.CanBeFocused = true
    overlay.IgnoreLayoutGroups = true
    state.MenuRoot = overlay

    local frame = GUI.Frame(Common.CreateRect(0.58, 0.72, overlay, GUI.Anchor.Center), nil)
    frame.Color = Color(30, 30, 40, 255)
    frame.OutlineColor = Color(255, 255, 255, 100)
    frame.OutlineThickness = 2

    local header = GUI.TextBlock(Common.CreateRect(0.94, 0.10, frame, GUI.Anchor.TopCenter), title, nil, nil, GUI.Alignment.Center, true)
    header.TextScale = 1.35
    header.TextColor = Color(255, 255, 255, 255)

    local list = GUI.ListBox(Common.CreateRect(0.94, 0.72, frame, GUI.Anchor.Center), nil)
    list.Color = Color(0, 0, 0, 55)

    local text = GUI.TextBlock(Common.CreateRect(0.96, 0, list.Content, nil), body, nil, nil, GUI.Alignment.TopLeft, true)
    text.CanBeFocused = false
    text.TextScale = 1.05
    text.TextColor = Color(225, 225, 220, 255)
    text.CalculateHeightFromText()

    local close = GUI.Button(Common.CreateRect(0.34, 0.085, frame, GUI.Anchor.BottomCenter), closeText or "Close", GUI.Alignment.Center, "GUIButton")
    close.OnClicked = function()
        closeSummary()
        return true
    end
end

Common.InstallHudPatch("VoidTraitor.RoundSummary.Hud", STATE_KEY, 2, 2)

Networking.Receive(NET_SUMMARY, function(message)
    showSummary(message.ReadString(), message.ReadString())
end)

Hook.Add("roundEnd", "VoidTraitor.RoundSummary.RoundEnd", closeSummary)
Hook.Add("roundStart", "VoidTraitor.RoundSummary.RoundStart", closeSummary)
