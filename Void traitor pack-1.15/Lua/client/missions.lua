local packPath = ...

local function isPackMission(mission)
    return mission.Prefab.ContentPackage.Dir == packPath
end

-- Missions from mods show the package name under their name; ours show only the name.
Hook.Patch("VoidTraitor.Missions.Name", "Barotrauma.Mission", "get_NameWithContentPackage", function(instance, ptable)
    if not isPackMission(instance) then return end
    ptable.PreventExecution = true
    return RichString.Plain(instance.Name)
end, Hook.HookMethodType.Before)

-- The round start message of the mission game mode doesn't mark the mission as shown,
-- so the first state change (e.g. the round ending) would show it a second time.
Hook.Patch("VoidTraitor.Missions.StartMessage", "Barotrauma.Mission", "ShowMissionStartMessageIfNeeded", function(instance, ptable)
    if isPackMission(instance) then ptable.PreventExecution = true end
end, Hook.HookMethodType.Before)
