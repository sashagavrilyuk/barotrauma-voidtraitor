-- The Station's own boats are not part of the station map: the evacuation ship named in the map's description and the
-- boats of the events from outside are loaded by the server and by every client right after the round's level, in
-- the same order, the way the game loads its respawn shuttle next. A loaded submarine takes its entity IDs after the
-- largest ID in use, so both sides give a boat the same IDs only if they load it at the same step of the round start.
-- The server's Station mode parks them (traitormod Lua/gamemodes/station/boats.lua and evacuation.lua).
local FOLDER = "void traitor pack submarine/Station/"

local function isStationRound(session)
    for mission in session.Missions do
        if mission.Prefab.Identifier == "vt_station" then return true end
    end
    return false
end

-- every boat of the Boat folder, and from the Evac folder the ship the map names as "EvacuationShuttle" in its
-- [traitormod] settings
local function stationBoats(station)
    local evacuationShuttle = string.match(station.Description.Value, '"EvacuationShuttle"%s*:%s*"([^"]+)"')
    local boats = {}
    for info in SubmarineInfo.SavedSubmarines do
        local path = string.gsub(info.FilePath, "\\", "/")
        if string.find(path, FOLDER .. "Boat/", 1, true)
            or (string.find(path, FOLDER .. "Evac/", 1, true) and info.Name == evacuationShuttle) then
            table.insert(boats, { Info = info, Path = path })
        end
    end
    table.sort(boats, function (a, b) return a.Path < b.Path end)
    return boats
end

Hook.Patch("VoidTraitorPack.StationBoats", "Barotrauma.GameSession", "StartRound", { "Barotrauma.LevelData", "System.Boolean" },
    function (session)
        if not isStationRound(session) then return end
        for _, boat in ipairs(stationBoats(session.SubmarineInfo)) do
            Submarine.Load(boat.Info, false)
        end
    end, Hook.HookMethodType.After)
