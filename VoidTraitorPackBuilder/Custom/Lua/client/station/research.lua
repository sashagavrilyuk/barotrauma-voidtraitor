if SERVER then return end
-- The research console and the lathes (traitormod Lua/gamemodes/station/research.lua). The console shows Goob Station's
-- tree: technologies are cells joined by lines from what they require, the tree is dragged with the mouse, and a click
-- shows a technology on the right with its research button. Each lathe prints only what the server allows, so research
-- opens recipes here as on the server; a finished technology is written over its console.
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorResearchGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
end
local UI = { Pan = Vector2(0, 0) }
_G.VoidTraitorResearchGuiState = UI
-- read without this, the dictionary of a fabricator's recipes turns into a Lua table that cannot be put back
LuaUserData.RegisterType("System.Collections.Immutable.ImmutableDictionary`2[[System.UInt32],[Barotrauma.FabricationRecipe]]")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Fabricator"], "fabricationRecipes")
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
local teams = LuaUserData.CreateEnumTable("Barotrauma.CharacterTeamType")

-- the distance between cells of the tree: the tree fits its view, within these bounds; a cell takes most of it
local MIN_STEP_PIXELS, MAX_STEP_PIXELS, NODE_SHARE = 56, 84, 0.62
local STATE_COLORS = {
    researched = Color(90, 200, 110, 255),
    available = Color(230, 230, 220, 255),
    unaffordable = Color(225, 185, 80, 255),
    locked = Color(90, 90, 90, 255),
}
local NODE_BACKGROUND = Color(18, 22, 24, 240)
local LINE_COLOR = Color(110, 110, 100, 255)
local MUTED_COLOR = Color(160, 160, 150, 255)

-- What each kind of lathe prints, from the server, and each lathe's full recipes, put back before every new filter.
local allowedRecipes, fullRecipes = nil, {}

local function needsRecipe(identifier)
    if not ItemPrefab.Prefabs.ContainsKey(identifier) then return false end
    for recipe in ItemPrefab.Prefabs[identifier].FabricationRecipes.Values do
        if recipe.RequiresRecipe then return true end
    end
    return false
end

