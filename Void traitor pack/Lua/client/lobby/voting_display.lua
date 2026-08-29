local P = ...
local S = P.State

function P.GetVoteProgress(active)
    if active == nil then return 0 end
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local remaining = math.max(0, tonumber(active.Remaining or 0) or 0)
    return math.max(0, math.min(1, remaining / duration))
end

function P.GetVoteTimeText(active)
    local remaining = 0
    if active ~= nil then remaining = math.max(0, tonumber(active.Remaining or 0) or 0) end
    return string.format("%s: %s", P.VoteUiText.Timer, tostring(math.floor(remaining)))
end

function P.ShowVoteStartMenu()
    if P.IsWelcomeMenuOpen ~= nil and P.IsWelcomeMenuOpen() then return end
    if not P.IsLobbyScreenAvailable() then return end
    if S.voteButtonRoot == nil then P.CreateVoteButton() end
    if S.voteButtonRoot == nil then return end

    local panel = GUI.Frame(P.GetVoteStartPanelRect(S.voteButtonRoot), "GUIFrame")
    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    S.currentMenu = panel
    S.currentMenuKind = "votestart"
    S.sharedState.CurrentMenu = panel
    S.sharedState.CurrentMenuKind = S.currentMenuKind
    P.SafeSetAsLastChild(panel)

    local width, optionHeight, spacing = P.GetVoteStartOptionMetrics()
    local canStart = S.voteSnapshot == nil or S.voteSnapshot.CanStart ~= false

    local modeRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    modeRect.AbsoluteOffset = Point(0, 0)
    local modeButton = GUI.Button(modeRect, P.VoteUiText.StartMode, GUI.Alignment.Center, "GUIButtonSmall")
    modeButton.Enabled = canStart
    P.SetButtonTextScale(modeButton, 0.70)
    modeButton.OnClicked = function()
        P.SendVoteStart("game")
        P.CloseMenu()
        return true
    end

    local mapRect = GUI.RectTransform(Point(width, optionHeight), panel.RectTransform, GUI.Anchor.TopCenter)
    mapRect.AbsoluteOffset = Point(0, optionHeight + spacing)
    local mapButton = GUI.Button(mapRect, P.VoteUiText.StartMap, GUI.Alignment.Center, "GUIButtonSmall")
    mapButton.Enabled = canStart
    P.SetButtonTextScale(mapButton, 0.70)
    mapButton.OnClicked = function()
        P.SendVoteStart("map")
        P.CloseMenu()
        return true
    end
end

function P.GetActiveVoteRemaining(active)
    if active == nil then return 0 end
    if active.LocalEndTime ~= nil then
        return math.max(0, math.ceil((tonumber(active.LocalEndTime) or 0) - P.GetTime()))
    end
    return math.max(0, tonumber(active.Remaining or 0) or 0)
end

function P.FormatVoteOptionLabel(option)
    local selectedPrefix = option.Selected and "✓ " or ""
    return string.format("%s%s — %s %s", selectedPrefix, tostring(option.Text or ""), tostring(option.Votes or 0), P.VoteUiText.Votes)
end

function P.CreateVoteOverlayOnComponent(target)
    if target == nil or target.RectTransform == nil then return nil end

    local overlayRect = nil
    if target.RectTransform.Parent ~= nil then
        overlayRect = target.RectTransform.Parent.Rect
    end
    if overlayRect == nil then
        overlayRect = P.GetComponentRect(target)
    end
    if overlayRect == nil then return nil end

    local x = P.ReadRectValue(overlayRect, "X", 0)
    local y = P.ReadRectValue(overlayRect, "Y", 0)
    local width = P.ReadRectValue(overlayRect, "Width", 0)
    local height = P.ReadRectValue(overlayRect, "Height", 0)
    if width <= 0 or height <= 0 then return nil end

    -- В NetLobbyScreen верхние блоки режима/подлодки создаются как одинаковые
    -- Stretch-панели внутри mainPanelTopLayout, поэтому активное голосование
    -- выравниваем по фактическим границам этих соседних lobby-блоков, а не по
    -- ручному большому запасу вниз.
    local topY = y
    local bottomY = y + height

    local function includeTopVotePanelBounds(componentName)
        local component = P.GetLobbyComponent(componentName)
        if component == nil or component.RectTransform == nil then return end

        local siblingRect = nil
        if component.RectTransform.Parent ~= nil then
            siblingRect = component.RectTransform.Parent.Rect
        end
        if siblingRect == nil then return end

        local siblingY = P.ReadRectValue(siblingRect, "Y", topY)
        local siblingHeight = P.ReadRectValue(siblingRect, "Height", 0)
        if siblingHeight <= 0 then return end

        topY = math.min(topY, siblingY)
        bottomY = math.max(bottomY, siblingY + siblingHeight)
    end

    includeTopVotePanelBounds("ModeList")
    includeTopVotePanelBounds("SubList")

    y = topY + 1
    height = math.max(1, bottomY - topY)

    -- Ванильный NetLobbyScreen использует PanelSpacing = 0.005f. Берём такой же
    -- масштабируемый небольшой нахлёст только на нижний шов, чтобы не было видно
    -- нижнюю линию родного блока, но без прежнего завышенного SafeIntScale(6).
    local seamCover = math.max(P.SafeIntScale(2), math.floor(height * 0.005 + 0.5))
    height = height + seamCover

    local rectTransform = P.CreateLobbyAbsoluteRect(x, y, width, height)
    if rectTransform == nil then return nil end

    local panel = GUI.Frame(rectTransform, "GUIFrame")
    panel.Color = Color(255, 255, 255, 255)
    panel.IgnoreLayoutGroups = true
    return panel
end

function P.RefreshActiveVoteUi()
    if S.currentMenuKind ~= "voteactive" or S.activeVoteUi == nil then return end
    local active = S.voteSnapshot and S.voteSnapshot.Active or nil
    if active == nil then return end

    local remaining = P.GetActiveVoteRemaining(active)
    local duration = math.max(1, tonumber(active.Duration or 1) or 1)
    local progress = math.max(0, math.min(1, remaining / duration))

    if S.activeVoteUi.TimerText ~= nil then
        S.activeVoteUi.TimerText.Text = string.format("%s: %s", P.VoteUiText.Timer, tostring(math.floor(remaining)))
    end
    if S.activeVoteUi.ProgressFill ~= nil and S.activeVoteUi.ProgressFill.RectTransform ~= nil then
        S.activeVoteUi.ProgressFill.RectTransform.RelativeSize = Vector2(progress, 1)
    end

    local buttons = S.activeVoteUi.OptionButtons or {}
    for _, option in ipairs(active.Options or {}) do
        local button = buttons[option.Index]
        if button ~= nil and button.TextBlock ~= nil then
            button.TextBlock.Text = P.FormatVoteOptionLabel(option)
        end
    end
end
