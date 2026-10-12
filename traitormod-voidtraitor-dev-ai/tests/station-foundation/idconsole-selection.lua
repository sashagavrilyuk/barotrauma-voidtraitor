local hooks, receivers, sent = {}, {}, {}
Hook = { Add=function(_, id, callback) hooks[id]=callback end, Patch=function() end, HookMethodType={Before=1,After=2} }
Networking = { IsActive=true, Receive=function(id, callback) receivers[id]=callback end,
    Start=function(id) local message={Id=id,WriteUInt16=function() end,WriteString=function() end} return message end,
    Send=function(message) sent[#sent+1]=message.Id end }
UShort=function(value) return value end
json={parse=function() return {} end,serialize=function() return '{}' end}
GUI={}
LuaUserData={CreateEnumTable=function() return {Deselect=1} end}
local common={RemoveGuiComponent=function() end,InstallPausePatch=function() end,UpdateMenuInteraction=function() end}
assert(loadfile(modpath..'/../Void traitor pack/Lua/client/idconsole.lua'))('',common)
local ui=VoidTraitorIdConsoleGuiState
local think=hooks['VoidTraitor.IdConsole.Selection']
local item={ID=1237,Prefab={Identifier='vt_station_access'}}
Character={Controlled={SelectedItem=item}}
think(0.01)
assert(#sent==1 and sent[1]=='VoidTraitor_IdConsoleOpen','selection was not requested immediately')
think(0.049) think(0.002)
assert(#sent==2,'open rejected during selection sync was not retried')
local shown=0
ui.Show=function(id) shown=shown+1 ui.AwaitingOpen=false ui.ItemId=id ui.MenuRoot={} end
local reply={ReadUInt16=function() return item.ID end,ReadString=function() return '{}' end}
receivers.VoidTraitor_IdConsoleSnapshot(reply)
assert(shown==1,'open response ignored')
think(1)
assert(sent[#sent]=='VoidTraitor_IdConsoleAction','open console was not refreshed')
ui.CloseMenu()
local count=#sent
think(1)
receivers.VoidTraitor_IdConsoleSnapshot(reply)
assert(#sent==count and shown==1,'closed console reopened or accepted late snapshot')
Character.Controlled.SelectedItem=nil think(0.01)
Character.Controlled.SelectedItem=item think(0.01)
assert(#sent==count+1 and sent[#sent]=='VoidTraitor_IdConsoleOpen','console could not reopen after reselection')
Networking.IsActive=false think(0.01)
assert(not ui.AwaitingOpen and ui.SelectedItem==nil,'disconnected request retained')
return 'PASS ID console selection: immediate open, retry after rejected request, refresh, close/late reply, reselection, disconnect'
