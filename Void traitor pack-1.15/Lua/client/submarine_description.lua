if SERVER then return end

local editorDescriptor = LuaUserData.RegisterType("Barotrauma.SubEditorScreen")
LuaUserData.MakeFieldAccessible(editorDescriptor, "descriptionBox")
LuaUserData.MakeFieldAccessible(editorDescriptor, "submarineDescriptionCharacterCount")
LuaUserData.MakeMethodAccessible(editorDescriptor, "ChangeSubDescription")
LuaUserData.MakeFieldAccessible(LuaUserData.RegisterType("Barotrauma.GUITextBox"), "OnTextChanged")
LuaUserData.RegisterType("Barotrauma.GUITextBox+OnTextChangedHandler")

local currentBox, nativeChanged

Hook.Patch("VoidTraitor.SubmarineDescription", "Barotrauma.GUITextBox", "SetText",
    { "System.String", "System.Boolean" }, function(box)
        if not Game.IsSubEditor then return end
        local editor = Game.SubEditorScreen
        if box ~= editor.descriptionBox or box == currentBox then return end

        -- The same descriptionBox field is also used when saving item assemblies.
        local counter = editor.submarineDescriptionCharacterCount
        local container = box.Parent.Parent.Parent
        if counter == nil or counter.Parent.Parent ~= container.Parent then return end

        currentBox, nativeChanged = box, box.OnTextChanged
        local original = nativeChanged
        box.OnTextChanged = function(textBox, text)
            if not text:find("[traitormod]", 1, true) then
                return original.Invoke(textBox, text)
            end

            local size = textBox.Font.MeasureString(textBox.WrappedText)
            textBox.RectTransform.NonScaledSize = Point(textBox.RectTransform.NonScaledSize.X,
                math.max(container.Content.Rect.Height, math.floor(size.Y) + 10))
            container.UpdateScrollBarSize()
            container.BarScroll = 1
            editor.ChangeSubDescription(textBox, text)
            counter.Text = tostring(textBox.TextBlock.Text.Length)
            return true
        end
    end, Hook.HookMethodType.Before)

Hook.Patch("VoidTraitor.SubmarineDescription.Counter", "Barotrauma.SubEditorScreen", "CreateSaveScreen",
    { "System.Boolean" }, function(editor)
        if editor.descriptionBox == currentBox and currentBox.Text:find("[traitormod]", 1, true) then
            editor.submarineDescriptionCharacterCount.Text = tostring(currentBox.TextBlock.Text.Length)
        end
    end, Hook.HookMethodType.After)

Hook.Add("stop", "VoidTraitor.SubmarineDescription", function()
    if currentBox ~= nil then currentBox.OnTextChanged = nativeChanged end
end)
