local P = ...
local S = P.State

P.NET_VOTE_READY = "VoidTraitor_LobbyVoteGuiReady"
P.NET_VOTE_SNAPSHOT = "VoidTraitor_LobbyVoteSnapshot"
P.NET_VOTE_START = "VoidTraitor_LobbyVoteStart"
P.NET_VOTE_CAST = "VoidTraitor_LobbyVoteCast"
P.NET_VOTE_CUSTOM = "VoidTraitor_LobbyVoteCustom"

-- the server's latest vote snapshot and the end of each of its votes by id, to hear a new one (voting_runtime.lua)
S.voteSnapshot = nil
S.voteEndTimes = {}
-- the side popups of the running votes (voting_display.lua)
S.votePopups = nil
-- the open list of votes to start under a vote button (voting_menu.lua)
S.voteList = nil
-- the draft of an admin's own vote, kept while its editor is rebuilt (voting_menu.lua)
S.customVoteDraft = nil

P.VoteUiText = P.Common.Language.Voting

local base = P.PackPath .. "/Lua/client/lobby/"
assert(loadfile(base .. "voting_layout.lua"))(P)
assert(loadfile(base .. "voting_display.lua"))(P)
assert(loadfile(base .. "voting_menu.lua"))(P)
assert(loadfile(base .. "voting_runtime.lua"))(P)
