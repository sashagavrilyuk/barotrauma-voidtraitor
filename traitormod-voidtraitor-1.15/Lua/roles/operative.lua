-- SS14's lone operative: a separatist who comes on his own shuttle to blow up the station with its own nuclear bomb. The
-- LoneOperative event (config/randomevents/loneoperative.lua) brings him in; the role gives him the codes of the bombs.
local role = Traitormod.RoleManager.Roles.Antagonist:new()

role.Name = "Operative"

function role:Start()
    local objective = Traitormod.RoleManager.Objectives.DetonateNuke:new()
    objective:Init(self.Character)
    if objective:Start() then self:AssignObjective(objective) end

    local client = Traitormod.FindClientCharacter(self.Character)
    if client ~= nil then
        local text = self:Greet()
        Traitormod.SendTraitorMessageBox(client, text)
        Traitormod.UpdateVanillaTraitor(client, true, text)
    end
end

function role:Greet()
    return Traitormod.FormatText("OperativeYou", table.concat(Traitormod.Nuclear.Codes(), ", "))
end

return role
