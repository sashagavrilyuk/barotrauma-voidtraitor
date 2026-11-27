using System;
using Barotrauma;
using Barotrauma.Plugins;
using HarmonyLib;

namespace VoidTraitor;

public sealed class CyberneticInjuries : IAssemblyPlugin
{
    private readonly Harmony harmony = new("VoidTraitor.CyberneticInjuries");
    private static Func<Character, string, LimbType, float, bool> hasAfflictionLimb = null!;
    private static Func<LimbType, LimbType> normalizeLimbType = null!;

    public void PreInitPatching() { }

    public void Initialize()
    {
        Type helpers = AccessTools.TypeByName("Neurotrauma.HF")
            ?? throw new InvalidOperationException("Neurotrauma.HF is unavailable.");
        hasAfflictionLimb = AccessTools.Method(
            helpers, "HasAfflictionLimb", new[] { typeof(Character), typeof(string), typeof(LimbType), typeof(float) })
            .CreateDelegate<Func<Character, string, LimbType, float, bool>>();
        normalizeLimbType = AccessTools.Method(helpers, "NormalizeLimbType", new[] { typeof(LimbType) })
            .CreateDelegate<Func<LimbType, LimbType>>();

        var prefix = new HarmonyMethod(typeof(CyberneticInjuries), nameof(AllowInjury));
        Type[] arguments = { typeof(Character), typeof(LimbType), typeof(float) };
        foreach (string method in new[] { "BreakLimb", "DislocateLimb", "ArteryCutLimb" })
        {
            harmony.Patch(AccessTools.Method(helpers, method, arguments), prefix: prefix);
        }
    }

    public void OnLoadCompleted() { }

    public void Dispose() => harmony.UnpatchSelf();

    private static bool AllowInjury(
        [HarmonyArgument(0)] Character character,
        [HarmonyArgument(1)] LimbType limb,
        [HarmonyArgument(2)] float strength)
    {
        return strength <= 0f || !hasAfflictionLimb(character, "ntc_cyberlimb", normalizeLimbType(limb), 0.1f);
    }
}