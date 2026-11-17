local P = ...
local S = P.State

function P.SendVoteReady()
    P.SendNetMessage(P.NET_VOTE_READY)
end

function P.SendVoteStart(voteType)
    P.SendNetMessage(P.NET_VOTE_START, function(msg)
        msg.WriteString(voteType)
    end)
end

function P.SendVoteCast(voteId, option)
    P.SendNetMessage(P.NET_VOTE_CAST, function(msg)
        msg.WriteString(voteId)
        msg.WriteByte(option)
    end)
end

function P.SendCustomVote(title, options)
    P.SendNetMessage(P.NET_VOTE_CUSTOM, function(msg)
        msg.WriteString(title)
        msg.WriteByte(#options)
        for _, option in ipairs(options) do msg.WriteString(option) end
    end)
end

function P.PlayVoteSound()
    if SoundPlayer.PlaySound("voteding", 1.0) == nil then
        SoundPlayer.PlayUISound(GUI.SoundType.Cart)
    end
end

function P.GetNetLobbyScreen()
    return Game.NetLobbyScreen
end

function P.IsLobbyScreenAvailable()
    local screen = P.GetNetLobbyScreen()
    return screen ~= nil and GUI.Screen.Selected == screen
end

function P.GetLobbyGuiFrame()
    local screen = P.GetNetLobbyScreen()
    if screen == nil then return nil end

    local frame = screen.Frame
    if frame ~= nil and frame.RectTransform ~= nil then return frame end
    return nil
end

function P.SafeSetAsLastChild(component)
    if component == nil or component.RectTransform == nil or component.RectTransform.Parent == nil then return end
    component.RectTransform.SetAsLastChild()
end

-- Vote windows and popups go into the lobby's own frame there, as its other windows do (panel.lua), and into the
-- menu's root during a round, which the game screen draws (menu_runtime.lua).
function P.GetVoteParent()
    if P.IsLobbyScreenAvailable() then return P.GetLobbyGuiFrame() end
    if Game.RoundStarted then return S.guiRoot end
    return nil
end
