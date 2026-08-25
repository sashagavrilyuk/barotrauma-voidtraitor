local skillAmountToAdd = math.random(20, 25)

local function addSurgerySkillToDoctors(character)
	if character ~= nil and character.Info.Job.Prefab.Identifier.Value == "medicaldoctor" and character.GetSkillLevel("surgery") <= 20 then
		character.Info.SetSkillLevel("surgery", skillAmountToAdd)
	end
end

Hook.Add("character.giveJobItems", function(newCharacter)
	addSurgerySkillToDoctors(newCharacter)
end)
