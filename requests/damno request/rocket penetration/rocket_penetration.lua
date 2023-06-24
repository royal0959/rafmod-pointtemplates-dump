local BASE_DAMAGE = 70

local function weaponMimic(properties, positional)
	local mimic = ents.CreateWithKeys("tf_point_weapon_mimic", properties)
	mimic:SetAbsOrigin(positional.Origin)
	mimic:SetAbsAngles(positional.Angles)
	return mimic
end

ents.AddCreateCallback("tf_projectile_rocket", function(projectile)
	timer.Simple(0, function()
		if not IsValid(projectile) then
			return
		end

		local owner = projectile.m_hOwnerEntity
		local primary = owner:GetPlayerItemBySlot(LOADOUT_POSITION_PRIMARY)

		if primary:GetClassname() ~= "tf_weapon_rocketlauncher" then
			return
		end

		local maxPenetrationCount = primary:GetAttributeValue("projectile penetration")

		if not maxPenetrationCount then
			return
		end

		local isCrit = projectile.m_bCritical

		local penetrations = 0
		local penetrated = {}

		local callback
		callback = projectile:AddCallback(ON_SHOULD_COLLIDE, function(_, other)
			if not other:IsPlayer() and not other:IsNPC() and not other:IsObject() then
				return
			end

			local index = other:GetHandleIndex()

			if penetrated[index] then
				return false
			end

			if penetrations >= maxPenetrationCount then
				projectile:RemoveCallback(callback)
				return
			end

			penetrations = penetrations + 1
			penetrated[index] = true

			local damageBonusMult = primary:GetAttributeValueByClass("mult_dmg", 1)
			local damage = BASE_DAMAGE * damageBonusMult

			local damageType = DMG_BLAST
			if isCrit == 1 then
				damageType = damageType + DMG_CRITICAL
			end

			local mimic = weaponMimic({
				TeamNum = owner.m_iTeamNum,
				WeaponType = 3, -- sticky
				Crits = isCrit,

				SpeedMax = 0,
				SpeedMin = 0,

				SplashRadius = 146,
				Damage = damage,
			}, {
				Origin = projectile:GetAbsOrigin(),
				Angles = Vector(0, 0, 0),
			})

			mimic["$SetOwner"](mimic, owner)

			mimic:FireOnce()
			mimic:DetonateStickies()

			timer.Simple(0.1, function()
				mimic:Remove()
			end)

			return false
		end)
	end)
end)