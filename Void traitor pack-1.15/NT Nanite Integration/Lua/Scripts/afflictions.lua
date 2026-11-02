-- NTNan.Afflictions = {}
-- NTNan.AfflictionsRes = {}

-- NTNan.Afflictions.Decay = "nanitedecay"
-- NTNan.Afflictions.Precursor = "precursor"
-- NTNan.Afflictions.Remover = "naniteremover"
-- NTNan.Afflictions.Reconstructor = "reconstructornanite"
-- NTNan.Afflictions.DeepFix = "deepfixnanite"
-- NTNan.Afflictions.BoneFix = "bonefixnanite"
-- NTNan.Afflictions.OxyBlood = "oxybloodnanite"
-- NTNan.Afflictions.Husk = "husknanite"
-- NTNan.Afflictions.Neural = "neuralnanite"
-- NTNan.Afflictions.AntiTox = "antitoxnanite"
-- NTNan.Afflictions.VigorBuff = "vigorbuffnanite"
-- NTNan.Afflictions.HyperBuff = "hyperbuffnanite"
-- NTNan.Afflictions.VisionBuff = "visionbuffnanite"
-- NTNan.Afflictions.LaniusXeno = "laniusxenonanite"
-- NTNan.Afflictions.Mechfix = "mechfixnanite"

-- Checking if NT Eyes is present
NTNan.EYESENABLED = false
for _,v in pairs(NTC.RegisteredExpansions) do
    if v.Name == "Eyes" then
        NTNan.EYESENABLED = true
    end
end

NTNan.IRENABLED = false
NTNan.RSENABLE = false
for mod in ContentPackageManager.EnabledPackages.All do
    if mod.Name == "Immersive Repairs" then NTNan.IRENABLED = true end
    if mod.Name == "Real Sonar" then NTNan.RSENABLE = true end
end

NTNan.RegisterXMLAffliction("vigorbuffnanite")
NTNan.RegisterXMLAffliction("hyperbuffnanite")

-- Ichor
NTNan.RegisterHealingAffliction("reconstructornanite", {
    {{"burn", 0.3, true},{"acidburn",0.15, true},{"lacerations",0.3, true}},
    {{"bleeding",0.5, true},{"bleedingnonstop",0.5, true},{"bitewounds",0.3, true}},
    {{"gunshotwound",0.4, true}}}, function(character)
        for _,limb in pairs(NTNan.Limbs) do
            HF.AddAfflictionLimb(character, "burn", limb, 10)
        end
    end)

-- Osmium
NTNan.RegisterHealingAffliction("bonefixnanite", {
    {{"blunttrauma", 0.4, true},{"bonedamage",0.5, true},{"dislocation1", 5},{"dislocation2", 5},{"dislocation3", 5},{"dislocation4", 5}},
    {{"rl_fracture", 3},{"ll_fracture", 3},{"t_fracture",3},{"ra_fracture", 3},{"la_fracture", 3}},
    {{"n_fracture", 3},{"h_fracture",3},{"t_paralysis",1}}}, function (character)
        for _,limb in pairs(NTNan.Limbs) do
            HF.AddAfflictionLimb(character, "bonedamage", limb, 80)
        end
    end)

--Kaltsit
NTNan.RegisterHealingAffliction("deepfixnanite", {
    {{"internalbleeding", 0.25},{"foreignbody", 0.2, true}},
    {{"organdamage", 0.5},{"liverdamage",0.05},{"heartdamage",0.05},{"lungdamage",0.05},{"kidneydamage",0.05},{"liverdamage",0.05}}}, function(character)
        HF.AddAffliction(character, "organdamage", 60)
    end)

NTNan.RegisterCustomAffliction("deepfixnanite", function (character)
    if NTNan.RSENABLE == true then
        if HF.GetAfflictionStrength(character, "deepfixnanite") > 0 then
            NTNan.applyHeals(character, {{"vibrationdamage", 0.5, true},{"nervedamage", 0.2, true},{"muscledamage", 0.2, true}})
        end
        if HF.GetAfflictionStrength(character, "deepfixnanite") > 1 then
            NTNan.applyHeals(character, {{"rupturedlung", 1, true}})
        end
    end
end, function (_) end)

