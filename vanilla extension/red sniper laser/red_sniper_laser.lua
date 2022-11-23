local function removeCallbacks(player, callbacks)
	if not IsValid(player) then
		return
	end

	for _, callbackId in pairs(callbacks) do
		player:RemoveCallback(callbackId)
	end
end

local function getEyeAngles(player)
	local pitch = player["m_angEyeAngles[0]"]
	local yaw = player["m_angEyeAngles[1]"]

	return Vector(pitch, yaw, 0)
end

function LaserOnAim(_, activator)
	local laser = ents.CreateWithKeys("info_particle_system", {
		effect_name = "laser_sight_beam",
		start_active = 0,
		flag_as_weather = 0,
	})

	local pointer = Entity("info_particle_system", true)
	local color = Entity("info_particle_system", true)

	color:SetAbsOrigin(Vector(255, 0, 0))

	laser.m_hControlPointEnts[1] = pointer
	laser.m_hControlPointEnts[2] = color

	local callbacks = {}

	local started = false

	local check

	-- might cause a client side memory leak because the laser isn't cleared when the laser entity itself is
	-- who knows!
	-- this is a bandaid to forcefully hide the lasers out of sight (and out of mind. don't think about it)
	local function hideLaser()
		laser:SetAbsOrigin(Vector(0, 0, -10000))
		pointer:SetAbsOrigin(Vector(0, 0, -10000))
		color:SetAbsOrigin(Vector(0, 0, 0))

		laser:Stop()
	end

	local function terminate()
		hideLaser()

		timer.Stop(check)
		removeCallbacks(activator, callbacks)

		timer.Simple(0.1, function ()
			for _, e in pairs( {laser, pointer, color}) do
				if IsValid(e) then
					e:Remove()
				end
			end
		end)
		-- laser:Remove()
		-- pointer:Remove()
		-- color:Remove()
	end

	check = timer.Create(0.015, function()
		if activator.m_iTeamNum == 0 or activator.m_iTeamNum == 1 then
			terminate()
			return
		end

		if activator:InCond(0) ~= 1 then
			if started then
				hideLaser()

				started = false
			end

			return
		end

		-- local origin = activator:GetAbsOrigin()

		-- laser:SetAbsOrigin(origin + Vector(0, 0, 53))

		local eyeAngles = getEyeAngles(activator)

		local DefaultTraceInfo = {
			start = activator,
			distance = 10000,
			angles = eyeAngles,
			mask = MASK_SOLID,
			collisiongroup = COLLISION_GROUP_DEBRIS,
		}
		local trace = util.Trace(DefaultTraceInfo)

		laser:SetAbsOrigin(trace.StartPos)
		pointer:SetAbsOrigin(trace.HitPos)

		laser:Start()

		started = true
	end, 0)

	callbacks.died = activator:AddCallback(ON_DEATH, function()
		terminate()
	end)
	callbacks.removed = activator:AddCallback(ON_REMOVE, function()
		terminate()
	end)
	callbacks.spawned = activator:AddCallback(ON_SPAWN, function()
		terminate()
	end)
end
