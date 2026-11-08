if SERVER then return end

-- Objectives of VoidTraitor roles (traitormod Lua/objectivehud.lua) sit in the vanilla objective list. When the text of
-- one changes, the server sends it here and it is written into that objective, so it keeps its place in the list.
local objectiveManager = LuaUserData.CreateStatic("Barotrauma.ObjectiveManager")
local UNLIMITED = 2147483647

Networking.Receive("VoidTraitor_ObjectiveText", function(message)
    local segment = objectiveManager.GetObjective(Identifier(message.ReadString()))
    local text = message.ReadString()
    if segment == nil or segment.LinkedTextBlock == nil then return end

    -- ObjectiveManager.ResetUI builds the list again from this text
    segment.ObjectiveText = text
    -- AddToObjectiveList fixes the text block to the size of its first text
    local block = segment.LinkedTextBlock
    local width = block.Rect.Width
    block.RectTransform.MinSize = Point(width, 0)
    block.RectTransform.MaxSize = Point(width, UNLIMITED)
    block.Text = text
    block.CalculateHeightFromText()
    local size = Point(width, block.Rect.Height)
    block.RectTransform.NonScaledSize = size
    block.RectTransform.MinSize = size
    block.RectTransform.MaxSize = size

    local frame = block.Parent
    frame.RectTransform.Resize(Point(frame.Rect.Width, size.Y), false)
    frame.Parent.Recalculate()
end)