--Halesium
NTNan.RegisterHealingAffliction("oxybloodnanite",{
    {{"bloodloss", 0.2},{"oxygenlow",0.4},{"radiationsickness",0.2},{"hypoxemia",0.3}},
    {{"fibrillation",1},{"cardiacarrest",1},{"tamponade", 2},{"cerebralhypoxia",0.15}}}, function(character)
        HF.AddAffliction(character, "cardiacarrest", 10)
        HF.AddAffliction(character, "oxygenlow", 100)
    end)

--Mithridates
NTNan.RegisterHealingAffliction("antitoxnanite",{{{"drunk",0.5},{"opiateoverdose",1},{"morbusinepoisoning",1.2},{"deliriuminepoisoning",1.2},{"sufforinpoisoning",2.1},{"cyanidepoisoning",1.1},{"paralysis",1.1}},
    {{"sepsis",0.25}}}, function (character)
        HF.AddAffliction(character, "drunk", 60)
        HF.AddAffliction(character, "paralysis", 50)
    end)

--Cerebrate
NTNan.RegisterHealingAffliction("neuralnanite",{
    {{"psychosis",0.2},{"hallucinating",0.2},{"stun", 1.1},{"opiateaddiction",0.2},{"chemaddiction",0.2}}}, function (character)
        HF.AddAffliction(character, "stun", 100)
        HF.AddAffliction(character, "opiateaddiction", 100)
    end)

NTNan.RegisterCustomAffliction("neuralnanite", function (character)
    if NTNan.RSENABLE then
        NTNan.applyHeals(character, {{"brainhemorrhage", 2, true}})
    end
end, function (_) end)

--Makinis
NTNan.RegisterHealingAffliction("mechfixnanite", {
    {{"ntc_loosescrews", 0.5, true},{"ntc_bentmetal", 0.5,true}},
    {{"ntc_materialloss", 0.3,true},{"ntc_damagedelectronics", 0.3,true}}}, function (character)
        HF.AddAffliction(character, "stun", 50)
    end)

--VisionBuff
-- if NTNan.EYESENABLED then
--     NTNan.RegisterHealingAffliction("visionbuffnanite",{
--         {},
--         {{"dm_human", 0.5},{"dm_cyber", 0.5},{"dm_enhanced", 0.5},{"dm_plastic", 0.5},{"dm_crawler", 0.5},{"dm_mudraptor", 0.5},{"dm_hammerhead", 0.5},{"dm_watcher", 0.5},{"dm_husk", 0.5},{"dm_charybdis", 0.5},{"dm_latcher", 0.5},{"dm_terror", 0.5}}}, function (character)
--             HF.AddAffliction(character, "psychosis", 100)
--         end)
-- end

--VisionBuff
NTNan.RegisterCustomAffliction("visionbuffnanite", function (character)
    local heals = {}
    
    if HF.GetAfflictionStrength(character, "visionbuffnanite") > 1 then
        if NTNan.EYESENABLED then

            local l = {{"dm_human", 0.5},{"dm_cyber", 0.5},{"dm_enhanced", 0.5},{"dm_plastic", 0.5},{"dm_crawler", 0.5},{"dm_mudraptor", 0.5},{"dm_hammerhead", 0.5},{"dm_watcher", 0.5},{"dm_husk", 0.5},{"dm_charybdis", 0.5},{"dm_latcher", 0.5},{"dm_terror", 0.5}}

            for e in l do
                table.insert(heals, e)
            end
        end

        if NTNan.IRENABLED then
            table.insert(heals, {"welderseye", 5})
        end
    end

    NTNan.applyHeals(character, heals)
    
end, function (character)
    HF.AddAffliction(character, "psychosis", 100)
end)

--Husk
NTNan.RegisterCustomAffliction("husknanite", function (character)
    local tier = HF.GetAfflictionStrength(character, "husknanite")

    if HF.HasAffliction(character, "huskinfection") then
        if tier == 1 then
            if HF.GetAfflictionStrength(character, "huskinfection") > 80 then
                HF.SetAffliction(character, "huskinfection", 79)
                --NTNan.applyHeals(character, {{"huskinfection", 1}})
            end
        else
            NTNan.applyHeals(character, {{"huskinfection", 5}})
        end
    end
end, function (character)
    HF.AddAffliction(character, "t_fracture", 50)
end)


