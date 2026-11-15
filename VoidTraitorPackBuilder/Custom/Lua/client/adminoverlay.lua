if SERVER then return end

-- Client half of the admin overlay (traitormod Lua/features/adminoverlay.lua), like Space Station 14's: above every
-- character the server listed it draws the name and job, the player who controls it, an antagonist role and the
-- health. The server sends only what this client can't know: who controls a character and its role.
local Common = select(2, ...)
local text = Common.Language.AdminOverlay

local NET_DATA = "VoidTraitor_AdminOverlay"
local PATCH_ID = "VoidTraitor.AdminOverlay"
local DRAW_ORDER = 0
-- how far above the character's centre the text starts, in world units
local HEAD_OFFSET = 130
local TEXT_COLOR = Color(235, 225, 190)
local PLAYER_COLOR = Color(145, 205, 145)
local ROLE_COLOR = Color(255, 90, 90)
local BACKGROUND = Color(0, 0, 0, 160)

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
-- { Id, Player, Role } from the server; empty while the overlay is off
local entries = {}
local root = nil

local function linesOf(character, entry)
    local name = tostring(character.Name)
    if character.Info ~= nil and character.Info.Job ~= nil then name = name .. " (" .. tostring(character.Info.Job.Name) .. ")" end
    local lines = {
        { Text = name, Color = TEXT_COLOR },
        { Text = entry.Player ~= "" and entry.Player or text.NoPlayer, Color = PLAYER_COLOR },
    }
    if entry.Role ~= "" then lines[#lines + 1] = { Text = entry.Role, Color = ROLE_COLOR } end
    lines[#lines + 1] = { Text = string.format(text.Health, math.floor(character.Vitality / character.MaxVitality * 100)), Color = TEXT_COLOR }
    return lines
end

local function draw(spriteBatch)
    local cam = gameMain.GameScreen.Cam
    local font = GUI.Style.SmallFont
    local width, height = gameMain.GraphicsWidth, gameMain.GraphicsHeight
    for _, entry in ipairs(entries) do
        local character = Entity.FindEntityByID(entry.Id)
        if character ~= nil and LuaUserData.IsTargetType(character, "Barotrauma.Character") and not character.Removed then
            local position = cam.WorldToScreen(Vector2(character.DrawPosition.X, character.DrawPosition.Y + HEAD_OFFSET))
            if position.X > 0 and position.Y > 0 and position.X < width and position.Y < height then
                local lines = linesOf(character, entry)
                local y = position.Y - #lines * font.LineHeight
                for _, line in ipairs(lines) do
                    local lineWidth = font.MeasureString(line.Text).X
                    GUI.DrawString(spriteBatch, Vector2(position.X - lineWidth / 2, y), line.Text, line.Color, BACKGROUND, 2, font)
                    y = y + font.LineHeight
                end
            end
        end
    end
end

Hook.Patch(PATCH_ID, "Barotrauma.GameSession", "AddToGUIUpdateList", function()
    if root == nil or #entries == 0 or GUI.DisableHUD then return end
    root.AddToGUIUpdateList(false, DRAW_ORDER)
end, Hook.HookMethodType.After)

Networking.Receive(NET_DATA, function(message)
    entries = {}
    for _ = 1, message.ReadUInt16() do
        entries[#entries + 1] = { Id = message.ReadUInt16(), Player = message.ReadString(), Role = message.ReadString() }
    end
    if root == nil then
        root = GUI.CustomComponent(Common.CreateCanvasRect(0, 0, gameMain.GraphicsWidth, gameMain.GraphicsHeight), function(spriteBatch) draw(spriteBatch) end)
        root.CanBeFocused = false
    end
end)

Hook.Add("roundEnd", PATCH_ID, function()
    entries = {}
end)
