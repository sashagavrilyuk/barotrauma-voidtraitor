local P = ...
local S = P.State
local Common = P.Common
local text = Common.Language.Lobby

-- The lobby's Antagonists window: which antagonists the player is willing to be, by mode. The server keeps the
-- choice and sends it on joining and after every change (clientmenu.lua); each tick sends one option.

S.antagonists = {}
S.antagonistTicks = {}

local function sendOption(category, key, value)
    P.SendNetMessage(P.NET_ANTAGONIST_SET, function(message)
        message.WriteString(category)
        message.WriteString(key)
        message.WriteBoolean(value)
    end)
end

function P.ShowAntagonistsWindow()
    local content = P.OpenCardWindow("antagonists", text.Antagonists)
    local list = GUI.ListBox(Common.CreateRect(1, 1, content), false)
    list.Spacing = Common.GetGap()
    local tickHeight = Common.GetStyleHeight("GUITickBox")
    S.antagonistTicks = {}
    for _, group in ipairs(S.antagonists) do
        if #group.Options > 0 then
            local header = Common.CreateText(list.Content, 1, 1, nil, text.AntagonistGroups[group.Category] or group.Category,
                GUI.Alignment.CenterLeft, 1, nil, false)
            header.Font = GUI.Style.SubHeadingFont
            header.CanBeFocused = false
            Common.FitHeightToText(header)
            local labels = text.AntagonistOptions[group.Category] or {}
            for _, option in ipairs(group.Options) do
                local tick = GUI.TickBox(Common.CreateRect(1, 1, list.Content), labels[option.Key] or option.Key)
                Common.SetFixedHeight(tick, tickHeight)
                Common.SetAutoScaleText(tick.TextBlock, 1)
                tick.Selected = option.Value
                tick.OnSelected = function(box)
                    sendOption(group.Category, option.Key, box.Selected)
                    return true
                end
                S.antagonistTicks[group.Category .. "." .. option.Key] = tick
            end
        end
    end
end

Networking.Receive(P.NET_ANTAGONISTS, function(message)
    if S.sharedState.Disabled then return end

    local groups = {}
    for _ = 1, message.ReadByte() do
        local group = { Category = message.ReadString(), Options = {} }
        for _ = 1, message.ReadByte() do
            group.Options[#group.Options + 1] = { Key = message.ReadString(), Value = message.ReadBoolean() }
        end
        groups[#groups + 1] = group
    end
    S.antagonists = groups

    -- the open window shows what the server stored, without sending it back
    for _, group in ipairs(groups) do
        for _, option in ipairs(group.Options) do
            local tick = S.antagonistTicks[group.Category .. "." .. option.Key]
            if tick ~= nil then tick.SetSelected(option.Value, false) end
        end
    end
end)
