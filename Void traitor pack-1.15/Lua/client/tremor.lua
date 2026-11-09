if SERVER then return end

-- Rumble, camera shake and the impact of the server's tremor (traitormod Lua/config/randomevents/utility/tremor.lua).
local NET_TREMOR = "VoidTraitor_SeismicTremor"
local SHAKE_HOOK = "VoidTraitor.SeismicTremor.Shake"
local DURATION = 5
local SHAKE = 30
local SOUNDS = {
    { Path = "Content/Sounds/Ambient/GlacialMovement.ogg", Gain = 1 },
    { Path = "Content/Sounds/Hull/HullLong1.ogg", Gain = 0.8 },
}

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
LuaUserData.MakeMethodAccessible(LuaUserData.RegisterType("Barotrauma.SubmarineBody"), "ApplyImpact")

-- loaded ahead of time: a sound played before its background loading finishes is cut off (Lua/client/station/announcements.lua)
for _, sound in ipairs(SOUNDS) do
    sound.Sound = gameMain.SoundManager.LoadSound(sound.Path)
end

Hook.Add("stop", "VoidTraitor.SeismicTremor", function ()
    for _, sound in ipairs(SOUNDS) do sound.Sound.Dispose() end
end)

Networking.Receive(NET_TREMOR, function (message)
    local impact, directionX = message.ReadSingle(), message.ReadSingle()
    -- the server's impact repeated here moves the own character at once instead of on the server's correction,
    -- as the game does with a collision of the sub
    local sub = Submarine.MainSub
    sub.SubBody.ApplyImpact(impact, Vector2(directionX, 0),
        ConvertUnits.ToSimUnits(sub.WorldPosition - Vector2(0, sub.Borders.Height)), false)

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
