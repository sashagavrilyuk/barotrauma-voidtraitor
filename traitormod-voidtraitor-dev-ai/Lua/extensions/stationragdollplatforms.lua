local extension = {}

extension.Identifier = "stationragdollplatforms"

function extension.Init()
    Hook.Patch("Barotrauma.Character", "Update", function(character)
        local selected = Traitormod.SelectedGamemode
        if selected == nil or selected.Name ~= "Station" or not character.Enabled
            or not character.IsHuman or character.IsDead or character.AnimController.InWater then return end

        if character.IsRagdolled or not character.CanMove then
            character.AnimController.IgnorePlatforms = false
        end
    end, Hook.HookMethodType.After)
end

return extension
