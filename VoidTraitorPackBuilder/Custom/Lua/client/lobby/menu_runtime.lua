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
