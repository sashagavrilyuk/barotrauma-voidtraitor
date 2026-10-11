local hooks, messages = {},0
Hook={Add=function(_,id,callback) hooks[id]=callback end}
require=function() return {Prompt=function() error('crew saw a shop dialog') end} end
local categories={}
local client={InGame=true,Character={IsHuman=true}}
local currentRole='Crew'
for _,name in ipairs({'traitor','cultist','saboteur','clown','medical'}) do
    categories[#categories+1]={Identifier=name,Products={{Identifier=name..'_product',Price=0}},CanAccess=function() return name=='medical' or name==string.lower(currentRole) end}
end
Traitormod={Config={PointShopConfig={Enabled=true,ItemCategories=categories}},Language={PointshopNotAvailable='Unavailable',PointshopCannotBeUsed='Denied',Pointshop={}},SelectedGamemode={Name='Station'},GetClientAccountKey=function() return 'player' end,IsSecretEnding=function() return false end,SendMessage=function() messages=messages+1 end}
local ps=dofile(modpath..'/Lua/pointshop.lua')
ps.Initialize({'traitor','cultist','saboteur','clown'})
assert(not ps.CanUseShop(client) and not ps.ValidateClient(client))
assert(not ps.CanClientSeeProduct(client,ps.AllCategories.traitor.Products[1]))
assert(ps.BuyProduct(client,ps.AllCategories.traitor.Products[1])=='Denied','direct purchase bypassed station role access')
for _,role in ipairs({'Traitor','Cultist','Saboteur','Clown'}) do
    currentRole=role
    assert(ps.CanUseShop(client) and ps.ValidateClient(client))
    for _,category in ipairs(categories) do
        assert(ps.CanClientSeeProduct(client,category.Products[1])==(category.Identifier==string.lower(role)),'antagonist saw another tab or normal supplies')
    end
end
client.Character.IsDead=true
assert(not ps.CanUseShop(client))
client.Character.IsDead=false
currentRole='Crew' Traitormod.SelectedGamemode.Name='Secret'
ps.Initialize({'medical','traitor'})
assert(ps.CanUseShop(client) and ps.ValidateClient(client) and ps.CanClientSeeProduct(client,ps.AllCategories.medical.Products[1]),'original Secret crew shop changed')
return 'PASS foundation shop: crew denied, all four antagonists only own products, dead denied, original Secret retained'
