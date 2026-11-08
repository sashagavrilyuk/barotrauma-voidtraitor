local event = {}

-- Station's take on the SS14 clerical error: the Coalition access records of a few crew members are lost, and their ID
-- cards lose part of their access until the ID card console gives it back.
event.Name = "ClericalError"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

-- share of the carded crew that is hit, as in SS14
local maxShare = 0.1

local function cardsWithAccess()
    local cards = {}
    for _, character in ipairs(Traitormod.SelectedGamemode.StationCrew) do
        local card = not character.Removed and not character.IsDead and character.Inventory ~= nil
            and character.Inventory.GetItemInLimbSlot(InvSlotType.Card) or nil
        if card then
            local tags = {}
            for _, entry in ipairs(Traitormod.IdConsole.Config.Access) do
                if card.HasTag(entry.Tag) then tags[#tags + 1] = entry.Tag end
            end
            if #tags > 0 then cards[#cards + 1] = { Card = card, Tags = tags } end
        end
    end
    return cards
end

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    return mode ~= nil and mode.Name == "Station" and #cardsWithAccess() > 0
end

event.Start = function ()
    local cards = cardsWithAccess()
    for _ = 1, math.random(1, math.max(1, math.floor(#cards * maxShare + 0.5))) do
        local entry = table.remove(cards, math.random(#cards))
        -- each access is lost with even odds, at least one of them
        local lost = math.random(#entry.Tags)
        for index, tag in ipairs(entry.Tags) do
            if index == lost or math.random() < 0.5 then entry.Card.RemoveTag(Identifier(tag)) end
        end
        Traitormod.IdConsole.Sync(entry.Card, entry.Card, "Tags")
    end

    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.GetText("ClericalError"), "green")
    event.End()
end

event.End = function ()

end

return event
