local event = {}

-- SS14's vent clog: after a Coalition warning some vents of the station blow out a coloured gas with a random reagent. The
-- gas spreads room by room through open doors and holes until its volume runs out, and works on everyone breathing it.
-- The clients draw the gas (Void traitor pack Lua/client/ventclog.lua).
event.Name = "VentClog"
event.MinRoundTime = 15
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

local NET_VENT_CLOG = "VoidTraitor_VentClog"
local minWarningSeconds, maxWarningSeconds = 20, 40
-- each vent blows out with this chance, at least one does
local ventChance = 0.33
-- SS14 rarely picks any reagent at all instead of a safe-ish one
local dangerousChance = 0.05
-- room area in square pixels one vent's gas fills, the weak reagents fill less
local spreadArea, weakSpreadArea = 1500000, 500000
local spreadSeconds = 2
local effectSeconds = 2
-- the gas is gone this long after it came out
local lastingSeconds = 40
local divingTag = Identifier("diving")

-- SS14's safe-ish vent chemicals; the affliction and its strength are given every few seconds to everyone in the gas,
-- a diving mask or suit keeps out all but those that work by touch
local reagents = {
    { Color = Color(80, 140, 255) }, -- water
    { Color = Color(170, 20, 20) }, -- blood
    { Color = Color(150, 230, 255) }, -- space cleaner
    { Color = Color(230, 200, 140) }, -- nutriment
    { Color = Color(90, 200, 60), Affliction = "slow", Strength = 25, Touch = true }, -- slime
    { Color = Color(240, 240, 200), Affliction = "slow", Strength = 40, Touch = true, Weak = true }, -- space glue
    { Color = Color(120, 200, 255), SlipChance = 0.3, Touch = true, Weak = true }, -- space lube
    { Color = Color(200, 60, 220), Affliction = "psychosis", Strength = 2 }, -- space drugs
    { Color = Color(255, 230, 60), Affliction = "haste", Strength = 8 }, -- ephedrine
    { Color = Color(200, 140, 40), Affliction = "drunk", Strength = 3 }, -- ale and beer
}
local dangerousReagents = {
    { Color = Color(120, 255, 60), Affliction = "acidburn", Strength = 3 },
    { Color = Color(160, 200, 80), Affliction = "nausea", Strength = 6 },
}

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    if mode == nil or mode.Name ~= "Station" then return false end
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("vent") then return true end
    end
    return false
end

event.Start = function ()
    event.ClogAt = Traitormod.RoundTime + math.random(minWarningSeconds, maxWarningSeconds)
    event.Clouds = nil
    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("VentClog"), "attention")
end

local function hullArea(hull)
    return hull.Rect.Width * hull.Rect.Height
end

local function sendRooms(cloud, hulls)
    local message = Networking.Start(NET_VENT_CLOG)
    message.WriteByte(cloud.Reagent.Color.R)
    message.WriteByte(cloud.Reagent.Color.G)
    message.WriteByte(cloud.Reagent.Color.B)
    message.WriteUInt16(math.max(0, math.ceil(event.EndsAt - Traitormod.RoundTime)))
    message.WriteUInt16(#hulls)
    for _, hull in ipairs(hulls) do message.WriteUInt16(hull.ID) end
    Networking.Send(message)
end

local function addRoom(cloud, hull, added)
    cloud.Hulls[hull] = true
    cloud.Budget = cloud.Budget - hullArea(hull)
    event.HullClouds[hull] = cloud
    table.insert(added, hull)
end

local function startClouds()
    local vents = {}
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        if item.HasTag("vent") and item.CurrentHull ~= nil then table.insert(vents, item) end
    end
    local clogged = {}
    for _, vent in ipairs(vents) do
        if math.random() < ventChance then table.insert(clogged, vent) end
    end
    if #clogged == 0 and #vents > 0 then table.insert(clogged, vents[math.random(#vents)]) end

    event.Clouds, event.HullClouds = {}, {}
    for _, vent in ipairs(clogged) do
        local pool = math.random() < dangerousChance and dangerousReagents or reagents
        local reagent = pool[math.random(#pool)]
        local cloud = { Reagent = reagent, Hulls = {}, Frontier = {}, Budget = reagent.Weak and weakSpreadArea or spreadArea }
        local added = {}
        addRoom(cloud, vent.CurrentHull, added)
        cloud.Frontier = added
        table.insert(event.Clouds, cloud)
        sendRooms(cloud, added)
    end
end

-- the next ring of rooms behind the open gaps of the rooms reached last
local function spread()
    for _, cloud in ipairs(event.Clouds) do
        local added = {}
        for _, hull in ipairs(cloud.Frontier) do
            for gap in hull.ConnectedGaps do
                if gap.Open > 0 then
                    for linked in gap.linkedTo do
                        if cloud.Budget > 0 and linked ~= hull and not cloud.Hulls[linked] then
                            addRoom(cloud, linked, added)
                        end
                    end
                end
            end
        end
        cloud.Frontier = added
        if #added > 0 then sendRooms(cloud, added) end
    end
end

local function isProtected(character)
    return character.GetEquippedItem(divingTag, InvSlotType.Head) ~= nil
        or character.GetEquippedItem(divingTag, InvSlotType.OuterClothes) ~= nil
end

local function applyEffects()
    for _, character in pairs(Character.CharacterList) do
        local cloud = not character.IsDead and character.CurrentHull ~= nil and event.HullClouds[character.CurrentHull]
        if cloud then
            local reagent = cloud.Reagent
            if reagent.Touch or not isProtected(character) then
                if reagent.Affliction ~= nil then
                    character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb,
                        AfflictionPrefab.Prefabs[reagent.Affliction].Instantiate(reagent.Strength))
                end
                if reagent.SlipChance ~= nil and math.random() < reagent.SlipChance then
                    character.Stun = math.max(character.Stun, 1)
                end
            end
        end
    end
end

event.Think = function ()
    local now = Traitormod.RoundTime
    if event.Clouds == nil then
        if now < event.ClogAt then return end
        event.EndsAt = now + lastingSeconds
        event.NextSpread, event.NextEffect = now + spreadSeconds, now
        startClouds()
    end
    if now >= event.EndsAt then
        event.End()
        return
    end
    if now >= event.NextSpread then
        event.NextSpread = now + spreadSeconds
        spread()
    end
    if now >= event.NextEffect then
        event.NextEffect = now + effectSeconds
        applyEffects()
    end
end

event.End = function ()
    event.Clouds, event.HullClouds = nil, nil
end

return event
