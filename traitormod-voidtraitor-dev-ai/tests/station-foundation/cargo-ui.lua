local hooks, patches, receivers, sent, all = {}, {}, {}, {}, {}
local baseLoad = loadfile
local cargoP
loadfile = function(path)
    local loaded = assert(baseLoad(path))
    return function(...)
        if string.find(path, '/pointshop/', 1, true) then cargoP = (...) end
        return loaded(...)
    end
end
local function size(x,y,relative) return {X=x,Y=y,Relative=relative} end
Point=function(x,y) return size(x,y,false) end
Vector2=function(x,y) return size(x,y,true) end
Color=function(...) return {...} end
local function rect(v,parent)
    local width,height = parent and parent.Size.X or 1600,parent and parent.Size.Y or 900
    return {Parent=parent,Size=size(v.Relative and v.X*width or v.X,v.Relative and v.Y*height or v.Y),MinSize=Point(0,0)}
end
local function component(transform,text)
    local c={RectTransform=transform,Children={},Text=text or '',Visible=true,Enabled=true,BarScroll=0,Rect={X=0,Y=0,Bottom=10,Width=100,Height=50}}
    transform.Component=c
    local parent=transform.Parent and transform.Parent.Component
    if parent then parent.Children[#parent.Children+1]=c end
    function c:ClearChildren() self.Children={} end
    function c:RemoveFromGUIUpdateList() end
    function c:AddToGUIUpdateList(_,order) self.LastDrawOrder=order end
    function c:RecalculateChildren() end
    function c:UpdateScrollBarSize() end
    all[#all+1]=c
    return c
end
GUI={RectTransform=rect,Anchor={Center=1,TopLeft=2,TopCenter=3,BottomLeft=4,CenterLeft=5,CenterRight=6,TopRight=7,BottomCenter=8},
    Pivot={TopLeft=1},Alignment={Left=1,Center=2,Right=3,BottomLeft=4,CenterLeft=5},Style={SubHeadingFont='sub',LargeFont='large',Apply=function() end}}
GUI.Frame=component
GUI.LayoutGroup=component
GUI.TextBlock=component
GUI.TextBox=component
GUI.Image=component
GUI.Button=function(...) local c=component(...) c.TextBlock={Text=c.Text} return c end
GUI.ListBox=function(transform)
    local c=component(transform)
    c.Content=component(rect(Vector2(1,1),transform))
    c.ContentBackground={}
    return c
end
Hook={Add=function(_,id,callback) hooks[id]=callback end,Patch=function(id,...)
    for _,value in ipairs({...}) do if type(value)=='function' then patches[id]=value end end
end,HookMethodType={Before=1,After=2}}
Networking={IsActive=true,Receive=function(id,callback) receivers[id]=callback end,Start=function(id)
    local m={Id=id}
    m.WriteUInt16=function(v) m.ItemId=v end
    m.WriteString=function(v) if not m.Action then m.Action=v else m.Payload=v end end
    return m
end,Send=function(m) sent[#sent+1]=m end}
UShort=function(v) return v end
json={serialize=function(v) return v end,parse=function(v) return v end}
LuaUserData={CreateEnumTable=function() return {Deselect=1,Yes=1,No=2} end}
Timer={GetTime=function() return 0 end,Wait=function(callback) callback() end}
Game={RoundStarted=true}
local common={Language={Pointshop={Categories='categories',BuyTab='products',Total='total',FilterAll='all',FilterAvailable='available',FilterAffordable='affordable',Filter='filter',Search='search',EmptyProducts='emptyproducts'}},
    CreateRect=function(w,h,p) return rect(Vector2(w,h),p and p.RectTransform) end,
    CreateText=function(p,w,h,anchor,text) return component(rect(Vector2(w,h),p and p.RectTransform),text) end,
    RemoveGuiComponent=function(c) if c then c.Visible=false end end,InstallPausePatch=function() end,
    GetPrefabIconData=function() return 'sprite',Color(1,1,1) end,GetScreenSize=function() return 1600,900 end}
VoidTraitorPointshopGuiState={Marker='ordinary shop'}
local ordinary=VoidTraitorPointshopGuiState
assert(baseLoad(packpath..'/Lua/client/cargo.lua'))(packpath,common)
local ui=VoidTraitorCargoGuiState
local think=hooks['VoidTraitor.Cargo.Selection']
local deselected=0
local item={ID=1237,Prefab={Identifier='vt_cargo_console'}}
Character={Controlled={SelectedItem=item,EmulateInput=function() deselected=deselected+1 end}}
think(0.01)
assert(#sent==1 and sent[1].Id=='VoidTraitor_CargoOpen','immediate opening')
think(0.049) think(0.002)
assert(#sent==2,'retry after selection sync')
local function product(id,name,path)
    return {Id=id,Name=name,Category='hardware',Path=path or '',Description='description',Price=10,Currency='кр',Stock=3,Limit=3,AllowQuantity=true,MaxQuantity=3,Type='item',DisabledReason='',IconIdentifier='wrench'}
end
local snapshot={Products={product('hardware:1','Гаечный ключ'),product('hardware:2','Hammer','tools')},Orders={},Budget=0,Reserved=0,CanManage=false,
    Ship={State='Home',SlotsFree=2,SlotsTotal=3,LargeFree=1,LargeTotal=1,SalesValue=0,LastSale=0},
    Text={Title='cargo',Close='close',Budget='budget',Reserved='reserved',Reason='reason',Submit='submit',Approve='approve',Reject='reject',Orders='orders',Quantity='quantity',Pending='pending',Accepted='accepted',Outbound='outbound',Delivered='delivered',Rejected='rejected',Home='home',Capacity='capacity',Large='large',Ship='ship',Sales='sales',LastSale='lastsale',NoShip='noship',Empty='empty',Search='search',Cart='cart'}}
local reply={ReadUInt16=function() return item.ID end,ReadString=function() return snapshot end}
receivers.VoidTraitor_CargoSnapshot(reply)
assert(ui.MenuRoot and ui.MenuRoot.RectTransform.ScreenSpaceOffset.Y == -25 and ui.MenuRoot.RectTransform.Size.X == 800 and ui.MenuRoot.RectTransform.Size.Y == 580 and not ui.AwaitingOpen,'first snapshot did not open')
assert(VoidTraitorPointshopGuiState==ordinary and ordinary.Marker=='ordinary shop','pointshop state mutated')
local p,s=cargoP,cargoP.State
assert(#p.BuildFolderList()==2 and p.FILTER_BAR_HEIGHT == 0.18 and p.FILTER_LABEL_SCALE == 0.95,'compact cargo catalog was not configured')
s.currentView,s.selectedCategory,s.selectedPath='products','hardware',''
p.ShowMenu()
assert(#s.productRows==1 and s.productRows[1].Price.Text=='10 кр','Cargo currency display')
p.ToggleFilterPopup(s.filterButton)
patches['VoidTraitor.Cargo.Hud']()
assert(s.filterPopup.LastDrawOrder==180 and ui.MenuRoot.LastDrawOrder==120,'filter popup below modal')
p.CloseFilterPopup()
local parameters={}
patches['VoidTraitor.Cargo.NativeHud'](item,parameters)
assert(parameters.PreventExecution,'Cargo native HUD not hidden')
parameters={}
patches['VoidTraitor.Cargo.NativeHud']({Prefab={Identifier='terminal'}},parameters)
assert(not parameters.PreventExecution,'ordinary terminal HUD hidden')
assert(p.NormalizeSearchText('ГАЕЧНЫЙ')=='гаечный','Russian normalization')
s.normalizedSearchText=p.NormalizeSearchText('ГАЕЧНЫЙ')
assert(p.ProductMatchesSearchAndFilter(s.products[1]) and not p.ProductMatchesSearchAndFilter(s.products[2]),'catalog search')
s.normalizedSearchText=''
p.AddToCart(s.products[1]) p.AddToCart(s.products[1]) p.AddToCart(s.products[1]) p.AddToCart(s.products[1])
assert(#s.cart==1 and s.cart[1].Quantity==3 and p.GetCartTotal()==30,'cart count/stock/budget semantics')
ui.Reason.Text=' ' p.RefreshCartOnly()
assert(not ui.Submit.Enabled,'blank reason allowed')
ui.Reason.Text='repair' p.RefreshCartOnly()
assert(ui.Submit.Enabled,'request incorrectly blocked by empty station budget')
ui.Submit.OnClicked()
assert(ui.SubmitPending and not ui.Submit.Enabled and #s.cart==1,'draft cleared before response')
assert(sent[#sent].Action=='submit' and sent[#sent].Payload.Entries[1].Quantity==3,'submission payload')
p.AddToCart(s.products[2])
assert(#s.cart==1,'pending draft was edited')
snapshot.Result={Action='submit',Success=false,Message='denied'} snapshot.SubmitAccepted=false
ui.Update(snapshot)
assert(not ui.SubmitPending and #s.cart==1 and ui.Reason.Text=='repair','rejected draft lost')
ui.Submit.OnClicked()
snapshot.Result={Action='submit',Success=true,Message='accepted'} snapshot.SubmitAccepted=true
ui.Update(snapshot)
assert(not ui.SubmitPending and #s.cart==0 and ui.Reason.Text=='','accepted draft retained')
snapshot.Result=nil snapshot.SubmitAccepted=nil
snapshot.Orders={{Id=1,Product='hardware:1',Name='wrench',IconIdentifier='wrench',Quantity=3,Price=30,Reason='repair',Author='alice',Status='pending'}}
local function buttons(parent,out)
    out=out or {}
    if parent.OnClicked then out[parent.Text]=parent end
    for _,child in ipairs(parent.Children) do buttons(child,out) end
    return out
end
ui.Update(snapshot)
local function hasText(parent,text)
    if string.find(tostring(parent.Text),text,1,true) then return true end
    for _,child in ipairs(parent.Children) do if hasText(child,text) then return true end end
    return false
end
assert(hasText(ui.OrderList.Content,'30 кр') and not hasText(ui.OrderList.Content,'90 кр'),'order total multiplied twice')
local controls=buttons(ui.OrderList.Content)
assert(not controls.approve.Enabled and not controls.reject.Enabled,'unprivileged actions enabled')
snapshot.CanManage=true ui.Update(snapshot) controls=buttons(ui.OrderList.Content)
assert(controls.approve.Enabled and controls.reject.Enabled,'manager cannot act on pending')
controls.approve.OnClicked()
assert(sent[#sent].Action=='approve' and sent[#sent].Payload.OrderId==1,'approve ID')
snapshot.Orders[1].Status='accepted' ui.Update(snapshot) controls=buttons(ui.OrderList.Content)
assert(not controls.approve.Enabled and controls.reject.Enabled,'accepted rejection state')
snapshot.Orders[1].Status='outbound' ui.Update(snapshot) controls=buttons(ui.OrderList.Content)
assert(not controls.approve.Enabled and not controls.reject.Enabled,'outbound actions enabled')
local messagesBefore = #sent
think(1)
assert(#sent == messagesBefore, 'idle catalog still requests a full refresh')
Character.Controlled.SelectedItem = nil
think(0.15)
assert(ui.MenuRoot ~= nil, 'transient loss of selection closed the menu')
Character.Controlled.SelectedItem = item
think(0.1)
assert(ui.MenuRoot ~= nil, 'selection recovery did not preserve the menu')
ui.CloseMenu(true)
assert(deselected==1 and not ui.MenuRoot and not Character.Controlled.SelectedItem,'close did not deselect')
local count=#sent
receivers.VoidTraitor_CargoSnapshot(reply)
assert(not ui.MenuRoot and #sent==count,'late reply reopened menu')
think(0.01)
Character.Controlled.SelectedItem=item think(0.01)
assert(sent[#sent].Id=='VoidTraitor_CargoOpen','reselection cannot open')
receivers.VoidTraitor_CargoSnapshot(reply)
assert(ui.MenuRoot and s.shopList and #s.catalogHost.Children>0,'same catalog absent after reopening')
Networking.IsActive=false think(0.01)
assert(not ui.AwaitingOpen and ui.SelectedItem==nil,'disconnect left selection')
local normalP={Common=common,State={currentPoints=100,products={},productById={},cart={},classLimitValues={},classLimitTextBlocks={shop={}},cooldownTextBlocks={shop={}},productRows={}},ITEM_ROW_HEIGHT=0.1,ITEM_ICON_PIXELS=56,ACTION_BUTTON_PIXELS=56,NET_INT32_MAX=2147483647}
for _,name in ipairs({'model_text','model_state','widgets','shop_products'}) do assert(baseLoad(packpath..'/Lua/client/pointshop/'..name..'.lua'))(normalP) end
local normalProduct=product('normal:1','normal') normalProduct.Currency=nil
normalP.AddProductButton(GUI.ListBox(rect(Point(500,500))),normalProduct)
assert(normalP.State.productRows[1].Price.Text=='10 pt','ordinary pointshop currency changed')
return 'PASS Cargo UI: shared catalog/folders/search, independent pointshop state/default pt, bounded cart, required reason, pending/success/rejected drafts, order permissions, modal popup layer, exact native HUD target, immediate/retry opening, refresh, Deselect close, late replies, catalog reopening/disconnect'
