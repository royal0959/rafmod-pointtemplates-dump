local tanksWaitingForHealthBars = {}

function ApplyFakeTank(_, tank)
	print("tank spawned (v6)")
	print(tank)

	local fakeTankModel = ents.CreateWithKeys("prop_dynamic", {
		model = "models/bots/boss_bot/boss_tank.mdl",
		-- DefaultAnim = "fly_idle",
		solid = 0,
		skin = 1,
	}, true, true)
	fakeTankModel:SetFakeParent(tank)

	tanksWaitingForHealthBars[tank:GetName()] = tank
end

function OnWaveSpawnBot(bot, wave, tags)
	for _, tag in pairs(tags) do
		local split = {}

		for k, _ in string.gmatch(tag, "([^_]+)") do
			table.insert(split, k)
		end

		if split[1]:lower() == "tankhealthbar" then
			local tankTargetname = split[2]

			local tankEnt = tanksWaitingForHealthBars[tankTargetname]
			if tankEnt then
				local maxHealth = tankEnt.m_iHealth

				timer.Simple(1, function()
					print("setting new max health" .. tostring(maxHealth - bot.m_iMaxHealth))
					bot.m_iHealth = tankEnt.m_iHealth
					bot:SetAttributeValue("hidden maxhealth non buffed", maxHealth - bot.m_iMaxHealth)
				end)

				tankEnt:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageInfo)
					print("new health" .. tankEnt.m_iHealth)
					bot.m_iHealth = tankEnt.m_iHealth
				end)

				tankEnt:AddCallback(ON_REMOVE, function()
					bot:Suicide()
				end)
			else
				print("COULD NOT FIND A VALID PAIRING TANK WITH TARGETNAME" .. tankTargetname)
			end
		end
	end
end
