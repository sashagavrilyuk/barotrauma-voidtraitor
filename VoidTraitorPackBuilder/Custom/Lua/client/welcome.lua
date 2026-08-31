if SERVER then return end 

-- === СИГНАЛЫ СЕРВЕРУ ===
local handshakeTimer = 0
local function SendHandshake()
    local msg = Networking.Start("VoidTraitor_LuaCheck")
    Networking.Send(msg)
end
SendHandshake()
Hook.Add("think", "VoidTraitor.LuaCheck", function(deltaTime)
    handshakeTimer = handshakeTimer + deltaTime
    if handshakeTimer < 5 then return end
    handshakeTimer = 0
    SendHandshake()
end)
Hook.Add("roundStart", "VoidTraitor.LuaCheck.RoundStart", SendHandshake)

-- =========================================================
-- ТЕКСТЫ И ГАЙДЫ
-- =========================================================

local packPath, Common = ...
local language = dofile(packPath .. "/Lua/language/welcome_russian.lua")
local menuText = language.MenuText
local GuideContent = language.GuideContent
local GuideOrder = language.GuideOrder
local CreateRect = Common.CreateRect

-- =========================================================
-- СИСТЕМНЫЙ КОД
-- =========================================================

local previousWelcomeRoot = rawget(_G, "VoidTraitorWelcomeMenuRoot")
if previousWelcomeRoot ~= nil and previousWelcomeRoot.RectTransform ~= nil then
    previousWelcomeRoot.RectTransform.Parent = nil
end

local currentWelcomeMenu = nil
_G.VoidTraitorWelcomeMenuOpen = false
_G.VoidTraitorWelcomeMenuRoot = nil
local ShowCustomWelcomeMenu, ShowGuidesMenu, ShowGuidePage

local function SetWelcomeMenuState(root)
    currentWelcomeMenu = root
    _G.VoidTraitorWelcomeMenuRoot = root
    _G.VoidTraitorWelcomeMenuOpen = root ~= nil
end

local function ApplyButtonStyle(btn)
    local mainColor = Color(200, 200, 200, 255)
    
    btn.Color = mainColor
    btn.SelectedColor = mainColor 
    btn.HoverColor = Color(255, 255, 255, 255) 
    btn.PressedColor = Color(150, 150, 150, 255)
    
    btn.TextColor = Color(0, 0, 0, 255)
end

local function CreateMyButton(width, height, parent, anchor, text)
    local rect = CreateRect(width, height, parent, anchor)
    local btn = GUI.Button(rect, text, GUI.Alignment.Center, "GUIButton") 
    ApplyButtonStyle(btn)
    if btn.TextBlock ~= nil then
        btn.TextBlock.AutoScaleHorizontal = true
    end
    return btn
end

local function ShowCopyWindow(url)
    local parent = nil
    if GUI.Screen.Selected and GUI.Screen.Selected.Frame then parent = GUI.Screen.Selected.Frame end
    local overlayRect = CreateRect(1, 1, parent, GUI.Anchor.Center)
    if parent then overlayRect.SetAsLastChild() end
    local overlay = GUI.Frame(overlayRect, nil)
    overlay.Color = Color(0,0,0,100)
    overlay.CanBeFocused = true
    
    local boxRect = CreateRect(0.25, 0.18, overlay, GUI.Anchor.Center)
    local box = GUI.Frame(boxRect, nil)

    box.Color = Color(30, 30, 40, 255) 
    box.OutlineColor = Color(255, 255, 255, 100)
    box.OutlineThickness = 2
    
    local titleRect = CreateRect(1, 0.4, box, GUI.Anchor.TopCenter)
    local title = GUI.TextBlock(titleRect, language.CopyLinkTitle, nil, nil, GUI.Alignment.Center)
    title.TextColor = Color(255, 255, 255, 255)
    title.TextScale = 1.5
    
    local textRect = CreateRect(0.9, 0.2, box, GUI.Anchor.Center)
    local textBox = GUI.TextBox(textRect, url)
    textBox.Selected = true
    
    local btnRect = CreateRect(0.3, 0.25, box, GUI.Anchor.BottomCenter)
    btnRect.AbsoluteOffset = Point(0, 8)
    
    local btn = GUI.Button(btnRect, "OK", GUI.Alignment.Center, "GUIButton")
    ApplyButtonStyle(btn)
    
    btn.OnClicked = function() if overlay.RectTransform then overlay.RectTransform.Parent = nil end end
