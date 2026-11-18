-- Station research, as SS14's with Goob Station's tree (config/station.lua, Research; pack items/research.xml and
-- Lua/client/station/research.lua). The research server keeps the station's points, the console spends them on
-- technologies, and each technology opens recipes on the lathes. A lathe collects the recipes of the vanilla fabricators
-- it shares a tag with and keeps only those it prints from the start and those research opened, here and on every
-- client, so researching puts nothing over the crew's heads as the game's recipe unlocks do.
local research = {}
Traitormod.Research = research
local json = require("json")
-- read without this, the dictionary of a fabricator's recipes turns into a Lua table that cannot be put back
LuaUserData.RegisterType("System.Collections.Immutable.ImmutableDictionary`2[[System.UInt32],[Barotrauma.FabricationRecipe]]")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Fabricator"], "fabricationRecipes")
local teams = LuaUserData.CreateEnumTable("Barotrauma.CharacterTeamType")

local config, state
local sessions = {}
local consoleTexts = { "ResearchTitle", "ResearchClose", "ResearchPoints", "ResearchRecenter", "ResearchTier", "ResearchCost",
    "ResearchRequires", "ResearchUnlocks", "ResearchButton", "ResearchDoneButton", "ResearchNoAccess", "ResearchLockedTier", "ResearchMissingRequired",
    "ResearchNotEnough", "ResearchSelect", "ResearchTierShare" }

-- the game's own unlock of a recipe that needs one tells every client, which writes it over each crew member's head
local quietUnlock = false
Hook.Patch("Traitormod.Research.QuietRecipes", "Barotrauma.Networking.GameServer", "UnlockRecipe", function(_, parameters)
    if quietUnlock then parameters.PreventExecution = true end
end, Hook.HookMethodType.Before)

local function needsRecipe(identifier)
    if not ItemPrefab.Prefabs.ContainsKey(identifier) then return false end
    for recipe in ItemPrefab.Prefabs[identifier].FabricationRecipes.Values do
        if recipe.RequiresRecipe then return true end
    end
    return false
end

