local objective = Traitormod.RoleManager.Objectives.Objective:new()

objective.Name = "DetonateNuke"
objective.Text = Traitormod.Language.ObjectiveDetonateNuke
objective.AmountPoints = 5000

function objective:Start()
    return true
end

-- a Station nuclear bomb went off at the station (Lua/gamemodes/station/nuclear.lua)
function objective:IsCompleted()
    return Traitormod.Nuclear.StationDestroyed == true
end

return objective
