local disposableOwners = {}

local function isInWave()
	local objectiveResoure = ents.FindByClass("tf_objective_resource")

	print(objectiveResoure.m_bMannVsMachineBetweenWaves)

	return objectiveResoure.m_bMannVsMachineBetweenWaves
end

function SplitSentryBought(tick, activator)
	print(tick)
	local handle = activator:GetHandleIndex()

	if not disposableOwners[handle] then
		disposableOwners[handle] = {
			Count = 0,
			Sentries = {},

			Cap = tick,
		}
	else
		disposableOwners[handle].Cap = tick
	end

	activator.SplitSentry = true
end
function SplitSentryRefunded(_, activator)
	activator.SplitSentry = false

	local handle = activator:GetHandleIndex()

	if disposableOwners[handle] then
		for _, sentry in pairs(disposableOwners[handle].Sentries) do
			if sentry:IsValid() then
				sentry:Remove()
			end
		end

		disposableOwners[handle] = nil
	end
end

function OnPlayerConnected(player)
	local handle = player:GetHandleIndex()

	local forcedSentriesDisposable = false

	-- make all extra sentries not be affected by wrangler
	player:AddCallback(ON_DEPLOY_WEAPON, function(_, weapon)
		if not disposableOwners[handle] then
			return true
		end

		if weapon.m_iClassname ~= "tf_weapon_laser_pointer" then
			if not forcedSentriesDisposable then
				return true
			end

			for _, sentry in pairs(disposableOwners[handle].Sentries) do
				sentry.m_bDisposableBuilding = 0
			end

			return true
		end

		for _, sentry in pairs(disposableOwners[handle].Sentries) do
			sentry.m_bDisposableBuilding = 1
		end

		forcedSentriesDisposable = true

		return true
	end)
end

function OnPlayerDisconnected(player)
	local handle = player:GetHandleIndex()

	if disposableOwners[handle] then
		for _, sentry in pairs(disposableOwners[handle].Sentries) do
			if sentry:IsValid() then
				sentry:Remove()
			end
		end

		disposableOwners[handle] = nil
	end
end

ents.AddCreateCallback("obj_sentrygun", function(building)
	timer.Simple(0, function()
		if building.m_bDisposableBuilding ~= 1 then
			return
		end

		local builder = building.m_hBuilder

		if not builder.SplitSentry then
			return
		end

		building.m_flModelScale = 1

		local buildingDeployedTimer
		buildingDeployedTimer = timer.Create(0.1, function()
			if not building:IsValid() then
				timer.Stop(buildingDeployedTimer)
			end

			if building.m_bPlacing ~= 0 then
				return
			end

			building.m_bDisposableBuilding = 0
			building.m_bMiniBuilding = 0
			building.m_iHighestUpgradeLevel = isInWave() and 3 or 1

			local handle = builder:GetHandleIndex()

			local buildingHandle = building:GetHandleIndex()

			local disposablesData = disposableOwners[handle]

			disposablesData.Count = disposablesData.Count + 1
			table.insert(disposablesData.Sentries, building)

			if disposablesData.Count > disposablesData.Cap then
				disposablesData.Sentries[1]:Remove()
				table.remove(disposablesData.Sentries, 1)
			end

			building:AddCallback(ON_REMOVE, function()
				disposablesData = disposableOwners[handle]

				disposablesData.Count = disposablesData.Count - 1

				for i, sentry in pairs(disposablesData.Sentries) do
					if sentry:GetHandleIndex() == buildingHandle then
						table.remove(disposablesData.Sentries, i)
						break
					end
				end
			end)

			timer.Stop(buildingDeployedTimer)
		end, 0)
	end)
end)
