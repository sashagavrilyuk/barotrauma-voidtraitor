from pathlib import Path

def rep(path, old, new):
    p=Path(path); s=p.read_text(encoding='utf-8')
    if s.count(old)!=1: raise SystemExit(f'{path}: expected one match, got {s.count(old)}')
    p.write_text(s.replace(old,new,1),encoding='utf-8',newline='')

secret='traitormod-voidtraitor-dev-ai/Lua/gamemodes/secret.lua'
rep(secret,'    else\n        Game.SendDirectChatMessage("", summary, nil, ChatMessageType.ServerMessageBoxInGame, client, "InfoFrameTabButton.Mission")\n    end','    else\n        local chatMessage = ChatMessage.Create(Traitormod.GetText("ChatSenderServer"), summary, ChatMessageType.ServerMessageBox, nil, nil)\n        Game.SendDirectChatMessage(chatMessage, client)\n    end')
rep(secret,'    Traitormod.RoleManager.CheckObjectives(false)\n    Traitormod.RoleManager.CheckObjectives(true)','    Traitormod.RoleManager.CheckObjectives(false, true)\n    Traitormod.RoleManager.CheckObjectives(true, true)')
rep(secret,'                objective:Fail()\n','                objective:Fail(true)\n')
rep(secret,'''        local objectivesCompleted = 0
        for _, objective in ipairs(role.Objectives or {}) do
            if objective.Awarded then objectivesCompleted = objectivesCompleted + 1 end
        end
        local client = Traitormod.FindClientCharacter(character)
        local accountKey = client ~= nil and Traitormod.GetClientAccountKey(client) or nil
        sb(Traitormod.Language.SecretSummary, objectivesCompleted, math.floor((accountKey ~= nil and self.AwardedPoints[accountKey]) or 0))

        for _, objective in ipairs(role.Objectives or {}) do
            local objectiveState
            if objective.Failed then
                objectiveState = Traitormod.Language.Failed
            elseif objective.Awarded then
                objectiveState = Traitormod.Language.Completed .. string.format(Traitormod.Language.Points, objective.AmountPoints or 0)
            else
                objectiveState = ""
            end
            sb(" > %s %s\\n", objective.Text, string.gsub(objectiveState, "^%s+", ""))
        end''','''        local client = Traitormod.FindClientCharacter(character)
        local accountKey = client ~= nil and Traitormod.GetClientAccountKey(client) or nil
        local pointsGained = math.floor((accountKey ~= nil and self.AwardedPoints[accountKey]) or 0)

        if role.Name == "Crew" then
            sb(Traitormod.Language.SecretCrewSummary, pointsGained)
        else
            local objectivesCompleted = 0
            for _, objective in ipairs(role.Objectives or {}) do
                if objective.Awarded then objectivesCompleted = objectivesCompleted + 1 end
            end
            sb(Traitormod.Language.SecretSummary, objectivesCompleted, pointsGained)

            for _, objective in ipairs(role.Objectives or {}) do
                local objectiveState
                if objective.Failed then
                    objectiveState = Traitormod.Language.Failed
                elseif objective.Awarded then
                    objectiveState = Traitormod.Language.Completed .. string.format(Traitormod.Language.Points, objective.AmountPoints or 0)
                else
                    objectiveState = ""
                end
                sb(" > %s %s\\n", objective.Text, string.gsub(objectiveState, "^%s+", ""))
            end
        end''')

obj='traitormod-voidtraitor-dev-ai/Lua/objectives/objective.lua'
rep(obj,'function objective:Fail()\n','function objective:Fail(silent)\n')
rep(obj,'    if client then \n        Traitormod.SendObjectiveFailed(client, self.Text)\n    end','    if client and not silent then \n        Traitormod.SendObjectiveFailed(client, self.Text)\n    end')

rm='traitormod-voidtraitor-dev-ai/Lua/rolemanager.lua'
rep(rm,'rm.CheckObjectives = function(endRound)\n','rm.CheckObjectives = function(endRound, silentFailures)\n')
rep(rm,'                        objective:Fail()\n','                        objective:Fail(silentFailures)\n')

rep('traitormod-voidtraitor-dev-ai/Lua/language/english.lua','language.SecretSummary = "Objectives Completed: %s - Points Gained: %s\\n"\n','language.SecretSummary = "Objectives Completed: %s - Points Gained: %s\\n"\nlanguage.SecretCrewSummary = "Points Gained: %s\\n"\n')
rep('traitormod-voidtraitor-dev-ai/Lua/language/russian.lua','language.SecretSummary = "Задачи выполнены: %s - Очки получены: %s\\n"\n','language.SecretSummary = "Задачи выполнены: %s - Очки получены: %s\\n"\nlanguage.SecretCrewSummary = "Очки получены: %s\\n"\n')

old='''-- === СИГНАЛЫ СЕРВЕРУ ===
local function SendHandshake()
    local msg = Networking.Start("VoidTraitor_LuaCheck")
    Networking.Send(msg)
end
SendHandshake()
Timer.Wait(function() SendHandshake() end, 2000)
'''
new='''-- === СИГНАЛЫ СЕРВЕРУ ===
local handshakeTimer = 0
local function SendHandshake()
    local msg = Networking.Start("VoidTraitor_LuaCheck")
    Networking.Send(msg)
end
SendHandshake()
Hook.Add("think", "VoidTraitor.LuaCheck", function(deltaTime)
    handshakeTimer = handshakeTimer + deltaTime
    if handshakeTimer < 5 then return end
    handshakeTimer = 0
    SendHandshake()
end)
Hook.Add("roundStart", "VoidTraitor.LuaCheck.RoundStart", SendHandshake)
'''
for p in ['Void traitor pack/Lua/client/welcome.lua','VoidTraitorPackBuilder/Custom/Lua/client/welcome.lua']: rep(p,old,new)
for p in ['Void traitor pack/Lua/client/init.lua','VoidTraitorPackBuilder/Custom/Lua/client/init.lua']:
    rep(p,'local clientCommon = assert(loadfile(packPath .. "/Lua/client/common.lua"))(packPath)\n\n','local clientCommon = assert(loadfile(packPath .. "/Lua/client/common.lua"))(packPath)\n\nassert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath, clientCommon)\nassert(loadfile(packPath .. "/Lua/client/roundsummary.lua"))(packPath, clientCommon)\n')
    rep(p,'assert(loadfile(packPath .. "/Lua/client/roundsummary.lua"))(packPath, clientCommon)\nassert(loadfile(packPath .. "/Lua/client/welcome.lua"))(packPath, clientCommon)\n','')

assert Path('Void traitor pack/Lua/client/init.lua').read_bytes()==Path('VoidTraitorPackBuilder/Custom/Lua/client/init.lua').read_bytes()
assert Path('Void traitor pack/Lua/client/welcome.lua').read_bytes()==Path('VoidTraitorPackBuilder/Custom/Lua/client/welcome.lua').read_bytes()
