local P = ...
local S = P.State

function P.ShowActiveVoteMenu()
    if P.IsWelcomeMenuOpen ~= nil and P.IsWelcomeMenuOpen() then return end

    local active = S.voteSnapshot and S.voteSnapshot.Active or nil
    if active == nil then
        P.ShowVoteStartMenu()
        return
    end

    if not P.IsLobbyScreenAvailable() then return end

    local target = P.GetVoteTargetComponent(active.Type)
    local panel = P.CreateVoteOverlayOnComponent(target)
    if panel == nil then
        if not P.AttachVoteGuiRoot() then return end
        panel = GUI.Frame(P.CreateRect(0.36, 0.30, S.guiRoot, GUI.Anchor.Center), "GUIFrame")
        panel.Color = Color(255, 255, 255, 255)
    end

    panel.CanBeFocused = true
    panel.IgnoreLayoutGroups = true
    S.currentMenu = panel
    S.currentMenuKind = "voteactive"
    S.sharedState.CurrentMenu = panel
    S.sharedState.CurrentMenuKind = S.currentMenuKind
    P.SafeSetAsLastChild(panel)

    S.activeVoteUi = { Panel = panel, ActiveId = tostring(active.Id or ""), OptionButtons = {} }

    local content = GUI.LayoutGroup(P.CreateRect(0.985, 0.985, panel, GUI.Anchor.Center), false, GUI.Anchor.TopCenter)
    content.Stretch = true
    content.RelativeSpacing = 0.008

    local header = GUI.LayoutGroup(P.CreateRect(1, 0.10, content, nil), true, GUI.Anchor.CenterLeft)
    header.Stretch = true
    header.RelativeSpacing = 0.012

    local title = P.CreateText(header, 0.70, 1, nil, active.Title or P.VoteUiText.StartTitle, GUI.Alignment.Left, 0.95, Color(255, 235, 170, 255), false)
    title.Font = GUI.Style.SubHeadingFont

    S.activeVoteUi.TimerText = P.CreateText(header, 0.30, 1, nil, P.GetVoteTimeText(active), GUI.Alignment.CenterRight, 1.125, Color(210, 220, 200, 255), false)

    local progressFrame = GUI.Frame(P.CreateRect(1, 0.035, content, nil), "GUIFrame")
    progressFrame.Color = Color(25, 35, 30, 230)
    S.activeVoteUi.ProgressFill = GUI.Frame(P.CreateRect(P.GetVoteProgress(active), 1, progressFrame, GUI.Anchor.CenterLeft), nil)
    S.activeVoteUi.ProgressFill.Color = Color(120, 170, 130, 230)

    local listArea = GUI.Frame(P.CreateRect(1, 0.855, content, nil), nil)
    listArea.Color = Color(0, 0, 0, 0)
    listArea.CanBeFocused = false

    -- Слои списка не должны перекрашивать ванильную рамку.
    -- Чёрный фон лежит под GUIFrameListBox, сама зелёная рамка остаётся родной,
    -- а ListBox внутри прозрачный и только держит кнопки вариантов.
    local listBackground = GUI.Frame(P.CreateRect(0.984, 0.944, listArea, GUI.Anchor.Center), nil)
    listBackground.Color = Color(0, 0, 0, 255)
    listBackground.CanBeFocused = false

    local listFrame = GUI.Frame(P.CreateRect(1, 1, listArea, GUI.Anchor.Center), "GUIFrameListBox")
    listFrame.CanBeFocused = false

    local list = GUI.ListBox(P.CreateRect(0.984, 0.944, listFrame, GUI.Anchor.Center), false, Color(0, 0, 0, 0), nil)
    list.Color = Color(0, 0, 0, 0)
    if list.ContentBackground ~= nil then
        list.ContentBackground.Color = Color(0, 0, 0, 0)
    end
    list.KeepSpaceForScrollBar = false

    for _, option in ipairs(active.Options or {}) do
        local label = P.FormatVoteOptionLabel(option)
        local button = GUI.Button(P.CreateRect(1, 0.105, list.Content, nil), label, GUI.Alignment.Center, "GUIButtonSmall")
        P.SetButtonTextScale(button, 0.73)
        S.activeVoteUi.OptionButtons[option.Index] = button
        button.OnClicked = function()
            P.SendVoteCast(option.Index)
            if S.voteSnapshot ~= nil and S.voteSnapshot.Active ~= nil then
                for _, localOption in ipairs(S.voteSnapshot.Active.Options or {}) do
                    localOption.Selected = localOption.Index == option.Index
                end
                P.RefreshActiveVoteUi()
            end
            return true
        end
    end

    P.RefreshActiveVoteUi()
end

P.CreateVoteButton = function()
    P.DestroyVoteButton()

    if not P.IsLobbyScreenAvailable() then return end

    local parent = P.GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then return end

    local root = GUI.Frame(P.GetVoteButtonRect(parent), nil)
    root.Color = Color(0, 0, 0, 0)
    root.CanBeFocused = true
    root.IgnoreLayoutGroups = true
    S.voteButtonRoot = root
    S.voteButtonParent = parent
    S.sharedState.VoteButtonRoot = S.voteButtonRoot

    P.SafeSetAsLastChild(root)

    local button = GUI.Button(P.CreateRect(1, 1, root, GUI.Anchor.Center), P.VoteUiText.Button, GUI.Alignment.Center, "GUITabButton")
    button.CanBeFocused = true
    button.ToolTip = P.VoteUiText.Tooltip
    P.SetButtonTextScale(button, 1.0)
    button.OnClicked = function()
        if S.currentMenuKind == "votestart" then
            P.CloseMenu()
            return true
        end
        P.RequestVoteSnapshot(true)
        return true
    end
end

P.IsWelcomeMenuOpen = function()
    local welcomeRoot = rawget(_G, "VoidTraitorWelcomeMenuRoot")
    if welcomeRoot == nil or welcomeRoot.RectTransform == nil then
        return rawget(_G, "VoidTraitorWelcomeMenuOpen") == true
    end

    local hasParent = welcomeRoot.RectTransform.Parent ~= nil
    if not hasParent then _G.VoidTraitorWelcomeMenuOpen = false end
    return hasParent
end

function P.EnsureVoteButton()
    if S.sharedState.Disabled then return end

    if P.IsWelcomeMenuOpen() then
        if S.currentMenuKind == "votestart" or S.currentMenuKind == "voteactive" then P.CloseMenu() end
        P.DestroyVoteButton()
        return
    end

    if not P.IsLobbyScreenAvailable() then
        if S.currentMenuKind == "votestart" or S.currentMenuKind == "voteactive" then P.CloseMenu() end
        P.DestroyVoteButton()
        return
    end

    local parent = P.GetVoteButtonParent()
    if parent == nil or parent.RectTransform == nil then
        P.DestroyVoteButton()
        return
    end

    local width, height = P.GetScreenSize()
    if S.voteButtonRoot == nil or S.voteButtonParent ~= parent or width ~= S.lastVoteButtonResolutionX or height ~= S.lastVoteButtonResolutionY then
        S.lastVoteButtonResolutionX = width
        S.lastVoteButtonResolutionY = height
        P.CreateVoteButton()
    end
end

S.sharedState.EnsureVoteButton = P.EnsureVoteButton
