-- TODO: notify player if bot can't be built because robot limit is reached

local BOTS_VARIANTS = {
	soldier = {
		Display = "Soldier",
		Class = "Soldier",
		Model = "models/bots/soldier/bot_soldier.mdl",

		DefaultAttributes = {},

		Tiers = {
			[2] = {
				Display = "Direct Hit Soldier",
				Scale = 1.1,

				Items = {"The Direct Hit", "Stainless Pot"},

				Attributes = {
					["faster reload rate"] = 0.8,
					["clip size upgrade atomic"] = 2.0,
				},
			},
			[3] = {
				Display = "Black Box Soldier",
				Scale = 1.25,

				Items = {"The Black Box", "The Grenadier's Softcap"},

				HealthIncrease = 150,

				Attributes = {
					["damage bonus"] = 1.5,
					["faster reload rate"] = 0.8,
					["clip size upgrade atomic"] = 4.0,
					["fire rate bonus"] = 0.85,
				},
			},
			[4] = {
				Display = "Sergeant Crits",
				Model = "models/bots/soldier_boss/bot_soldier_boss.mdl",
				Scale = 1.7,

				Conds = {37},
				HealthIncrease = 3800,

				Items = {"Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Tyrant's Helm"},

				Attributes = {
					["damage bonus"] = 2,
					-- ["faster reload rate"] = -0.6,
					["fire rate bonus"] = 0.4,
					["clip size upgrade atomic"] = 20.0,
					["Projectile speed increased"] = 0.5,
					["move speed bonus"] = 0.5,

					["damage force reduction"] = 0.4,
					["airblast vulnerability multiplier"] = 0.4,
					["override footstep sound set"] = 3,
				},
			},
		},
	},

	heavy = {
		Display = "Heavyweapons",
		CLass = "Heavy",
		Model = "models/bots/heavy/bot_heavy.mdl",

		DefaultAttributes = {},

		Tiers = {},
	}
}

local BOTS_ATTRIBUTES = {
	["not solid to players"] = 1,
	["collect currency on kill"] = 1,
	["ammo regen"] = 10,
}
local BOTS_WRANGLED_ATTRIBUTES = {
	-- ["CARD: damage bonus"] = 1.3,
	["fire rate bonus HIDDEN"] = 0.9,
	["Reload time increased"] = 0.9,
	["SET BONUS: move speed set bonus"] = 1.3,
}

-- we can't expect lua to do all the work - joshua graham
-- local BOT_SETUP_VSCRIPT = "activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(0.1)"
local BOT_SETUP_VSCRIPT = "activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(100000"
local BOT_DISABLE_VISION_VSCRIPT = "activator.SetMaxVisionRangeOverride(0.1)"
local BOT_ENABLE_VISION_VSCRIPT = "activator.SetMaxVisionRangeOverride(100000)"
-- local BOT_CLEAR_FOCUS = "activator.ClearAttentionFocus()"

local BOT_ATTACK_VSCRIPT = "activator.PressFireButton(0.1)"

local activeBuiltBots = {}
local activeBuiltBotsOwner = {}

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
		bot:RemoveCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
		bot:SetAttributeValue("ignored by enemy sentries", nil)
		bot:SetAttributeValue("ignored by bots", nil)
		bot:SetAttributeValue("damage bonus HIDDEN", nil)
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

-- convert damage dealt by bots to owner
local function addGlobalDamageCallback(player)
	player:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageinfo)
		local attacker = damageinfo.Attacker

		if not attacker then
			return
		end

		local handle = attacker:GetHandleIndex()

		local owner = activeBuiltBotsOwner[handle]

		if not owner then
			return
		end

		if player == owner then
			return
		end

		damageinfo.Attacker = owner

		return true
	end)
end

function OnPlayerConnected(player)
	addGlobalDamageCallback(player)
end

-- for _, player in pairs(ents.GetAllPlayers()) do
-- 	addGlobalDamageCallback(player)
-- end

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

local atan = math.atan
local sqrt = math.sqrt
local pi = math.pi

