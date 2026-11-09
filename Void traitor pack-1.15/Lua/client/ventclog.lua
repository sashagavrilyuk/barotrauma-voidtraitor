if SERVER then return end

-- Coloured gas of the server's VentClog event (traitormod Lua/config/randomevents/ventclog.lua): the server sends the
-- rooms the gas reaches, and the client keeps them filled with tinted mist until the gas is gone.
local NET_VENT_CLOG = "VoidTraitor_VentClog"
local THINK_HOOK = "VoidTraitor.VentClog"
local PARTICLE = "mist"
local INTERVAL = 0.25
-- one puff a second for every this many square pixels of a room
local AREA_PER_PUFF = 15000
-- the plain mist is too small and faint for a room full of gas
local SIZE_SCALE = 3
-- puffs start this far inside the walls, so they swell into the room rather than through the walls
local INSET = 50

local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local rooms = {}
local nextPuff = 0

local function update()
    local now = Timer.GetTime()
    if now < nextPuff then return end
    nextPuff = now + INTERVAL

    local any = false
    for hull, room in pairs(rooms) do
        if now >= room.EndsAt or hull.Removed then
            rooms[hull] = nil
        else
            any = true
            local rect = hull.WorldRect
            local puffs = rect.Width * rect.Height / AREA_PER_PUFF * INTERVAL
            for _ = 1, math.floor(puffs + math.random()) do
                local position = Vector2(rect.X + INSET + math.random() * (rect.Width - 2 * INSET),
                    rect.Y - INSET - math.random() * (rect.Height - 2 * INSET))
                local particle = gameMain.ParticleManager.CreateParticle(PARTICLE, position,
                    Vector2(math.random(-20, 20), math.random(-10, 10)), 0, hull)
                if particle ~= nil then
                    particle.ColorMultiplier = room.Color
                    particle.Size = particle.Size * SIZE_SCALE
                end
            end
        end
    end
    if not any then Hook.Remove("think", THINK_HOOK) end
end

Networking.Receive(NET_VENT_CLOG, function (message)
    -- an alpha of 2 makes the faint mist twice as opaque
    local color = Vector4(message.ReadByte() / 255, message.ReadByte() / 255, message.ReadByte() / 255, 2)
    local endsAt = Timer.GetTime() + message.ReadUInt16()
    for _ = 1, message.ReadUInt16() do
        local hull = Entity.FindEntityByID(message.ReadUInt16())
        if hull ~= nil then rooms[hull] = { Color = color, EndsAt = endsAt } end
    end
    Hook.Add("think", THINK_HOOK, update)
end)

Hook.Add("roundEnd", THINK_HOOK, function ()
    rooms = {}
    Hook.Remove("think", THINK_HOOK)
end)
