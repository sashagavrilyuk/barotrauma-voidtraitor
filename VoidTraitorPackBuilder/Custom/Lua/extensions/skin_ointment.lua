local AfflictionsLoader = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions+NTAfflictionsLoader", true)
local AfflictionBuilder = LuaUserData.CreateStatic("Neurotrauma.NTAfflictions+NTAfflictionPrefabBuilder", true)
local priority = LuaUserData.CreateEnumTable("Neurotrauma.NTAfflictions+AfflictionPriority")

local wounds = {
    burn = 50,
    lacerations = 50,
    gunshotwound = 50,
    bitewounds = 100,
    explosiondamage = 50,
    blunttrauma = 100,
}

local loader = AfflictionsLoader("VoidTraitor")
local builder = AfflictionBuilder()
loader.Register(builder:New("skinointmented")
    :IsLimbSpecific(true)
    :SetStrengths(0, 100, 0)
    :SetPriority(priority.HIGH)
    :SetUpdateAction(function(character, identifier, limb, deltaTime)
        local strength = character.GetAfflictionStrengthLimb(identifier, limb)
        local healing = -math.min(strength, 1) * 0.12 * character.GetFloatStat("healingrate") * deltaTime
        for wound, threshold in pairs(wounds) do
            local damage = character.GetAfflictionStrengthLimb(wound, limb)
            if damage > 0 and damage < threshold then
                character.AddAfflictionLimb(wound, limb, healing)
            end
        end
        character.AddAfflictionLimb(identifier, limb, -0.2 * deltaTime)
    end)
    :Build())