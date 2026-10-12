local calls, queued, patches = {}, nil, {}
LuaUserData = {
    CreateEnumTable=function() return {Static=0, None=0} end,
    IsRegistered=function() return true end,
    RegisterType=function() return {} end,
    MakePropertyAccessible=function() end
}
Descriptors = {}
Hook={Patch=function(id,_,_,callback) patches[id]=callback end,Add=function() end,HookMethodType={Before=1,After=2}}
Character={CharacterList=function() end}
Game={RoundStarted=true,ServerSettings={MissionTypes='Salvage'},NetLobbyScreen={},GameSession={Missions=function() end}}
Submarine={MainSub={SubBody={Body={BodyType=2}}}}
local client={}
client.PendingPositionUpdates={Contains=function() return queued~=nil end,Enqueue=function(sub) queued=sub end}
Client={ClientList={client}}
Traitormod={Path=modpath,Cargo={Start=function() calls.cargo=true end},Gamemodes={Gamemode={PreStart=function(self) calls.categories=self.PointshopCategories end}},Pointshop={CanUseShop=function() return false end},ClientMenu={SendSnapshot=function() calls.menu=(calls.menu or 0)+1 end}}
function Traitormod.Gamemodes.Gamemode:new(o) o=o or {} setmetatable(o,self) self.__index=self return o end
local secret=dofile(modpath..'/Lua/gamemodes/secret.lua')
Traitormod.Gamemodes.Secret=secret
secret.PointshopCategories={'medical','traitor'}
secret.Start=function() calls.started=true end
secret.Think=function() error('station called travel-ending Secret Think') end
secret.BeginEnding=function() calls.ending=(calls.ending or 0)+1 end
secret.End=function() calls.ended=true end
local gm=dofile(modpath..'/Lua/gamemodes/station.lua'):new()
gm.PointshopCategories={'traitor','cultist','saboteur','clown'}
Traitormod.SelectedGamemode=gm
assert(gm.UsesSecretRules and gm.RestrictShopToAccessibleCategories and not patches['Traitormod.Station.EndGame.Before'],'station must share the Secret ending hook')
gm:PreStart()
assert(Game.ServerSettings.MissionTypes=='VoidTraitorStation' and calls.categories==gm.PointshopCategories)
gm:Start()
assert(calls.started and calls.cargo and Submarine.MainSub.SubBody.Body.BodyType==0 and not Submarine.LockX and not Submarine.LockY)
gm:Think() gm:Think()
assert(queued==Submarine.MainSub and calls.menu==1,'position or crew shop state was not synchronized')
local hook=assert(patches['Traitormod.Secret.EndGame.Before'])
local instance={EndRoundTimer=9}
local parameters={transitionType=0}
hook(instance,parameters)
assert(parameters.PreventExecution and calls.ending==1,'station did not enter the shared ending flow')
gm.Ending=true parameters={}
hook(instance,parameters)
assert(parameters.PreventExecution and instance.EndRoundTimer==0.1,'ending timeout was not postponed')
gm.AllowRealEndGame=true gm.EndTransitionStarted=false parameters={}
gm.FinishEnding=function() calls.finish=(calls.finish or 0)+1 end
hook(instance,parameters)
assert(parameters.PreventExecution and calls.finish==1 and not gm.AllowRealEndGame,'early force end bypassed summary flow')
gm.AllowRealEndGame=true gm.EndTransitionStarted=true parameters={}
hook(instance,parameters)
assert(not parameters.PreventExecution,'final native EndGame was blocked')
Traitormod.SelectedGamemode=secret:new()
parameters={}
hook(instance,parameters)
assert(parameters.PreventExecution and calls.ending==2,'Secret ending flow was broken')
Traitormod.SelectedGamemode={Name='AttackDefendV2'}
parameters={}
hook(instance,parameters)
assert(not parameters.PreventExecution,'unrelated gamemode was intercepted')
Traitormod.SelectedGamemode=gm
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
return 'PASS foundation mode: independent config, anchored body, position sync, shop state, shared EndGame flow'
