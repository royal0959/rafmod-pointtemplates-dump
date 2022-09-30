local AMMO_COST = 50
local COOLDOWN = 1

local function getEyeAngles(player)
	local pitch = player["m_angEyeAngles[0]"]
	local yaw = player["m_angEyeAngles[1]"]

	return Vector(pitch, yaw, 0)
end

local function weaponMimic(properties, positional)
	local mimic = ents.CreateWithKeys("tf_point_weapon_mimic", properties)
	mimic:SetAbsOrigin(positional.Origin)
	mimic:SetAbsAngles(positional.Angles)

	return mimic
end

local cooldowns = {}

local function blast(activator)
	local weapon = activator.m_hActiveWeapon

	if weapon.m_iClassname ~= "tf_weapon_flamethrower" then
		return
	end

	local awesomeMagicNumberToGetPrimaryClip = 2 -- I love magic numbers
	local clip = activator.m_iAmmo[awesomeMagicNumberToGetPrimaryClip]

	if clip < AMMO_COST then
		return
	end

	local handle = activator:GetHandleIndex()

	if cooldowns[handle] then
		if CurTime() < cooldowns[handle] then
			return
		end
	end

	cooldowns[handle] = CurTime() + COOLDOWN

	activator.m_iAmmo[awesomeMagicNumberToGetPrimaryClip - 1] = clip - AMMO_COST

	local eyeAngle = getEyeAngles(activator)

	local mimic = weaponMimic({
		-- these are probably irrelevant
		TeamNum = activator.m_iTeamNum,
		WeaponType = 0,

		SpeedMax = 700,
		SpeedMin = 700,

		SplashRadius = 146,
		Damage = 10,

		["$weaponname"] = "PROJECTILE_SHORTCIRCUIT_ORB"
	},
	{
		Origin = activator:GetAbsOrigin() + Vector(0, 0, 50),
		Angles = eyeAngle,
	})

	-- disable attacking while airblast animation plays
	-- weapon.m_flNextPrimaryAttack = TickCount() + 100
	weapon:SetAttributeValue("no_attack", 1)

	timer.Simple(0.5, function()
		weapon:SetAttributeValue("no_attack", nil)
	end)

	-- play airblast sequence
	for _, viewmodel in pairs(ents.FindAllByClass("tf_viewmodel")) do
		if viewmodel.m_hOwner == activator then
			viewmodel.m_nSequence = 13
			break
		end
	end

	mimic["$SetOwner"](mimic,activator)

	mimic:FireOnce()

	mimic:Remove()
end

function CircuitBlast(_, activator)
	local callbacks = {}

	local handle = activator:GetHandleIndex()

	local held = false

	local function stopHeld()
		if not held then
			return
		end

		timer.Stop(held)

		held = false
	end

	local function removeCallbacks()
		stopHeld()

		for _, id in pairs(callbacks) do
			activator:RemoveCallback(id)
		end

		if not IsValid(activator) then
			return
		end

		if cooldowns[handle] then
			cooldowns[handle] = nil
		end
	end

	callbacks.onPress = activator:AddCallback(ON_KEY_PRESSED, function(_, key)
		if held then
			return
		end

		if key ~= IN_ATTACK2 then
			return
		end

		blast(activator)

		held = timer.Create(0.1, blast, 0, activator)
	end)

	callbacks.onRelease = activator:AddCallback(ON_KEY_RELEASED, function(_, key)
		if key ~= IN_ATTACK2 then
			return
		end

		stopHeld()
	end)

	callbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		removeCallbacks()
	end)
	callbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		removeCallbacks()
	end)
end