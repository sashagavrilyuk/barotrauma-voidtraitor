local event = {}

event.Name = "ArmoryCrate"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
-- only the director and admins start it
event.ChancePerMinute = 0
event.OnlyOncePerRound = true

-- the crate (Void traitor pack) opens for security and captain ID cards, anyone else has to break it open
local cratePrefab = ItemPrefab.GetItemPrefab("vtarmorycrate")
local items = {
    "harpoongun", "harpoongun", "spear", "spear", "spear", "spear", "spear", "spear", "spear", "spear",
    "shotgun", "shotgunshell", "shotgunshell", "shotgunshell", "shotgunshell", "shotgunshell", "shotgunshell",
}

event.Start = function ()
    local position = nil

    for key, value in pairs(Submarine.MainSub.GetWaypoints(true)) do
        if value.AssignedJob and value.AssignedJob.Identifier == "securityofficer" then
            position = value.WorldPosition
            break
        end
    end

    if position == nil then
        position = Submarine.MainSub.WorldPosition
    end

    Entity.Spawner.AddItemToSpawnQueue(cratePrefab, position, nil, nil, function (crate)
        for _, identifier in ipairs(items) do
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab(identifier), crate.OwnInventory)
        end
    end)

    Traitormod.RoundEvents.SendEventMessage(Traitormod.Language.ArmoryCrate, "GameModeIcon.sandbox")

    event.End()
end

event.End = function ()

end

return event
