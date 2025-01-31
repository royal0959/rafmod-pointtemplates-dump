local BOTS_VARIANTS = {
	soldier = {
		Display = "Soldier",
		Class = "Soldier",
		Model = "models/bots/soldier/bot_soldier.mdl",

		-- TODO
		MaxClip = 4,

		DefaultAttributes = {},

		Tiers = {
			[2] = {
				Display = "Direct Hit Soldier",
				Model = "models/bots/soldier/bot_soldier.mdl",
				Scale = 1.1,

				Items = { "The Direct Hit", "Stainless Pot" },

				Attributes = {
					["faster reload rate"] = 0.8,
					["rocket specialist"] = 1,
					-- ["clip size upgrade atomic"] = 2.0,
				},
			},
			[3] = {
				Display = "Burst Fire Soldier",
				Model = "models/bots/soldier/bot_soldier.mdl",
				Scale = 1.25,

				Items = { "Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Armored Authority" },

				HealthIncrease = 150,

				Attributes = {
					["damage bonus"] = 1.1,

					["reload full clip at once"] = 1,
					["force fire full clip"] = 1,
					["projectile spread angle penalty"] = 3,

					["faster reload rate"] = 5,
					["fire rate bonus"] = 0.1,
					["clip size upgrade atomic"] = 3.0,
					["Projectile speed increased"] = 0.65,
				},
			},
			[4] = {
				Display = "Rapid Fire Soldier",
				Model = "models/bots/soldier/bot_soldier.mdl",
				Scale = 1.55,

				Items = { "Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Soldier Drill Hat" },

				HealthIncrease = 200,

				Attributes = {
					["damage bonus"] = 1.2,

					["faster reload rate"] = -0.8,
					["fire rate bonus"] = 0.5,
				},
			},
			[5] = {
				Display = "Giant Charged Soldier",
				Model = "models/bots/soldier_boss/bot_soldier_boss.mdl",
				Scale = 1.75,

				Items = { "The Original", "The Nuke" },

				Conds = { 37 },
				HealthIncrease = 1800,

				MiniBoss = true,

				Attributes = {
					["damage bonus"] = 1.5,
					["faster reload rate"] = 0.5,
					["fire rate bonus"] = 2,
					["Projectile speed increased"] = 0.5,

					["move speed bonus"] = 0.6,

					["damage force reduction"] = 0.4,
					["airblast vulnerability multiplier"] = 0.4,
					["override footstep sound set"] = 3,
				},
			},
			[6] = {
				Display = "Sergeant Crits",
				Model = "models/bots/soldier_boss/bot_soldier_boss.mdl",
				Scale = 1.7,

				Conds = { 37 },
				HealthIncrease = 3800,

				Items = { "Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Tyrant's Helm" },

				MiniBoss = true,

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
	},
}

local SPEED_BOOST_DISTANCE = 400 -- apply speed boost to bot when it's far away from owner

local BOTS_ATTRIBUTES = {
	-- ["not solid to players"] = 1, -- prevents bot from taking teleporter
	["collect currency on kill"] = 1,
	["ammo regen"] = 10,
}
local BOTS_WRANGLED_ATTRIBUTES = {
	-- ["CARD: damage bonus"] = 1.3,
	["fire rate bonus HIDDEN"] = 0.9,
	["Reload time increased"] = 0.9,
	["SET BONUS: move speed set bonus"] = 1.3,
}

-- if owner has these conds, apply them on the bot
-- used to replicate canteen effects
local REPLICATE_CONDS = {
	TF_COND_CRITBOOSTED_USER_BUFF,
	TF_COND_INVULNERABLE_USER_BUFF,
}

-- for making "sentry fire rate" upgrade replicate to bot as a different attribute
local SENTRY_FIRERATE_REPLICATE_ATTR = "halloween fire rate bonus" -- should be a unique attribute that isn't applied by anything else
local SENTRY_FIRERATE_REPLICATE_MULT = 1

-- we can't expect lua to do all the work - joshua graham
-- local BOT_SETUP_VSCRIPT = "activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(0.1)"
-- 16 -- disable dodge
local BOT_SETUP_VSCRIPT =
	"activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(100000); activator.AddBotAttribute(16)"
local BOT_DISABLE_VISION_VSCRIPT = "activator.SetDifficulty(0); activator.SetMaxVisionRangeOverride(0.1)"
local BOT_ENABLE_VISION_VSCRIPT = "activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(100000)"
local BOT_SET_WEPRESTRICTION_VSCRIPT = "activator.AddWeaponRestriction(%s)"
local BOT_CLEAR_RESTRICTIONS_VSCRIPT = "activator.ClearAllWeaponRestrictions()"

-- local BOT_CLEAR_FOCUS = "activator.ClearAttentionFocus()"

local BOT_ATTACK_VSCRIPT = "activator.PressFireButton(0.1)"

local activeBots = {} -- bots alive

local activeBuiltBots = {} -- bot built by player
local activeBuiltBotsOwner = {}

local lingeringBuiltBots = {}

local inWave = false

local PACK_ITEMS = {
	"item_currencypack_small",
	"item_currencypack_medium",
	"item_currencypack_large",
	"item_currencypack_custom",
}
-- delete cash dropped by bots that were built by players
-- due to inheriting TFBot's currency count
local function removeCashSafe(pack)
	pack:SetAbsOrigin(Vector(0, -100000, 0))
	local objectiveResource = ents.FindByClass("tf_objective_resource")

	local moneyBefore = objectiveResource.m_nMvMWorldMoney
	pack:Remove()
	local moneyAfter = objectiveResource.m_nMvMWorldMoney

	local packPrice = moneyBefore - moneyAfter
	-- print("price: "..tostring(packPrice))
	local mvmStats = ents.FindByClass("tf_mann_vs_machine_stats")

	local vscript =
		'NetProps.SetPropInt(activator, "%s.nCreditsDropped", NetProps.GetPropInt(activator, "%s.nCreditsDropped") - %s)'
	local curWave = "m_currentWaveStats"
	mvmStats:RunScriptCode(vscript:format(curWave, curWave, packPrice), mvmStats, mvmStats)
end

for _, packName in pairs(PACK_ITEMS) do
	ents.AddCreateCallback(packName, function(pack)
		local disablePickUp = pack:AddCallback(ON_SHOULD_COLLIDE, function()
			return false
		end)
		timer.Simple(0, function()
			-- failsafe for a glitch where spamming rebuild can very rarely drop cash
			if not inWave then
				removeCashSafe(pack)
				return
			end

			local handle = pack.m_hOwnerEntity:GetHandleIndex()

			if not lingeringBuiltBots[handle] then
				pack:RemoveCallback(disablePickUp)
				return
			end

			removeCashSafe(pack)

			lingeringBuiltBots[handle] = nil
		end)
	end)
end

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
		bot:ResetFakeSendProp("m_iTeamNum")
		bot.m_iTeamNum = 2
		-- bot:RemoveCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
		bot:SetAttributeValue("not solid to players", nil)
		bot:SetAttributeValue("ignored by enemy sentries", nil)
		bot:SetAttributeValue("ignored by bots", nil)
		bot:SetAttributeValue("damage bonus HIDDEN", nil)
	end
end

local function checkOnHit(parent, damageinfo)
	local attacker = damageinfo.Attacker

	if not attacker then
		return
	end

	local handle = attacker:GetHandleIndex()

	local owner = activeBuiltBotsOwner[handle]

	if not owner then
		return
	end

	if parent == owner then
		return
	end

	damageinfo.Attacker = owner

	return true
end

ents.AddCreateCallback("tank_boss", function(tank)
	tank:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageinfo)
		return checkOnHit(tank, damageinfo)
	end)
end)

