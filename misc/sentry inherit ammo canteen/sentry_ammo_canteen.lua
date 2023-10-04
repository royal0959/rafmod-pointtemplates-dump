-- washy — Today at 12:28 AM
-- man i wish that worked with sentries

local AMMO_CANTEEN = 4

local MAX_AMMO_LVL1 = 150
local MAX_AMMO = 200
local MAX_ROCKETS = 20

local function getSentry(player)
	local hIndex = player:GetHandleIndex()
	for _, sentry in pairs(ents.FindAllByClass("obj_sentrygun")) do
		if sentry.m_hBuilder:GetHandleIndex() == hIndex then
			return sentry
		end
	end
end

AddEventCallback("player_used_powerup_bottle", function(eventTable)
	local netId = eventTable.player
	local canteenType = eventTable.type


	local player = ents.GetAllPlayers()[netId]

	if canteenType ~= AMMO_CANTEEN then
		return
	end

	local sentry = getSentry(player)

	if not sentry then
		return
	end

	if canteenType == AMMO_CANTEEN then
		sentry.m_iAmmoShells = sentry.m_iHighestUpgradeLevel <= 1 and MAX_AMMO_LVL1 or MAX_AMMO
		sentry.m_iAmmoRockets = MAX_ROCKETS
	end
end)
