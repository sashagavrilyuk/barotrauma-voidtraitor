Hook.Add("item.created", "VoidTraitorPack.MoreArts.ClownStandingPhysics", function(item)
    if item.Prefab.Identifier.Value ~= "artmod_clownstanding" then return end

    local previousSubmarine = item.Submarine
    item.UpdateTransform()
    if item.Submarine ~= previousSubmarine then
        item.body.SetTransform(item.body.SimPosition, item.body.Rotation)
    end
end)
