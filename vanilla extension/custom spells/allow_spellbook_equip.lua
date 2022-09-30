function OnWaveInit(wave)
	ForceAllowSpellbooks()
end

function ForceAllowSpellbooks()
	local holidayLogic = ents.FindByClass("tf_logic_holiday")

	if not holidayLogic then
		holidayLogic = Entity("tf_logic_holiday", true)
	end

	holidayLogic:AcceptInput("HalloweenSetUsingSpells", "1")
end