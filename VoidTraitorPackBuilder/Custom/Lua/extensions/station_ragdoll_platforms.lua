-- In Station rounds human characters that are knocked down stay on platforms instead of falling through them. This runs on
-- the server and on every client: clients simulate ragdolls themselves, so a fix on the server alone let the client drop
-- the body through the platform while the server held it up.
local stationRound = false
local patched = false

local function isStationCharacter(character)
    return stationRound and character.Enabled and not character.IsDead and character.IsHuman
        and not character.AnimController.InWater and character.SelectedBy == nil
end

local function patch()
    local physics = LuaUserData.CreateStatic("Barotrauma.Physics")

    Hook.Patch("VoidTraitorPack.StationRagdollPlatforms.Fall", "Barotrauma.Character", "Update", function(character)
        if not isStationCharacter(character) then return end
        if (character.IsRagdolled or not character.CanMove) and not character.AnimController.IsHangingWithRope then
            character.AnimController.IgnorePlatforms = false
        end
    end, Hook.HookMethodType.After)

    Hook.Patch("VoidTraitorPack.StationRagdollPlatforms.Stand", "Barotrauma.HumanoidAnimController", "UpdateAnim", {"System.Single"}, function(anim)
        local character = anim.Character
        if not isStationCharacter(character) or not character.CanMove or anim.Collider.Enabled
            or anim.IsHangingWithRope then return end

        local lowest = anim.FindLowestLimb()
        if lowest == nil then return end
        local x = anim.Collider.Position.X
        local y = lowest.Position.Y
        local platformY
        for _, wall in pairs(Structure.WallList) do
            if wall.IsPlatform and wall.HasBody and wall.Submarine == character.Submarine
                and x >= wall.Rect.X and x <= wall.Rect.Right
                and math.abs(y - wall.Rect.Y) <= 16
                and (platformY == nil or wall.Rect.Y > platformY) then
                platformY = wall.Rect.Y
            end
        end
        if platformY == nil then return end

        local collider = anim.Collider
        local targetY = platformY / physics.DisplayToSimRation + collider.Height / 2 + collider.Radius + anim.ColliderHeightFromFloor
        if collider.SimPosition.Y < targetY then
            collider.SetTransformIgnoreContacts(Vector2(collider.SimPosition.X, targetY), collider.Rotation)
            anim.ForceRefreshFloorY()
        end
    end, Hook.HookMethodType.Before)
end

-- the Station game mode always runs its vt_station mission, which clients know as well
Hook.Add("roundStart", "VoidTraitorPack.StationRagdollPlatforms", function()
    stationRound = false
    for mission in Game.GameSession.Missions do
        if mission.Prefab.Identifier == "vt_station" then stationRound = true end
    end
    -- patched only once a Station round starts: the patches then run for every character each frame for the rest of the session
    if stationRound and not patched then
        patched = true
        patch()
    end
end)

Hook.Add("roundEnd", "VoidTraitorPack.StationRagdollPlatforms", function()
    stationRound = false
end)