local function filterLathe(item)
    local list = allowedRecipes[item.Prefab.Identifier.Value]
    if list == nil then return end
    local fabricator = item.GetComponentString("Fabricator")
    if fullRecipes[item] == nil then fullRecipes[item] = fabricator.fabricationRecipes end
    fabricator.fabricationRecipes = fullRecipes[item]
    local ids = {}
    for _, id in ipairs(list) do ids[#ids + 1] = Identifier(id) end
    fabricator.RemoveFabricationRecipes(ids)
end

-- recipes that need an unlock open for the crew without the game's message over every crew member's head
local function unlockRecipes()
    if Game.GameSession == nil then return end
    for _, list in pairs(allowedRecipes) do
        for _, id in ipairs(list) do
            if needsRecipe(id) then Game.GameSession.UnlockRecipe(teams.Team1, Identifier(id), false) end
        end
    end
end

function UI.Send(action, value)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_ResearchAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
    message.WriteString(value or "")
    Networking.Send(message)
end

function UI.CloseMenu()
    UI.Send("close")
    local character = Character.Controlled
    if character ~= nil and character.SelectedItem ~= nil and character.SelectedItem.ID == UI.ItemId then
        character.EmulateInput(inputTypes.Deselect)
        character.SelectedItem = nil
    end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update, UI.SelectedItem = nil, nil, nil, nil, nil
    UI.Snapshot, UI.Selected, UI.Drag, UI.NodeRects, UI.Tree = nil, nil, nil, nil, nil
end

local function createWrappedText(parent, value, color, font)
    local block = Common.CreateText(parent, 1, 1, nil, value, GUI.Alignment.TopLeft, 1, color, true)
    if font ~= nil then block.Font = font end
    block.CanBeFocused = false
    block.CalculateHeightFromText()
    Common.SetFixedHeight(block, block.Rect.Height)
    return block
end

local function itemSprite(identifier)
    if not ItemPrefab.Prefabs.ContainsKey(identifier) then return nil end
    local prefab = ItemPrefab.Prefabs[identifier]
    return prefab.InventoryIcon or prefab.Sprite, prefab
end

-- the part of the segment a-b inside the rectangle (Liang-Barsky), or nil
local function clipLine(a, b, rect)
    local t0, t1 = 0, 1
    local dx, dy = b.X - a.X, b.Y - a.Y
    for _, edge in ipairs({ { -dx, a.X - rect.X }, { dx, rect.X + rect.Width - a.X }, { -dy, a.Y - rect.Y }, { dy, rect.Y + rect.Height - a.Y } }) do
        local p, q = edge[1], edge[2]
        if p == 0 then
            if q < 0 then return nil end
        else
            local t = q / p
            if p < 0 then
                if t > t1 then return nil end
                if t > t0 then t0 = t end
            else
                if t < t0 then return nil end
                if t < t1 then t1 = t end
            end
        end
    end
    return Vector2(a.X + t0 * dx, a.Y + t0 * dy), Vector2(a.X + t1 * dx, a.Y + t1 * dy)
end

local function treeBounds()
    local bounds = { MinX = math.huge, MaxX = -math.huge, MinY = math.huge, MaxY = -math.huge }
    for _, technology in ipairs(UI.Snapshot.Technologies) do
        bounds.MinX, bounds.MaxX = math.min(bounds.MinX, technology.Position[1]), math.max(bounds.MaxX, technology.Position[1])
        bounds.MinY, bounds.MaxY = math.min(bounds.MinY, technology.Position[2]), math.max(bounds.MaxY, technology.Position[2])
    end
    return bounds
end

local function treeStep(rect)
    local bounds = treeBounds()
    local fit = math.min(rect.Width / (bounds.MaxX - bounds.MinX + 1.5), rect.Height / (bounds.MaxY - bounds.MinY + 1.5))
    return math.max(Common.SafeIntScale(MIN_STEP_PIXELS), math.min(Common.SafeIntScale(MAX_STEP_PIXELS), math.floor(fit)))
end

local function nodeCenter(rect, step, technology)
    return Vector2(rect.Center.X + UI.Pan.X + technology.Position[1] * step, rect.Center.Y + UI.Pan.Y + technology.Position[2] * step)
end

-- the middle of the tree goes to the middle of the view
local function recenter()
    local bounds, step = treeBounds(), treeStep(UI.Tree.Rect)
    UI.Pan = Vector2(-(bounds.MinX + bounds.MaxX) / 2 * step, -(bounds.MinY + bounds.MaxY) / 2 * step)
end

local function drawTree(spriteBatch, component)
    local snapshot, rect = UI.Snapshot, component.Rect
    if snapshot == nil then return end
    local byId, rects, step = {}, {}, treeStep(rect)
    for _, technology in ipairs(snapshot.Technologies) do byId[technology.Id] = technology end
    for _, technology in ipairs(snapshot.Technologies) do
        for _, id in ipairs(technology.Requires) do
            local from = byId[id]
            if from ~= nil then
                local a, b = clipLine(nodeCenter(rect, step, from), nodeCenter(rect, step, technology), rect)
                if a ~= nil then
                    local color = from.State == "researched" and technology.State == "researched" and STATE_COLORS.researched or LINE_COLOR
                    GUI.DrawLine(spriteBatch, a, b, color, 0, 2)
                end
            end
        end
    end
    local size = math.floor(step * NODE_SHARE)
    local hovered
    for _, technology in ipairs(snapshot.Technologies) do
        local center = nodeCenter(rect, step, technology)
        local x, y = math.floor(center.X - size / 2), math.floor(center.Y - size / 2)
        if x >= rect.X and y >= rect.Y and x + size <= rect.X + rect.Width and y + size <= rect.Y + rect.Height then
            local color = STATE_COLORS[technology.State]
            GUI.DrawRectangle(spriteBatch, Vector2(x, y), Vector2(size, size), NODE_BACKGROUND, true)
            GUI.DrawRectangle(spriteBatch, Vector2(x, y), Vector2(size, size), color, false, 0, UI.Selected == technology.Id and 4 or 2)
            local sprite = itemSprite(technology.Icon)
            if sprite ~= nil then
                local scale = size * 0.75 / math.max(sprite.size.X, sprite.size.Y)
                sprite.Draw(spriteBatch, center, technology.State == "locked" and Color(110, 110, 110, 255) or Color(255, 255, 255, 255), 0, scale)
            end
            rects[technology.Id] = { X = x, Y = y, Size = size }
            local mouse = PlayerInput.MousePosition
            if GUI.MouseOn == component and mouse.X >= x and mouse.X <= x + size and mouse.Y >= y and mouse.Y <= y + size then
                hovered = technology
            end
        end
    end
    UI.NodeRects = rects
    if hovered ~= nil then
        local mouse = PlayerInput.MousePosition
        GUI.DrawString(spriteBatch, Vector2(mouse.X + size * 0.4, mouse.Y + size * 0.2), hovered.Name, STATE_COLORS[hovered.State],
            Color(0, 0, 0, 220), 4, GUI.Style.SmallFont)
    end
end

-- A press on the tree starts a drag; a release without moving picks the technology under the mouse. Called from the
-- module's think hook: LuaCs cannot pass a Lua function as the custom component's update callback.
local function updateTree(component)
    local mouse = PlayerInput.MousePosition
    if UI.Drag == nil and GUI.MouseOn == component and PlayerInput.PrimaryMouseButtonDown() then
        UI.Drag = { Start = mouse, Pan = UI.Pan, Moved = false }
    end
    local drag = UI.Drag
    if drag == nil then return end
    if PlayerInput.PrimaryMouseButtonHeld() then
        local dx, dy = mouse.X - drag.Start.X, mouse.Y - drag.Start.Y
        if math.abs(dx) + math.abs(dy) > Common.SafeIntScale(4) then drag.Moved = true end
        if drag.Moved then UI.Pan = Vector2(drag.Pan.X + dx, drag.Pan.Y + dy) end
        return
    end
    UI.Drag = nil
    if drag.Moved or UI.NodeRects == nil then return end
    for id, node in pairs(UI.NodeRects) do
        if mouse.X >= node.X and mouse.X <= node.X + node.Size and mouse.Y >= node.Y and mouse.Y <= node.Y + node.Size then
            UI.Selected = id
            UI.ShowTechnology()
            return
        end
    end
end

function UI.ShowTechnology()
    local snapshot, layout = UI.Snapshot, UI.InfoLayout
    local text = snapshot.Text
    layout.ClearChildren()
    local technology
    for _, entry in ipairs(snapshot.Technologies) do
        if entry.Id == UI.Selected then technology = entry end
    end
    if technology == nil then
        createWrappedText(layout, text.ResearchSelect, MUTED_COLOR)
        UI.InfoFrame.ForceLayoutRecalculation()
        return
    end
    local discipline
    for _, entry in ipairs(snapshot.Disciplines) do
        if entry.Id == technology.Discipline then discipline = entry end
    end
    createWrappedText(layout, technology.Name, STATE_COLORS[technology.State], GUI.Style.SubHeadingFont)
    createWrappedText(layout, discipline.Name .. " · " .. string.format(text.ResearchTier, technology.Tier),
        Color(discipline.Color[1], discipline.Color[2], discipline.Color[3], 255))
    createWrappedText(layout, string.format(text.ResearchCost, technology.Cost))
    createWrappedText(layout, technology.Description, MUTED_COLOR)
    local missingRequired = false
    if #technology.Requires > 0 then
        local names = {}
        for _, id in ipairs(technology.Requires) do
            for _, entry in ipairs(snapshot.Technologies) do
                if entry.Id == id then
                    names[#names + 1] = entry.Name
                    if entry.State ~= "researched" then missingRequired = true end
                end
            end
        end
        createWrappedText(layout, text.ResearchRequires .. " " .. table.concat(names, ", "))
    end
    createWrappedText(layout, text.ResearchUnlocks)
    local list = GUI.ListBox(Common.CreateRect(1, 1, layout), false, nil, "GUIListBoxNoBorder")
    local rowHeight = Common.GetTextHeight(GUI.Style.Font) + Common.GetGap()
    for _, recipe in ipairs(technology.Recipes) do
        local sprite, prefab = itemSprite(recipe.Item)
        local row = GUI.LayoutGroup(Common.CreateRect(1, 1, list.Content), true, GUI.Anchor.CenterLeft)
        Common.SetFixedHeight(row, rowHeight)
        row.Stretch = true
        row.AbsoluteSpacing = Common.GetGap()
        row.CanBeFocused = false
        local iconRect = GUI.RectTransform(Point(rowHeight, rowHeight), row.RectTransform)
        iconRect.IsFixedSize = true
        if sprite ~= nil then GUI.Image(iconRect, sprite, true).CanBeFocused = false end
        local name = prefab ~= nil and prefab.Name.Value or recipe.Item
        local label = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), row.RectTransform), name .. " (" .. recipe.Lathe .. ")", nil, GUI.Style.SmallFont, GUI.Alignment.CenterLeft)
        label.CanBeFocused = false
        Common.SetAutoScaleText(label, 1)
    end
    local status
    if technology.State == "researched" then status = nil
    elseif snapshot.Server ~= nil then status = snapshot.Server
    elseif technology.State == "locked" then status = missingRequired and text.ResearchMissingRequired or text.ResearchLockedTier
    elseif technology.State == "unaffordable" then status = text.ResearchNotEnough
    elseif not snapshot.Access then status = text.ResearchNoAccess end
    if status ~= nil then createWrappedText(layout, status, STATE_COLORS.unaffordable) end
    local button = Common.CreateButton(layout, 1, technology.State == "researched" and text.ResearchDoneButton or text.ResearchButton)
    button.Enabled = technology.State == "available" and snapshot.Access and snapshot.Server == nil
    button.OnClicked = function()
        UI.Send("research", technology.Id)
        return true
    end
    UI.InfoFrame.ForceLayoutRecalculation()
