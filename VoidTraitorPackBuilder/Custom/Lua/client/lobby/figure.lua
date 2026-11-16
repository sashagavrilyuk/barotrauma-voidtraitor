local P = ...

-- The whole character in a job's outfit for the lobby card; vanilla draws only heads in menus.
-- The limbs stand in the ragdoll's rest pose (every joint at angle 0), the outfit's wearable sprites go over them
-- by the vanilla rules (Limb.Draw, WearableSprite) and the head with its hair is drawn by the character info itself.

local SpriteEffects = LuaUserData.CreateEnumTable("Microsoft.Xna.Framework.Graphics.SpriteEffects")
-- each further wearable on a limb lies this much in front of the previous one, as in Limb.Draw
local DEPTH_STEP = 0.000001

local function named(element, name)
    return string.lower(tostring(element.Name)) == name
end

-- Limb sprites at their places in display units (y up), chained from the torso through the joints.
local function buildLimbs(info)
    local ragdoll = info.Ragdoll
    local limbs, byId = {}, {}
    for params in ragdoll.Limbs do
        local spriteParams = params.GetSprite()
        local texture = spriteParams.Texture ~= "" and spriteParams.Texture or ragdoll.Texture
        local limb = {
            Type = string.lower(params.Element.GetAttributeString("type", "")),
            Sprite = Sprite(spriteParams.Element, "", info.ReplaceVars(texture), false, ragdoll.SourceRectScale),
            Depth = spriteParams.Depth,
            LimbScale = params.Scale,
            Scale = params.Scale * ragdoll.LimbScale * ragdoll.TextureScale,
            Worn = 0,
        }
        if limb.Type == "torso" then limb.X, limb.Y = 0, 0 end
        byId[params.ID] = limb
        limbs[#limbs + 1] = limb
    end

    local placed = true
    while placed do
        placed = false
        for joint in ragdoll.Joints do
            local a, b = byId[joint.Limb1], byId[joint.Limb2]
            if (a.X == nil) ~= (b.X == nil) then
                local dx = (joint.Limb1Anchor.X - joint.Limb2Anchor.X) * ragdoll.JointScale
                local dy = (joint.Limb1Anchor.Y - joint.Limb2Anchor.Y) * ragdoll.JointScale
                if b.X == nil then
                    b.X, b.Y = a.X + dx, a.Y + dy
                else
                    a.X, a.Y = b.X - dx, b.Y - dy
                end
                placed = true
            end
        end
    end
    return limbs
end

-- Identifiers of the items the job's item set of this variant (Jobs.xml) puts on: the outfit and the other equipped
-- items, such as a cap or a tool belt. Like the game's preview of a variant's items (JobPrefab.JobItem), it leaves out
-- items with showpreview="false" and those given only in PvP, or only outside it.
local function wornItems(variant, pvp)
    local identifiers = {}
    local function collect(element, gameMode)
        for child in element.Elements() do
            if named(child, "item") then
                local mode = string.lower(child.GetAttributeString("gamemode", gameMode))
                if (child.GetAttributeBool("outfit", false) or child.GetAttributeBool("equip", false))
                    and child.GetAttributeBool("showpreview", true) and mode ~= (pvp and "pve" or "pvp") then
                    identifiers[#identifiers + 1] = child.GetAttributeString("identifier", "")
                end
                collect(child, mode)
            end
        end
    end
    local index = 0
    for element in variant.Prefab.Element.Elements() do
        if named(element, "itemset") then
            if index == variant.Variant then collect(element, "any") end
            index = index + 1
        end
    end
    return identifiers
end

-- A texture given by file name alone lies next to the item's XML; [VARIANT] falls back to the first variant.
local function wearableTexture(info, prefab, element)
    local texture = element.GetAttributeString("texture", "")
    if not string.find(texture, "[/\\]") then
        local file = (prefab.ParentPrefab or prefab).FilePath.Value
        texture = string.match(file, "^(.*)[/\\]") .. "/" .. texture
    end
    return (string.gsub(info.ReplaceVars(texture), "%[VARIANT%]", "1"))
end

local function wearableScale(element, limb, ragdoll)
    local scale = element.GetAttributeFloat("scale", 1)
    local inherit
    if element.GetAttribute("inheritscale") ~= nil then
        inherit = element.GetAttributeBool("inheritscale", false)
    else
        inherit = element.GetAttributeBool("inherittexturescale", false)
    end
    if not inherit then return scale end
    if not element.GetAttributeBool("ignoretexturescale", false) then scale = scale * ragdoll.TextureScale end
    if not element.GetAttributeBool("ignorelimbscale", false) then scale = scale * limb.LimbScale end
    if not element.GetAttributeBool("ignoreragdollscale", false) then scale = scale * ragdoll.LimbScale end
    return scale
end

local function addWearable(info, prefab, element, limbs, parts)
    local limbType = string.lower(element.GetAttributeString("limb", "Head"))
    for _, limb in ipairs(limbs) do
        if limb.Type == limbType then
            local sprite = Sprite(element, "", wearableTexture(info, prefab, element), false, 1)
            if element.GetAttributeBool("inheritsourcerect", false) then sprite.SourceRect = limb.Sprite.SourceRect end
            if element.GetAttributeBool("inheritorigin", false) then sprite.Origin = limb.Sprite.Origin end
            if element.GetAttributeBool("hidelimb", false) then limb.Hidden = true end
            limb.Worn = limb.Worn + 1
            parts[#parts + 1] = { Sprite = sprite, Limb = limb, Scale = wearableScale(element, limb, info.Ragdoll),
                Depth = limb.Depth - DEPTH_STEP * limb.Worn }
        end
    end
end

local function addOutfit(info, variant, limbs, parts)
    local mode = Game.NetLobbyScreen.SelectedMode
    for _, identifier in ipairs(wornItems(variant, mode ~= nil and mode.Identifier.Value == "pvp")) do
        -- LuaCs' lookup returns nil without an error for an item of a disabled mod
        local prefab = ItemPrefab.GetItemPrefab(identifier)
        if prefab ~= nil then
            for wearable in prefab.ConfigElement.Elements() do
                if named(wearable, "wearable") then
                    for element in wearable.Elements() do
                        if named(element, "sprite") then addWearable(info, prefab, element, limbs, parts) end
                    end
                end
            end
        end
    end
end

-- Draw list from back to front and the bounds of the figure in display units (y down).
local function build(info, variant)
    local limbs = buildLimbs(info)
    local parts = {}
    if variant ~= nil then addOutfit(info, variant, limbs, parts) end
    local sprites = {}
    for _, part in ipairs(parts) do
        sprites[#sprites + 1] = part.Sprite
    end
    for _, limb in ipairs(limbs) do
        sprites[#sprites + 1] = limb.Sprite
        if not limb.Hidden then
            parts[#parts + 1] = { Sprite = limb.Sprite, Limb = limb, Scale = limb.Scale, Depth = limb.Depth,
                Head = limb.Type == "head", Tinted = true }
        end
    end
    table.sort(parts, function(a, b) return a.Depth > b.Depth end)

    local bounds = { Left = math.huge, Right = -math.huge, Top = math.huge, Bottom = -math.huge }
    for _, part in ipairs(parts) do
        local rect, origin, scale = part.Sprite.SourceRect, part.Sprite.Origin, part.Scale
        local x, y = part.Limb.X, -part.Limb.Y
        bounds.Left = math.min(bounds.Left, x - origin.X * scale)
        bounds.Right = math.max(bounds.Right, x + (rect.Width - origin.X) * scale)
        bounds.Top = math.min(bounds.Top, y - origin.Y * scale)
        bounds.Bottom = math.max(bounds.Bottom, y + (rect.Height - origin.Y) * scale)
    end
    return { Parts = parts, Sprites = sprites, Bounds = bounds }
end

local function remove(built)
    for _, sprite in ipairs(built ~= nil and built.Sprites or {}) do
        sprite.Remove()
    end
end

local function draw(spriteBatch, rect, figure)
    local built, info = figure.Built, figure.Info
    if built == nil then return end
    local bounds = built.Bounds
    local scale = math.min(rect.Width / (bounds.Right - bounds.Left), rect.Height / (bounds.Bottom - bounds.Top))
    local x = rect.X + rect.Width / 2 - (bounds.Left + bounds.Right) / 2 * scale
    local y = rect.Y + rect.Height / 2 - (bounds.Top + bounds.Bottom) / 2 * scale
    local skin = info.Head.SkinColor
    for _, part in ipairs(built.Parts) do
        local sprite, size = part.Sprite, part.Scale * scale
        local position = Vector2(x + part.Limb.X * scale, y - part.Limb.Y * scale)
        if part.Head then
            -- the head sprite of the character info has the same source rectangle as the head limb
            info.DrawIcon(spriteBatch, position, Vector2(sprite.SourceRect.Width * size, sprite.SourceRect.Height * size))
        else
            sprite.Draw(spriteBatch, position, part.Tinted and skin or Color.White, sprite.Origin, 0, size, SpriteEffects.None, nil)
        end
    end
end

function P.CreateCharacterFigure(rectTransform, info)
    local figure = { Info = info }
    figure.Component = GUI.CustomComponent(rectTransform, function(spriteBatch, component)
        draw(spriteBatch, component.Rect, figure)
    end)
    figure.Component.CanBeFocused = false
    return figure
end

-- Rebuilt on a change of job, variant or head, which can change the outfit and the body's [GENDER] texture.
-- The new sprites load before the old ones are removed, so the textures they share stay loaded.
function P.SetFigureJob(figure, variant)
    local old = figure.Built
    figure.Built = build(figure.Info, variant)
    remove(old)
end

function P.RemoveCharacterFigure(figure)
    remove(figure.Built)
    figure.Built = nil
end
