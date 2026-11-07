-- Station's take on the SS14 initial infected: a husk cultist who carries the parasite himself. The PatientZero event
-- (config/randomevents/patientzero.lua) times the infection; the role only needs its own name for its texts and shop.
local role = Traitormod.RoleManager.Roles.Cultist:new()

role.Name = "PatientZero"

return role
