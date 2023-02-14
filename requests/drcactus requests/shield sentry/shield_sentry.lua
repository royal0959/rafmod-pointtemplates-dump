local SHIELD_OFFSET = 100

local SHIELD_DAMAGE_ABSORB_MULT = 0.8
local SHIELD_DAMAGE_AMMO_REDUCTION_MULT = 0.5

local function DisableShield(shield)
	shield:SetModel("models/empty.mdl")
end

local function UpdateShieldModel(shield, building)
	local buildingLevel = building.m_iHighestUpgradeLevel

	if building.m_bDisposableBuilding ~= 0 or buildingLevel <= 1 then
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
	if building.m_bDisposableBuilding ~= 0 then
		building["$attributeoverride"] = 1
	end

	local shield = ents.CreateWithKeys("entity_medigun_shield", {
		teamnum = owner.m_iTeamNum,
		spawnflags = 1,
	})

	UpdateSentryShield(shield, building, owner)
	-- shield:SetParent(building)

	building:AddCallback(ON_REMOVE, function()
		shield:Remove()
	end)

	local lastDamageTick = TickCount()
	shield:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageinfo)
		local curTick = TickCount()
		lastDamageTick = curTick

		shield:Color("200 0 100")

		timer.Simple(0.1, function()
			if not IsValid(shield) then
				return
			end

			-- prevents constant flickering on constant damage
			if lastDamageTick ~= curTick then
				return
			end

			shield:Color("255 255 255")
		end)

		if building.m_bDisposableBuilding ~= 0 then
			building.m_iAmmoShells = building.m_iAmmoShells - (damageinfo.Damage * SHIELD_DAMAGE_AMMO_REDUCTION_MULT)
			return
		end

		damageinfo.Damage = damageinfo.Damage * SHIELD_DAMAGE_ABSORB_MULT
		building:TakeDamage(damageinfo)
	end)

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