end

local function OpenLink(url)
    if Steam ~= nil then
        local ok = pcall(function() Steam.OpenUrl(url) end)
        if ok then return end
    end
    ShowCopyWindow(url)
end

-- Базовое окно
local function CreateBaseWindow()
    if currentWelcomeMenu and currentWelcomeMenu.RectTransform then
        currentWelcomeMenu.RectTransform.Parent = nil
        SetWelcomeMenuState(nil)
    end
    local targetParent = nil
    if Game.NetLobbyScreen and GUI.Screen.Selected == Game.NetLobbyScreen then
        targetParent = Game.NetLobbyScreen.Frame
    end
    local overlayRect = CreateRect(1, 1, nil, GUI.Anchor.Center)
    local overlay = GUI.Frame(overlayRect, nil)
    overlay.Color = Color(0, 0, 0, 120) 
    overlay.CanBeFocused = true
    overlay.IgnoreLayoutGroups = true 
    if targetParent then
        overlayRect.Parent = targetParent.RectTransform
        overlayRect.SetAsLastChild()
    end
    SetWelcomeMenuState(overlay)
    local frameRect = CreateRect(0.5, 0.6, overlay, GUI.Anchor.Center)
    local frame = GUI.Frame(frameRect, nil)
    frame.Color = Color(30, 30, 40, 255)
    frame.OutlineColor = Color(255, 255, 255, 100)
    frame.OutlineThickness = 2
    return frame, overlay
end

-- === СТРАНИЦА ГАЙДА ===
ShowGuidePage = function(title, text)
    local frame = CreateBaseWindow()
    
    local headerRect = CreateRect(1, 0.15, frame, GUI.Anchor.TopCenter)
    local header = GUI.TextBlock(headerRect, title, nil, nil, GUI.Alignment.Center)
    header.TextScale = 1.5 
    header.TextColor = Color(255, 255, 255, 255)

    local listRect = CreateRect(0.95, 0.70, frame, GUI.Anchor.TopCenter)
    listRect.RelativeOffset = Vector2(0, 0.16)
    local contentArea = GUI.ListBox(listRect, nil)
    contentArea.Color = Color(0,0,0,50)
    
    local textRect = CreateRect(1, 0, contentArea.Content, nil) 
    local textBlock = GUI.TextBlock(textRect, text, nil, nil, GUI.Alignment.TopLeft, true)
    textBlock.CanBeFocused = false
    textBlock.TextScale = 1.1
    textBlock.TextColor = Color(220, 220, 220, 255)
    textBlock.CalculateHeightFromText() 

    local btnGroupRect = CreateRect(0.95, 0.12, frame, GUI.Anchor.BottomCenter)
    btnGroupRect.AbsoluteOffset = Point(0, 10)
    local btnContainer = GUI.Frame(btnGroupRect, nil)
    btnContainer.Color = Color(0,0,0,0)

    local btnBack = CreateMyButton(0.4, 0.9, btnContainer, GUI.Anchor.Center, language.GuideBack)
    btnBack.OnClicked = function() ShowGuidesMenu() end
end

