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

P.VoteUiText = {
    Button = "Начать голосование",
    Tooltip = "Открыть меню голосования в лобби",
    StartTitle = "Vote",
    StartMode = "Start game mode vote",
    StartMap = "Start submarine vote",
    StartBlockedReason = "",
    Close = "Close",
    NoActive = "No active vote right now.",
    StartedBy = "Started by",
    Timer = "Time left",
    Votes = "votes",
}


local base = P.PackPath .. "/Lua/client/lobby/"
assert(loadfile(base .. "voting_layout.lua"))(P)
assert(loadfile(base .. "voting_display.lua"))(P)
assert(loadfile(base .. "voting_menu.lua"))(P)
assert(loadfile(base .. "voting_runtime.lua"))(P)