end

local function updateHeader()
    local snapshot = UI.Snapshot
    local text = snapshot.Text
    UI.PointsLabel.Text = snapshot.Server or string.format(text.ResearchPoints, snapshot.Points)
    UI.PointsLabel.TextColor = snapshot.Server ~= nil and STATE_COLORS.unaffordable or Color(235, 235, 225, 255)
    for index, discipline in ipairs(snapshot.Disciplines) do
        UI.DisciplineLabels[index].Text = discipline.Name .. ": " .. string.format(text.ResearchTier, discipline.Tier) .. " · "
            .. string.format(text.ResearchTierShare, discipline.Share)
    end
end

function UI.Show(itemId, snapshot)
    UI.Snapshot = snapshot
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update() return end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.ItemId, UI.Selected = itemId, nil
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(math.min(Common.SafeIntScale(1100), screenWidth * 0.9))
    local height = math.floor(math.min(Common.SafeIntScale(780), screenHeight * 0.85))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, text.ResearchTitle, text.ResearchClose, function()
        UI.CloseMenu()
        return true
    end)
    local header = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true, GUI.Anchor.CenterLeft)
    Common.SetFixedHeight(header, Common.GetTextHeight(GUI.Style.Font))
    header.Stretch = true
    header.AbsoluteSpacing = Common.GetGap() * 3
    header.CanBeFocused = false
    UI.PointsLabel = GUI.TextBlock(GUI.RectTransform(Vector2(0.24, 1), header.RectTransform), "", nil, nil, GUI.Alignment.CenterLeft)
    Common.SetAutoScaleText(UI.PointsLabel, 1)
    UI.DisciplineLabels = {}
    for index, discipline in ipairs(snapshot.Disciplines) do
        local label = GUI.TextBlock(GUI.RectTransform(Vector2(0.19, 1), header.RectTransform), "",
            Color(discipline.Color[1], discipline.Color[2], discipline.Color[3], 255), GUI.Style.SmallFont, GUI.Alignment.CenterLeft)
        Common.SetAutoScaleText(label, 1)
        label.CanBeFocused = false
        UI.DisciplineLabels[index] = label
    end
    Common.CreateDivider(layout)
    local body = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
    body.Stretch = true
    body.AbsoluteSpacing = Common.GetGap()
    local treeFrame = GUI.Frame(Common.CreateRect(0.68, 1, body), "GUIFrameListBox")
    UI.Tree = GUI.CustomComponent(GUI.RectTransform(Vector2(1, 1), treeFrame.RectTransform), drawTree)
    local recenterButton = GUI.Button(GUI.RectTransform(Point(Common.SafeIntScale(120), Common.GetStyleHeight("GUIButtonSmall")),
        treeFrame.RectTransform, GUI.Anchor.TopRight), text.ResearchRecenter, GUI.Alignment.Center, "GUIButtonSmall")
    recenterButton.RectTransform.AbsoluteOffset = Point(Common.GetGap(), Common.GetGap())
    recenterButton.OnClicked = function()
        recenter()
        return true
    end
    UI.InfoFrame = GUI.Frame(Common.CreateRect(0.32, 1, body), "GUIFrameListBox")
    UI.InfoLayout = Common.CreateWindowContent(UI.InfoFrame)
    UI.Update = function()
        updateHeader()
        UI.ShowTechnology()
    end
    root.ForceLayoutRecalculation()
    recenter()
    UI.Update()