-- convert damage dealt by bots to owner
-- and nullify damage taken by built bot during prewave
local function addGlobalCallbacks(player)
	player:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageinfo)
		local isBot = activeBots[player:GetHandleIndex()]
		if isBot and not inWave then
			-- nullify attacks in prewave
			damageinfo.Damage = 0
			damageinfo.Inflictor = nil
			damageinfo.Weapon = nil
			return true
		end

		return checkOnHit(player, damageinfo)
	end)

	-- failsafe for spawning bot in setup
	player:AddCallback(ON_SPAWN, function()
		if player:IsRealPlayer() then
			return
		end

		timer.Simple(0.1, function()
			if inWave then
				return
			end

			local owner = activeBuiltBots[player:GetHandleIndex()]

			if not owner then
				return
			end

			if player.m_iTeamNum == owner.m_iTeamNum then
				player:Suicide()
			end
		end)
	end)
end

function OnPlayerConnected(player)
	addGlobalCallbacks(player)
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

local function getCursorPos(player, bot)
	local eyeAngles = getEyeAngles(player)

	util.StartLagCompensation(player)
	local DefaultTraceInfo = {
		start = player,
		distance = 100000,
		angles = eyeAngles,
		mask = MASK_SHOT,
		collisiongroup = COLLISION_GROUP_PLAYER, --COLLISION_GROUP_DEBRIS,
		filter = { player, bot },
	}
	local trace = util.Trace(DefaultTraceInfo)
	util.FinishLagCompensation(player)
	return trace.HitPos
