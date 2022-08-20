-- cod zombie points system recreated

local function cashforhits(activator)
	local callbacks = {}

	local function removeCallbacks()
		for _, callbackId in pairs(callbacks) do
			activator:RemoveCallback(callbackId)
		end
	end

	callbacks.damagetype = activator:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageInfo)
		-- PrintTable(damageInfo)

		local damage = damageInfo.Damage

		if damage <= 0 then
			return
		end

		local damageType = damageInfo.DamageType
		local hitter = damageInfo.Attacker

		if (damageType & TF_DMG_CUSTOM_BURNING) ~= 0 then
			return
		end

		local isCrit = (damageType & DMG_CRITICAL) ~= 0

		if isCrit then
			damage = damage * 3
		end

		local curHealth = activator.m_iHealth

		local isLethal = curHealth - (damage + 1) <= 0

		if not isLethal then
			hitter:AddCurrency(10)
			return
		end

		if (damageType & DMG_BLAST) ~= 0 then
			hitter:AddCurrency(50)
			print("explosive?")
		elseif (damageType & DMG_MELEE) == 0 and (damageType & DMG_CRITICAL) ~= 0 then -- this is used for headshots, may overlap with Instakill
			hitter:AddCurrency(50)
			print("crit?")
		elseif (damageType & DMG_MELEE) ~= 0 then
			hitter:AddCurrency(100)
			print("melee?")
		else
			hitter:AddCurrency(10)
			print("hell if I know")
		end
	end)

	callbacks.spawned = activator:AddCallback(1, function()
		removeCallbacks()
	end)

	callbacks.died = activator:AddCallback(9, function()
		removeCallbacks()
	end)
end

function OnWaveSpawnBot(bot)
	timer.Simple(1, function()
		cashforhits(bot)
	end)
end
