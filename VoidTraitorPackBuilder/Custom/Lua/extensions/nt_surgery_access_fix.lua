local TagsToAdd = {"id_medic", "id_medical", "id_medicaldoctor", "med"}

local function upgradeIDCard(instance)
    local item = instance.item
    if item.HasTag("jobid:surgeon") then
        local updated = false

        -- Has to be added before to preserve the job identification
        if not item.HasTag("jobid:medicaldoctor") then
            item.Tags = "jobid:medicaldoctor," .. item.Tags
            updated = true
        end

        for _, tag in ipairs(TagsToAdd) do
            if not item.HasTag(tag) then
                item.AddTag(tag)
                updated = true
            end
        end

        if updated and SERVER then
            Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(item.SerializableProperties[Identifier("Tags")], item))
        end
    end
end

Hook.Patch(
    "VoidTraitor.NTSurgeryAccessFix.OnItemLoaded",
    "Barotrauma.Items.Components.IdCard",
    "OnItemLoaded",
    upgradeIDCard,
    Hook.HookMethodType.After
)

Hook.Patch(
    "VoidTraitor.NTSurgeryAccessFix.Initialize",
    "Barotrauma.Items.Components.IdCard",
    "Initialize",
    upgradeIDCard,
    Hook.HookMethodType.After
)
