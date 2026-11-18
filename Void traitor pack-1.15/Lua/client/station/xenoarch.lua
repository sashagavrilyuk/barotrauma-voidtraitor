if SERVER then return end
-- Xenoarchaeology on the client (traitormod Lua/gamemodes/station/xenoarch.lua): what artifacts look and sound like when
-- they go off, and the analysis console's window: the scanned artifact's node map, as in SS14's newer analysis console,
-- the node picked on it, and the buttons that scan the artifact on the analyzer and extract its points.
local packPath, Common = ...
local previous = rawget(_G, "VoidTraitorAnalysisGuiState")
if previous ~= nil then
    previous.Disabled = true
    Common.RemoveGuiComponent(previous.MenuRoot)
end
local UI = {}
_G.VoidTraitorAnalysisGuiState = UI
local inputTypes = LuaUserData.CreateEnumTable("Barotrauma.InputType")
local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local SOUND_RANGE, SOUND_GAIN = 1500, 0.8
local NODE_COLORS = {
    unknown = Color(70, 72, 74, 255),
    discovered = Color(160, 160, 150, 255),
    triggered = Color(90, 200, 110, 255),
}
local CURRENT_COLOR, LINE_COLOR, TEXT_COLOR = Color(235, 190, 80, 255), Color(100, 100, 92, 255), Color(230, 230, 220, 255)
local MUTED_COLOR, PROBLEM_COLOR = Color(160, 160, 150, 255), Color(225, 185, 80, 255)

-- An artifact sounds and sparkles as its own vanilla or More Arts item did (vtsound and vtparticle in
-- items/artifacts.xml); one without a sound of its own has SS14's activation sounds. The game loads a sound in the
-- background and skips playing it until then, so all of them load with the module.
local function loadSound(file)
    return gameMain.SoundManager.LoadSound((string.gsub(file, "%%ModDir%%", packPath)))
end
local fallbackSounds, ownSounds = {}, {}
for index = 1, 7 do fallbackSounds[index] = loadSound(packPath .. "/Sounds/Xenoarch/artifact" .. index .. ".ogg") end
for prefab in ItemPrefab.Prefabs do
    local file = prefab.ConfigElement.GetAttributeString("vtsound", "")
    if file ~= "" and ownSounds[file] == nil then ownSounds[file] = loadSound(file) end
end
local scanSound = loadSound(packPath .. "/Sounds/Xenoarch/scan_finish.ogg")

