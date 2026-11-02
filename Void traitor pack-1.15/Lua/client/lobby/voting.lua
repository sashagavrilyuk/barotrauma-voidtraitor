local P = ...
local S = P.State

P.NET_VOTE_READY = "VoidTraitor_LobbyVoteGuiReady"
P.NET_VOTE_REQUEST = "VoidTraitor_LobbyVoteRequest"
P.NET_VOTE_SNAPSHOT = "VoidTraitor_LobbyVoteSnapshot"
P.NET_VOTE_START = "VoidTraitor_LobbyVoteStart"
P.NET_VOTE_CAST = "VoidTraitor_LobbyVoteCast"

S.voteButtonRoot = nil
S.voteButtonParent = nil
S.activeVoteUi = nil
S.voteSnapshot = nil
S.pendingVoteMenuOpen = false
S.lastActiveVoteId = ""
S.lastShownActiveVoteId = ""
S.lastVoteButtonResolutionX = -1
S.lastVoteButtonResolutionY = -1

P.VoteUiText = P.Common.Language.Voting
P.VoteUiText.StartBlockedReason = ""


local base = P.PackPath .. "/Lua/client/lobby/"
assert(loadfile(base .. "voting_layout.lua"))(P)
assert(loadfile(base .. "voting_display.lua"))(P)
assert(loadfile(base .. "voting_menu.lua"))(P)
assert(loadfile(base .. "voting_runtime.lua"))(P)
