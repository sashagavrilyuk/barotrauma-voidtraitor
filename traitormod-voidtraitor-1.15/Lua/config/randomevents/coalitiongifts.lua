local event = {}

-- Station's take on the SS14 cargo gifts: the Coalition supply service sends a department a free set of goods. The
-- orders show up in the cargo console already accepted and fly with the next trip of the cargo shuttle.
event.Name = "CoalitionGifts"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the Station scheduler and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = false

event.CanStart = function ()
    local mode = Traitormod.SelectedGamemode
    local state = Traitormod.Cargo.State
    return mode ~= nil and mode.Name == "Station" and state ~= nil and state.Ship ~= nil
end

event.Start = function ()
    local gifts = Traitormod.Config.Cargo.Gifts
    local gift = gifts[math.random(#gifts)]
    local description = Traitormod.GetText(gift.Text)
    for _, order in ipairs(gift.Orders) do
        if not Traitormod.Cargo.AddGift(order.Category, order.Identifier, order.Quantity,
            Traitormod.GetText("CoalitionGiftSender"), description) then
            Traitormod.Error("Coalition gift " .. order.Category .. ":" .. order.Identifier .. " is not sold by cargo.")
        end
    end

    Traitormod.SelectedGamemode:SendCoalitionAnnouncement(Traitormod.FormatText("CoalitionGifts", description), "green")
    event.End()
end

event.End = function ()

end

return event