end

local function getMaxClip(bot)
	local clipBonusMult = bot:GetAttributeValueByClass("mult_clipsize", 1)
	local clipBonusAtomic = bot:GetAttributeValueByClass("mult_clipsize_upgrade_atomic", 0)

	return (4 * clipBonusMult) + clipBonusAtomic -- TODO: make this account for different classes other than soldier
end

local function applyName(bot, name, owner)
	local displayName = name .. " (" .. owner.m_szNetname .. ")"
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

	if data.MiniBoss then
		bot.m_bIsMiniBoss = 1
	else
		bot.m_bIsMiniBoss = 0
	end

	if data.Display then
		applyName(bot, data.Display, activeBuiltBotsOwner[bot:GetHandleIndex()])
	end
end

local function applyMaxHealthUpgrade(owner, bot)
	local pda = owner:GetPlayerItemBySlot(LOADOUT_POSITION_PDA)
	local healthBonusMult = pda:GetAttributeValue("engy building health bonus") or 1

	-- each upgrade gives 150 extra health
	local extraHealth = 150 * (healthBonusMult - 1)
	local curMaxHealthBuff = bot:GetAttributeValue("hidden maxhealth non buffed") or 0
	bot:SetAttributeValue("hidden maxhealth non buffed", curMaxHealthBuff + extraHealth)
end

local function applyDefaultData(owner, bot, class)
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

	applyMaxHealthUpgrade(owner, bot)
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

	bot:RefillAmmo()
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

local function applyBotTier(owner, bot, class, tier)
	if tier > 2 then
		removePreviousTier(bot, class, tier - 1)
	end

	local tierData = BOTS_VARIANTS[class].Tiers[tier]

	applyTierData(bot, tierData)

	applyMaxHealthUpgrade(owner, bot)
end

local function setupBot(bot, owner, handle, building)
	local callbacks = {}

	local botHandle = bot:GetHandleIndex()

	applyName(bot, "Soldier", owner)

	bot.m_iTeamNum = owner.m_iTeamNum

	bot.m_iszClassIcon = "" -- don't remove from wave on death

	for name, value in pairs(BOTS_ATTRIBUTES) do
		bot:SetAttributeValue(name, value)
	end

	owner.BuiltBotHandle = tostring(botHandle)
	owner.BuiltBotSentry = tostring(building:GetHandleIndex())

	activeBots[botHandle] = true
	activeBuiltBots[handle] = bot
	lingeringBuiltBots[botHandle] = true
	activeBuiltBotsOwner[botHandle] = owner

	-- callbacks.shouldCollide = bot:AddCallback(ON_SHOULD_COLLIDE, function(other, cause)
	-- 	if cause == ON_SHOULD_COLLIDE_CAUSE_FIRE_WEAPON then
	-- 		return
	-- 	end

	-- 	if not other:IsPlayer() then
	-- 		return
	-- 	end

	-- 	return false
	-- end)
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

		activeBots[botHandle] = nil
		activeBuiltBots[handle] = nil
		activeBuiltBotsOwner[botHandle] = nil

		bot:ResetFakeSendProp("m_iTeamNum")
		bot.m_iTeamNum = 1

		removeCallbacks(bot, callbacks)
		if IsValid(building) then
			building:Remove()
		end

		-- remove $tf_bot
		bot:Remove()
	end)

	return callbacks
end

-- local function findFreeBot()
-- 	local chosen

-- 	for _, bot in pairs(ents.GetAllPlayers()) do
-- 		if
-- 			not bot:IsRealPlayer()
-- 			and not bot:IsAlive()
-- 			and (bot.m_iTeamNum == 1 or bot.m_iTeamNum == 0)
-- 			and bot:GetPlayerName() ~= "Demo-Bot"
-- 		then
-- 			chosen = bot
-- 			break
-- 		end
-- 	end

-- 	return chosen
-- end

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

	if not bot then
		return
	end

	applyBotTier(activator, bot, "soldier", tier)
end

