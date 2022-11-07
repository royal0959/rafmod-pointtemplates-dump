local DAMAGE_MULT = 0.02 -- remember that shield takes full rampup damage regardless of distance
local MIN_DAMAGE_METER = 20 -- damage cannot bring shield below this threshold. put at 0 to disable this grace period

local function handleShield(shieldEnt)
	local owner = shieldEnt.m_hOwnerEntity

	local lastDamageTick = TickCount()

	shieldEnt:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageinfo)
		if owner.m_flRageMeter < MIN_DAMAGE_METER then
			return
		end

		local curTick = TickCount()
		lastDamageTick = curTick

		shieldEnt:Color("200 0 100")

		local damage = damageinfo.Damage * DAMAGE_MULT

		owner.m_flRageMeter = owner.m_flRageMeter - damage
		if owner.m_flRageMeter < MIN_DAMAGE_METER then
			owner.m_flRageMeter = MIN_DAMAGE_METER
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
