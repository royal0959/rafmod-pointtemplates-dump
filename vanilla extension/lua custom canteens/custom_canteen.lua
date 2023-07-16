CUSTOM_CANTEENS = {}

local canteenPlayers = {}

local function canteenMessage(activator)
	local index = activator:GetHandleIndex()

	local canteenName = canteenPlayers[index].CustomCanteenData.Display
	local team = activator.m_iTeamNum == 2 and "{red}" or "{blue}"

	for _, player in pairs(ents.GetAllPlayers()) do
		player["$DisplayTextChat"](player, team .. activator:GetPlayerName() .."{reset} has used their {9BBF4D}" .. canteenName .. " {reset}Power Up Canteen!")
	end
end

function CanteenSpawn(_, activator)
	local index = activator:GetHandleIndex()
	canteenPlayers[index] = {
		CustomCanteenData = nil
	}

	local canteen = activator:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION)
	canteen.i_LastCanteenCharges = canteen.m_usNumCharges

	local think
	think = timer.Create(0.1, function ()
		local function stop()
			canteenPlayers[index] = nil
			timer.Stop(think)
		end

		if not IsValid(activator) then
			stop()
			return
		end

		if not activator:IsAlive() then
			stop()
			return
		end

		if activator:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION) ~= canteen then
			print("canteen changed")
			stop()
			return
		end

		if not canteenPlayers[index].CustomCanteenData then
			return
		end

		-- if the canteen count was decreased, that means the player has used a canteen
		-- checking m_bUsingActionSlot means we bypass the internal stuff behind canteen usage such as cooldown
		-- while checking for canteen count changes happens after the internal stuff

		if canteen.m_usNumCharges >= canteen.i_LastCanteenCharges then
			return
		end

		-- so long as the canteen entity does not have any canteen attributes
		-- i.e 'critboost', 'ubercharge', 'building instant upgrade'
		-- no chat message will be displayed and no effect will be activated, canteen usage sound effect will still play
		-- we can fill in with our custom behavior

		canteenMessage(activator)
		canteenPlayers[index].CustomCanteenData.Effect(activator)

		canteen.i_LastCanteenCharges = canteen.m_usNumCharges
	end, 0)
end

function CanteenPurchase(tick, activator)
	local canteen = activator:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION)

	-- assume only one custom canteen attribute are applied at once
	local purchasedCanteenIndex
	for i, canteenData in pairs(CUSTOM_CANTEENS) do
		if canteen:GetAttributeValue(canteenData.Attribute) then
			purchasedCanteenIndex = i
			break
		end
	end

	if not purchasedCanteenIndex then
		print("NO CUSTOM CANTEEN FOUND")
		return
	end

	canteen.i_LastCanteenCharges = tick

	local index = activator:GetHandleIndex()

	local canteenData = CUSTOM_CANTEENS[purchasedCanteenIndex]

	canteen:SetAttributeValue("special item description", canteenData.Description)

	canteenPlayers[index].CustomCanteenData = canteenData
end