local function startBotConstruction(owner, building, bot)
	if not inWave then
		building.m_iHealth = building.m_iMaxHealth
		return
	end

	building.m_bBuilding = 1
	bot.m_iHealth = 1

	local botTier = getCurBotTier(owner) or 1
	local healthIncrement = 1

	if botTier >= 5 then
		healthIncrement = 3
	end

	bot:AddCond(TF_COND_MVM_BOT_STUN_RADIOWAVE, 50000)
	-- bot:StunPlayer(500000, 1, TF_STUNFLAG_NOSOUNDOREFFECT)

	local constructionTimer
	constructionTimer = timer.Create(0, function()
		if not IsValid(building) then
			timer.Stop(constructionTimer)
			return
		end

		building.m_bBuilding = 1

		bot.m_iHealth = bot.m_iHealth + healthIncrement

		building.m_iHealth = bot.m_iHealth

		local percent = building.m_iHealth / building.m_iMaxHealth
		building.m_flPercentageConstructed = percent

		building.m_bBuilding = 1

		if percent >= 1 then
			timer.Stop(constructionTimer)
			-- bot:RemoveCond(TF_COND_MVM_BOT_STUN_RADIOWAVE)
			bot:RemoveCond(TF_COND_STUNNED)
			building.m_bBuilding = 0
			return
		end
	end, 0)
end

