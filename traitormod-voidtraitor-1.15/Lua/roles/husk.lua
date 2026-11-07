-- A player who turned into a husk on Station. Unlike the husk church servant there are no cultists to obey: the husk
-- spreads the infection.
local role = Traitormod.RoleManager.Roles.HuskServant:new()

role.Name = "Husk"

function role:Greet()
    return Traitormod.Language.HuskYou
end

function role:OtherGreet()
    return string.format(Traitormod.Language.HuskOther, self.Character.Name)
end

return role