-- === МЕНЮ ГАЙДОВ ===
ShowGuidesMenu = function()
    local frame = CreateBaseWindow()
    
    local headerRect = CreateRect(1, 0.15, frame, GUI.Anchor.TopCenter)
    local header = GUI.TextBlock(headerRect, language.GuidesHeader, nil, nil, GUI.Alignment.Center)
    header.TextScale = 1.5 
    header.TextColor = Color(255, 255, 255, 255)

    local listRect = CreateRect(0.95, 0.70, frame, GUI.Anchor.TopCenter)
    listRect.RelativeOffset = Vector2(0, 0.16)
    local contentArea = GUI.ListBox(listRect, nil)
    contentArea.Color = Color(0,0,0,50)
    
    for _, title in ipairs(GuideOrder) do
        local spacerRect = CreateRect(1, 0.15, contentArea.Content, nil)
        local spacer = GUI.Frame(spacerRect, nil)
        spacer.Color = Color(0,0,0,0)
        local btn = CreateMyButton(0.9, 0.85, spacer, GUI.Anchor.Center, title)
        btn.OnClicked = function()
            local content = GuideContent[title] or language.MissingGuide
            ShowGuidePage(title, content)
        end
    end

    local btnGroupRect = CreateRect(0.95, 0.12, frame, GUI.Anchor.BottomCenter)
    btnGroupRect.AbsoluteOffset = Point(0, 10)
    local btnContainer = GUI.Frame(btnGroupRect, nil)
    btnContainer.Color = Color(0,0,0,0)

    local btnBack = CreateMyButton(0.6, 0.9, btnContainer, GUI.Anchor.Center, language.MainMenuBack)
    btnBack.OnClicked = function() ShowCustomWelcomeMenu() end
end

-- === ГЛАВНОЕ МЕНЮ ===
ShowCustomWelcomeMenu = function()
    local frame = CreateBaseWindow()

    local headerRect = CreateRect(1, 0.15, frame, GUI.Anchor.TopCenter)
    local header = GUI.TextBlock(headerRect, language.WelcomeHeader, nil, nil, GUI.Alignment.Center)
    header.TextScale = 1.5 
    header.TextColor = Color(255, 255, 255, 255)

    local listRect = CreateRect(0.95, 0.70, frame, GUI.Anchor.TopCenter)
    listRect.RelativeOffset = Vector2(0, 0.16)
    local contentArea = GUI.ListBox(listRect, nil)
    contentArea.Color = Color(0,0,0,50)
    
    local textRect = CreateRect(1, 0, contentArea.Content, nil)
    local textBlock = GUI.TextBlock(textRect, menuText, nil, nil, GUI.Alignment.TopLeft, true)
    textBlock.CanBeFocused = false
    textBlock.TextScale = 1.1
    textBlock.TextColor = Color(220, 220, 220, 255)
    textBlock.CalculateHeightFromText() 

    -- ПАНЕЛЬ КНОПОК
    local btnGroupRect = CreateRect(0.95, 0.12, frame, GUI.Anchor.BottomCenter)
    btnGroupRect.AbsoluteOffset = Point(0, 10)
    local btnContainer = GUI.Frame(btnGroupRect, nil)
    btnContainer.Color = Color(0,0,0,0)

    local w = 0.24 

    local btn1 = CreateMyButton(w, 0.9, btnContainer, GUI.Anchor.CenterLeft, "Discord")
    btn1.RectTransform.RelativeOffset = Vector2(0.01, 0)
    btn1.OnClicked = function() OpenLink("https://discord.gg/rFrwmXg8DQ") end
    
    local btn2 = CreateMyButton(w, 0.9, btnContainer, GUI.Anchor.CenterLeft, "Encelada")
    btn2.RectTransform.RelativeOffset = Vector2(0.26, 0)
    btn2.OnClicked = function() OpenLink("https://discord.gg/encelada") end

    local btn3 = CreateMyButton(w, 0.9, btnContainer, GUI.Anchor.CenterLeft, language.GuidesButton)
    btn3.RectTransform.RelativeOffset = Vector2(0.51, 0)
    btn3.OnClicked = function() ShowGuidesMenu() end

    local btn4 = CreateMyButton(w, 0.9, btnContainer, GUI.Anchor.CenterLeft, language.CloseButton)
    btn4.RectTransform.RelativeOffset = Vector2(0.76, 0)
    btn4.OnClicked = function() 
        if currentWelcomeMenu and currentWelcomeMenu.RectTransform then
            currentWelcomeMenu.RectTransform.Parent = nil 
            SetWelcomeMenuState(nil)
        end
    end
end

Networking.Receive("VoidTraitor_WelcomeMenuOpen", function()
    ShowCustomWelcomeMenu()
end)

-- === АВТОМАТИЗАЦИЯ ===
Timer.Wait(ShowCustomWelcomeMenu, 1500)