function SentrySpawned(_, building)
	if not IsValid(building) then
		print("building was destroyed before logic could register lol")
		return
	end

	local owner = building.m_hBuilder
	local handle = owner:GetHandleIndex()

	local origin = building:GetAbsOrigin()

	local newBuilding = ents.CreateWithKeys("obj_sentrygun", {
		defaultupgrade = 0,
		team = owner.m_iTeamNum,
		SolidToPlayer = 0,
	}, true)

	newBuilding.m_bBuilding = 1

	building:Remove()
	newBuilding:SetBuilder(owner, owner, owner)

	newBuilding:SetAbsOrigin(Vector(0, 0, -10000))
	newBuilding:Disable()

	if activeBuiltBots[handle] and activeBuiltBots[handle]:IsAlive() then
		newBuilding:Remove()
		return
	end

	-- local botSpawn = findFreeBot()
	local botSpawn = Entity("$tf_bot")

	-- botSpawn["$Spawn"](botSpawn)

	if not botSpawn then
		owner:Print(PRINT_TARGET_CENTER, "GLOBAL BOT LIMIT REACHED")
		newBuilding:Remove()
		return
	end

	local callbacks = setupBot(botSpawn, owner, handle, newBuilding)

	timer.Simple(0, function()
		if not IsValid(newBuilding) then
			print("newBuilding was destroyed before logic could happen")
			botSpawn:Suicide()
			return
		end
		botSpawn:SetAbsOrigin(origin)
		botSpawn:SwitchClassInPlace("Soldier")

		local botTier = getCurBotTier(owner)

		if botTier and botTier > 1 then
			print("applying tier", botTier)
			applyBotTier(owner, botSpawn, "soldier", botTier)
		else
			applyDefaultData(owner, botSpawn, "soldier")
		end

		botSpawn:RunScriptCode(BOT_SETUP_VSCRIPT, botSpawn, botSpawn)

		-- botSpawn:RunScriptCode((BOT_SET_WEPRESTRICTION_VSCRIPT):format("0"), botSpawn, botSpawn)
		botSpawn:RunScriptCode(BOT_CLEAR_RESTRICTIONS_VSCRIPT, botSpawn, botSpawn)

		-- set max health
		newBuilding.m_iMaxHealth = botSpawn.m_iHealth

		local teleParticle = ents.CreateWithKeys("info_particle_system", {
			effect_name = botSpawn.m_iTeamNum == TEAM_RED and "teleportedin_red" or "teleportedin_blue",
			start_active = 1,
			flag_as_weather = 0,
		}, true, true)
		teleParticle:SetAbsOrigin(botSpawn:GetAbsOrigin())
		teleParticle:Start()
	
		timer.Simple(1, function ()
			teleParticle:Remove()
		end)

		startBotConstruction(owner, newBuilding, botSpawn)

		newBuilding:AddCallback(ON_REMOVE, function()
			if not activeBuiltBots[handle] then
				return
			end

			botSpawn:Suicide()
		end)

		if not inWave then
			botSpawn:SetFakeSendProp("m_iTeamNum", 2)
			botSpawn.m_iTeamNum = 1
			-- botSpawn:AddCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
			botSpawn:SetAttributeValue("not solid to players", 1)
			botSpawn:SetAttributeValue("ignored by enemy sentries", 1)
			botSpawn:SetAttributeValue("ignored by bots", 1)
			botSpawn:SetAttributeValue("damage bonus HIDDEN", 0.0001)
		end

		-- callbacks.spawned = botSpawn:AddCallback(ON_SPAWN, function()
		-- 	removeCallbacks(botSpawn, callbacks)
		-- 	if IsValid(newBuilding) then
		-- 		newBuilding:Remove()
		-- 	end
		-- end)
		local spawnedCallback
		spawnedCallback = botSpawn:AddCallback(ON_SPAWN, function()
			if IsValid(newBuilding) then
				newBuilding:Remove()
			end

			botSpawn:ResetFakeSendProp("m_iTeamNum")

			lingeringBuiltBots[handle] = nil

			botSpawn:RemoveCallback(spawnedCallback)
			spawnedCallback = nil
		end)

		local cursorPos = Vector(0, 0, 0)

		local lastWrangled = false

		botSpawn["$kickafterdeathdelay"] = 1

		-- bot behavior
		-- default behavior is always following you
		local logicLoop
		logicLoop = timer.Create(0.2, function()
			if not activeBuiltBots[handle] then
				timer.Stop(logicLoop)
				return
			end

			if not owner:IsAlive() then
				return
			end

			if owner:InCond(TF_COND_TAUNTING) then
				botSpawn["$Taunt"](botSpawn)
			end

			for _, cond in pairs(REPLICATE_CONDS) do
				if owner:InCond(cond) then
					botSpawn:AddCond(cond, 0.25, owner)
				end
			end

			local pda = owner:GetPlayerItemBySlot(LOADOUT_POSITION_PDA)
			local ownerFireRateUpgrade = pda:GetAttributeValue("engy sentry fire rate increased")

			if ownerFireRateUpgrade then
				botSpawn:SetAttributeValue(
					SENTRY_FIRERATE_REPLICATE_ATTR,
					ownerFireRateUpgrade * SENTRY_FIRERATE_REPLICATE_MULT
				)
			else
				botSpawn:SetAttributeValue(SENTRY_FIRERATE_REPLICATE_ATTR, nil)
			end

			local botWeapon = botSpawn.m_hActiveWeapon
			local botWeaponClip = botWeapon.m_iClip1
			if botWeaponClip then
				local maxClip = getMaxClip(botSpawn)
				local clipCalcMult = 150 / maxClip
				-- m_iAmmoShells max is 150
				newBuilding.m_iAmmoShells = botWeaponClip * clipCalcMult
			end

			if owner.m_hActiveWeapon.m_iClassname == "tf_weapon_laser_pointer" then
				-- wrangle behavior:
				-- if attack is held: fire weapon
				-- if alt fire is held: move toward cursor while attacking independently

				if not lastWrangled then
					-- botSpawn:BotCommand("stop interrupt action")

					botSpawn:RunScriptCode(BOT_DISABLE_VISION_VSCRIPT, botSpawn)
					botSpawn:AddCond(TF_COND_ENERGY_BUFF)

					for name, value in pairs(BOTS_WRANGLED_ATTRIBUTES) do
						botSpawn:SetAttributeValue(name, value)
					end

					lastWrangled = true
				end

				botSpawn:RunScriptCode("activator.ClearAttentionFocus()", botSpawn)

				local altFireHeld = owner.m_nButtons & IN_ATTACK2 ~= 0
				local attackHeld = owner.m_nButtons & IN_ATTACK ~= 0

				cursorPos = getCursorPos(owner, botSpawn)

				if attackHeld then
					botSpawn:RunScriptCode(BOT_ATTACK_VSCRIPT, botSpawn)
				end

				if altFireHeld then
					local interruptAction = ("interrupt_action -pos %s %s %s -distance 1 -duration 0.1"):format(
						cursorPos[1],
						cursorPos[2],
						cursorPos[3]
					)

					botSpawn:BotCommand(interruptAction)

					-- allow bot to attack when alt fire is held
					botSpawn:RunScriptCode(BOT_ENABLE_VISION_VSCRIPT, botSpawn)

					-- botSpawn:RemoveCond(TF_COND_ENERGY_BUFF)
					-- for name, _ in pairs(BOTS_WRANGLED_ATTRIBUTES) do
					-- 	botSpawn:SetAttributeValue(name, nil)
					-- end
				else
					botSpawn:RunScriptCode(BOT_DISABLE_VISION_VSCRIPT, botSpawn)

					-- botSpawn:AddCond(TF_COND_ENERGY_BUFF)
					-- for name, value in pairs(BOTS_WRANGLED_ATTRIBUTES) do
					-- 	botSpawn:SetAttributeValue(name, value)
					-- end
				end

				return
			end

			if lastWrangled then
				for name, _ in pairs(BOTS_WRANGLED_ATTRIBUTES) do
					botSpawn:SetAttributeValue(name, nil)
				end

				-- botSpawn:BotCommand("stop interrupt action")

				botSpawn:RunScriptCode(BOT_ENABLE_VISION_VSCRIPT, botSpawn)
				botSpawn:RemoveCond(TF_COND_ENERGY_BUFF)

				lastWrangled = false
			end

			local pos = owner:GetAbsOrigin()
			local distance = pos:Distance(botSpawn:GetAbsOrigin())

			if distance >= SPEED_BOOST_DISTANCE then
				botSpawn:AddCond(TF_COND_SPEED_BOOST, 1)
			end

			local stringStart = "interrupt_action -switch_action Default"

			-- don't move if already close
			if distance <= 150 then
				botSpawn:BotCommand(stringStart .. " -duration 0.1")
				return
			end

			local interruptAction = ("%s -pos %s %s %s -duration 0.1"):format(stringStart, pos[1], pos[2], pos[3])

			botSpawn:BotCommand(interruptAction)
		end, 0)

		local wranglerLogic
		wranglerLogic = timer.Create(0, function()
			if not activeBuiltBots[handle] then
				timer.Stop(wranglerLogic)
				return
			end

			if not owner.m_hActiveWeapon then
				return
			end

			if owner.m_hActiveWeapon.m_iClassname == "tf_weapon_laser_pointer" then
				-- wrangle behavior:
				-- if attack is held: fire weapon
				-- if alt fire is held: move toward cursor while attacking independently
				local altFireHeld = owner.m_nButtons & IN_ATTACK2 ~= 0

				cursorPos = getCursorPos(owner, botSpawn)

				if not altFireHeld then
					-- local interruptAction = ("interrupt_action -lookpos %s %s %s -alwayslook -duration 0.14"):format(
					-- 	cursorPos[1],
					-- 	cursorPos[2],
					-- 	cursorPos[3]
					-- )

					-- botSpawn:BotCommand(interruptAction)

					-- thanks mince
					local targetAngles = (cursorPos - (botSpawn:GetAbsOrigin() + Vector(
						0,
						0,
						botSpawn["m_vecViewOffset[2]"]
					))):ToAngles()
					targetAngles = Vector(targetAngles[1], targetAngles[2], 0)

					botSpawn:SnapEyeAngles(targetAngles)
				end

				return
			end
		end, 0)
	end)
