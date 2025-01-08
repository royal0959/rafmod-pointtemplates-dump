local stickyLinksByPlayer = {}

function LaserStickyFired(_, projectile)
	timer.Simple(1, function()
		local owner = projectile.m_hLauncher.m_hOwnerEntity

		local ownerHandle = owner:GetHandleIndex()

		if not stickyLinksByPlayer[ownerHandle] then
			stickyLinksByPlayer[ownerHandle] = {}

			owner:AddCallback(ON_REMOVE, function()
				stickyLinksByPlayer[ownerHandle] = nil
			end)
		end

		local links = stickyLinksByPlayer[ownerHandle]

		local projectileHandleIndex = projectile:GetHandleIndex()

		local projectileIndex = #links + 1
		table.insert(links, projectileIndex, projectileHandleIndex)

		if projectileIndex % 2 == 0 then
			-- local previousProjectileHandle = links[projectileIndex - 1]
			-- local previousProjectile = Entity(previousProjectileHandle)
			local previousProjectile
			for _, handle in pairs(links) do
				local entity = Entity(handle)

				if not entity.BeamLinked then
					previousProjectile = entity
					break
				end
			end

			local previousProjectileTargetname = "PreviousProjectile_" .. tostring(previousProjectile:GetHandleIndex())
			previousProjectile:SetName(previousProjectileTargetname)

			local currentProjectileTargetname = "CurrentProjectile_" .. tostring(projectile:GetHandleIndex())
			projectile:SetName(currentProjectileTargetname)

			previousProjectile.BeamLinked = true
			projectile.BeamLinked = true

			print("linking with previous projectile", previousProjectile)

			-- local laser = ents.CreateWithKeys("env_laser", {
			-- 	LaserTarget = targetname,
			-- 	origin = tostring(projectile:GetAbsOrigin()),
			-- 	width = "1",
			-- 	rendercolor = "255 0 0",
			-- 	renderamt = "255",
			-- 	damage = "50",
			-- 	TextureScroll = "1",
			-- 	NoiseAmplitude = "1",
			-- 	ClipStyle = "0",
			-- 	texture = "sprites/laserbeam.spr",
			-- }, true, true)

			-- laser:SetFakeParent(projectile)
			-- laser:TurnOn()

			local beam = ents.CreateWithKeys("env_beam", {
				LightningStart = currentProjectileTargetname,
				LightningEnd = previousProjectileTargetname,
				-- origin = tostring(projectile:GetAbsOrigin()),
				TouchType = "0",
				life = "0",
				BoltWidth = "1",
				rendercolor = "200 0 0",
				renderamt = "255",
				damage = "0",
				TextureScroll = "0.1",
				NoiseAmplitude = "0",
				ClipStyle = "1",
				texture = "sprites/laserbeam.spr",
			}, true, true)

			beam:SetFakeParent(projectile)
			beam:TurnOn()

			projectile:AddCallback(ON_REMOVE, function()
				if IsValid(beam) then
					beam:Remove()
				end
				if IsValid(previousProjectile) then
					previousProjectile.BeamLinked = nil
				end
			end)
			previousProjectile:AddCallback(ON_REMOVE, function()
				if IsValid(beam) then
					beam:Remove()
				end
				if IsValid(projectile) then
					projectile.BeamLinked = nil
				end
			end)

			local laserDamageTimer
			laserDamageTimer = timer.Create(0, function()
				if not IsValid(beam) or not IsValid(projectile) or not IsValid(previousProjectile) then
					timer.Stop(laserDamageTimer)
					return
				end

				-- TODO(royal): check if this damages tanks
				local DefaultTraceInfo = {
					start = projectile:GetAbsOrigin(),
					endpos = previousProjectile:GetAbsOrigin(),
					mask = MASK_SOLID,
					collisiongroup = COLLISION_GROUP_PLAYER,
					filter = { owner },
				}

				local trace = util.Trace(DefaultTraceInfo)

				if not trace.Entity then
					return
				end

				if trace.Entity:IsWorld() then
					return
				end

				if trace.Entity.m_iTeamNum == owner.m_iTeamNum then
					return
				end

				local damageInfo = {
					Attacker = owner,
					Inflictor = nil,
					Weapon = owner:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY),
					Damage = 1,
					DamageType = DMG_SHOCK,
					DamageCustom = 0,
					DamagePosition = trace.Entity:GetAbsOrigin(),
					DamageForce = Vector(0, 0, 0),
					ReportedPosition = owner:GetAbsOrigin(),
				}

				trace.Entity:TakeDamage(damageInfo)
			end, 0)
		end

		projectile:AddCallback(ON_REMOVE, function()
			for i, val in ipairs(links) do
				if val == projectileHandleIndex then
					table.remove(links, i)
					break
				end
			end
		end)
	end)
end
