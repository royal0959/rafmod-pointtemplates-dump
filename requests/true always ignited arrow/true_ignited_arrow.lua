local callbacks = {}

local function _applyIgniteToBow(player)
	local properties = player:DumpProperties()

	local bow = properties.m_hMyWeapons[1]

	if tostring(bow) == "Invalid entity handle id: -1" then
		return
	end

	bow:AcceptInput("$SetProp$m_bArrowAlight", "1")
end

function RemoveCallbacks(player)
	local handle = player:GetHandleIndex()

	if not callbacks[handle] then
		return
	end

	for callbackType, callbackID in pairs(callbacks[handle]) do
		player:RemoveCallback(callbackType, callbackID)
	end

	callbacks[handle] = {}
end

function ApplyAlwaysIgnite(_, activator)
	local handle = activator:GetHandleIndex()

	if callbacks[handle] then
		RemoveCallbacks(activator)
	end

	callbacks[handle] = {}

	_applyIgniteToBow(activator)

	-- on key release
	-- re-apply ignition everytime player attacks
	callbacks[handle][8] = activator:AddCallback(8, function(_, key)
		if key ~= IN_ATTACK then
			return
		end

		timer.Simple(0.1, function()
			_applyIgniteToBow(activator)
		end)
	end)

	-- on death
	callbacks[handle][9] = activator:AddCallback(9, function()
		RemoveCallbacks(activator)
	end)

	-- on spawn
	callbacks[handle][1] = activator:AddCallback(1, function()
		RemoveCallbacks(activator)
	end)
end

-- automatic detection
-- function OnPlayerConnected(player)
-- 	if not player:IsRealPlayer() then
-- 		return
-- 	end

-- 	-- on item equip
-- 	player:AddCallback(10, function(_, weapon)
-- 		if weapon.m_iClassname ~= "tf_weapon_compound_bow" then
-- 			return
-- 		end

-- 		timer.Simple(0.1, function()
-- 			ApplyAlwaysIgnite(nil, player)
-- 		end)
-- 	end)
-- end
