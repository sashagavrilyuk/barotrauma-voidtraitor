local initialization = LuaUserData.CreateStatic("Neurotrauma.Initialization", true)
local human = LuaUserData.CreateStatic("Neurotrauma.NTHuman", true)
local treatmentInfo = LuaUserData.CreateStatic("Neurotrauma.NTItems+ItemUpdateFunctionInfos", true)
local cooldown = LuaUserData.CreateStatic("Barotrauma.HealingCooldown", true)

-- Match the tools and limb requirements from Neurotrauma's surgery kit menu.
local surgicalTools = {
    advscalpel = true,
    advhemostat = true,
    advretractors = true,
    surgicaldrill = true,
    surgerysaw = true,
    tweezers = true,
    traumashears = true,
    organscalpel_kidneys = LimbType.Torso,
    organscalpel_liver = LimbType.Torso,
    organscalpel_lungs = LimbType.Torso,
    organscalpel_heart = LimbType.Torso,
    organscalpel_brain = LimbType.Head,
}

-- Replace the upstream receiver, which uses the supplied character IDs directly.
Networking.Receive("NT.HUIButtonTreatment", function(message, client)
    local user = client and client.Character
    if not Game.RoundStarted or not user or not user.Enabled or user.IsDead or user.IsIncapacitated then return end
    if cooldown.IsOnCooldown(client) or message.ReadUInt16() ~= user.ID then return end
    cooldown.SetCooldown(client)

    local target = Entity.FindEntityByID(message.ReadUInt16())
    local limbIndex = message.ReadInt32()
    local tool = message.ReadString()
    local requiredLimb = surgicalTools[tool]
    if not requiredLimb or not target or not LuaUserData.IsTargetType(target, "Barotrauma.Character") then return end
    if target.Removed or target.IsDead then return end
    if target ~= user and (user.SelectedCharacter ~= target or not user.CanInteractWith(target)) then return end

    local kit = user.Inventory and user.Inventory.FindItemByIdentifier("surgerykit", true)
    if not kit or not user.CanInteractWith(kit) then return end

    local targetLimb
    for limb in target.AnimController.Limbs do
        if limb.HealthIndex == limbIndex then
            targetLimb = limb
            break
        end
    end
    if not targetLimb or (requiredLimb ~= true and targetLimb.type ~= requiredLimb) then return end

    local surgeon, patient = human.getNTHumanFromCharacter(user), human.getNTHumanFromCharacter(target)
    local treat = initialization.NTItemsLoader.Get(tool)
    if not surgeon or not patient or not treat then return end

    Hook.Call("voidtraitor.surgeryButtonTreatment", user, target)
    treat(treatmentInfo(nil, surgeon, patient, targetLimb))
end)
