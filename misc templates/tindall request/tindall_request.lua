local HARD_HIT_THRESHOLD = 300 -- in damage
local HARD_HIT_DAMAGE_TYPE = DMG_CRITICAL -- can also be broken by crit
local HARD_HIT_RECOVERY_TIME = 8 -- in seconds, time needed to regain flat resist after broken

local VULNERABLE_CAP = 3 -- damage damage taken mult

function FlatResist(amount, activator)
	local callbacks = {}

	local function removeCallbacks()
		for _, id in pairs(callbacks) do
			activator:RemoveCallback(id)
		end
	end

	local active = true

	local function hardHit()
		print("hard hit")
		active = false
		timer.Simple(HARD_HIT_RECOVERY_TIME, function()
			active = true
		end)
	end

	callbacks.onDamage = activator:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageInfo)
		if not active then
			return
		end

		if damageInfo.Damage >= HARD_HIT_THRESHOLD or (damageInfo.DamageType & HARD_HIT_DAMAGE_TYPE) ~= 0 then
			hardHit()
			return
		end

		damageInfo.Damage = damageInfo.Damage - tonumber(amount)
		if damageInfo.Damage < 0 then
			damageInfo.Damage = 0
		end
		-- print("new damage: "..tostring(damageInfo.Damage))

		return true
	end)

	callbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		removeCallbacks()
	end)
	callbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		removeCallbacks()
	end)
end

function VulnerableOnHit(amount, activator)
	local callbacks = {}

	local function removeCallbacks()
		for _, id in pairs(callbacks) do
			activator:RemoveCallback(id)
		end
	end

	local damageVulnerability = 1

	callbacks.onDamage = activator:AddCallback(ON_DAMAGE_RECEIVED_POST, function()
		if damageVulnerability == VULNERABLE_CAP then
			return
		end

		damageVulnerability = damageVulnerability + tonumber(amount)

		if damageVulnerability > VULNERABLE_CAP then
			damageVulnerability = VULNERABLE_CAP
		end

		-- print(damageVulnerability)

		activator:SetAttributeValue("dmg taken increased", damageVulnerability)
		activator:SetAttributeValue("head scale", damageVulnerability )
	end)

	callbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		removeCallbacks()
	end)
	callbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		removeCallbacks()
	end)
end
