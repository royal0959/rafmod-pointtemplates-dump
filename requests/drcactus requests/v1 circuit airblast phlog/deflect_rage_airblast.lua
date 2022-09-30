local AMMO_COST = 25
local COOLDOWN = 1

local AIRBLAST_RANGE = 200

local DEFLECTABLE_PROJECTILES = {"tf_projectile_pipe", "tf_projectile_pipe_remote", "tf_projectile_rocket"
, "tf_projectile_sentryrocket"}

local function getEyeAngles(player)
	local pitch = player["m_angEyeAngles[0]"]
	local yaw = player["m_angEyeAngles[1]"]

	return Vector(pitch, yaw, 0)
end

local DR_callbacks = {}
local cooldowns = {}

function DR_Refunded(_, activator)
	if not IsValid(activator) then
		return
	end

	local handle = activator:GetHandleIndex()

	local callbacks = DR_callbacks[handle]

	for _, id in pairs(callbacks) do
		activator:RemoveCallback(id)
	end
end

local _DEFLECTABLE_INDEX = {}
for _, classname in pairs(DEFLECTABLE_PROJECTILES) do
	_DEFLECTABLE_INDEX[classname] = true
end

local function DR_Blast(activator)
	local weapon = activator.m_hActiveWeapon

	if weapon.m_iClassname ~= "tf_weapon_flamethrower" then
		return
	end

	local awesomeMagicNumberToGetPrimaryClip = 2 -- I love magic numbers
	local clip = activator.m_iAmmo[awesomeMagicNumberToGetPrimaryClip]

	if clip < AMMO_COST then
		return
	end

	-- disable attacking while airblast animation plays
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

	activator.m_iAmmo[awesomeMagicNumberToGetPrimaryClip - 1] = clip - AMMO_COST

	local origin = activator:GetAbsOrigin() + Vector(0, 0, 50)
	local eyeAngles = getEyeAngles(activator)

	local DefaultTraceInfo = {
		start = origin,
		distance = 100,
		angles = eyeAngles,
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)

	-- util.ParticleEffect("ExplosionCore_buildings", trace.HitPos, nil)

	for _, ent in pairs(ents.FindInSphere(origin, AIRBLAST_RANGE)) do
		if _DEFLECTABLE_INDEX[ent.m_iClassname] then
			ent:Remove()
		end
	end
end

function DR_Purchased(_, activator)
	local handle = activator:GetHandleIndex()
	local callbacks = {}

	DR_callbacks[handle] = callbacks

	local primary = activator:GetPlayerItemBySlot(0)

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

		if not IsValid(activator) then
			return
		end

		DR_Refunded(_, activator)

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

		DR_Blast(activator)

		held = timer.Create(0.1, function ()
			if not IsValid(activator) then
				return true -- cancel
			end

			DR_Blast(activator)
		end, 0)
	end)

	callbacks.onRemove = activator:AddCallback(ON_REMOVE, function()
		stopHeld()

		if cooldowns[handle] then
			cooldowns[handle] = nil
		end
	end)

	callbacks.onRelease = activator:AddCallback(ON_KEY_RELEASED, function(_, key)
		if key ~= IN_ATTACK2 then
			return
		end

		stopHeld()
	end)

	callbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		if activator:GetPlayerItemBySlot(0) == primary then
			return
		end

		removeCallbacks()
	end)
	callbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		if activator:GetPlayerItemBySlot(0) == primary then
			return
		end

		removeCallbacks()
	end)
end