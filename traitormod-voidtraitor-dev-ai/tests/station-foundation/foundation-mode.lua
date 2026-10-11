local calls, queued, patches = {}, nil, {}
LuaUserData = { CreateEnumTable=function() return {Static=0} end,RegisterType=function() end }
Hook={Patch=function(id,_,_,callback) patches[id]=callback end,HookMethodType={Before=1}}
Game={RoundStarted=true,ServerSettings={MissionTypes='Salvage'},NetLobbyScreen={},GameSession={Missions=function() end}}
Submarine={MainSub={SubBody={Body={BodyType=2}}}}
local client={}
client.PendingPositionUpdates={Contains=function() return queued~=nil end,Enqueue=function(sub) queued=sub end}
Client={ClientList={client}}
local secret={Name='Secret',PointshopCategories={'medical','traitor'},TraitorTypeChance={Traitor=50}}
function secret:new(o) o=o or {} setmetatable(o,self) self.__index=self return o end
secret.Start=function() calls.started=true end
secret.Think=function() error('station called travel-ending Secret Think') end
secret.BeginEnding=function() calls.ending=(calls.ending or 0)+1 end
secret.End=function() calls.ended=true end
Traitormod={Gamemodes={Secret=secret,Gamemode={PreStart=function(self) calls.categories=self.PointshopCategories end}},Pointshop={CanUseShop=function() return false end},ClientMenu={SendSnapshot=function() calls.menu=(calls.menu or 0)+1 end}}
local gm=dofile(modpath..'/Lua/gamemodes/station.lua'):new()
gm.PointshopCategories={'traitor','cultist','saboteur','clown'}
Traitormod.SelectedGamemode=gm
gm:PreStart()
assert(Game.ServerSettings.MissionTypes=='VoidTraitorStation' and calls.categories==gm.PointshopCategories)
gm:Start()
assert(calls.started and Submarine.MainSub.SubBody.Body.BodyType==0 and not Submarine.LockX and not Submarine.LockY)
gm:Think() gm:Think()
assert(queued==Submarine.MainSub and calls.menu==1,'position or crew shop state was not synchronized')
local parameters={transitionType=0}
patches['Traitormod.Station.EndGame.Before']({},parameters)
assert(parameters.PreventExecution and calls.ending==1)
gm.AllowRealEndGame=true parameters={}
patches['Traitormod.Station.EndGame.Before']({},parameters)
assert(not parameters.PreventExecution,'final ending was blocked')
gm:End()
assert(calls.ended and Game.ServerSettings.MissionTypes=='Salvage')
assert(secret.Name=='Secret' and #secret.PointshopCategories==2,'station mutated Secret defaults')
local originalDofile=dofile
dofile=function() return {} end
ChatMessageType={Private=1}
CharacterTeamType={Team1=1}
Traitormod.Path=modpath
local config=assert(loadfile(modpath..'/Lua/config/baseconfig.lua'))()
dofile=originalDofile
local count=0
for role in pairs(config.GamemodeConfig.Station.TraitorTypeChance) do
    assert(role=='Traitor' or role=='Cultist' or role=='Saboteur' or role=='Clown') count=count+1
end
assert(count==4 and #config.GamemodeConfig.Station.PointshopCategories==4)
assert(config.GamemodeConfig.Station.TraitorTypeChance~=config.GamemodeConfig.Secret.TraitorTypeChance,'submode pool aliases Secret')
return 'PASS foundation mode: independent config/pool, anchored body, static position sync, restricted shop state and native ending'
