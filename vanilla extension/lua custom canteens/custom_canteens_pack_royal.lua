local canteens = {
	{
		-- Name of canteen to display in chat when using
		Display = "SPEED BOOST",
		-- Any attribute, should be one that has no effect
		-- Attribute in equivalent extended upgrade should match this
		Attribute = "mvm completed challenges bitmask",
		-- Custom item description to apply to the canteen
		Description = "Consumable: Gain a speed boost for 5 seconds",
		-- Effect function
		Effect = function(activator)
			activator:AddCond(TF_COND_SPEED_BOOST, 5, activator)
		end
	},
	{
		Display = "BULLET RESIST",
		Attribute = "throwable fire speed",
		Description = "Consumable: Gain resistance to bullets for 5 seconds",
		Effect = function(activator)
			activator:AddCond(TF_COND_MEDIGUN_UBER_BULLET_RESIST, 5, activator)
		end
	},
	{
		Display = "REPROGRAM",
		Attribute = "throwable damage",
		Description = "Consumable: Reprogram nearby non-giant robots to fight for you for 8 seconds",
		Effect = function(activator)
			local DURATION = 8
			local RANGE = 300

			local origin = activator:GetAbsOrigin()

			for _, target in pairs(ents.FindInSphere(origin, RANGE)) do
				if target.m_iTeamNum ~= activator.m_iTeamNum and target.m_bIsMiniBoss == 0 then
					target:AddCond(TF_COND_REPROGRAMMED, DURATION, activator)
					target:AddCond(TF_COND_SAPPED, DURATION, activator)
					target:SetAttributeValue("receive friendly fire", 1)

					local shockwaveParticle = ents.CreateWithKeys("info_particle_system", {
						origin = tostring(origin),
						effect_name = "Explosion_ShockWave_01",
						start_active = 1,
						flag_as_weather = 0,
					}, true, true)

					timer.Simple(DURATION, function()
						shockwaveParticle:Remove()
						target:Suicide()
					end)
				end
			end
		end
	},
	{
		Display = "STEALTH",
		Attribute = "throwable particle trail only",
		Description = "Consumable: Cloak for up to 15 seconds, cloak is cancelled when attacking",
		Effect = function(activator)
			activator:AddCond(TF_COND_STEALTHED_USER_BUFF, 15, activator)
		end
	},
}

for _, canteen in pairs(canteens) do
	table.insert(CUSTOM_CANTEENS, canteen)
end