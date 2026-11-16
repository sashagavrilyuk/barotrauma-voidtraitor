if SERVER then return end

-- Like SS14, a character's job icon comes from the ID card it wears wherever the game draws it for that character:
-- its own portrait, the health window and the order wheel (CharacterInfo.DrawJobIcon). A Station card's vt_preset: tag
-- is the ID console preset it was made out with, which gives a head its emblem; its jobid: tag is the job, whose icon
-- and colour the others show. The job: tag, the title anyone can write at the console, changes neither. In Station a
-- character without a card shows the "no ID card" icon. Cards of other modes have no job: tag and keep the game's icon,
-- as do the crew list on the left (the role each was given) and Station's crew tab.
local _, Common = ...

local PATCH_ID = "VoidTraitor.JobIcons"
-- how often the card of a drawn character is read again
local REFRESH_SECONDS = 0.5
local NO_CARD_COLOR = Color(200, 200, 200, 255)

-- character -> { Time, Sprite, Color }; Sprite is nil where the game's icon stays
local cache = setmetatable({}, { __mode = "k" })

local function cardIcon(character)
    local card = character.Inventory ~= nil and character.Inventory.GetItemInLimbSlot(InvSlotType.Card) or nil
    if card == nil then
        if Common.StationCrew == nil then return nil end
        return Common.GetNoIdCardIcon(false), NO_CARD_COLOR
    end
    local station, preset, jobId = false, nil, nil
    for tag in card.GetTags() do
        local value = tag.Value
        if value:sub(1, 4) == "job:" then
            station = true
        elseif value:sub(1, 10) == "vt_preset:" then
            preset = value:sub(11)
        elseif value:sub(1, 6) == "jobid:" then
            jobId = value:sub(7)
        end
    end
    if not station then return nil end
    local job = jobId ~= nil and JobPrefab.Prefabs.ContainsKey(jobId) and JobPrefab.Get(jobId) or nil
    return Common.GetRoleIcon(preset, jobId, false), job ~= nil and job.UIColor or NO_CARD_COLOR
end

Hook.Patch(PATCH_ID, "Barotrauma.CharacterInfo", "DrawJobIcon", function(instance, ptable)
    local character = instance.Character
    if character == nil then return end
    local now = Timer.GetTime()
    local entry = cache[character]
    if entry == nil or entry.Time < now then
        local sprite, color = cardIcon(character)
        entry = { Time = now + REFRESH_SECONDS, Sprite = sprite, Color = color }
        cache[character] = entry
    end
    local sprite = entry.Sprite
    if sprite == nil then return end
    -- as the game draws it: centred in the area, scaled to fit
    local area = ptable["area"]
    local scale = math.min(area.Width / sprite.SourceRect.Width, area.Height / sprite.SourceRect.Height)
    sprite.Draw(ptable["spriteBatch"], Vector2(area.X + area.Width / 2, area.Y + area.Height / 2), entry.Color, 0, scale)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)