-- ported from C:\Users\Admin\Documents\GitHub\sigsegv-mvm\src\sdk2013\mathlib_base.cpp
local function vectorAngles(forward)
	local yaw, pitch

	if forward[2] == 0 and forward[1] == 0 then
		yaw = 0
		if forward[3] > 0 then
			pitch = 270
		else
			pitch = 90
		end
	else
		yaw = (atan(forward[2], forward[1]) * 180 / pi)
		-- if yaw < 0 then
		-- 	yaw = yaw + 360
		-- end

		local tmp = sqrt(forward[1] * forward[1] + forward[2] * forward[2])
		tmp = forward[3] > 0 and tmp or -tmp

		pitch = (atan(-forward[3], tmp) * 180 / pi)
		-- if pitch < 0 then
		-- 	pitch = pitch + 360
		-- end
	end

	return Vector(pitch, yaw, 0)
end

local function getCursorPos(player)
	local eyeAngles = getEyeAngles(player)

	local DefaultTraceInfo = {
		start = player,
		distance = 10000,
		angles = eyeAngles,
		mask = MASK_SOLID,
		collisiongroup = TFCOLLISION_GROUP_ROCKETS, --COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)
	return trace.HitPos
end

local function applyName(bot, name, owner)
	local displayName = name.." (" .. owner.m_szNetname .. ")"
	bot.m_szNetname = displayName

	bot:SetFakeClientConVar("name", displayName)
end

local function applyUniversalData(bot, data)
	if data.Model then
		bot:SetCustomModelWithClassAnimations(data.Model)
	end

	if data.Scale then
		local vscript = ("activator.SetScaleOverride(%s)"):format(tostring(data.Scale))
		bot:RunScriptCode(vscript, bot)
	end


	if data.Items then
		for _, itemName in pairs(data.Items) do
			bot:GiveItem(itemName)
		end
	end

	if data.Attributes then
		for name, value in pairs(data.Attributes) do
			bot:SetAttributeValue(name, value)
		end
	end

	if data.Display then
		applyName(bot, data.Display, activeBuiltBotsOwner[bot:GetHandleIndex()])
	end
end

local function applyDefaultData(bot, class)
	local data = BOTS_VARIANTS[class]

	if data.DefaultAttributes then
		for name, value in pairs(data.DefaultAttributes) do
			bot:SetAttributeValue(name, value)
		end
	end

	bot:SwitchClassInPlace(data.Class)
	-- remove potential lingering health
	bot:SetAttributeValue("hidden maxhealth non buffed", nil)

	applyUniversalData(bot, data)
end

local function applyTierData(bot, data)
	applyUniversalData(bot, data)

	if data.HealthIncrease then
		bot:SetAttributeValue("hidden maxhealth non buffed", data.HealthIncrease)

		local owner = activeBuiltBotsOwner[bot:GetHandleIndex()]

		local sentry = Entity(tonumber(owner.BuiltBotSentry))
		sentry.m_iMaxHealth = owner.m_iMaxHealth + data.HealthIncrease
		sentry.m_iHealth = sentry.m_iHealth + data.HealthIncrease
	end

	if data.Conds then
		for _, id in pairs(data.Conds) do
			bot:AddCond(id)
		end
	end
end

-- remove lingering stuff
local function removePreviousTier(bot, class, previousTier)
	local data = BOTS_VARIANTS[class].Tiers[previousTier]

	if data.Conds then
		for _, id in pairs(data.Conds) do
			bot:RemoveCond(id)
		end
	end

	if data.Items then
		for _, itemName in pairs(data.Items) do
			bot:RemoveItem(itemName)
		end
	end

	if data.Attributes then
		for name, _ in pairs(data.Attributes) do
			bot:SetAttributeValue(name, nil)
		end
	end
end

local function getCurBotTier(owner)
	return owner:GetPlayerItemBySlot(2):GetAttributeValue("throwable fire speed")
end