end

Networking.Receive("VoidTraitor_ResearchRecipes", function(message)
    allowedRecipes = json.parse(message.ReadString())
    for item in Item.ItemList do filterLathe(item) end
    unlockRecipes()
end)
Networking.Receive("VoidTraitor_ResearchSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.SelectedItem ~= nil and UI.SelectedItem.ID == itemId
        and character.SelectedItem == UI.SelectedItem then UI.Show(itemId, snapshot) end
end)
Networking.Receive("VoidTraitor_ResearchDone", function(message)
    local console, text = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    if console == nil or console.Removed then return end
    GUI.AddMessage(text, STATE_COLORS.researched, console.WorldPosition + Vector2(0, console.Rect.Height * 0.6), Vector2(0, 25), 5, true)
end)
Hook.Add("item.created", "VoidTraitor.Research.Lathe", function(item)
    if allowedRecipes == nil or allowedRecipes[item.Prefab.Identifier.Value] == nil then return end
    filterLathe(item)
    unlockRecipes()
end)
Common.AddWindowLayer(120, function()
    if not UI.Disabled and UI.MenuRoot ~= nil then UI.MenuRoot:AddToGUIUpdateList(false, 0) end
end)
Common.InstallPausePatch("VoidTraitor.Research.Pause", "VoidTraitorResearchGuiState")
Hook.Patch("VoidTraitor.Research.Inventory", "Barotrauma.CharacterHUD", "LockInventory", { "Barotrauma.Character" }, function(_, parameters)
    if not UI.Disabled and UI.CurrentMenu ~= nil and parameters["character"] == Character.Controlled then return true end
end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitor.Research.End", function()
    UI.CloseMenu()
    allowedRecipes, fullRecipes = nil, {}
end)
Hook.Add("think", "VoidTraitor.Research.Selection", function()
    Common.UpdateSelectedItemMenu(UI, "vt_rnd_console", function(selected)
        local message = Networking.Start("VoidTraitor_ResearchOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
    if not UI.Disabled and UI.Tree ~= nil then updateTree(UI.Tree) end
end)
-- a client that joins during a round asks for the lathes' recipes
if Networking.IsActive then Networking.Send(Networking.Start("VoidTraitor_ResearchRequest")) end
