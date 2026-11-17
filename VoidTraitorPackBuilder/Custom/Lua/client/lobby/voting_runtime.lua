local P = ...
local S = P.State

-- The server sends the votes when one starts, ends or gets a vote, and when asked (voting.lua and clientmenu.lua).
Networking.Receive(P.NET_VOTE_SNAPSHOT, function(message)
    if S.sharedState.Disabled then return end

    local now = P.GetTime()
    local snapshot = { CanStartGame = message.ReadBoolean(), CanStartMap = message.ReadBoolean(),
        CanStartCustom = message.ReadBoolean(), StationMap = message.ReadBoolean(), Votes = {} }
    snapshot.GameCooldownEndTime = now + message.ReadInt32()
    snapshot.MapCooldownEndTime = now + message.ReadInt32()
    local endTimes = {}
    for index = 1, message.ReadByte() do
        local vote = { Id = message.ReadString(), Type = message.ReadString(), Title = message.ReadString(),
            StartedBy = message.ReadString(), Options = {} }
        -- the time left comes in whole seconds, rounded up, with every vote cast; a vote keeps the end it got first,
        -- or its bar would jump back at each one
        local remaining = message.ReadInt32()
        vote.EndTime = S.voteEndTimes[vote.Id] or now + remaining
        vote.Duration = message.ReadInt32()
        for option = 1, message.ReadUInt16() do
            vote.Options[option] = { Text = message.ReadString(), Votes = message.ReadInt32(), Selected = message.ReadBoolean() }
        end
        snapshot.Votes[index] = vote
        endTimes[vote.Id] = vote.EndTime
    end

    for id in pairs(endTimes) do
        if S.voteEndTimes[id] == nil then
            P.PlayVoteSound()
            break
        end
    end
    S.voteEndTimes = endTimes
    S.voteSnapshot = snapshot
    P.BuildVotePopups()
    P.RefreshVoteList()
end)

P.SendVoteReady()
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 2500)
Timer.Wait(function() if not S.sharedState.Disabled then P.SendVoteReady() end end, 6500)
