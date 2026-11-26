local extension = {}

extension.Identifier = "ntmodconflict"

extension.Init = function ()
    Timer.Wait(function()
        if not NT or not NT.CheckModConflicts then return end

        local checkModConflicts = NT.CheckModConflicts
        NT.CheckModConflicts = function()
            local prefabs = ItemPrefab.Prefabs
            local bed = prefabs.ContainsKey("opdeco_hospitalbed") and prefabs["opdeco_hospitalbed"]
            local medicine = prefabs.ContainsKey("antidama2") and prefabs["antidama2"]
            local bedPackageId = bed and bed.ContentPackage.UgcId
            local medicinePackageId = medicine and medicine.ContentPackage.UgcId

            -- The bundled Hungry Europans patch is reported under the pack's name.
            if bedPackageId and bedPackageId.ToString() == "3466169195"
                and bed.FilePath.Value:match("/Hungry Europans NT Patch/Content/Beds%.xml$")
                and medicinePackageId and medicinePackageId.ToString() == "3190189044" then
                NT.modconflict = false
                return
            end

            checkModConflicts()
        end
    end, 1)
end

return extension
