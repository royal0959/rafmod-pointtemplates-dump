local tanksWaitingForHealthBars = {}

function ApplyFakeTank(_, tank)
	print(tank)

	local tankModelTargetName = "tankboss_" .. tostring(tank:GetHandleIndex())
	local fakeTankModel = ents.CreateWithKeys("prop_dynamic", {
		targetname = tankModelTargetName,
		model = "models/bots/boss_bot/boss_tank.mdl",
		DefaultAnim = "forward",
		skin = 0,
	})
	fakeTankModel:SetAbsOrigin(tank:GetAbsOrigin())
	fakeTankModel:SetFakeParent(tank)

	local tankTrackLeft = ents.CreateWithKeys("prop_dynamic", {
		model = "models/bots/boss_bot/tank_track_l.mdl",
		DefaultAnim = "forward",

		-- origin = "0 55 0",
		-- parentname = tankModelTargetName,
	})
	tankTrackLeft:SetAbsOrigin(fakeTankModel:GetAbsOrigin() + Vector(0, 55, 0))
	tankTrackLeft:AcceptInput("SetParent", tankModelTargetName)

	local tankTrackRight = ents.CreateWithKeys("prop_dynamic", {
		model = "models/bots/boss_bot/tank_track_r.mdl",
		DefaultAnim = "forward",

		-- origin = "0 -55 0",
		-- parentname = tankModelTargetName,
	})
	tankTrackRight:SetAbsOrigin(fakeTankModel:GetAbsOrigin() + Vector(0, -55, 0))
	tankTrackRight:AcceptInput("SetParent", tankModelTargetName)

	local bombMechanism = ents.CreateWithKeys("prop_dynamic", {
		model = "models/bots/boss_bot/bomb_mechanism.mdl",
		DefaultAnim = "idle",

		parentname = tankModelTargetName,
	})
	bombMechanism:SetAbsOrigin(fakeTankModel:GetAbsOrigin())
	bombMechanism:AcceptInput("SetParent", tankModelTargetName)

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
