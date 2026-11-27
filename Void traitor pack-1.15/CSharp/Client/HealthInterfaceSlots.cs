using System.Collections;
using System.Reflection;
using Barotrauma;
using Barotrauma.Plugins;
using HarmonyLib;
using Microsoft.Xna.Framework;

namespace VoidTraitor;

public sealed class HealthInterfaceSlots : IAssemblyPlugin
{
    private readonly Harmony harmony = new("VoidTraitor.HealthInterfaceSlots");
    private static readonly FieldInfo indicatorSprite = AccessTools.Field(
        AccessTools.Inner(typeof(CharacterHealth), "LimbHealth"), "IndicatorSprite");

    public void PreInitPatching() { }

    public void Initialize()
    {
        harmony.Patch(
            AccessTools.Method(typeof(CharacterHealth), nameof(CharacterHealth.GetInventorySlotPosition)),
            prefix: new HarmonyMethod(typeof(HealthInterfaceSlots), nameof(HasLimbIndicator)));
    }

    public void OnLoadCompleted() { }
    public void Dispose() => harmony.UnpatchSelf();

    private static bool HasLimbIndicator(
        CharacterHealth __instance,
        InvSlotType slotType,
        GUIComponent? ___limbSelection,
        IList ___limbHealths,
        ref Vector2? __result)
    {
        LimbType limbType = slotType switch
        {
            InvSlotType.LeftLegProsthetic => LimbType.LeftLeg,
            InvSlotType.RightLegProsthetic => LimbType.RightLeg,
            InvSlotType.LeftHandProsthetic => LimbType.LeftHand,
            InvSlotType.RightHandProsthetic => LimbType.RightHand,
            _ => LimbType.None,
        };
        if (limbType == LimbType.None) return true;

        // Slot layout can be requested before all limb indicators exist or while they are being removed.
        Limb? limb = __instance.Character?.AnimController?.GetLimb(limbType, excludeSevered: false);
        if (___limbSelection is not null && limb is not null
            && (uint)limb.HealthIndex < (uint)___limbHealths.Count
            && indicatorSprite.GetValue(___limbHealths[limb.HealthIndex]) is not null)
        {
            return true;
        }

        __result = null;
        return false;
    }
}
