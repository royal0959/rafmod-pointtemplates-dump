--requested by colonel for funny ultrakill mission

local COOLDOWN = 2

local cooldown_players = {}

local function _getPlayerCameraAngleUp(player)
	local properties = player:DumpProperties()

	local pitch = properties["m_angEyeAngles[0]"]

	return Vector(0, 0, -pitch)
end

local function _dash(player)
	local handle = player:GetHandleIndex()

	if cooldown_players[handle] then
		return
	end

	cooldown_players[handle] = true

	timer.Simple(COOLDOWN, function()
		cooldown_players[handle] = nil
	end)

	local angle = _getPlayerCameraAngleUp(player)

	player:SetForwardVelocity(1000)
	player:AddOutput("BaseVelocity " .. tostring(angle * 10))
end

function OnPlayerConnected(player)
	if not player:IsRealPlayer() then
		return
	end

	player:AddCallback(ON_KEY_PRESSED, function(_, key)
		if key ~= IN_ATTACK2 then
			goto continue
		end

		print("dashing")
		_dash(player)

		::continue::
	end)
end
