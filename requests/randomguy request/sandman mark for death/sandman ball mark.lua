local ON_HIT_FUNCS = {
	["throwable fire speed"] = function(target, duration)
		target:AddCond(TF_COND_MARKEDFORDEATH, duration)
	end,
}

local sandmanPlayers = {}

function SandmanBallStart(_, activator)
	local handleIndex = activator:GetHandleIndex()
	sandmanPlayers[handleIndex] = true
end

function SandmanBallStop(_, activator)
	local handleIndex = activator:GetHandleIndex()
	sandmanPlayers[handleIndex] = nil
end

ents.AddCreateCallback("tf_projectile_*", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) then
			return
		end

		local owner = ent.m_hOwnerEntity

		if not owner then
			return
		end

		if not IsValid(owner) then
			return
		end

		if not sandmanPlayers[owner:GetHandleIndex()] then
			return
		end

		local melee = owner:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE)

		ent:AddCallback(ON_SHOULD_COLLIDE, function(_, other)
			if not other:IsPlayer() then
				return
			end

			if other.m_iTeamNum == owner.m_iTeamNum then
				return
			end

			if ent.m_bTouched == 1 then
				return
			end

			for attributeName, func in pairs(ON_HIT_FUNCS) do
				local param = melee:GetAttributeValue(attributeName, true)
				if param then
					func(other, param)
				end
			end
		end)
	end)
end)
