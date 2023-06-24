local BASE_DAMAGE = 70
local WEAPON_STICKY_GRENADE = 3

local function weaponMimic(properties)
	local mimic = ents.CreateWithKeys("tf_point_weapon_mimic", properties)
	return mimic
end

local function addGlobalDamageCallback(player)
	-- Weird hack to fix conch not healing with penetration (thanks Orin xoxo)
	player:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageinfo)
		-- Ugly way to check for rocket penetrations
		if damageinfo.Inflictor:GetClassname() ~= "tf_projectile_pipe" then return end
		if damageinfo.Weapon ~= nil then return end

		damageinfo.Weapon = damageinfo.Attacker:GetPlayerItemBySlot(LOADOUT_POSITION_PRIMARY)
		return true
	end)
end

function OnPlayerConnected(player)
	addGlobalDamageCallback(player)
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

		local callback;
		local isCrit = projectile.m_bCritical
		local penetrated = {}
		local penetrations = 0
		callback = projectile:AddCallback(ON_SHOULD_COLLIDE, function(_, collided)
			-- CTFPlayer, then NextBotCombatCharacter, then CTFBaseObject
			if not collided:IsPlayer() and not collided:IsNPC() and not collided:IsObject() then
				return
			end

			if collided.m_iTeamNum == owner.m_iTeamNum then
				return
			end

			-- Make sure it hasn't been penetrated already
			local index = collided:GetHandleIndex()
			if penetrated[index] then
				return false
			end

			-- Boring shit
			if penetrations >= maxPenetrationCount then
				projectile:RemoveCallback(callback)
				return
			end

			penetrations = penetrations + 1
			penetrated[index] = true

			-- Good shit
			local damageBonusMult = primary:GetAttributeValueByClass("mult_dmg", 1)
			local damage = BASE_DAMAGE * damageBonusMult

			local mimic = weaponMimic({
				TeamNum = owner.m_iTeamNum,
				WeaponType = WEAPON_STICKY_GRENADE, -- sticky
				Damage = damage,
				Crits = isCrit,
				SplashRadius = 146,
				SpeedMax = 0,
				SpeedMin = 0,
				["$dmgtype"] = 69420,
				["$killicon"] = "player_penetration",
				origin = tostring(projectile:GetAbsOrigin()),
				angles = tostring(Vector(0, 0, 0)),
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