local function activationSound(prefab)
    local file = prefab.ConfigElement.GetAttributeString("vtsound", "")
    return ownSounds[file] or fallbackSounds[math.random(#fallbackSounds)]
end

local function sparkle(prefab, position, amount)
    local particle = prefab.ConfigElement.GetAttributeString("vtparticle", "")
    if particle == "" then return end
    for _ = 1, amount do
        gameMain.ParticleManager.CreateParticle(particle, position, Vector2(math.random(-60, 60), math.random(-20, 80)), 0, nil)
    end
end

Networking.Receive("VoidTraitor_ArtifactFx", function(message)
    local artifact, kind = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    local position = Vector2(message.ReadSingle(), message.ReadSingle())
    local range = message.ReadSingle()
    if kind == "explosion" then
        -- only the look: the server already dealt the damage
        Explosion(range, 0, 0, 0, 0, 0).Explode(position, nil)
    elseif artifact ~= nil and not artifact.Removed then
        sparkle(artifact.Prefab, position, kind == "flash" and 25 or 10)
        if kind == "activation" then activationSound(artifact.Prefab).Play(SOUND_GAIN, SOUND_RANGE, position) end
    end
end)

function UI.Send(action)
    if UI.ItemId == nil or not Networking.IsActive then return end
    local message = Networking.Start("VoidTraitor_AnalysisAction")
    message.WriteUInt16(UShort(UI.ItemId))
    message.WriteString(action)
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
    UI.MenuRoot, UI.CurrentMenu, UI.ItemId, UI.Update, UI.SelectedItem, UI.Done = nil, nil, nil, nil, nil, nil
    UI.Result, UI.Selected, UI.Map, UI.NodeRects = nil, nil, nil, nil
end

-- Nodes in rows by depth, each row in its parents' order, as SS14's node map.
local function layoutNodes(result, rect)
    local byId, root = {}, nil
    for _, node in ipairs(result.Nodes) do
        byId[node.Id] = node
        if node.Depth == 0 then root = node end
    end
    local rows, deepest, widest = {}, 0, 1
    local queue, seen = { root }, { [root.Id] = true }
    while #queue > 0 do
        local node = table.remove(queue, 1)
        rows[node.Depth] = rows[node.Depth] or {}
        table.insert(rows[node.Depth], node)
        deepest = math.max(deepest, node.Depth)
        widest = math.max(widest, #rows[node.Depth])
        for _, id in ipairs(node.Edges) do
            if not seen[id] and byId[id] ~= nil then
                seen[id] = true
                queue[#queue + 1] = byId[id]
            end
        end
    end
    local positions, rowHeight = {}, rect.Height / (deepest + 1)
    for depth = 0, deepest do
        for index, node in ipairs(rows[depth]) do
            positions[node.Id] = Vector2(rect.X + rect.Width * (index - 0.5) / #rows[depth], rect.Y + rowHeight * (depth + 0.5))
        end
    end
    local size = math.floor(math.min(Common.SafeIntScale(48), rowHeight * 0.6, rect.Width / widest * 0.6))
    return byId, positions, size
end

local function drawMap(spriteBatch, component)
    local result = UI.Result
    if result == nil then return end
    local byId, positions, size = layoutNodes(result, component.Rect)
    for _, node in ipairs(result.Nodes) do
        for _, id in ipairs(node.Edges) do
            if byId[id] ~= nil and byId[id].Depth == node.Depth + 1 then
                GUI.DrawLine(spriteBatch, positions[node.Id], positions[id], LINE_COLOR, 0, 2)
            end
        end
    end
    local font, rects = GUI.Style.SmallFont, {}
    for _, node in ipairs(result.Nodes) do
        local center, current = positions[node.Id], node.Id == result.Current
        local corner = Vector2(math.floor(center.X - size / 2), math.floor(center.Y - size / 2))
        local color = not node.Discovered and NODE_COLORS.unknown or node.Triggered and NODE_COLORS.triggered or NODE_COLORS.discovered
        GUI.DrawRectangle(spriteBatch, corner, Vector2(size, size), Color(18, 22, 24, 255), true)
        GUI.DrawRectangle(spriteBatch, corner, Vector2(size, size), current and CURRENT_COLOR or color, false, 0, current and 4 or 2)
        if UI.Selected == node.Id then
            GUI.DrawRectangle(spriteBatch, corner - Vector2(5, 5), Vector2(size + 10, size + 10), TEXT_COLOR, false, 0, 1)
        end
        local label = node.Discovered and tostring(node.Id) or "?"
        local labelSize = font.MeasureString(label)
        GUI.DrawString(spriteBatch, Vector2(math.floor(center.X - labelSize.X / 2), math.floor(center.Y - labelSize.Y / 2)), label,
            color, nil, 0, font)
        rects[node.Id] = { X = corner.X, Y = corner.Y, Size = size }
    end
    UI.NodeRects = rects
end

-- A click on a node shows it on the right. Called from the think hook: LuaCs cannot take the component's update.
local function updateMap(component)
    if UI.NodeRects == nil or GUI.MouseOn ~= component or not PlayerInput.PrimaryMouseButtonClicked() then return end
    local mouse = PlayerInput.MousePosition
    for id, node in pairs(UI.NodeRects) do
        if mouse.X >= node.X and mouse.X <= node.X + node.Size and mouse.Y >= node.Y and mouse.Y <= node.Y + node.Size then
            UI.Selected = id
            UI.ShowNode()
            return
        end
    end
end

local function createLine(parent)
    local block = Common.CreateText(parent, 1, 1, nil, "", GUI.Alignment.Left, 1, TEXT_COLOR, false)
    block.CanBeFocused = false
    Common.SetAutoScaleText(block, 1)
    Common.FitHeightToText(block)
    return block
end

-- the picked node, or the one the artifact sits on
function UI.ShowNode()
    local text, result, node = UI.Text, UI.Result, nil
    if result ~= nil then
        for _, entry in ipairs(result.Nodes) do
            if entry.Id == (UI.Selected or result.Current) then node = entry end
        end
    end
    local values = {}
    if node ~= nil and not node.Discovered then
        values = { text.XenoarchUnknown }
    elseif node ~= nil then
        values = { string.format(text.XenoarchNode, node.Id), string.format(text.XenoarchDepth, node.Depth),
            string.format(text.XenoarchEdges, #node.Edges), node.Triggered and text.XenoarchTriggered or text.XenoarchUntriggered,
            string.format(text.XenoarchTrigger, node.Trigger), string.format(text.XenoarchEffect, node.Effect),
            node.Id == result.Current and text.XenoarchCurrent or "" }
    end
    for index, line in ipairs(UI.NodeLines) do
        line.Text = values[index] or ""
        line.TextColor = index == 7 and CURRENT_COLOR or (node ~= nil and not node.Discovered and MUTED_COLOR or TEXT_COLOR)
    end
end

function UI.Show(itemId, snapshot)
    if UI.ItemId == itemId and UI.Update ~= nil then UI.Update(snapshot) return end
    Common.RemoveGuiComponent(UI.MenuRoot)
    UI.ItemId, UI.Selected, UI.Text = itemId, nil, snapshot.Text
    local text = snapshot.Text
    local screenWidth, screenHeight = Common.GetScreenSize()
    local width = math.floor(math.min(Common.SafeIntScale(820), screenWidth * 0.9))
    local height = math.floor(math.min(Common.SafeIntScale(520), screenHeight * 0.85))
    local root = GUI.Frame(GUI.RectTransform(Point(width, height), nil, GUI.Anchor.Center), "GUIFrame")
    UI.MenuRoot, UI.CurrentMenu = root, root
    local layout = Common.CreateWindowContent(root)
    Common.CreateWindowHeader(layout, root, text.XenoarchTitle, text.XenoarchClose, function()
        UI.CloseMenu()
        return true
    end)
    local body = GUI.LayoutGroup(Common.CreateRect(1, 1, layout), true)
    body.Stretch = true
    body.AbsoluteSpacing = Common.GetGap()
    local mapFrame = GUI.Frame(Common.CreateRect(0.6, 1, body), "GUIFrameListBox")
    local mapContent = Common.CreateWindowContent(mapFrame)
    UI.Map = GUI.CustomComponent(Common.CreateRect(1, 1, mapContent), drawMap)
    -- over the map while there is no scan to draw
    local mapStatus = GUI.TextBlock(GUI.RectTransform(Vector2(0.9, 1), mapFrame.RectTransform, GUI.Anchor.Center), "", MUTED_COLOR,
        nil, GUI.Alignment.Center, true)
    mapStatus.CanBeFocused = false
    local info = Common.CreateWindowContent(GUI.Frame(Common.CreateRect(0.4, 1, body), "GUIFrameListBox"))
    UI.NodeLines = {}
    for index = 1, 7 do UI.NodeLines[index] = createLine(info) end
    -- the lines above stay at the top and the controls below at the bottom
    local filler = GUI.Frame(Common.CreateRect(1, 1, info), nil)
    filler.Color, filler.CanBeFocused = Color(0, 0, 0, 0), false
    Common.CreateDivider(info)
    local points = createLine(info)
    local progress = GUI.ProgressBar(Common.CreateRect(1, 1, info), 0, Color(80, 210, 240, 255))
    Common.SetFixedHeight(progress, math.floor(Common.GetTextHeight(GUI.Style.Font) * 0.6))
    -- where the artifact goes when it next goes off, as the up/down buttons of SS14's analysis console
    local biasRow = GUI.LayoutGroup(Common.CreateRect(1, 1, info), true)
    biasRow.Stretch = true
    biasRow.AbsoluteSpacing = Common.GetGap()
    Common.SetFixedHeight(biasRow, Common.GetStyleHeight("GUIButton"))
    local up = Common.CreateButton(biasRow, 0.5, text.XenoarchBiasUp)
    up.OnClicked = function() UI.Send("up") return true end
    local down = Common.CreateButton(biasRow, 0.5, text.XenoarchBiasDown)
    down.OnClicked = function() UI.Send("down") return true end
    local scan = Common.CreateButton(info, 1, text.XenoarchScan)
    scan.OnClicked = function() UI.Send("scan") return true end
    local extract = Common.CreateButton(info, 1, text.XenoarchExtract)
    extract.OnClicked = function() UI.Send("extract") return true end
    UI.Update = function(state)
        local problem = not state.Analyzer and text.XenoarchNoAnalyzer or not state.Artifact and text.XenoarchNoArtifact
            or not state.Powered and text.XenoarchNoPower or nil
        UI.Result = problem == nil and state.Result or nil
        mapStatus.Text = problem or (UI.Result == nil and (state.Progress ~= nil and text.XenoarchScanning or text.XenoarchNotScanned) or "")
        mapStatus.TextColor = problem ~= nil and PROBLEM_COLOR or MUTED_COLOR
        points.Text = UI.Result ~= nil and string.format(text.XenoarchPoints, UI.Result.Points) or ""
        progress.BarSize = state.Progress or 0
        scan.Enabled = problem == nil and (state.Progress == nil or UI.Result ~= nil)
        extract.Enabled = UI.Result ~= nil and UI.Result.Points > 0
        up.Enabled, down.Enabled = state.Analyzer and state.Powered, state.Analyzer and state.Powered
        up.Selected, down.Selected = state.Bias == "up", state.Bias == "down"
        UI.ShowNode()
        -- the scan's end, once, as SS14's analyzer chimes
        if UI.Result ~= nil and not UI.Done then
            UI.Done = true
            scanSound.Play(SOUND_GAIN)
        elseif UI.Result == nil then
            UI.Done = false
        end
    end
    root.ForceLayoutRecalculation()
    UI.Update(snapshot)
end

Networking.Receive("VoidTraitor_AnalysisSnapshot", function(message)
    local itemId, snapshot = message.ReadUInt16(), json.parse(message.ReadString())
    local character = Character.Controlled
    if character ~= nil and UI.SelectedItem ~= nil and UI.SelectedItem.ID == itemId
        and character.SelectedItem == UI.SelectedItem then UI.Show(itemId, snapshot) end
end)
Common.AddWindowLayer(120, function()
    if not UI.Disabled and UI.MenuRoot ~= nil then UI.MenuRoot:AddToGUIUpdateList(false, 0) end
end)
Common.InstallPausePatch("VoidTraitor.Analysis.Pause", "VoidTraitorAnalysisGuiState")
Hook.Add("roundEnd", "VoidTraitor.Analysis.End", function() UI.CloseMenu() end)
Hook.Add("think", "VoidTraitor.Analysis.Selection", function()
    Common.UpdateSelectedItemMenu(UI, "vt_analysis_console", function(selected)
        local message = Networking.Start("VoidTraitor_AnalysisOpen")
        message.WriteUInt16(UShort(selected.ID))
        Networking.Send(message)
    end)
    if not UI.Disabled and UI.Map ~= nil then updateMap(UI.Map) end
end)
