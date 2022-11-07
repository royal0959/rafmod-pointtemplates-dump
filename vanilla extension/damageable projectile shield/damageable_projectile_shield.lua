local DAMAGE_MULT = 0.02 -- remember that shield takes full rampup damage regardless of distance

local function handleShield(shieldEnt)
	local owner = shieldEnt.m_hOwnerEntity

	local lastDamageTick = TickCount()

	shieldEnt:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageinfo)
		local curTick = TickCount()
		lastDamageTick = curTick

		shieldEnt:Color("200 0 100")

		local damage = damageinfo.Damage * DAMAGE_MULT

		owner.m_flRageMeter = owner.m_flRageMeter - damage
		if  owner.m_flRageMeter < 0 then
			owner.m_flRageMeter = 0
		end

		-- owner:Print(PRINT_TARGET_CHAT, "Shield taken damage for: " .. damage)

		timer.Simple(0.1, function()
			if not IsValid(shieldEnt) then
				return
			end

			-- prevents constant flickering on constant damage
			if lastDamageTick ~= curTick then
				return
			end

			shieldEnt:Color("255 255 255")
		end)
	end)
end

ents.AddCreateCallback("entity_medigun_shield", function(ent)
	timer.Simple(0, function()
		if ent.m_iTeamNum ~= 2 then
			return
		end

		handleShield(ent)
	end)
end)
