--[[
	REQUIRED: 
		-"FixSetCustomModelInput 1" in wave schedule

	OPTIONAL:
		-Up to 6 extra bots slot
]]
--

local BOTS_ATTRIBUTES = {
	["not solid to players"] = 1,
	["collect currency on kill"] = 1,
}

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

local function getEyeAngles(player)
	local pitch = player["m_angEyeAngles[0]"]
	local yaw = player["m_angEyeAngles[1]"]

	return Vector(pitch, yaw, 0)
end

local function getCursorPos(player)
	local eyeAngles = getEyeAngles(player)

	local DefaultTraceInfo = {
		start = player,
		distance = 10000,
		angles = eyeAngles,
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)
	return trace.HitPos
end

local function forceSpawnBot(bot, owner, handle, building)
	local callbacks = {}

	local displayName = "Soldier (" .. owner.m_szNetname .. ")"
	bot.m_szNetname = displayName

	bot:SetFakeClientConVar("name", displayName)

	bot.m_iTeamNum = owner.m_iTeamNum
	bot.m_nBotSkill = 4 -- expert
	bot.m_iszClassIcon = "" -- don't remove from wave on death

	for name, value in pairs(BOTS_ATTRIBUTES) do
		bot:SetAttributeValue(name, value)
	end

	activeBuiltBots[handle] = bot

	callbacks.damaged = bot:AddCallback(ON_DAMAGE_RECEIVED_POST, function()
		building.m_iHealth = bot.m_iHealth
	end)
	callbacks.died = bot:AddCallback(ON_DEATH, function()
		activeBuiltBots[handle] = nil
		bot.m_iTeamNum = 1

		removeCallbacks(bot, callbacks)
		if IsValid(building) then
			building:Remove()
		end
	end)

	return callbacks
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

-- TODO: replace player's sentry with a spawned sentry to skip the deploy animation
function SentrySpawned(_, building)
	local owner = building.m_hBuilder
	local handle = owner:GetHandleIndex()

	local origin = building:GetAbsOrigin()

	building:SetAbsOrigin(Vector(0, 0, -10000))
	building:Hide()

	if activeBuiltBots[handle] and activeBuiltBots[handle]:IsAlive() then
		building:Remove()
		return
	end

	local botSpawn = findFreeBot()

	if not botSpawn then
		building:Remove()
		return
	end

	local callbacks = forceSpawnBot(botSpawn, owner, handle, building)

	timer.Simple(0, function()
		botSpawn:SetAbsOrigin(origin)
		botSpawn:SwitchClassInPlace("Soldier")
		botSpawn:SetCustomModelWithClassAnimations("models/bots/soldier/bot_soldier.mdl")

		-- set max health
		building.m_iMaxHealth = botSpawn.m_iHealth

		building:AddCallback(ON_REMOVE, function()
			if not activeBuiltBots[handle] then
				return
			end

			botSpawn:Suicide()
		end)

		if not inWave then
			botSpawn.m_iTeamNum = 1
		end

		callbacks.spawned = botSpawn:AddCallback(ON_SPAWN, function()
			removeCallbacks(botSpawn, callbacks)
			if IsValid(building) then
				building:Remove()
			end
		end)

		-- bot behavior
		-- default behavior is always following you
		local logicLoop
		logicLoop = timer.Create(0.2, function()
			if not activeBuiltBots[handle] then
				timer.Stop(logicLoop)
				return
			end

			if owner.m_hActiveWeapon.m_iClassname == "tf_weapon_laser_pointer" then
				-- wrangle behavior:
				-- look toward cursor
				-- if alt fire is held: move toward cursor

				local altFireHeld = owner.m_nButtons & IN_ATTACK2 ~= 0
				-- local attackHeld = owner.m_nButtons & IN_ATTACK ~= 0

				local cursorPos = getCursorPos(owner)

				local stringStart = "interrupt_action_queue"
				if altFireHeld then
					stringStart = stringStart
						.. (" -pos %s %s %s"):format(cursorPos[1], cursorPos[2], cursorPos[3])
				end

				local stringMiddle = ("-lookpos %s %s %s "):format(cursorPos[1], cursorPos[2], cursorPos[3])

				-- if attackHeld then
				-- 	stringMiddle = stringMiddle .. " -killlook"
				-- end

				local interruptAction = ("%s %s -duration 0.1"):format(stringStart, stringMiddle)

				botSpawn["$BotCommand"](botSpawn, interruptAction)

				return
			end

			local pos = owner:GetAbsOrigin()

			local interruptAction = ("interrupt_action_queue -pos %s %s %s -duration 0.1"):format(
				pos[1],
				pos[2],
				pos[3]
			)

			botSpawn["$BotCommand"](botSpawn, interruptAction)
		end, 0)
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
