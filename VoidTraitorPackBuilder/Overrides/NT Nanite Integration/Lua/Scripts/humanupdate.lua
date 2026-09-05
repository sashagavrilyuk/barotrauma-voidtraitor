
function NTNan.UpdateHuman(character)
        
    local afflictions = NTNan.GetAllNanAfflictions(character)

    if #afflictions == 0 then
        if HF.HasAffliction(character, "nanitedecay") then
            HF.AddAffliction(character, "nanitedecay", -1*1*NT.Deltatime)
        end
        if HF.HasAffliction(character, "naniteremover") then
            HF.SetAffliction(character, "naniteremover", 0)
        end
        return
    end

    if NTNan.hasEnoughPrecursors(character, afflictions) then
        HF.AddAffliction(character, "nanitedecay", -1*1*NT.Deltatime)
    else
        HF.AddAffliction(character, "nanitedecay", 1*NT.Deltatime)
    end

    if HF.HasAffliction(character, "nanitedecay") then
        if HF.GetAfflictionStrength(character, "nanitedecay") == 100 then
            for _,aff in pairs(afflictions) do

                if not(NTNan.AfflictionsCustom[aff] == nil) then
                    NTNan.AfflictionsCustom[aff][2](character)
                end
                if not(NTNan.AfflictionsHealing[aff] == nil) then
                    NTNan.AfflictionsHealing[aff][2](character)
                end

                HF.AddAffliction(character, aff, -10)
            end

            HF.AddAffliction(character, "nanitedecay", -100)

        end
    end

    for aff in afflictions do

        if not(NTNan.AfflictionsCustom[aff] == nil) then
            NTNan.AfflictionsCustom[aff][1](character)
        end
        if not(NTNan.AfflictionsHealing[aff] == nil) then
            NTNan.applyHeals(character, NTNan.GetAfflictionHeals(NTNan.AfflictionsHealing[aff][1], HF.GetAfflictionStrength(character, aff)))
        end

    end


    -- --Reconstructor
    -- if HF.HasAffliction(character, NTNan.Afflictions.Reconstructor) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.Reconstructor, HF.GetAfflictionStrength(character, NTNan.Afflictions.Reconstructor)))
    -- end

    -- --BoneFix
    -- if HF.HasAffliction(character, NTNan.Afflictions.BoneFix) then
        
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.BoneFix, HF.GetAfflictionStrength(character, NTNan.Afflictions.BoneFix)))
    -- end

    -- --DeepFix
    -- if HF.HasAffliction(character, NTNan.Afflictions.DeepFix) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.DeepFix, HF.GetAfflictionStrength(character, NTNan.Afflictions.DeepFix)))
    --     if RSENABLE == true then
    --         if HF.GetAfflictionStrength(character, NTNan.Afflictions.DeepFix) > 0 then
    --             applyHeals(character, {{"vibrationdamage", 0.5},{"nervedamage", 0,2},{"muscledamage", 0,2}})
    --         end
    --         if HF.GetAfflictionStrength(character, NTNan.Afflictions.DeepFix) > 1 then
    --             applyHeals(character, {{"rupturedlung", 1}})
    --         end
    --     end
    -- end

    -- --OxyBlood
    -- if HF.HasAffliction(character, NTNan.Afflictions.OxyBlood) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.OxyBlood, HF.GetAfflictionStrength(character, NTNan.Afflictions.OxyBlood)))
    -- end

    -- --AntiTox
    -- if HF.HasAffliction(character, NTNan.Afflictions.AntiTox) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.AntiTox, HF.GetAfflictionStrength(character, NTNan.Afflictions.AntiTox)))
    -- end

    -- --Neural
    -- if HF.HasAffliction(character, NTNan.Afflictions.Neural) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.Neural, HF.GetAfflictionStrength(character, NTNan.Afflictions.Neural)))
    --     if RSENABLE == true then
    --         if HF.GetAfflictionStrength(character, NTNan.Afflictions.DeepFix) > 0 then
    --             applyHeals(character, {{"brainhemorrhage", 2}})
    --         end
    --     end
    -- end

    -- --MechFix
    -- if HF.HasAffliction(character, NTNan.Afflictions.Mechfix) then
    --     applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.Mechfix, HF.GetAfflictionStrength(character, NTNan.Afflictions.Mechfix)))
    -- end

    -- --VisionBuff
    -- if EYESENABLED then
    --     if HF.HasAffliction(character, NTNan.Afflictions.VisionBuff) then
    --         applyHeals(character, NTNan.GetAfflictionResistances(NTNan.Afflictions.VisionBuff, HF.GetAfflictionStrength(character, NTNan.Afflictions.VisionBuff)))
    --     end
    -- end

    -- if IRENABLED then
    --     if HF.HasAffliction(character, NTNan.Afflictions.VisionBuff) then
    --         if HF.GetAfflictionStrength(character, NTNan.Afflictions.VisionBuff) > 1 then
    --             applyHeals(character, {{"welderseye", 5}})
    --         end
    --     end
    -- end

    -- --Husk
    -- if HF.HasAffliction(character, NTNan.Afflictions.Husk) then
        
    --     local tier = HF.GetAfflictionStrength(character, NTNan.Afflictions.Husk)

    --     if HF.HasAffliction(character, "huskinfection") then
    --         if math.floor(tier) == 1 then
    --             if HF.GetAfflictionStrength(character, "huskinfection") > 80 then
    --                 applyHeals(character, {{"huskinfection", 1}})
    --             end
    --         else
    --             applyHeals(character, {{"huskinfection", 5}})
    --         end
    --     end
    -- end

    --Remover
    if HF.HasAffliction(character, "naniteremover") then
        for e in afflictions do
            HF.SetAffliction(character, e, 0)
        end
        HF.SetAffliction(character, "naniteremover", 0)
    end
end

