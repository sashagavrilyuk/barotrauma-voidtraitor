if SERVER then return end

local packPath, Common = ...
local P = { PackPath = packPath, Common = Common, State = {} }
local S = P.State

-- Void Traitor Pointshop GUI.
-- Client-side visual shell only. The server is still authoritative for prices,
-- limits, stock, cooldowns and actual purchases.

P.NET_READY = "VoidTraitor_PointshopGuiReady"
P.NET_REQUEST = "VoidTraitor_PointshopRequest"
P.NET_SNAPSHOT = "VoidTraitor_PointshopSnapshot"
P.NET_STATE = "VoidTraitor_PointshopState"
P.NET_BALANCE = "VoidTraitor_PointshopBalance"
P.NET_PRODUCT_STATE = "VoidTraitor_PointshopProductState"
P.NET_BUY_CART = "VoidTraitor_PointshopBuyCart"
P.NET_PROBE = "VoidTraitor_PointshopProbe"
P.NET_PURCHASE_SOUND = "VoidTraitor_PointshopPurchaseSound"
P.NET_CLASS_LIMITS = "VoidTraitor_PointshopClassLimits"
P.NET_CLOSE_LOCK = "VoidTraitor_PointshopCloseLock"

P.GUI_DRAW_ORDER = 120
P.PANEL_WIDTH = 0.290
P.ITEM_ROW_HEIGHT = 0.124
P.ITEM_ICON_PIXELS = 86
P.ACTION_BUTTON_PIXELS = 102
P.NET_INT32_MAX = 2147483647

S.currentMenu = nil
S.cartPanelRoot = nil
S.shopList = nil
S.shopListScroll = 0
S.escapeClosePending = false
S.products = {}
S.productById = {}
S.cart = {}
S.selectedCategory = nil
S.selectedPath = nil
S.selectedProductId = nil
S.currentView = "categories"
S.currentPoints = 0
S.lastMessage = ""
S.shopMode = "shop"
S.pendingProductId = nil
S.closeMenuAfterSnapshot = false
S.expandedFolders = {}
S.cooldownTextBlocks = { shop = {}, cart = {} }
S.classLimitTextBlocks = { shop = {}, cart = {} }
S.classLimitValues = {}
S.nextCooldownTextUpdateTime = 0
S.cooldownSnapshotRequested = false
S.buyRequestPending = false
S.searchText = ""
S.normalizedSearchText = ""
S.selectedFilter = "all"
S.productRows = {}
S.rebuildProductList = nil
S.filterPopup = nil
S.filterButton = nil

P.GLOBAL_STATE_KEY = "VoidTraitorPointshopGuiState"
P.HUD_PATCH_ID = "VoidTraitor.PointshopGui.Hud"
P.PAUSE_PATCH_ID = "VoidTraitor.PointshopGui.Pause"

local previousState = rawget(_G, P.GLOBAL_STATE_KEY)
if previousState ~= nil then
    previousState.Disabled = true
    if previousState.CloseMenu ~= nil then previousState.CloseMenu() end
    Common.RemoveGuiComponent(previousState.GuiRoot)
end
S.sharedState = { Disabled = false, CloseLocked = false }
_G[P.GLOBAL_STATE_KEY] = S.sharedState

local modulePath = packPath .. "/Lua/client/pointshop/"
assert(loadfile(modulePath .. "model_text.lua"))(P)
assert(loadfile(modulePath .. "model_state.lua"))(P)
assert(loadfile(modulePath .. "model_network.lua"))(P)
assert(loadfile(modulePath .. "model_folders.lua"))(P)
assert(loadfile(modulePath .. "widgets.lua"))(P)
assert(loadfile(modulePath .. "shop_categories.lua"))(P)
assert(loadfile(modulePath .. "shop_products.lua"))(P)
assert(loadfile(modulePath .. "shop_filters.lua"))(P)
assert(loadfile(modulePath .. "shop_panel.lua"))(P)
assert(loadfile(modulePath .. "cart_items.lua"))(P)
assert(loadfile(modulePath .. "cart_panel.lua"))(P)

