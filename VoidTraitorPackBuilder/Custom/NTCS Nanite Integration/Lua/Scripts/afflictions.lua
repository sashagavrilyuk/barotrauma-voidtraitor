-- NTCS_Nanite.Afflictions = {}
-- NTCS_Nanite.AfflictionsRes = {}

-- NTCS_Nanite.Afflictions.Decay = "nanitedecay"
-- NTCS_Nanite.Afflictions.Precursor = "precursor"
-- NTCS_Nanite.Afflictions.Remover = "naniteremover"
-- NTCS_Nanite.Afflictions.Reconstructor = "reconstructornanite"
-- NTCS_Nanite.Afflictions.DeepFix = "deepfixnanite"
-- NTCS_Nanite.Afflictions.BoneFix = "bonefixnanite"
-- NTCS_Nanite.Afflictions.OxyBlood = "oxybloodnanite"
-- NTCS_Nanite.Afflictions.Husk = "husknanite"
-- NTCS_Nanite.Afflictions.Neural = "neuralnanite"
-- NTCS_Nanite.Afflictions.AntiTox = "antitoxnanite"
-- NTCS_Nanite.Afflictions.VigorBuff = "vigorbuffnanite"
-- NTCS_Nanite.Afflictions.HyperBuff = "hyperbuffnanite"
-- NTCS_Nanite.Afflictions.VisionBuff = "visionbuffnanite"
-- NTCS_Nanite.Afflictions.LaniusXeno = "laniusxenonanite"
-- NTCS_Nanite.Afflictions.Mechfix = "mechfixnanite"

-- Checking if NT Eyes is present

NTCS_Nanite.EYESENABLED = NTCS.Info.isAddonRegistered("NT Eyes")

NTCS_Nanite.IRENABLED = false
NTCS_Nanite.RSENABLE = false
for mod in ContentPackageManager.EnabledPackages.All do
    if mod.Name == "Immersive Repairs" then NTCS_Nanite.IRENABLED = true end
    if mod.Name == "Real Sonar" then NTCS_Nanite.RSENABLE = true end
end

local affLoader = NTCS.AfflictionsLoader(NTCS_Nanite.Name)
local builder = NTCS.AfflictionPrefabBuilder()

affLoader.Register(
    builder:New("vigorbuffnanite")
    :SetStrengths(0,2,0)
    :SetPriority(NTCS.AfflictionsPriority.LOW)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)
    end)
    :Build())

affLoader.Register(
    builder:New("hyperbuffnanite")
    :SetStrengths(0,2,0)
    :SetPriority(NTCS.AfflictionsPriority.LOW)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)
    end)
    :Build())

-- Ichor
affLoader:Register(
    builder:New("reconstructornanite")
    :SetStrengths(0,6,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        NTCS_Nanite.addAfflictionAllLimbs(C, "burn", 0.3 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "acidburn", 0.15 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "lacerations", 0.3 * -1 * dT)

        if str >= 3.5 then
            -- Tier 2
            NTCS_Nanite.addAfflictionAllLimbs(C, "bleeding", 0.5 * -1 * dT)
            NTCS_Nanite.addAfflictionAllLimbs(C, "bleedingnonstop", 0.5 * -1 * dT)
            NTCS_Nanite.addAfflictionAllLimbs(C, "bitewounds", 0.3 * -1 * dT)

            if str >= 5.5 then
                -- Tier 3
                NTCS_Nanite.addAfflictionAllLimbs(C, "gunshotwound", 0.4 * -1 * dT)
            end
        end

    end)
    :Build())


