Hook.Add("item.created", "VoidTraitorPack.MoreArts.ClownStandingPhysics", function(item)
    if item.Prefab.Identifier.Value ~= "artmod_clownstanding" then return end
    item.UpdateTransform()
end)
