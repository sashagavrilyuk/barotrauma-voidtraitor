local P = ...
local S = P.State

Networking.Receive(P.NET_VOTE_SNAPSHOT, function(message)
    if S.sharedState.Disabled then return end

    P.VoteUiText.StartBlockedReason = message.ReadString()

    local canStart = message.ReadBoolean()
    local hasActive = message.ReadBoolean()
    local snapshot = { CanStart = canStart, Active = nil }

    if hasActive then
        local active = {
            Id = message.ReadString(),
            Type = message.ReadString(),
            Title = "",
            StartedBy = message.ReadString(),
            Remaining = message.ReadInt32(),
            Duration = message.ReadInt32(),
            Options = {},
        }
        active.Title = active.Type == "map" and P.VoteUiText.MapTitle or P.VoteUiText.GameTitle
        active.LocalEndTime = P.GetTime() + math.max(0, tonumber(active.Remaining or 0) or 0)

        local count = message.ReadInt32()
        for i = 1, count do
            table.insert(active.Options, {
                Index = message.ReadInt32(),
                Text = message.ReadString(),
                Votes = message.ReadInt32(),
                Selected = message.ReadBoolean(),
            })
        end

        snapshot.Active = active
        if active.Id ~= "" and active.Id ~= S.lastActiveVoteId then
            S.lastActiveVoteId = active.Id
            P.PlayVoteSound()
        end
    else
        S.lastActiveVoteId = ""
        S.lastShownActiveVoteId = ""
    end

    local now = P.GetTime()
    snapshot.GameCooldownEndTime = now + math.max(0, message.ReadInt32())
    snapshot.MapCooldownEndTime = now + math.max(0, message.ReadInt32())

    S.voteSnapshot = snapshot

    if S.voteButtonRoot ~= nil and P.IsLobbyScreenAvailable() and S.currentMenuKind ~= "votestart" and S.currentMenuKind ~= "voteactive" then
        P.CreateVoteButton()
    end

    if S.pendingVoteMenuOpen then
        S.pendingVoteMenuOpen = false
        if S.currentMenu ~= nil then P.CloseMenu() end
        if S.voteSnapshot.Active ~= nil then
            S.lastShownActiveVoteId = tostring(S.voteSnapshot.Active.Id or "")
            P.ShowActiveVoteMenu()
        else
            P.ShowVoteStartMenu()
        end
    elseif S.currentMenu ~= nil and S.currentMenuKind == "voteactive" then
        if S.voteSnapshot.Active == nil then
            P.CloseMenu()
        elseif S.activeVoteUi ~= nil and tostring(S.voteSnapshot.Active.Id or "") == tostring(S.activeVoteUi.ActiveId or "") then
            P.RefreshActiveVoteUi()
        else
            P.CloseMenu()
            S.lastShownActiveVoteId = tostring(S.voteSnapshot.Active.Id or "")
            P.ShowActiveVoteMenu()
        end
    elseif S.currentMenu ~= nil and S.currentMenuKind == "votestart" and S.voteSnapshot.Active ~= nil then
        P.CloseMenu()
        S.lastShownActiveVoteId = tostring(S.voteSnapshot.Active.Id or "")
        P.ShowActiveVoteMenu()
    elseif S.voteSnapshot.Active ~= nil and tostring(S.voteSnapshot.Active.Id or "") ~= "" and tostring(S.voteSnapshot.Active.Id or "") ~= S.lastShownActiveVoteId then
        S.lastShownActiveVoteId = tostring(S.voteSnapshot.Active.Id or "")
        P.ShowActiveVoteMenu()
    end
end)

P.SendVoteReady()
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 2500)
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 6500)
