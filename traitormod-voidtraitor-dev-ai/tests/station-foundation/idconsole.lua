local function sequence(values)
    local index = 0
    return function() index = index + 1 return values[index] end
end
local function identifier(value) return { Value = value } end
Identifier = identifier
local patches = {}
Hook = { Add = function() end, Patch = function(id, _, _, callback) patches[id] = callback end, HookMethodType = {Before=1} }
Networking = { Receive = function() end, CreateEntityEvent = function() end }
Item = { ChangePropertyEventData = function(property) assert(property=='Tags','non-editable ID property sent over the property channel') return {} end }
JobPrefab = { Prefabs={ContainsKey=function(id) return id=='engineer' or id=='captain' or id=='assistant' end}, Get = function(id) return { Name = {Value=id} } end }
local identityEvents = {}
LuaUserData = { CreateStatic=function(kind) return function(item) return {Kind=kind,Item=item} end end,
    IsTargetType=function(data,kind) return data.Kind==kind end }
Entity = { Spawner={CreateNetworkEvent=function(event) identityEvents[#identityEvents+1]=event end} }
Traitormod = { Path=modpath, IsRoundFinalizing=function() return false end }
Traitormod.Config = { IdConsole=dofile(modpath..'/Lua/config/idconsole.lua') }
table.insert(Traitormod.Config.IdConsole.Access,{Tag='vt_access_lab',Name='Laboratory'})
table.insert(Traitormod.Config.IdConsole.Presets,{Id='custom_laboratory',Name='Laboratory technician',Tags={'vt_access_lab','vt_access_engineering'}})
Game = { RoundStarted=true, Server={EntityEventManager={Events=sequence({})}} }
require = function(module)
    if module == 'json' then return { encode=function(parts)
        local result={}
        for _, row in ipairs(parts) do for _, value in ipairs(row) do result[#result+1]=tostring(value) end end
        return table.concat(result,'|')
    end } end
    return {}
end
local console = dofile(modpath..'/Lua/features/idconsole.lua')
local captainPreset
for _, preset in ipairs(console.Config.Presets) do
    if preset.Id=='captain' then captainPreset=preset end
end
assert(captainPreset ~= nil and captainPreset.Tags[#captainPreset.Tags]=='vt_access_lab','AllAccess did not include a user-configured permission')
local function card(id, tags)
    local data = { ID=id, Description='original', Tags='', Name='ID' }
    local info = { OwnerName='Original name', OwnerJobId=identifier('assistant'), OwnerJob={Name={Value='Assistant'}}, Description='original', SerializableProperties=sequence({}) }
    data.SerializableProperties=setmetatable({}, {__index=function(_,key) return key.Value=='Tags' and 'Tags' or nil end})
    data.CreateStatusEvent=function(loading) assert(loading==true) data.StatusSynced=true end
    local function update() local rows={} for tag in pairs(tags) do rows[#rows+1]=tag end table.sort(rows) data.Tags=table.concat(rows,',') end
    data.GetComponentString=function() return info end
    data.HasTag=function(tag) return tags[tag]==true end
    data.AddTag=function(tag) tags[tag]=true update() end
    data.RemoveTag=function(tag) tags[tag.Value]=nil update() end
    data.GetTags=function() local rows={} for tag in pairs(tags) do rows[#rows+1]=identifier(tag) end return sequence(rows) end
    update()
    return data,info
end
local auth=card(1,{vt_access_engineering=true,vt_access_reactor=true})
local target,info=card(2,{vt_access_security=true,['name:Original name']=true,['jobid:assistant']=true,id_medical=true,med=true})
local slots={auth,target}
local item={Prefab={Identifier='vt_station_access'},OwnInventory={GetItemAt=function(index) return slots[index+1] end},CanClientAccess=function() return true end}
local client={Character={IsHuman=true,SelectedItem=item}}
local function payload(tags, name, title) return {Tags=tags,Name=name,Title=title,Revision=console.Revision(item)} end
assert(console.Apply(client,item,payload({'vt_access_security'},info.OwnerName,console.CardTitle(target))))
assert(target.Description=='original' and #identityEvents==0,'saving unchanged identity overwrote original card description')
assert(console.Apply(client,item,payload({'vt_access_security','vt_access_reactor'})))
assert(target.HasTag('vt_access_reactor') and target.HasTag('vt_access_security') and target.HasTag('med'))
assert(not console.Apply(client,item,payload({'vt_access_reactor'})),'engineer revoked security access')
assert(not console.Apply(client,item,payload({'vt_access_security','vt_access_reactor','vt_access_armory'})),'engineer granted armory access')
assert(not console.Apply(client,item,payload({'made_up_access'})),'unknown access accepted')
local stale=payload({'vt_access_security'})
auth.RemoveTag(identifier('vt_access_reactor'))
assert(not console.Apply(client,item,stale),'stale authority accepted')
auth.AddTag('vt_access_reactor')
stale=payload({'vt_access_security'})
slots[2]=card(3,{})
assert(not console.Apply(client,item,stale),'swapped card edited')
slots[2]=target
assert(console.Apply(client,item,payload({'vt_access_security','vt_access_reactor'},'New name','Reactor engineer')))
assert(info.OwnerName=='New name' and target.HasTag('name:New name') and console.CardTitle(target)=='Reactor engineer')
assert(#identityEvents==2 and identityEvents[1].Item==target and identityEvents[2].Item==target,'identity refresh replaced the server card')
assert(target.StatusSynced,'identity refresh lost client condition')
assert(target.HasTag('jobid:assistant') and target.HasTag('id_medical') and target.HasTag('med'),'unrelated ID compatibility tags lost')
local function pending(events) Game.Server.EntityEventManager.Events=sequence(events) end
pending({{Entity=Entity.Spawner,Sent=false,Data={Kind='Barotrauma.EntitySpawner+SpawnEntity',Entity=target}}})
local accepted,reason=console.Apply(client,item,payload({'vt_access_security'},'Next name','Next title'))
assert(not accepted and reason=='IdConsoleSyncing' and info.OwnerName=='New name' and target.HasTag('vt_access_reactor'),'pending spawn did not block identity mutation')
pending({{Entity=Entity.Spawner,Sent=true,Data={Kind='Barotrauma.EntitySpawner+SpawnEntity',Entity=target}}, {Entity=target,Sent=false,Data={Kind='Status'}}})
accepted,reason=console.Apply(client,item,payload({'vt_access_security'},'Next name','Next title'))
assert(not accepted and reason=='IdConsoleSyncing' and info.OwnerName=='New name','pending status after a sent spawn did not block refresh')
pending({{Entity=target,Sent=false,Data={Kind='Status'}}})
assert(console.Apply(client,item,payload({'vt_access_security'})),'pending identity events blocked a rights-only edit')
pending({{Entity=target,Sent=true,Data={Kind='Status'}}})
assert(console.Apply(client,item,payload({'vt_access_security'},'Next name','Next title')),'identity retry after sent events failed')
assert(info.OwnerName=='Next name' and #identityEvents==4)
assert(console.Apply(client,item,{Tags={'vt_access_security','vt_access_reactor'},Job='custom_laboratory',Title='Laboratory technician',Revision=console.Revision(item)}),'custom preset was not accepted')
assert(info.OwnerJobId.Value=='assistant' and target.HasTag('jobid:assistant') and target.HasTag('vt_access_reactor'),'custom preset changed the native job ID')
assert(not console.Apply(client,item,{Tags={'vt_access_lab'},Job='custom_laboratory',Revision=console.Revision(item)}),'custom preset bypassed authorization')
assert(console.Apply(client,item,{Tags={'vt_access_security','vt_access_reactor'},Job='engineer',Title='Engineer',Revision=console.Revision(item)}),'native engineer preset failed')
assert(info.OwnerJobId.Value=='engineer' and target.HasTag('jobid:engineer') and not target.HasTag('jobid:assistant'),'explicit native JobId did not update the card correctly')
assert(not console.Apply(client,item,payload({'vt_access_security'},'bad,tag','Job')),'tag injection accepted')
client.Character.SelectedItem=nil
assert(not console.Apply(client,item,payload({'vt_access_security'})),'remote edit accepted')
client.Character.SelectedItem=item
client.Character.IsIncapacitated=true
assert(not console.Apply(client,item,payload({'vt_access_security'})),'incapacitated edit accepted')
client.Character.IsIncapacitated=false
slots[1]=nil
assert(not console.Apply(client,item,payload({'vt_access_security'})),'missing authority accepted')
assert(patches['Traitormod.IdConsole.Native'],'native console handler missing')
InvSlotType={Card=1}
local captainCard=card(9,{})
console.InitializeCard({Info={Job={Prefab={Identifier=identifier('captain')}}},Inventory={GetItemInLimbSlot=function() return captainCard end}})
assert(captainCard.HasTag('vt_station_original_captain_id'),'genuine captain ID marker was not set')
local fakeCaptain=card(10,{})
fakeCaptain.GetComponentString('IdCard').OwnerJobId=identifier('captain')
Traitormod.RoleManager={Objectives={Objective={new=function(self) return setmetatable({}, {__index=self}) end}}}
Traitormod.SelectedGamemode={Name='Station'}
local steal=dofile(modpath..'/Lua/objectives/stealcaptainid.lua')
steal.Character={Inventory={AllItems=sequence({fakeCaptain})}}
assert(not steal:IsCompleted(),'forged captain job ID counted as stolen captain card')
steal.Character.Inventory.AllItems=sequence({captainCard})
assert(steal:IsCompleted(),'genuine captain card did not complete the objective')
return 'PASS ID console: authority differences, unknown tags, stale/swapped cards, identity, compatibility tags, physical interaction'
