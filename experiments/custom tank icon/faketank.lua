local tanksWaitingForHealthBars = {}

function ApplyFakeTank(_, tank)
	print("tank spawned (v8)")
	print(tank)

	local fakeTankModel = ents.CreateWithKeys("prop_dynamic", {
		model = "models/bots/boss_bot/boss_tank.mdl",
		-- DefaultAnim = "fly_idle",
		solid = 0,
		skin = 1,
	}, true, true)
	fakeTankModel:SetAbsOrigin(tank:GetAbsOrigin())
	fakeTankModel:SetFakeParent(tank)

	local damageHolderBuilding = ents.CreateWithKeys("obj_dispenser", {
		TeamNum = tank.m_iTeamNum,

		["$positiononly"] = 1,
	})

	damageHolderBuilding:SetHealth(100000)
	damageHolderBuilding:Disable()
	damageHolderBuilding:SetFakeParent(tank)

	tanksWaitingForHealthBars[tank:GetName()] = {
		TankEntity = tank,
		FakeModel = fakeTankModel,
		DamageHolder = damageHolderBuilding,
	}
end

function OnWaveSpawnBot(bot, wave, tags)
	for _, tag in pairs(tags) do
		local split = {}

		for k, _ in string.gmatch(tag, "([^_]+)") do
			table.insert(split, k)
		end

		if split[1]:lower() == "tankhealthbar" then
			local tankTargetname = split[2]

			local tankInfo = tanksWaitingForHealthBars[tankTargetname]
			if tankInfo then
				local tankEnt = tankInfo.TankEntity

				local maxHealth = tankEnt.m_iHealth

				timer.Simple(1, function()
					bot.m_iHealth = tankEnt.m_iHealth
					bot:SetAttributeValue("hidden maxhealth non buffed", maxHealth - bot.m_iMaxHealth)
				end)

				tankEnt:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageInfo)
					bot.m_iHealth = tankEnt.m_iHealth

					-- show damage indicator
					local damageHolder = tankInfo.DamageHolder
					damageHolder:TakeDamage(damageInfo)
					damageHolder:SetHealth(100000)
				end)

				tankEnt:AddCallback(ON_REMOVE, function()
					bot:Suicide()
					tankInfo.FakeModel:Remove()
					tankInfo.DamageHolder:Remove()
				end)
			else
				print("COULD NOT FIND A VALID PAIRING TANK WITH TARGETNAME" .. tankTargetname)
			end
		end
	end
end