end

AddEventCallback("player_used_powerup_bottle", function(eventTable)
	local netId = eventTable.player
	local canteenType = eventTable.type

	local AMMO_CANTEEN = 4

	local player = ents.GetAllPlayers()[netId]
	local bot = activeBuiltBots[player:GetHandleIndex()]

	if not bot then
		return
	end

	if canteenType == AMMO_CANTEEN then
		local botWeapon = bot.m_hActiveWeapon
		local botWeaponClip = botWeapon.m_iClip1
		if botWeaponClip then
			local maxClip = getMaxClip(bot)

			botWeapon.m_iClip1 = maxClip
		end
	end
end)

AddEventCallback("player_death", function(eventTable)
	local attacker = eventTable.attacker
	local player = ents.GetPlayerByUserId(attacker)

	local attackerBot = activeBuiltBots[player:GetHandleIndex()]

	if not attackerBot then
		return
	end

	local isBotKill = false

	local inflictor = Entity(eventTable.inflictor_entindex)

	if inflictor == attackerBot.m_hActiveWeapon then
		-- weapon
		isBotKill = true
	elseif inflictor.m_hLauncher then
		-- projectile
		local weaponOwner = inflictor.m_hLauncher.m_hOwnerEntity
		if weaponOwner == attackerBot then
			isBotKill = true
		end
	end

	if not isBotKill then
		return
	end

	local victim = Entity(eventTable.victim_entindex)

	local killAddition = 1

	if victim.m_bIsMiniBoss ~= 0 then
		killAddition = 5
	end

	local sentry = Entity(tonumber(player.BuiltBotSentry))
	sentry.m_iKills = sentry.m_iKills + killAddition
end)