local function applyBotTier(bot, class, tier)
	if tier > 2 then
		removePreviousTier(bot, class, tier - 1)
	end

	local tierData = BOTS_VARIANTS[class].Tiers[tier]

	applyTierData(bot, tierData)
end

local function setupBot(bot, owner, handle, building)
	local callbacks = {}

	local botHandle = bot:GetHandleIndex()

	-- local displayName = "Soldier (" .. owner.m_szNetname .. ")"
	-- bot.m_szNetname = displayName

	-- bot:SetFakeClientConVar("name", displayName)
	applyName(bot, "Soldier", owner)

	bot.m_iTeamNum = owner.m_iTeamNum

	bot.m_iszClassIcon = "" -- don't remove from wave on death

	for name, value in pairs(BOTS_ATTRIBUTES) do
		bot:SetAttributeValue(name, value)
	end

	-- bot:AddModule("rotator")
	-- bot["$lookat"] = "center"
	-- bot["$projectilespeed"] = 1100

	owner.BuiltBotHandle = tostring(botHandle)
	owner.BuiltBotSentry = tostring(building:GetHandleIndex())

	activeBuiltBots[handle] = bot
	activeBuiltBotsOwner[botHandle] = owner

	callbacks.damaged = bot:AddCallback(ON_DAMAGE_RECEIVED_POST, function()
		building.m_iHealth = bot.m_iHealth
	end)
	callbacks.died = bot:AddCallback(ON_DEATH, function()
		-- attributes applied to bot spawned through script are not cleared automatically on death
		for name, _ in pairs(bot:GetAllAttributeValues()) do
			bot:SetAttributeValue(name, nil)
		end

		owner.BuiltBotHandle = false
		owner.BuiltBotSentry = false

		activeBuiltBots[handle] = nil
		activeBuiltBotsOwner[botHandle] = nil
		bot.m_iTeamNum = 1

		-- bot:RemoveModule("rotator")

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
			and not bot:IsAlive()
			and (bot.m_iTeamNum == 1 or bot.m_iTeamNum == 0)
			and bot:GetPlayerName() ~= "Demo-Bot"
		then
			chosen = bot
			break
		end
	end

	return chosen
end

local function traceBetween(player, originTarget)
	local DefaultTraceInfo = {
		start = player,
		endpos = originTarget,
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)

	return trace.Hit
end

-- finds closest bot to use as target, TODO: prioritize medics and spies
local function getBotTarget(bot, owner)
	local botTeam = bot.m_iTeamNum

	-- don't target anything in pre wave
	if botTeam == 1 then
		return owner
	end

	local closest = { nil, 1000000 }

	local players = ents.GetAllPlayers()

	local botOrigin = bot:GetAbsOrigin()

	local origin
	local distance

	local function validateTarget(player)
		if not player:IsAlive() then
			return
		end

		if player.m_iTeamNum == botTeam then
			return
		end

		origin = player:GetAbsOrigin()
		distance = origin:Distance(botOrigin)

		if distance > closest[2] then
			return
		end

		if traceBetween(bot, origin) then
			return
		end

		closest = { player, distance }
	end

	for _, player in pairs(players) do
		validateTarget(player)
	end

	if not closest[1] then
		-- if no target was found, have the bot look at its owner
		return owner
	end

	return closest[1]
end

function TierPurchase(tier, activator)
	tier = tier + 1

	print("purchasing tier", tier)

	-- activator.BotTier = tier

	local botHandle = activator.BuiltBotHandle
	local bot = botHandle and Entity(tonumber(botHandle))

	if tier <= 1 then
		if bot then
			bot:Suicide()
		end

		return
	end

	-- local botHandle = activator.BuiltBotHandle
	-- if not botHandle then
	-- 	return
	-- end

	-- botHandle = tonumber(botHandle)
	-- local bot = Entity(botHandle)

	if not bot then
		return
	end

	applyBotTier(bot, "soldier", tier)
end

function SentrySpawned(_, building)
	local owner = building.m_hBuilder
	local handle = owner:GetHandleIndex()

	local origin = building:GetAbsOrigin()

	local newBuilding = ents.CreateWithKeys("obj_sentrygun", {
		defaultupgrade = 0,
		team = owner.m_iTeamNum,
		SolidToPlayer = 0,
	}, true)

	building:Remove()
	newBuilding:SetBuilder(owner, owner, owner)

	newBuilding:SetAbsOrigin(Vector(0, 0, -10000))
	newBuilding:Disable()

	if activeBuiltBots[handle] and activeBuiltBots[handle]:IsAlive() then
		newBuilding:Remove()
		return
	end

	local botSpawn = findFreeBot()

	if not botSpawn then
		newBuilding:Remove()
		return
	end

	local callbacks = setupBot(botSpawn, owner, handle, newBuilding)

	timer.Simple(0, function()
		botSpawn:SetAbsOrigin(origin)
		botSpawn:SwitchClassInPlace("Soldier")

		local botTier = getCurBotTier(owner)

		if botTier and botTier > 1 then
			print("applying tier", botTier)
			applyBotTier(botSpawn, "soldier", botTier)
		else
			applyDefaultData(botSpawn, "soldier")
		end

		botSpawn:RunScriptCode(BOT_SETUP_VSCRIPT, botSpawn, botSpawn)

		-- set max health
		newBuilding.m_iMaxHealth = botSpawn.m_iHealth
		newBuilding.m_iHealth = botSpawn.m_iHealth

		newBuilding:AddCallback(ON_REMOVE, function()
			if not activeBuiltBots[handle] then
				return
			end

			botSpawn:Suicide()
		end)

		-- timer.Simple(1, function ()
		-- 	local displayName = "Soldier (" .. owner.m_szNetname .. ")"
		-- 	botSpawn.m_szNetname = displayName

		-- 	botSpawn:RunScriptFile("rename_to_netname.nut", botSpawn, botSpawn)
		-- 	-- botSpawn:CallScriptFunction("forceNameToNetName", botSpawn, botSpawn)
		-- end)

		if not inWave then
			botSpawn.m_iTeamNum = 1
			botSpawn:AddCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
			botSpawn:SetAttributeValue("ignored by enemy sentries", 1)
			botSpawn:SetAttributeValue("ignored by bots", 1)
			botSpawn:SetAttributeValue("damage bonus HIDDEN", 0.0001)
		end

		callbacks.spawned = botSpawn:AddCallback(ON_SPAWN, function()
			removeCallbacks(botSpawn, callbacks)
			if IsValid(newBuilding) then
				newBuilding:Remove()
			end
		end)

		-- local aimPointerName = "BotAimPointer" .. tostring(handle)
		-- local aimPointer = Entity("info_particle_system", true)
		-- aimPointer:SetName(aimPointerName)

		-- local killPointerName = "BotKillPointer" .. tostring(handle)
		-- local killPointer = Entity("info_particle_system", true)
		-- killPointer:SetName(killPointerName)

		local cursorPos = Vector(0, 0, 0)

		-- local function forceLookAtCursor()
		-- 	local delta = cursorPos - botSpawn:GetAbsOrigin()
		-- 	local angles = vectorAngles(delta)

		-- 	botSpawn:SetAbsAngles(angles)
		-- 	botSpawn:SnapEyeAngles(angles)
		-- end

		-- local forceAngleLoop
		-- forceAngleLoop = timer.Create(0, function()
		-- 	if not activeBuiltBots[handle] then
		-- 		timer.Stop(forceAngleLoop)
		-- 		return
		-- 	end

		-- 	if not owner:IsAlive() then
		-- 		return
		-- 	end

		-- 	if owner.m_hActiveWeapon.m_iClassname ~= "tf_weapon_laser_pointer" then
		-- 		return
		-- 	end

		-- 	-- botSpawn:FaceEntity(aimPointer)
		-- 	-- botSpawn:SnapEyeAngles(getEyeAngles(owner))

		-- 	local delta = cursorPos - botSpawn:GetAbsOrigin()
		-- 	local angles = vectorAngles(delta)

		-- 	botSpawn:SetAbsAngles(angles)
		-- 	botSpawn:SnapEyeAngles(angles)
		-- end, 0)

		local lastWrangled = false

		-- bot behavior
		-- default behavior is always following you
		local logicLoop
		logicLoop = timer.Create(0.2, function()
			if not activeBuiltBots[handle] then
				timer.Stop(logicLoop)
				-- if IsValid(aimPointer) then
				-- 	aimPointer:Remove()
				-- end
				-- if IsValid(killPointer) then
				-- 	killPointer:Remove()
				-- end
				return
			end

			if not owner:IsAlive() then
				return
			end

			if owner.m_hActiveWeapon.m_iClassname == "tf_weapon_laser_pointer" then
				-- wrangle behavior:
				-- if attack is held: fire weapon
				-- if alt fire is held: move toward cursor

				if not lastWrangled then
					botSpawn:BotCommand("stop interrupt action")

					botSpawn:RunScriptCode(BOT_DISABLE_VISION_VSCRIPT, botSpawn)
					botSpawn:AddCond(TF_COND_ENERGY_BUFF)

					for name, value in pairs(BOTS_WRANGLED_ATTRIBUTES) do
						botSpawn:SetAttributeValue(name, value)
					end

					lastWrangled = true
				end

				local altFireHeld = owner.m_nButtons & IN_ATTACK2 ~= 0
				local attackHeld = owner.m_nButtons & IN_ATTACK ~= 0

				cursorPos = getCursorPos(owner)

				if attackHeld then
					botSpawn:RunScriptCode(BOT_ATTACK_VSCRIPT, botSpawn)
				end

				local stringStart = ("interrupt_action -lookpos %s %s %s -alwayslook"):format(
					cursorPos[1], cursorPos[2], cursorPos[3]
				)

				if altFireHeld then
					stringStart = stringStart
						.. (" -pos %s %s %s -distance 1"):format(cursorPos[1], cursorPos[2], cursorPos[3])
				end

				local interruptAction = ("%s -duration 420000"):format(stringStart)

				botSpawn:BotCommand(interruptAction)
				return
			end

			if lastWrangled then
				for name, _ in pairs(BOTS_WRANGLED_ATTRIBUTES) do
					botSpawn:SetAttributeValue(name, nil)
				end

				botSpawn:BotCommand("stop interrupt action")

				botSpawn:RunScriptCode(BOT_ENABLE_VISION_VSCRIPT, botSpawn)
				botSpawn:RemoveCond(TF_COND_ENERGY_BUFF)

				lastWrangled = false
			end

			-- local lookTarget = getBotTarget(botSpawn, owner)
			-- local lookTargetPos = lookTarget:GetAbsOrigin()

			-- killPointer:SetAbsOrigin(lookTargetPos)

			local pos = owner:GetAbsOrigin()

			-- local stringStart = ("interrupt_action -lookposent %s -waituntildone"):format(killPointerName)
			local stringStart = "interrupt_action"

			-- force attack target if not facing owner
			-- if lookTarget ~= owner then
				-- botSpawn:RunScriptCode(BOT_ATTACK_VSCRIPT, botSpawn)
			-- 	stringStart = stringStart .. " -killlook"
			-- end

			-- don't move if already close
			if pos:Distance(botSpawn:GetAbsOrigin()) <= 150 then
				botSpawn:BotCommand(stringStart .. " -duration 0.1")
				return
			end

			local interruptAction = ("%s -pos %s %s %s -duration 0.1"):format(stringStart, pos[1], pos[2], pos[3])

			botSpawn:BotCommand(interruptAction)
		end, 0)
	end)

	-- table.insert(activeBuiltBots, botSpawn)
end

-- timer.Simple(5, function ()
-- 	for _, player in pairs(ents.GetAllPlayers()) do
-- 		if player:IsRealPlayer() then
-- 			goto continue
-- 		end

-- 		setupBot(player)

-- 		::continue::
-- 	end
-- end)
