if SERVER then return end

-- While the local character is stunned (a long stun or a Neurotrauma coma) the darkness closes in around them
-- like the crit view of Space Station 14, instead of a black screen.
local packPath = ...
local PATCH_ID = "VoidTraitor.StunView"
local RISE_TIME = 2.5
local FALL_TIME = 1
-- radius of the dark mask as a share of the screen width, as in SS14; its inner third stays clear
local FAR_RADIUS = 0.6
local NEAR_RADIUS = 0.06

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local mask = Sprite(packPath .. "/the void traitor pack/UI/stunmask.png", Vector2(0.5, 0.5))
local level = 0
local lastTime = Timer.GetTime()

local function darkness()
    if level < 1 then
        return math.max(0, math.min(0.98, 0.3 * math.log(level) + 1))
    end
    -- the full view lets a little light through now and then, like SS14 does
    local t = Timer.GetTime() * 2
    local breath = math.max(0, math.sin(t) + 2 * math.sin(t / 2) + math.sin(t / 4) - 3)
    return 1 - breath / 1.5
end

local function fill(spriteBatch, x, y, width, height, color)
    if width > 0 and height > 0 then
        GUI.DrawRectangle(spriteBatch, Vector2(x, y), Vector2(width, height), color, true)
    end
end

-- Runs before the HUD, so the darkness covers the world but not the interface.
Hook.Patch(PATCH_ID, "Barotrauma.CharacterHUD", "Draw", function (instance, ptable)
    local now = Timer.GetTime()
    local deltaTime = now - lastTime
    lastTime = now

    local character = ptable["character"]
    if character.IsDead then
        level = 0
        return
    end
    if character.Stun > 0 then
        level = math.min(1, level + deltaTime / RISE_TIME)
    elseif level > 0 then
        level = math.max(0, level - deltaTime / FALL_TIME)
    end
    if level <= 0 then return end

    if level >= 1 then
        -- muffles sounds the same way as having the head underwater
        character.LowPassMultiplier = 0
    end

    local spriteBatch = ptable["spriteBatch"]
    local width, height = gameMain.GraphicsWidth, gameMain.GraphicsHeight
    -- whole pixels keep the mask and the filled edges from overlapping or leaving a gap
    local center = ptable["cam"].WorldToScreen(character.DrawPosition)
    local x, y = math.floor(center.X + 0.5), math.floor(center.Y + 0.5)
    local radius = math.floor((FAR_RADIUS + level * (NEAR_RADIUS - FAR_RADIUS)) * width + 0.5)
    local color = Color(0, 0, 0, math.floor(255 * darkness() + 0.5))

    mask.Draw(spriteBatch, Vector2(x, y), color, 0, 2 * radius / mask.size.X)
    fill(spriteBatch, 0, 0, width, y - radius, color)
    fill(spriteBatch, 0, y + radius, width, height - y - radius, color)
    fill(spriteBatch, 0, y - radius, x - radius, 2 * radius, color)
    fill(spriteBatch, x + radius, y - radius, width - x - radius, 2 * radius, color)
end, Hook.HookMethodType.Before)
