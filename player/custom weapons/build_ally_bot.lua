local activeBuiltBots = {}

local inWave = false

function OnWaveInit()
	inWave = false

	for _, bot in pairs(activeBuiltBots) do
		bot:Suicide()
		bot.m_iTeamNum = 1
	end

	activeBuiltBots = {}
end

function OnWaveStart()
	inWave = true

	-- bots spawned in prewave are put to spectate/gray team so they don't take up slot
	for _, bot in pairs(activeBuiltBots) do
		bot.m_iTeamNum = 2
	end

	-- local objResource = ents.FindByClass("tf_objective_resource")

	-- objResource.m_nMannVsMachineWaveEnemyCount = 1000

	-- for i = 1, #objResource.m_nMannVsMachineWaveClassFlags  do
	-- 	objResource:AcceptInput("$setprop$m_nMannVsMachineWaveClassFlags$" .. i - 1, 9)
	-- end
	-- for i = 1, #objResource.m_iszMannVsMachineWaveClassNames do
	-- 	objResource:AcceptInput("$setprop$m_iszMannVsMachineWaveClassNames$" .. i - 1, "soldier_barrage")
	-- end
	-- for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
	-- 	objResource:AcceptInput("$setprop$m_nMannVsMachineWaveClassCounts$" .. i - 1, 1)
	-- end
	-- for i = 1, #objResource.m_bMannVsMachineWaveClassActive do
	-- 	objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive$" .. i - 1, true)
	-- end
	-- for i = 1, #objResource.m_bMannVsMachineWaveClassActive2 do
	-- 	objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive2$" .. i - 1, true)
	-- end
end

local function removeCallbacks(player, callbacks)
	if not IsValid(player) then
		return
	end

	for _, callbackId in pairs(callbacks) do
		player:RemoveCallback(callbackId)
	end
end

local function forceSpawnBot(bot, owner, handle)
	local callbacks = {}

	-- print(bot.m_szNetname)

	-- bot.m_szNetname = "Soldier ("..owner.m_szNetname..")"

	-- print(bot.m_szNetname)

	bot.m_iTeamNum = owner.m_iTeamNum
	bot.m_nBotSkill = 4 -- expert
	bot.m_iszClassIcon = "" -- don't remove from wave on death

	activeBuiltBots[handle] = bot

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		-- activeBuiltBots[handle] = nil -- causes issues I think
		bot.m_iTeamNum = 1
		removeCallbacks(bot, callbacks)
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
	end)
end

local function findFreeBot()
	local chosen

	for _, bot in pairs(ents.GetAllPlayers()) do
		if
			not bot:IsRealPlayer()
			and (bot.m_iTeamNum == 1 or bot.m_iTeamNum == 0)
			and bot:GetPlayerName() ~= "Demo-Bot"
		then
			chosen = bot
			break
		end
	end

	return chosen
end

function SentrySpawned(_, building)
	local owner = building.m_hBuilder
	local handle = owner:GetHandleIndex()

	local origin = building:GetAbsOrigin()

	building:Remove()

	if activeBuiltBots[handle] and activeBuiltBots[handle]:IsAlive() then
		return
	end

	local botSpawn = findFreeBot()

	if not botSpawn then
		return
	end

	forceSpawnBot(botSpawn, owner, handle)

	timer.Simple(0, function()
		botSpawn:SetAbsOrigin(origin)
		botSpawn:SwitchClassInPlace("Soldier")

		if not inWave then
			botSpawn.m_iTeamNum = 1
		end
	end)

	-- table.insert(activeBuiltBots, botSpawn)
end

-- timer.Simple(5, function ()
-- 	for _, player in pairs(ents.GetAllPlayers()) do
-- 		if player:IsRealPlayer() then
-- 			goto continue
-- 		end

-- 		forceSpawnBot(player)

-- 		::continue::
-- 	end
-- end)
