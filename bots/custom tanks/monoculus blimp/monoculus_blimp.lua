function MonoculusBlimpInit(_, tankboss)
	tankboss:AddCallback(ON_SHOULD_COLLIDE, function(_, collided)
		local teamNum = collided.m_iTeamNum

		if teamNum == tankboss.m_iTeamNum then
			return false
		end

		return true
	end)
end