-- Osmium
affLoader:Register(
    builder:New("bonefixnanite")
    :SetStrengths(0,6,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        NTCS_Nanite.addAfflictionAllLimbs(C, "blunttrauma", 0.4 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "bonedamage", 0.5 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "dislocation", 5 * -1 * dT)


        if str >= 3.5 then
            -- Tier 2
            NTCS_Nanite.addAfflictionAllLimbs(C, "fracturedextremity", 3 * -1 * dT)
            C:AddAffliction("fracturedribs", 3 * -1 * dT)

            if str >= 5.5 then
                -- Tier 3
                C:AddAffliction("fracturedneck", 3 * -1 * dT)
                C:AddAffliction("fracturedskull", 3 * -1 * dT)
                C:AddAffliction("spinalcordinjury", 1 * -1 * dT)
            end
        end

    end)
    :Build()
)


--Kaltsit
affLoader:Register(
    builder:New("deepfixnanite")
    :SetStrengths(0,4,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        C:AddAffliction("internalbleeding", 0.25 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "foreignbody", 0.2 * -1 * dT)

        if NTCS_Nanite.RSENABLE then
            NTCS_Nanite.addAfflictionAllLimbs(C, "vibrationdamage", 0.5 * -1 * dT)
            NTCS_Nanite.addAfflictionAllLimbs(C, "nervedamage", 0.2 * -1 * dT)
            NTCS_Nanite.addAfflictionAllLimbs(C, "muscledamage", 0.2 * -1 * dT)
        end

        if str >= 3.5 then
            -- Tier 2
            C:AddAffliction("organdamage", 0.5 * -1 * dT)
            C:AddAffliction("liverdamage", 0.05 * -1 * dT)
            C:AddAffliction("heartdamage", 0.05 * -1 * dT)
            C:AddAffliction("lungdamage", 0.05 * -1 * dT)
            C:AddAffliction("kidneydamage", 0.05 * -1 * dT)
            C:AddAffliction("liverdamage", 0.05 * -1 * dT)

            if NTCS_Nanite.RSENABLE then
                C:AddAffliction("rupturedlung", 1 * -1 * dT)
            end
        end

    end)
    :Build())


--Halesium
affLoader:Register(
    builder:New("oxybloodnanite")
    :SetStrengths(0,4,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        C:AddAffliction("bloodloss", 0.2 * -1 * dT)
        C:AddAffliction("oxygenlow", 0.4 * -1 * dT)
        C:AddAffliction("radiationsickness", 0.2 * -1 * dT)
        C:AddAffliction("hypoxemia", 0.3 * -1 * dT)

        if str >= 3.5 then
            -- Tier 2
            C:AddAffliction("fibrillation", 1 * -1 * dT)
            C:AddAffliction("cardiacarrest", 1 * -1 * dT)
            C:AddAffliction("tamponade", 2 * -1 * dT)
            C:AddAffliction("neurotrauma", 0.15 * -1 * dT)
        end

    end)
    :Build())


--Mithridates
affLoader:Register(
    builder:New("antitoxnanite")
    :SetStrengths(0,4,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        C:AddAffliction("drunk", 0.5 * -1 * dT)
        C:AddAffliction("opiateoverdose", 1 * -1 * dT)
        C:AddAffliction("morbusinepoisoning", 1.2 * -1 * dT)
        C:AddAffliction("deliriuminepoisoning", 1.2 * -1 * dT)
        C:AddAffliction("sufforinpoisoning", 2.1 * -1 * dT)
        C:AddAffliction("cyanidepoisoning", 1.1 * -1 * dT)
        C:AddAffliction("paralysis", 1.1 * -1 * dT)

        if str >= 3.5 then
            -- Tier 2
            C:AddAffliction("sepsis", 0.25 * -1 * dT)
        end

    end)
    :Build()
)


--Cerebrate
affLoader:Register(
    builder:New("neuralnanite")
    :SetStrengths(0,2,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        -- Tier 1
        C:AddAffliction("psychosis", 0.2 * -1 * dT)
        C:AddAffliction("hallucinating", 0.2 * -1 * dT)
        C:AddAffliction("stun", 1.1 * -1 * dT)
        C:AddAffliction("opiateaddiction", 0.2 * -1 * dT)
        C:AddAffliction("chemaddiction", 0.2 * -1 * dT)

        if NTCS_Nanite.RSENABLE then
            C:AddAfflictionLimb("brainhemorrhage", LimbType.head ,2 * -1 * dT)
        end

    end)
    :Build())


