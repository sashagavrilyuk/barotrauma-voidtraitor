local P = ...
local S = P.State

function P.SendVoteReady()
    P.SendNetMessage(P.NET_VOTE_READY)
end

function P.RequestVoteSnapshot(openAfterResponse)
    S.pendingVoteMenuOpen = openAfterResponse == true
    P.SendNetMessage(P.NET_VOTE_REQUEST)
end

function P.SendVoteStart(voteType)
    P.SendNetMessage(P.NET_VOTE_START, function(msg)
        msg.WriteString(tostring(voteType or ""))
    end)
end

function P.SendVoteCast(optionId)
    P.SendNetMessage(P.NET_VOTE_CAST, function(msg)
        msg.WriteInt32(tonumber(optionId or 0) or 0)
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

function P.ReadRectValue(rect, key, fallback)
    if rect == nil then return fallback or 0 end
    return tonumber(rect[key]) or fallback or 0
end

function P.GetComponentRect(component)
    if component == nil then return nil end
    return component.Rect
end

function P.GetLobbyComponent(name)
    local screen = P.GetNetLobbyScreen()
    return screen ~= nil and screen[name] or nil
end

function P.GetLobbyComponentRect(name)
    return P.GetComponentRect(P.GetLobbyComponent(name))
end

function P.GetVoteButtonParent()
    return P.GetLobbyGuiFrame()
end

function P.GetVoteButtonAnchorRect()
    local subRect = P.GetLobbyComponentRect("SubList")
    local modeRect = P.GetLobbyComponentRect("ModeList")
    local anchorRect = subRect or modeRect
    if anchorRect == nil then return nil end

    local x = P.ReadRectValue(anchorRect, "X", 0)
    local y = P.ReadRectValue(anchorRect, "Y", 0)
    local width = P.ReadRectValue(anchorRect, "Width", 0)
    local height = P.ReadRectValue(anchorRect, "Height", 0)
    if width <= 0 or height <= 0 then return nil end

    local buttonWidth = math.max(P.SafeIntScale(170), math.min(P.SafeIntScale(245), math.floor(width * 0.324)))
    local buttonY = y + height + P.SafeIntScale(6)
    local buttonHeight = P.SafeIntScale(32)
    local respawnRect = P.GetComponentRect(P.GetLobbyComponent("respawnTabButton"))
    if respawnRect ~= nil then
        buttonY = P.ReadRectValue(respawnRect, "Y", buttonY)
        buttonHeight = P.ReadRectValue(respawnRect, "Height", buttonHeight)
    end

    return {
        X = x + width - buttonWidth - P.SafeIntScale(6),
        Y = buttonY,
        Width = buttonWidth,
        Height = buttonHeight,
    }
end

function P.GetVoteButtonMetrics()
    local anchor = P.GetVoteButtonAnchorRect()
    if anchor ~= nil then
        return math.max(1, math.floor(anchor.Width)), math.max(P.SafeIntScale(22), math.floor(anchor.Height)), P.SafeIntScale(2)
    end

    return P.SafeIntScale(190), P.SafeIntScale(26), P.SafeIntScale(2)
end

function P.GetVoteStartOptionMetrics()
    local width, height, gap = P.GetVoteButtonMetrics()
    local optionHeight = math.max(P.SafeIntScale(18), math.floor(height * 0.48))
    return width, optionHeight, P.SafeIntScale(1), gap
end

function P.CreateLobbyAbsoluteRect(x, y, width, height)
    local lobbyFrame = P.GetLobbyGuiFrame()
    if lobbyFrame == nil or lobbyFrame.RectTransform == nil then return nil end

    local frameRect = P.GetComponentRect(lobbyFrame)
    local frameX = P.ReadRectValue(frameRect, "X", 0)
    local frameY = P.ReadRectValue(frameRect, "Y", 0)

    local rectTransform = GUI.RectTransform(Point(math.max(1, math.floor(width)), math.max(1, math.floor(height))), lobbyFrame.RectTransform, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(math.floor(x - frameX), math.floor(y - frameY))
    return rectTransform
end

function P.GetVoteButtonRect(parent)
    local anchor = P.GetVoteButtonAnchorRect()
    if anchor ~= nil then
        local rect = P.CreateLobbyAbsoluteRect(anchor.X, anchor.Y, anchor.Width, anchor.Height)
        if rect ~= nil then return rect end
    end

    local width, height = P.GetVoteButtonMetrics()
    return GUI.RectTransform(Point(width, height), parent ~= nil and parent.RectTransform or nil, GUI.Anchor.TopLeft)
end

function P.GetVoteStartPanelRect(parent)
    local width, optionHeight, spacing, gap = P.GetVoteStartOptionMetrics()

    local buttonRect = P.GetComponentRect(parent)
    if buttonRect ~= nil then
        local x = P.ReadRectValue(buttonRect, "X", 0)
        local y = P.ReadRectValue(buttonRect, "Y", 0) + P.ReadRectValue(buttonRect, "Height", optionHeight) + gap
        local rect = P.CreateLobbyAbsoluteRect(x, y, width, optionHeight * 2 + spacing)
        if rect ~= nil then return rect end
    end

    local rectTransform = GUI.RectTransform(Point(width, optionHeight * 2 + spacing), parent ~= nil and parent.RectTransform or nil, GUI.Anchor.TopLeft)
    rectTransform.AbsoluteOffset = Point(0, optionHeight + gap)
    return rectTransform
end

function P.GetVoteTargetComponent(voteType)
    if tostring(voteType or "") == "map" then
        return P.GetLobbyComponent("SubList")
    end

    return P.GetLobbyComponent("ModeList")
end

function P.DestroyVoteButton()
    P.Common.RemoveGuiComponent(S.voteButtonRoot)
    S.voteButtonRoot = nil
    S.voteButtonParent = nil
    S.sharedState.VoteButtonRoot = nil
end

function P.AttachVoteGuiRoot()
    if not P.IsLobbyScreenAvailable() or S.guiRoot == nil or S.guiRoot.RectTransform == nil then return false end

    local lobbyFrame = P.GetLobbyGuiFrame()
    if lobbyFrame == nil then return false end

    S.guiRoot:RemoveFromGUIUpdateList(true)
    S.guiRoot.Visible = true
    S.guiRoot.RectTransform.Parent = lobbyFrame.RectTransform
    S.guiRoot.RectTransform.RelativeSize = Vector2(1, 1)
    S.guiRoot.RectTransform.AbsoluteOffset = Point(0, 0)
    P.SafeSetAsLastChild(S.guiRoot)

    return true
end
