Hook.Add("NTNanApplyNanite", function(effect, deltaTime, item, targets, worldPosition, element)

    local id = element.GetAttributeString("id", "UNKNOWN")

    if id=="UNKNOWN" then
        local msg = "Error when giving nanites, items.xml is not configured properly !"
        print(msg)
        Game.ChatBox.AddMessage(ChatMessage.Create("", msg, ChatMessageType.Server, nil))
        return
    end

    local str = element.GetAttributeString("strength", 1)

    for _,character in pairs(targets) do
        HF.AddAffliction(character, id, str)
    end

end)