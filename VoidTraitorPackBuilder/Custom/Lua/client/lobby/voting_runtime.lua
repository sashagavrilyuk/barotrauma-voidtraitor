local P = ...
local S = P.State

-- The server sends the votes when one starts, ends or gets a vote, and when asked (voting.lua and clientmenu.lua).
Networking.Receive(P.NET_VOTE_SNAPSHOT, function(message)
    if S.sharedState.Disabled then return end

    local now = P.GetTime()
    local snapshot = { CanStart = message.ReadBoolean(), StationMap = message.ReadBoolean(), Votes = {} }
    snapshot.GameCooldownEndTime = now + message.ReadInt32()
    snapshot.MapCooldownEndTime = now + message.ReadInt32()
    local ids = {}
    for index = 1, message.ReadByte() do
        local vote = { Id = message.ReadString(), Type = message.ReadString(), Title = message.ReadString(),
            StartedBy = message.ReadString(), Options = {} }
        vote.EndTime = now + message.ReadInt32()
        vote.Duration = message.ReadInt32()
        for option = 1, message.ReadUInt16() do
            vote.Options[option] = { Text = message.ReadString(), Votes = message.ReadInt32(), Selected = message.ReadBoolean() }
        end
        snapshot.Votes[index] = vote
        ids[vote.Id] = true
    end

    for id in pairs(ids) do
        if not S.voteIds[id] then
            P.PlayVoteSound()
            break
        end
    end
    S.voteIds = ids
    S.voteSnapshot = snapshot
    P.BuildVotePopups()
    P.RefreshVoteMenu()
end)

P.SendVoteReady()
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 2500)
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 6500)
