-- Alien artifacts of the Station's xenoarchaeology (traitormod Lua/gamemodes/station/xenoarch.lua). Their XML gets in
-- memory the status effects that tell the server what happened to the artifact, the light of SS14's PointLight effect
-- and, on a big artifact, the effects of its whole family. The server and every client add exactly the same, since
-- network events address components by index. An artifact runs only the effects of its own tier; in a Station round a
-- big one runs none until the server wakes the tier of the node it sits on, while trinkets keep theirs.
if CLIENT and not Game.IsMultiplayer then return end

local NET_TIER, NET_REQUEST = "VoidTraitor_ArtifactTier", "VoidTraitor_ArtifactTierRequest"

-- weakest to strongest: the vanilla artifact, then More Arts' of the same kind, which it tags by kind and prices 1500,
-- 2500 and 5000. The rusted ones cost the same; the one heard across the station comes last.
local FAMILIES = {
    { "thermalartifact", "artmod_brazierartifact", "artmod_meltingartifact", "artmod_infernoartifact" },
    { "faradayartifact", "artmod_pulseartifact", "artmod_sparkartifact", "artmod_electrodeathartifact" },
    { "psychosisartifact", "artmod_silentartifact", "artmod_zombieartifact", "artmod_mindbentartifact" },
    { "nasonovartifact", "artmod_incubatorartifact", "artmod_heartoftheswarmartifact", "artmod_heartofEuropeartifact" },
    { "skyholderartifact", "artmod_vacuumartifact", "artmod_biohazardartifact" },
    { "artmod_vampireartifact", "artmod_theheavenartifact", "artmod_oasisartifact" },
    { "rust2artifact", "rust3artifact", "rust1artifact" },
}
local TRINKETS = {
    "alientrinket1", "alientrinket2", "alientrinket3", "artmod_alientrinket1_shock", "artmod_alientrinket2_wax",
    "artmod_alientrinket3_brainbreaker", "artmod_alientrinket4_eyes", "artmod_alientrinket5_figure",
    "artmod_alientrinket6_hugebracelet", "artmod_alientrinket7_piece", "artmod_alientrinket8_psihealsphere",
    "artmod_alientrinket9_slowdownsphere", "artmod_alientrinket10_lamp", "artmod_alientrinket11_chief",
    "artmod_alientrinket12_animation", "artmod_alientrinket13_nomnom", "artmod_alientrinket14_whereisit",
    "artmod_alientrinket15_mimic", "artmod_alientrinket16_invisible", "artmod_alientrinket17_blind",
    "artmod_alientrinket18_wrongbox", "artmod_alientrinket19_anotherlamp", "artmod_alientrinket11_browtube",
    "artmod_alientrinket12_greentube", "artmod_alientrinket13_pinktube", "artmod_alientrinket14_bluetube",
    "artmod_alientrinket15_redtube", "artmod_alientrinket16_rottube", "artmod_alientrinket17_lightbluetube",
}

-- What happens to the artifact, for its node's trigger; damage and landing after a throw the server sees itself. The
-- lasting ones call it only while the server has armed the artifact with that trigger's tag. A status effect passes when
-- any of its conditionals does, unless told otherwise.
local TRIGGERS = {
    '<StatusEffect type="OnPicked" target="This"><LuaHook name="VoidTraitor.ArtifactTrigger" trigger="examine" /></StatusEffect>',
    '<StatusEffect type="OnFire" target="This"><Conditional hastag="vt_xenoarch_heat" /><LuaHook name="VoidTraitor.ArtifactTrigger" trigger="heat" /></StatusEffect>',
    '<StatusEffect type="InWater" target="This"><Conditional hastag="vt_xenoarch_water" /><LuaHook name="VoidTraitor.ArtifactTrigger" trigger="water" /></StatusEffect>',
    [[<StatusEffect type="OnContained" target="This" comparison="and">
        <Conditional hastag="vt_xenoarch_electricity" />
        <Conditional hastag="neq artifactcontainer" targetcontainer="true" />
        <Conditional hastag="neq vt_artifact_analyzer" targetcontainer="true" />
        <Conditional voltage="gte 0.5" targetcontainer="true" />
        <LuaHook name="VoidTraitor.ArtifactTrigger" trigger="electricity" />
    </StatusEffect>]],
}
local GLOW = '<LightComponent range="300" lightcolor="180,220,255,180" IsOn="false" castshadows="false" allowingameediting="false" />'
local HOSTS = { holdable = true, throwable = true, wearable = true }