P.CloseMenu = function(preserveNavigation)
    if P.CloseFilterPopup ~= nil then P.CloseFilterPopup() end

    if S.shopList ~= nil then
        S.shopListScroll = S.shopList.BarScroll
    end
    S.shopList = nil

    Common.RemoveGuiComponent(S.currentMenu)


    S.currentMenu = nil
    S.sharedState.CurrentMenu = nil
    S.cartPanelRoot = nil
    S.filterButton = nil
    S.rebuildProductList = nil
    S.productRows = {}
    S.cooldownTextBlocks.shop = {}
    S.cooldownTextBlocks.cart = {}
    S.classLimitTextBlocks.shop = {}
    S.classLimitTextBlocks.cart = {}
    S.escapeClosePending = false
    S.buyRequestPending = false

    if not preserveNavigation then
        S.currentView = "categories"
        S.selectedCategory = nil
        S.selectedPath = nil
        S.selectedProductId = nil
        S.pendingProductId = nil
        S.shopListScroll = 0
    end
end

P.ShowMenu = function()
    P.CloseMenu(true)
    S.cooldownTextBlocks.shop = {}
    S.cooldownTextBlocks.cart = {}
    S.classLimitTextBlocks.shop = {}
    S.classLimitTextBlocks.cart = {}
    S.nextCooldownTextUpdateTime = 0

    local overlay = GUI.Frame(P.CreateRect(1, 1, S.guiRoot, GUI.Anchor.Center), nil)
    overlay.Color = Color(0, 0, 0, 191)
    overlay.CanBeFocused = false
    overlay.IgnoreLayoutGroups = true
    S.currentMenu = overlay
    S.sharedState.CurrentMenu = overlay

    P.BuildShopPanel(overlay)
    S.cartPanelRoot = P.BuildCartPanel(overlay)
    S.guiRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)
end

function P.SendReady()
    local msg = Networking.Start(P.NET_READY)
    Networking.Send(msg)
end

function P.RequestSnapshot()
    local msg = Networking.Start(P.NET_REQUEST)
    Networking.Send(msg)
end

S.sharedState.CloseMenu = P.CloseMenu

P.SendReady()
Timer.Wait(function() if not S.sharedState.Disabled then P.SendReady() end end, 2000)
Timer.Wait(function() if not S.sharedState.Disabled then P.SendReady() end end, 6000)

S.guiRoot = GUI.Frame(P.CreateRect(1, 1, nil, GUI.Anchor.Center), nil)
S.guiRoot.Color = Color(0, 0, 0, 0)
S.guiRoot.CanBeFocused = false
S.guiRoot.IgnoreLayoutGroups = true
S.sharedState.GuiRoot = S.guiRoot
S.guiRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)

-- Reinsert the root when Barotrauma rebuilds the GUI update list.
Hook.Patch(P.HUD_PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state ~= nil and state.GuiRoot ~= nil and not state.Disabled then
        state.GuiRoot:AddToGUIUpdateList(false, P.GUI_DRAW_ORDER)
    end
end)

-- ESC guard: close the shop instead of opening the vanilla pause menu.
Hook.Patch(P.PAUSE_PATCH_ID, "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, params)
    local state = rawget(_G, P.GLOBAL_STATE_KEY)
    if state ~= nil and not state.Disabled and (state.CurrentMenu ~= nil or state.BlockPauseMenu == true) then
        if state.CurrentMenu ~= nil and state.CloseMenu ~= nil and state.CloseLocked ~= true then
            state.CloseMenu()
        end
        if params ~= nil then params.PreventExecution = true end
        return false
    end
end, Hook.HookMethodType.Before)

function P.RequestEscapeClose()
    if S.currentMenu == nil or S.escapeClosePending or S.sharedState.CloseLocked == true then return end
    S.escapeClosePending = true
    S.sharedState.BlockPauseMenu = true
    P.CloseMenu()
    Timer.Wait(function()
        S.sharedState.BlockPauseMenu = false
    end, 250)
end

-- keyUpdate fires before the game's ESC handler.
Hook.Add("keyUpdate", "VoidTraitor.PointshopGui.PauseGuard", function()
    if S.sharedState.Disabled then return end
    if S.currentMenu ~= nil and PlayerInput.KeyHit(Keys.Escape) then
        P.RequestEscapeClose()
    end
end)

function P.SendBuyRequest(entries)
    if entries == nil or #entries == 0 then return end
    if S.buyRequestPending then return end

    local msg = Networking.Start(P.NET_BUY_CART)
    msg.WriteInt32(#entries)
    for _, entry in ipairs(entries) do
        msg.WriteString(entry.Id)
        msg.WriteInt32(entry.Quantity or 1)
    end
    Networking.Send(msg)

    S.buyRequestPending = true
    Timer.Wait(function()
        S.buyRequestPending = false
    end, 1500)
end


return P