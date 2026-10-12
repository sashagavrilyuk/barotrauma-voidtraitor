local hooks, now, messages = {},0,{}
Hook={Add=function(_,id,callback) hooks[id]=callback end}
require=function() return {} end
Descriptors={}
LuaUserData={RegisterType=function() return {} end,MakePropertyAccessible=function() end,CreateEnumTable=function() return {HideInMenus=8,Shuttle=16} end}
Timer={GetTime=function() return now end}
File={Exists=function() return false end}
Networking={ClientWriteLobby=function() end}
Color={LightGreen=1,White=2,LightBlue=3}
ClientPermissions={ConsoleCommands=1}
local client={Name='Player',HasPermission=function() return false end}
Client={ClientList={client}}
local function sub(name,station,tags)
    return {Name=name,Description={Value=station and 'station' or 'normal'},IsPlayer=true,IsCampaignCompatible=true,Tags=tags or '',RecommendedCrewSizeMin=1,RecommendedCrewSizeMax=16,HasTag=function(_,tag) return tags=='HideInMenus' and tag==8 end}
end
local normal,a,b,hidden=sub('Normal',false),sub('Station A',true),sub('Station B',true),sub('Hidden',true,'HideInMenus')
local saved={normal,a,b,hidden}
local index=0
SubmarineInfo={SavedSubmarines=function() index=index+1 if saved[index]==nil then index=0 return nil end return saved[index] end}
Game={RoundStarted=false,NetLobbyScreen={SelectedSub=normal},ServerSettings={GameModeIdentifier='mission',AllowSubVoting=true,ForcePropertyUpdate=function() end}}
local missionTypes='Salvage'
setmetatable(Game.ServerSettings,{__index=function(_,key)
    if key=='MissionTypes' then return missionTypes end
    if key=='AllowedRandomMissionTypes' then
        local values,index={},0
        for mission in missionTypes:gmatch('[^,]+') do values[#values+1]=mission end
        return function() index=index+1 return values[index] end
    end
end,__newindex=function(settings,key,value)
    if key=='MissionTypes' then missionTypes=value else rawset(settings,key,value) end
end})
Traitormod={Path=modpath,Language={},Config={GameVote={DurationSeconds=1,CooldownSeconds=0,Modes={{Name='Secret',Apply='Secret',LanguageKey='GameVoteOptionSecret'},{Name='Station',Apply='Station',LanguageKey='GameVoteOptionStation'}},SecretMissionTypes={'Salvage'},SecretBlockedTags={'HideInMenus'}}},ParseSubmarineConfig=function(description) return description=='station' and {Gamemode='Station'} or {} end,SendMessage=function(_,text) messages[#messages+1]=text end,SendMessageEveryone=function(text) messages[#messages+1]=text end,SendChatMessage=function(_,text) messages[#messages+1]=text end}
assert(loadfile(modpath..'/Lua/language/russian/gamemodes.lua'))(Traitormod.Language)
local vt=dofile(modpath..'/Lua/voting.lua')
Game.NetLobbyScreen.SelectedSub=a
assert(not vt.IsStationLobby(),'station map alone enabled station voting')
Game.NetLobbyScreen.SelectedSub=normal
Game.ServerSettings.MissionTypes='VoidTraitorStation'
assert(vt.IsStationLobby(),'selected station mission required an already selected station map')
Game.ServerSettings.GameModeIdentifier='pvp'
assert(not vt.IsStationLobby(),'station mission enabled station voting outside mission mode')
Game.ServerSettings.GameModeIdentifier='mission'
Game.ServerSettings.MissionTypes='Salvage'
vt.StartGameVote(client)
assert(vt.TryHandleGameVoteCommand(client,{'2'}))
now=2 hooks['Traitormod.Voting.Think']()
assert(vt.IsStationLobby() and Game.ServerSettings.MissionTypes=='VoidTraitorStation' and not Game.ServerSettings.AllowSubVoting)
vt.StartMapVote(client)
assert(#vt.MapVote.Candidates==2 and vt.MapVote.StationMap,'station vote included normal or hidden maps')
assert(vt.GetGuiSnapshot(client).StationMap)
assert(vt.TryHandleGameVoteCommand(client,{'2'}))
now=4 hooks['Traitormod.Voting.Think']()
assert(Game.NetLobbyScreen.SelectedSub==b,'ordinary client station vote was not applied')
vt.StartGameVote(client)
vt.TryHandleGameVoteCommand(client,{'1'})
now=6 hooks['Traitormod.Voting.Think']()
assert(Game.NetLobbyScreen.SelectedSub==normal and Game.ServerSettings.AllowSubVoting and Game.ServerSettings.MissionTypes=='Salvage','Secret selection did not restore its map/settings')
vt.StartMapVote(client)
assert(#vt.MapVote.Candidates==1 and vt.MapVote.Candidates[1]==normal and not vt.GetGuiSnapshot(client).StationMap)
Game.ServerSettings.MissionTypes='VoidTraitorStation'
hooks['Traitormod.Voting.Think']()
assert(vt.MapVote==nil,'old submarine vote remained after station mission was selected')
vt.StartMapVote(client)
assert(vt.MapVote.StationMap and #vt.MapVote.Candidates==2,'station mission did not enable station candidates from an ordinary submarine')
Game.ServerSettings.MissionTypes='Salvage'
hooks['Traitormod.Voting.Think']()
assert(vt.MapVote==nil,'station vote remained after station mission was deselected')
Game.NetLobbyScreen.SelectedSub=a
vt.StartMapVote(client)
assert(not vt.MapVote.StationMap and #vt.MapVote.Candidates==1,'station map alone changed vote candidates')
return 'PASS foundation voting: ordinary mode/map votes, station-only candidates, hidden exclusion, full mission settings and original Secret restoration'
