local SHIELD_OFFSET = 100

local function DisableShield(shield)
	shield:SetModel("models/empty.mdl")
end

local function UpdateShieldModel(shield, building)
	local buildingLevel = building.m_iHighestUpgradeLevel

	if buildingLevel <= 1 then
		shield:SetModel("models/props_mvm/mvm_comically_small_player_shield.mdl")
	elseif buildingLevel == 2 then
		shield:SetModel("models/props_mvm/mvm_player_shield.mdl")
	else
		shield:SetModel("models/props_mvm/mvm_player_shield2.mdl")
	end
end

local function UpdateSentryShield(shield, building, owner)
	if building.m_bCarried == 1 or building.m_bPlacing == 1 then
		DisableShield(shield)
		return
	end

	local angles = building.m_bPlayerControlled == 1 and owner:GetAbsAngles() or building:GetAbsAngles()
	shield:SetAbsOrigin(building:GetAbsOrigin() + angles:GetForward() * SHIELD_OFFSET)
	shield:SetAbsAngles(angles)

	UpdateShieldModel(shield, building)
end

local function SetupPSGSentry(building, owner)
	local shield = ents.CreateWithKeys("entity_medigun_shield", {
		teamnum = owner.m_iTeamNum,
		spawnflags = 1,
	})

	UpdateSentryShield(shield, building, owner)
	-- shield:SetParent(building)

	local updateLoop
	updateLoop = timer.Create(0.1, function ()
		if not IsValid(building) then
			timer.Stop(updateLoop)
			return
		end
		UpdateSentryShield(shield, building, owner)
	end, 0)
end

function OnPSGSentrySpawn(building)
	local owner = building.m_hBuilder

	local pda = owner:GetPlayerItemBySlot(LOADOUT_POSITION_PDA)

	if not pda:GetAttributeValue("throwable fire speed") then
		return
	end

	timer.Simple(0.1, function ()
		SetupPSGSentry(building, owner)
	end)
end

ents.AddCreateCallback("obj_sentrygun", function(building)
	timer.Simple(0, function()
		OnPSGSentrySpawn(building)
	end)
end)