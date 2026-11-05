local P = ...
local S = P.State

Networking.Receive(P.NET_SNAPSHOT, function(message)
    if S.sharedState.Disabled then return end

    local count = message.ReadInt32()
    local entries = {}
    for i = 1, count do
        local command = message.ReadString()
        local enabled = message.ReadBoolean()
        local disabledReason = message.ReadString()
        local inputType = message.ReadString()
        local actionText = P.MenuText.Actions[command] or {}
        local hint = tostring(actionText.Hint or "")
        if not enabled and disabledReason ~= "" then
            hint = disabledReason .. (hint ~= "" and "\n\n" .. hint or "")
        end
        local categoryKey = tostring(actionText.Category or "Main")
        table.insert(entries, {
            Command = command,
            Label = actionText.Label or command,
            Hint = hint,
            Category = P.MenuText.Categories[categoryKey] or categoryKey,
            InputType = inputType,
            InputHint = actionText.InputHint or "",
            ConfirmTitle = actionText.ConfirmTitle or "",
            ConfirmText = actionText.ConfirmText or "",
            Enabled = enabled,
        })
    end

    S.shopAvailable = message.BitPosition >= message.LengthBits or message.ReadBoolean()
    S.menuEntries = entries
    if S.buttonRoot ~= nil then
        P.CreateTopButtons()
    end
    if S.pendingMenuOpen then
        S.pendingMenuOpen = false
        P.ShowVoidTraitorMenu()
    end
end)


P.SendReady()
Timer.Wait(function() if not S.sharedState.Disabled then P.SendReady() end end, 2000)
Timer.Wait(function() if not S.sharedState.Disabled then P.SendReady() end end, 6000)

Hook.Patch(P.HUD_PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state == nil or state.Disabled then return end
    if GUI.DisableHUD then return end

    if state.GuiRoot ~= nil then
        state.GuiRoot:AddToGUIUpdateList(false, P.MENU_DRAW_ORDER)
    end
    if state.ButtonRoot == nil and state.EnsureTopButtons ~= nil then
        state.EnsureTopButtons()
    end
    if state.ButtonRoot ~= nil then
        state.ButtonRoot:AddToGUIUpdateList(false, P.BUTTON_DRAW_ORDER)
    end
end)

-- The respawn text normally sits in the top-left button row, where the SHOP and VT buttons are.
-- Move it down into the gap between those buttons and the crew list; where that gap is narrower
-- than a line (low resolutions), the crew list moves down while the text is shown.
local respawnTextOffset, crewListShift, respawnTextShown
Hook.Patch(P.RESPAWN_TEXT_PATCH_ID, "Barotrauma.GameSession", "CreateTopLeftButtons", function(instance)
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state == nil or state.Disabled then return end

    local frame, text = instance.deathChoiceInfoFrame, instance.respawnInfoText
    local rowHeight = frame.RectTransform.Parent.Rect.Height
    local _, buttonHeight = P.GetTopButtonSize()
    local buttonsBottom = (rowHeight + buttonHeight) / 2
    local crewListTop = rowHeight + P.GetTopButtonSpacing()
    local lineHeight = math.ceil(text.Font.LineHeight * text.TextScale)
    local margin = GUI.IntScale(4)
    local textTop = math.max(buttonsBottom + margin, (buttonsBottom + crewListTop - lineHeight) / 2)
    crewListShift = math.max(0, math.ceil(textTop + lineHeight + margin - crewListTop))
    -- the text block is top-aligned in its frame
    respawnTextOffset = Point(0, math.floor(textTop - text.Padding.Y))
    respawnTextShown = nil
    frame.IgnoreLayoutGroups = true
    frame.RectTransform.AbsoluteOffset = respawnTextOffset
end, Hook.HookMethodType.After)

-- SetRespawnInfo runs every frame and, while the text is shown, hands it back to the button row
Hook.Patch(P.RESPAWN_INFO_PATCH_ID, "Barotrauma.GameSession", "SetRespawnInfo", function(instance, ptable)
    if respawnTextOffset == nil then return end
    local frame = instance.deathChoiceInfoFrame
    if not frame.Visible and respawnTextShown == false then return end
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state == nil or state.Disabled then return end
    -- the frame also stays visible, empty, once the player has spawned
    local text = ptable["text"]
    local shown = frame.Visible and text ~= nil and text ~= ""
    respawnTextShown = shown

    if frame.Visible then
        frame.IgnoreLayoutGroups = true
        local offset = frame.RectTransform.AbsoluteOffset
        if offset.X ~= respawnTextOffset.X or offset.Y ~= respawnTextOffset.Y then
            frame.RectTransform.AbsoluteOffset = respawnTextOffset
        end
        -- the right half holds the campaign's bot takeover buttons; without them the text gets the whole width
        local width = instance.deathChoiceButtonContainer.Visible and 0.5 or 1
        local textRect = instance.respawnInfoText.RectTransform
        if textRect.RelativeSize.X ~= width then textRect.RelativeSize = Vector2(width, 1) end
    end

    -- CrewManager rewrites the list's AbsoluteOffset every frame to slide it in, but leaves ScreenSpaceOffset alone
    local crewArea = instance.CrewManager ~= nil and instance.CrewManager.crewArea or nil
    if crewArea ~= nil then
        local shift = shown and crewListShift or 0
        if crewArea.RectTransform.ScreenSpaceOffset.Y ~= shift then
            crewArea.RectTransform.ScreenSpaceOffset = Point(0, shift)
        end
    end
end, Hook.HookMethodType.After)

Hook.Patch(P.PAUSE_PATCH_ID, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, params)
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
        if state.CurrentMenuKind == "voteactive" and state.BlockPauseMenu ~= true then
            return
        end
        if state.CurrentMenu ~= nil and state.CloseMenu ~= nil then
            state.CloseMenu()
        end
        if params ~= nil then params.PreventExecution = true end
        return false
    end
end, Hook.HookMethodType.Before)

Hook.Remove("think", "VoidTraitor.ClientMenu.KeepPauseBlocked")

Hook.Add("keyUpdate", "VoidTraitor.ClientMenu.PauseGuard", function()
    if S.sharedState.Disabled then return end
    if S.currentMenu ~= nil and PlayerInput.KeyHit(Keys.Escape) then
        P.RequestEscapeClose()
    end
end)

Hook.Add("roundEnd", "VoidTraitor.ClientMenu.RoundEnd", function()
    if S.sharedState.Disabled then return end
    P.CloseMenu()
    S.shopAvailable = nil
    P.CreateTopButtons()
end)

Hook.Add("think", "VoidTraitor.ClientMenu.UiState", function(deltaTime)
    if S.sharedState.Disabled then return end

    P.UpdateVoidTraitorMenuInteraction()

    S.uiStateCheckTimer = S.uiStateCheckTimer + (tonumber(deltaTime) or 0)
    if S.uiStateCheckTimer < 0.1 then return end
    S.uiStateCheckTimer = 0

    P.EnsureTopButtons()

    if P.IsLobbyScreenAvailable() then
        P.EnsureVoteButton()
        P.RefreshActiveVoteUi()
    else
        if S.currentMenuKind == "votestart" or S.currentMenuKind == "voteactive" then P.CloseMenu() end
        P.DestroyVoteButton()
    end
end)