-- for _,v in pairs(NTC.RegisteredExpansions) do
--     if v.Name == "Eyes" then
--         print("NT Eyes detected !")

--     NTNan.AfflictionsRes[NTNan.Afflictions.VisionBuff] = {name = NTNan.Afflictions.VisionBuff, levels = {
--         {},
--         {{"dm_human", 0.5},{"dm_cyber", 0.5},{"dm_enhanced", 0.5},{"dm_plastic", 0.5},{"dm_crawler", 0.5},{"dm_mudraptor", 0.5},{"dm_hammerhead", 0.5},{"dm_watcher", 0.5},{"dm_husk", 0.5},{"dm_charybdis", 0.5},{"dm_latcher", 0.5},{"dm_terror", 0.5}}
--     }}


--     end


-- end

--HealingNanites
    --Ichor
-- NTNan.AfflictionsRes[NTNan.Afflictions.Reconstructor] = { name = NTNan.Afflictions.Reconstructor, levels = {
--     {{"burn", 0.3, true},{"acidburn",0.15, true},{"lacerations",0.3, true}},
--     {{"bleeding",0.5, true},{"bleedingnonstop",0.5, true},{"bitewounds",0.3, true}},
--     {{"gunshotwounds",0.2, true}}}
-- }
    --Osmium
-- NTNan.AfflictionsRes[NTNan.Afflictions.BoneFix] = { name = NTNan.Afflictions.BoneFix, levels = {
--     {{"blunttrauma", 0.4, true},{"bonedamage",0.5, true},{"dislocation1", 3},{"dislocation2", 3},{"dislocation3", 3},{"dislocation4", 3}},
--     {{"rl_fracture", 3},{"ll_fracture", 3},{"t_fracture",3},{"ra_fracture", 3},{"la_fracture", 3}},
--     {{"n_fracture", 3},{"h_fracture",3},{"t_paralysis",1}}}
-- }
    --Kaltsit
-- NTNan.AfflictionsRes[NTNan.Afflictions.DeepFix] = { name = NTNan.Afflictions.DeepFix, levels = {
--     {{"internalbleeding", 0.25},{"foreignbody", 0.2, true}},
--     {{"organdamage", 0.5},{"liverdamage",0.05},{"heartdamage",0.05},{"lungdamage",0.05},{"kidneydamage",0.05},{"liverdamage",0.05}}}
-- }
    --Halesium
-- NTNan.AfflictionsRes[NTNan.Afflictions.OxyBlood] = {name=NTNan.Afflictions.OxyBlood, levels = {
--     {{"bloodloss", 0.2},{"oxygenlow",0.4},{"radiationsickness",0.2},{"hypoxemia",0.3}},
--     {{"fibrillation",1},{"cardiacarrest",1},{"tamponade", 2},{"cerebralhypoxia",0.15}}}
-- }
    --Mithridates
-- NTNan.AfflictionsRes[NTNan.Afflictions.AntiTox] = {name=NTNan.Afflictions.AntiTox, levels = {
--     {{"drunk",0.5},{"opiateoverdose",1},{"morbusinepoisoning",1.2},{"deliriuminepoisoning",1.2},{"sufforinpoisoning",2.1},{"cyanidepoisoning",1.1},{"paralysis",1.1}},
--     {{"sepsis",0.25}}}
-- }
    --Cerebrate
-- NTNan.AfflictionsRes[NTNan.Afflictions.Neural] = {name=NTNan.Afflictions.Neural, levels = {
--     {{"psychosis",0.2},{"hallucinating",0.2},{"stun", 1.1},{"opiateaddiction",0.2},{"chemaddiction",0.2}}}
-- }

    --Makinis
-- NTNan.AfflictionsRes[NTNan.Afflictions.Mechfix] = {name = NTNan.Afflictions.Mechfix, levels = {
--     {{"ntc_loosescrews", 0.5, true},{"ntc_bentmetal", 0.5,true}},
--     {{"ntc_materialloss", 0.3,true},{"ntc_damagedelectronics", 0.3,true}}
-- }}