-- Recipes a lathe of this kind prints now: its static ones and those of its StaticFrom fabricator, less any a
-- technology holds, plus those of the technologies researched. Built from the first lathe of the kind seen.
local function allowedRecipes(latheId, fabricator)
    local lathe = config.Lathes[latheId]
    if state.Static[latheId] == nil then
        local static = {}
        for _, id in ipairs(lathe.Static) do static[id] = true end
        if lathe.StaticFrom ~= nil then
            for recipe in fabricator.fabricationRecipes.Values do
                for _, fabricatorId in ipairs(recipe.SuitableFabricatorIdentifiers) do
                    if fabricatorId.Value == lathe.StaticFrom then static[recipe.TargetItemPrefabIdentifier.Value] = true end
                end
            end
        end
        state.Static[latheId] = static
    end
    local allowed = {}
    for id in pairs(state.Static[latheId]) do allowed[id] = true end
    for _, technology in ipairs(config.Technologies) do
        for _, id in ipairs(technology.Recipes[latheId] or {}) do allowed[id] = state.Unlocked[technology.Id] == true end
    end
    local list = {}
    for id, open in pairs(allowed) do
        if open then list[#list + 1] = id end
    end
    table.sort(list)
    return list
end

local function filterLathe(item)
    local fabricator = item.GetComponentString("Fabricator")
    local latheId = item.Prefab.Identifier.Value
    if state.Full[item] == nil then state.Full[item] = fabricator.fabricationRecipes end
    local allowed = allowedRecipes(latheId, fabricator)
    state.Allowed[latheId] = allowed
    fabricator.fabricationRecipes = state.Full[item]
    local ids = {}
    for _, id in ipairs(allowed) do ids[#ids + 1] = Identifier(id) end
    fabricator.RemoveFabricationRecipes(ids)
end

-- every lathe on the station, and the recipes that need an unlock opened for the crew without telling anyone
local function applyRecipes()
    for item in pairs(state.Full) do
        if item.Removed then state.Full[item] = nil else filterLathe(item) end
    end
    quietUnlock = true
    for _, allowed in pairs(state.Allowed) do
        for _, id in ipairs(allowed) do
            if needsRecipe(id) then Game.GameSession.UnlockRecipe(teams.Team1, Identifier(id), false) end
        end
    end
    quietUnlock = false
end

function research.SendRecipes(client)
    if state == nil then return end
    local message = Networking.Start("VoidTraitor_ResearchRecipes")
    message.WriteString(json.encode(state.Allowed))
    Networking.Send(message, client ~= nil and client.Connection or nil)
end

-- A working server, as SS14 consoles need one: not broken and powered. Without one the station has no points; a broken
-- server loses them.
local function serverState()
    local found
    for item in pairs(state.Servers) do
        if item.Removed then
            state.Servers[item] = nil
        elseif item.Condition > 0 then
            if item.GetComponentString("Powered").Voltage >= 0.5 then return "ok" end
            found = "ResearchServerNoPower"
        else
            found = found or "ResearchServerBroken"
        end
    end
    return found or "ResearchServerMissing"
end

local function disciplineTiers()
    local tiers = {}
    for _, discipline in ipairs(config.Disciplines) do
        local tier = 2
        while tier <= #config.TierShare do
            local all, unlocked = 0, 0
            for _, technology in ipairs(config.Technologies) do
                if technology.Discipline == discipline.Id and technology.Tier == tier - 1 then
                    all = all + 1
                    if state.Unlocked[technology.Id] then unlocked = unlocked + 1 end
                end
            end
            if all == 0 or unlocked / all < config.TierShare[tier] then break end
            tier = tier + 1
        end
        tiers[discipline.Id] = tier - 1
    end
    return tiers
end

local function technologyState(technology, tiers)
    if state.Unlocked[technology.Id] then return "researched" end
    if technology.Tier > tiers[technology.Discipline] then return "locked" end
    for _, id in ipairs(technology.Requires or {}) do
        if not state.Unlocked[id] then return "locked" end
    end
    return state.Points >= technology.Cost and "available" or "unaffordable"
end

local function hasAccess(character)
    for slot = 0, character.Inventory.Capacity - 1 do
        local card = character.Inventory.GetItemAt(slot)
        if card ~= nil and card.GetComponentString("IdCard") ~= nil and card.HasTag(config.AccessTag) then return true end
    end
    return false
end

function research.Snapshot(client)
    local server = serverState()
    local tiers = disciplineTiers()
    local names = Traitormod.Language.ResearchTechnologies
    local snapshot = { Points = server == "ok" and state.Points or 0, Server = server ~= "ok" and Traitormod.GetText(server) or nil,
        Access = hasAccess(client.Character), Disciplines = {}, Technologies = {}, Text = {} }
    for _, discipline in ipairs(config.Disciplines) do
        local tier, all, unlocked = tiers[discipline.Id], 0, 0
        for _, technology in ipairs(config.Technologies) do
            if technology.Discipline == discipline.Id and technology.Tier == tier then
                all = all + 1
                if state.Unlocked[technology.Id] then unlocked = unlocked + 1 end
            end
        end
        snapshot.Disciplines[#snapshot.Disciplines + 1] = { Id = discipline.Id, Name = Traitormod.Language.ResearchDisciplines[discipline.Id],
            Color = discipline.Color, Tier = tier, Share = all > 0 and math.floor(unlocked / all * 100) or 0 }
    end
    for _, technology in ipairs(config.Technologies) do
        local recipes = {}
        for latheId, items in pairs(technology.Recipes) do
            for _, id in ipairs(items) do recipes[#recipes + 1] = { Item = id, Lathe = Traitormod.Language.ResearchLathes[latheId] } end
        end
        snapshot.Technologies[#snapshot.Technologies + 1] = { Id = technology.Id, Name = names[technology.Id].Name,
            Description = names[technology.Id].Description, Discipline = technology.Discipline, Tier = technology.Tier,
            Cost = technology.Cost, Position = technology.Position, Requires = technology.Requires or {}, Icon = technology.Icon,
            Recipes = recipes, State = technologyState(technology, tiers) }
    end
    for _, key in ipairs(consoleTexts) do snapshot.Text[key] = Traitormod.GetText(key) end
    return snapshot
end

local function validConsole(client, console, requireSelected)
    return state ~= nil and Game.RoundStarted and console ~= nil and not console.Removed and console.Prefab.Identifier == "vt_rnd_console"
        and client.Character ~= nil and client.Character.IsHuman and not client.Character.IsDead and not client.Character.IsIncapacitated
        and (not requireSelected or client.Character.SelectedItem == console) and console.CanClientAccess(client)
end

local function sendConsole(client, console)
    local message = Networking.Start("VoidTraitor_ResearchSnapshot")
    message.WriteUInt16(UShort(console.ID))
    message.WriteString(json.encode(research.Snapshot(client)))
    Networking.Send(message, client.Connection)
end

local function refreshConsoles()
    for client, console in pairs(sessions) do
        if validConsole(client, console, false) then sendConsole(client, console) else sessions[client] = nil end
    end
end

-- Points from artifacts and anomalies (SS14's ResearchServer points); nothing reaches a station without a working server.
function research.AddPoints(amount)
    if state == nil or serverState() ~= "ok" then return false end
    state.Points = state.Points + amount
    refreshConsoles()
    return true
end

local function researchTechnology(client, console, id)
    local technology = state.Technologies[id]
    if technology == nil or serverState() ~= "ok" or not hasAccess(client.Character)
        or technologyState(technology, disciplineTiers()) ~= "available" then return end
    state.Points = state.Points - technology.Cost
    state.Unlocked[id] = true
    applyRecipes()
    research.SendRecipes()
    local message = Networking.Start("VoidTraitor_ResearchDone")
    message.WriteUInt16(UShort(console.ID))
    message.WriteString(string.format(Traitormod.GetText("ResearchDone"), Traitormod.Language.ResearchTechnologies[id].Name))
    Networking.Send(message)
    Traitormod.Log(Traitormod.ClientLogName(client) .. " researched " .. id)
end

function research.Start(mode)
    config, sessions = mode.Research, {}
    state = { Points = config.StartPoints, Unlocked = {}, Technologies = {}, Full = {}, Static = {}, Allowed = {}, Servers = {}, Elapsed = 0 }
    for _, technology in ipairs(config.Technologies) do state.Technologies[technology.Id] = technology end
    for item in Item.ItemList do
        if config.Lathes[item.Prefab.Identifier.Value] ~= nil then state.Full[item] = item.GetComponentString("Fabricator").fabricationRecipes end
        if item.Prefab.Identifier == "vt_rnd_server" then state.Servers[item] = true end
    end
    applyRecipes()
    research.SendRecipes()
end

-- a server that breaks loses its points; open consoles follow the server's state
local lastServer
Hook.Add("think", "Traitormod.Research.Update", function(deltaTime)
    if state == nil then return end
    state.Elapsed = state.Elapsed + deltaTime
    if state.Elapsed < 1 then return end
    state.Elapsed = 0
    local server = serverState()
    if server == "ResearchServerBroken" or server == "ResearchServerMissing" then state.Points = 0 end
    if server ~= lastServer then
        lastServer = server
        refreshConsoles()
    end
end)

Hook.Add("item.created", "Traitormod.Research.NewDevice", function(item)
    if state == nil then return end
    local id = item.Prefab.Identifier.Value
    if id == "vt_rnd_server" then state.Servers[item] = true end
    if config.Lathes[id] ~= nil then
        state.Full[item] = item.GetComponentString("Fabricator").fabricationRecipes
        applyRecipes()
        research.SendRecipes()
    end
end)

local lastRequest = {}
Networking.Receive("VoidTraitor_ResearchRequest", function(message, client)
    local now = Timer.GetTime()
    if (lastRequest[client] or 0) > now then return end
    lastRequest[client] = now + 2
    research.SendRecipes(client)
end)
Networking.Receive("VoidTraitor_ResearchOpen", function(message, client)
    local console = Entity.FindEntityByID(message.ReadUInt16())
    -- the request can arrive before the server sees the console selected; research requires the selection
    if not validConsole(client, console, false) then return end
    sessions[client] = console
    sendConsole(client, console)
end)
Networking.Receive("VoidTraitor_ResearchAction", function(message, client)
    local console, action = Entity.FindEntityByID(message.ReadUInt16()), message.ReadString()
    if console == nil or sessions[client] ~= console then return end
    if action == "close" then sessions[client] = nil return end
    if not validConsole(client, console, true) then return end
    researchTechnology(client, console, message.ReadString())
    refreshConsoles()
end)
Hook.Add("roundEnd", "Traitormod.Research.End", function() state, sessions, lastServer = nil, {}, nil end)
Hook.Add("client.disconnected", "Traitormod.Research.Disconnect", function(client)
    sessions[client] = nil
    lastRequest[client] = nil
end)

return research