local maxTiers = 0
for _, family in ipairs(FAMILIES) do maxTiers = math.max(maxTiers, #family) end
local TIER_TAGS = {}
for tier = 1, maxTiers do TIER_TAGS[tier] = Identifier("vt_xenoarch_tier" .. tier) end

local function nameOf(element)
    return string.lower(element.Name.LocalName)
end

local function attribute(element, name)
    for found in element.Attributes() do
        if string.lower(found.Name.LocalName) == name then return found end
    end
end

-- what is changed in the prefabs' XML, undone when the client leaves for the menu, singleplayer or another server
local undo = {}
local function add(parent, element)
    parent.Add(element)
    undo[#undo + 1] = function() element.Remove() end
end
local function setAttribute(element, name, value)
    local found = attribute(element, name)
    local old = found ~= nil and found.Value or nil
    if found ~= nil then found.Value = value else element.SetAttributeValue(name, value) end
    undo[#undo + 1] = function()
        if found ~= nil then found.Value = old else element.SetAttributeValue(name, nil) end
    end
end

-- a tier's tag joins the effect's status tags, which the game reads from statuseffecttags or else tags
local function tagTier(effect, tier)
    local tags = attribute(effect, "statuseffecttags") or attribute(effect, "tags")
    local tag = "vt_xenoarch_tier" .. tier
    if tags == nil then setAttribute(effect, "tags", tag) else setAttribute(effect, nameOf(tags), tags.Value .. "," .. tag) end
end

-- another package's element in this item: its %ModDir% has to keep naming that package
local function copyOf(xml, package)
    local copy = XElement.Parse(xml)
    for element in copy.DescendantsAndSelf() do
        for found in element.Attributes() do
            local value, count = string.gsub(found.Value, "%%ModDir%%", "%%ModDir:" .. package .. "%%")
            if count > 0 then found.Value = value end
        end
    end
    return copy
end

local function hostOf(root)
    for element in root.Elements() do
        if HOSTS[nameOf(element)] then return element end
    end
end

-- what the artifact sounds and sparkles like when it goes off (Lua/client/station/xenoarch.lua): its own sound, a loop
-- only when it has nothing else, and the rusted ones that have none clank like a failed repair
local function ownSound(root, identifier)
    local loop
    for element in root.Descendants() do
        local file = nameOf(element) == "sound" and attribute(element, "file") or nil
        if file ~= nil then
            if not string.find(string.lower(file.Value), "loop", 1, true) then return file.Value end
            loop = loop or file.Value
        end
    end
    return loop or (string.sub(identifier, 1, 4) == "rust" and "Content/Items/MechanicalRepairFail.ogg" or "")
end

local function ownParticle(root)
    for element in root.Descendants() do
        local particle = nameOf(element) == "particleemitter" and attribute(element, "particle") or nil
        if particle ~= nil then return particle.Value end
    end
    return ""
end

-- sound and particle as the item had them before anything was added
local function finish(root, kind, sound, particle)
    setAttribute(root, "vtsound", sound)
    setAttribute(root, "vtparticle", particle)
    setAttribute(root, "vtartifact", kind)
    for _, xml in ipairs(TRIGGERS) do add(hostOf(root), XElement.Parse(xml)) end
    -- last, where the server's PointLight effect looks for it (xenoarch_effects.lua)
    add(root, XElement.Parse(GLOW))
end

-- the components of an item that carry status effects, as they were before anything was added
local function componentsOf(root)
    local components = {}
    for element in root.Elements() do
        local effects, effectXml = {}, {}
        for child in element.Elements() do
            if nameOf(child) == "statuseffect" then
                effects[#effects + 1] = child
                effectXml[#effectXml + 1] = tostring(child)
            end
        end
        if #effects > 0 then
            components[#components + 1] = { Element = element, Name = nameOf(element), Xml = tostring(element),
                Effects = effects, EffectXml = effectXml }
        end
    end
    return components
end

-- lower-case identifier -> its tier and how many its family has
local big = {}
for _, family in ipairs(FAMILIES) do
    local members = {}
    for tier, identifier in ipairs(family) do
        local prefab = ItemPrefab.Prefabs[identifier]
        local root = prefab.ConfigElement.Element
        members[tier] = { Prefab = prefab, Root = root, Components = componentsOf(root), Sound = ownSound(root, identifier),
            Particle = ownParticle(root) }
        big[string.lower(identifier)] = { Tier = tier, Tiers = #family }
    end
    for tier, member in ipairs(members) do
        local host = hostOf(member.Root)
        for _, component in ipairs(member.Components) do
            for _, effect in ipairs(component.Effects) do tagTier(effect, tier) end
            if not HOSTS[component.Name] then setAttribute(component.Element, "vttier", tostring(tier)) end
        end
        for otherTier, other in ipairs(members) do
            if other ~= member then
                local package = other.Prefab.ContentPackage.Name
                for _, component in ipairs(other.Components) do
                    if HOSTS[component.Name] then
                        for _, xml in ipairs(component.EffectXml) do
                            local effect = copyOf(xml, package)
                            tagTier(effect, otherTier)
                            add(host, effect)
                        end
                    -- a container would give every artifact of the family a slot
                    elseif component.Name ~= "itemcontainer" then
                        local copy = copyOf(component.Xml, package)
                        copy.SetAttributeValue("vttier", tostring(otherTier))
                        for child in copy.Elements() do
                            if nameOf(child) == "statuseffect" then tagTier(child, otherTier) end
                        end
                        add(member.Root, copy)
                    end
                end
            end
        end
        setAttribute(member.Root, "vttiers", tostring(#family))
        finish(member.Root, "big", member.Sound, member.Particle)
    end
end
for _, identifier in ipairs(TRINKETS) do
    local root = ItemPrefab.Prefabs[identifier].ConfigElement.Element
    finish(root, "trinket", ownSound(root, identifier), ownParticle(root))
end

Hook.Add("stop", "VoidTraitorPack.Artifacts", function()
    for index = #undo, 1, -1 do undo[index]() end
    undo = {}
end)

-- the setter is private: a property opened on the base class does not reach a delayed effect, the setter method does
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.StatusEffect"] or LuaUserData.RegisterType("Barotrauma.StatusEffect"), "set_Disabled")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.DelayedEffect"] or LuaUserData.RegisterType("Barotrauma.DelayedEffect"), "set_Disabled")

local function tierOf(effect)
    for tier, tag in ipairs(TIER_TAGS) do
        if effect.HasTag(tag) then return tier end
    end
end

-- tier 0 runs none of the family's effects
local function setTier(item, tier)
    for component in item.Components do
        local lists = component.GetRawStatusEffectLists()
        if lists ~= nil then
            for _, list in pairs(lists) do
                for _, effect in pairs(list) do
                    local own = tierOf(effect)
                    if own ~= nil then effect.set_Disabled(own ~= tier) end
                end
            end
        end
        local componentTier = component.originalElement.GetAttributeInt("vttier", 0)
        if componentTier > 0 then
            local active = componentTier == tier
            -- the tier's effects use the item, which would set off another tier's discharger as well (Item.Use)
            component.AutoActivateOnUse = active and component.originalElement.GetAttributeBool("autoactivateonuse", true)
            -- a light or a pump the tier's effects switched on goes off with them
            if not active and (component.Name == "LightComponent" or component.Name == "Pump") then component.IsOn = false end
        end
    end
end

-- as Lua/extensions/station_boats.lua
local function isStationRound(session)
    for mission in session.Missions do
        if mission.Prefab.Identifier == "vt_station" then return true end
    end
    return false
end

local stationRound = false
-- item -> the tier a Station node woke, for the clients that load the round later
local awake = {}

Hook.Add("item.created", "VoidTraitorPack.Artifacts", function(item)
    local artifact = big[string.lower(item.Prefab.Identifier.Value)]
    if artifact ~= nil then setTier(item, stationRound and 0 or artifact.Tier) end
end)

-- the map's items are made before the round is known to be the Station's
Hook.Patch("VoidTraitorPack.Artifacts", "Barotrauma.GameSession", "StartRound", { "Barotrauma.LevelData", "System.Boolean" },
    function(session)
        stationRound, awake = isStationRound(session), {}
        if not stationRound then return end
        for item in Item.ItemList do
            if big[string.lower(item.Prefab.Identifier.Value)] ~= nil then setTier(item, 0) end
        end
        if CLIENT then Networking.Send(Networking.Start(NET_REQUEST)) end
    end, Hook.HookMethodType.After)
Hook.Add("roundEnd", "VoidTraitorPack.Artifacts", function() stationRound, awake = false, {} end)

if CLIENT then
    Networking.Receive(NET_TIER, function(message)
        local item, tier = Entity.FindEntityByID(message.ReadUInt16()), message.ReadByte()
        if item ~= nil and big[string.lower(item.Prefab.Identifier.Value)] ~= nil then setTier(item, tier) end
    end)
    return
end

local function sendTier(item, tier, connection)
    local message = Networking.Start(NET_TIER)
    message.WriteUInt16(UShort(item.ID))
    message.WriteByte(tier)
    Networking.Send(message, connection)
end

-- the Station's xenoarchaeology wakes and lulls big artifacts
Hook.Add("VoidTraitor.ArtifactTier", "VoidTraitorPack.Artifacts", function(item, tier)
    setTier(item, tier)
    awake[item] = tier > 0 and tier or nil
    sendTier(item, tier, nil)
end)

local lastRequest = {}
Networking.Receive(NET_REQUEST, function(_, client)
    local now = Timer.GetTime()
    if (lastRequest[client] or 0) > now then return end
    lastRequest[client] = now + 2
    for item, tier in pairs(awake) do
        if not item.Removed then sendTier(item, tier, client.Connection) end
    end
end)
