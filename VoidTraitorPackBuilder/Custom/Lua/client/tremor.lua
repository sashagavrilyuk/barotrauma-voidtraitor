if SERVER then return end

-- Rumble and camera shake for the server's SeismicTremor and IceCollapse events (traitormod Lua/config/randomevents).
local NET_TREMOR = "VoidTraitor_SeismicTremor"
local SHAKE_HOOK = "VoidTraitor.SeismicTremor.Shake"
local DURATION = 4
local SHAKE = 12
local SOUNDS = {
    { Path = "Content/Sounds/Ambient/GlacialMovement.ogg", Gain = 1 },
    { Path = "Content/Sounds/Hull/HullLong1.ogg", Gain = 0.8 },
    { Path = "Content/Sounds/Impact/MetalImpactHeavy1.ogg", Gain = 0.6 },
}

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")

-- loaded ahead of time: a sound played before its background loading finishes is cut off (Lua/client/station/announcements.lua)
for _, sound in ipairs(SOUNDS) do
    sound.Sound = gameMain.SoundManager.LoadSound(sound.Path)
end

Hook.Add("stop", "VoidTraitor.SeismicTremor", function ()
    for _, sound in ipairs(SOUNDS) do sound.Sound.Dispose() end
end)

Networking.Receive(NET_TREMOR, function ()
    for _, sound in ipairs(SOUNDS) do
        sound.Sound.Play(sound.Gain)
    end

    -- the camera eases its shake back to zero by itself, so keep it up while the tremor fades
    local endTime = Timer.GetTime() + DURATION
    Hook.Add("think", SHAKE_HOOK, function ()
        local left = endTime - Timer.GetTime()
        if left <= 0 then
            Hook.Remove("think", SHAKE_HOOK)
            return
        end
        local camera = gameMain.GameScreen.Cam
        camera.Shake = math.max(camera.Shake, SHAKE * left / DURATION)
    end)
end)
