if SERVER then return end

local prefab = ItemPrefab.Prefabs["artmod_alientrinket12_animation"]
if prefab == nil or prefab.Sprite == nil then return end

local frames = {
    Rectangle(26, 0, 88, 152),
    Rectangle(121, 0, 88, 152),
    Rectangle(213, 0, 88, 152),
    Rectangle(305, 0, 88, 152),
    Rectangle(395, 0, 88, 152),
    Rectangle(483, 0, 88, 152),
    Rectangle(577, 0, 88, 152),
    Rectangle(665, 0, 88, 152),
    Rectangle(758, 0, 88, 152),
    Rectangle(845, 0, 88, 152),
    Rectangle(29, 179, 88, 152),
    Rectangle(115, 179, 88, 152),
    Rectangle(205, 179, 88, 152),
    Rectangle(295, 179, 88, 152),
    Rectangle(386, 179, 88, 152),
    Rectangle(475, 179, 88, 152),
    Rectangle(565, 179, 88, 152),
    Rectangle(657, 179, 88, 152),
    Rectangle(747, 179, 88, 152),
    Rectangle(841, 179, 87, 152)
}

local sprite = prefab.Sprite
local frame = 1

local function advanceFrame()
    frame = frame % #frames + 1
    sprite.SourceRect = frames[frame]
    Timer.Wait(advanceFrame, 100)
end

sprite.SourceRect = frames[frame]
Timer.Wait(advanceFrame, 100)