--Makinis
affLoader:Register(
    builder:New("mechfixnanite")
    :SetStrengths(0,4,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        NTCS_Nanite.addAfflictionAllLimbs(C, "ntc_loosescrews", 0.5 * -1 * dT)
        NTCS_Nanite.addAfflictionAllLimbs(C, "ntc_bentmetal", 0.5 * -1 * dT)

        if str >= 3.5 then
            -- Tier 2
            NTCS_Nanite.addAfflictionAllLimbs(C, "ntc_materialloss", 0.3 * -1 * dT)
            NTCS_Nanite.addAfflictionAllLimbs(C, "ntc_damagedelectronics", 0.3 * -1 * dT)
        end

    end)
    :Build())


--VisionBuff
affLoader:Register(
    builder:New("visionbuffnanite")
    :SetStrengths(0,2,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end

        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        if str > 1 then
            if NTCS_Nanite.EYESENABLED then
                C:AddAffliction("dm_human", 0.5 * -1 * dT)
                C:AddAffliction("dm_cyber", 0.5 * -1 * dT)
                C:AddAffliction("dm_enhanced", 0.5 * -1 * dT)
                C:AddAffliction("dm_plastic", 0.5 * -1 * dT)
                C:AddAffliction("dm_crawler", 0.5 * -1 * dT)
                C:AddAffliction("dm_mudraptor", 0.5 * -1 * dT)
                C:AddAffliction("dm_hammerhead", 0.5 * -1 * dT)
                C:AddAffliction("dm_watcher", 0.5 * -1 * dT)
                C:AddAffliction("dm_husk", 0.5 * -1 * dT)
                C:AddAffliction("dm_charybdis", 0.5 * -1 * dT)
                C:AddAffliction("dm_latcher", 0.5 * -1 * dT)
                C:AddAffliction("dm_terror", 0.5 * -1 * dT)
            end

            if NTCS_Nanite.IRENABLED then
                C:AddAffliction("welderseye", 5 * -1 * dT)
            end
        end

    end)
    :Build())


--Husk
affLoader:Register(
    builder:New("husknanite")
    :SetStrengths(0,2,0)
    :SetPriority(NTCS.AfflictionsPriority.MEDIUM)
    :SetUpdateAction(function(C, ID, Limb, dT)

        if C:GetBoolStat("stasis", false) then return end
        if not C:GetBoolStat("naniteEnoughBattery", false) then
            C:SetAffliction("nanitenobattery", 2)
            return
        end

        NTCS_Nanite.downBattery(C, 0.025 * dT)

        local str = C:GetAfflictionStrength(ID)

        -- Tier 1
        if C:HasAffliction("huskinfection") then
            if str >= 1.5 then
                if C:GetAfflictionStrength("huskinfection") > 80 then
                    C:SetAffliction("huskinfection", 79)
                end
            else
                C:AffAffliction("huskinfection", 5 * -1 * dT)
            end
        end

    end)
    :Build())


--Nanite battery
affLoader:Register(
    builder:New("nanitebattery")
    :SetPriority(NTCS.AfflictionsPriority.LOW)
    :SetStrengths(0,200,0)
    :SetUpdateAction(function(C, ID, Limb, dT)

        local str = C:GetAfflictionStrength(ID)

        if str <= 20 then
            if str <= 2 then
                C:SetAffliction("nanitenobattery", 2)
            else
                C:SetAffliction("nanitebatterylow", 2)
            end
        else
            C:SetAffliction("nanitenobattery", 0)

            C:SetAffliction("nanitebatterylow", 0)
        end

    end)
    :Build())