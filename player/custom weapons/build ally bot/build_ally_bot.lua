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
				Scale = 1.25,

				Items = { "Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Armored Authority" },

				HealthIncrease = 150,

				Attributes = {
					["damage bonus"] = 1.1,

					-- ["reload full clip at once"] = 1,
					["force fire full clip"] = 1,

					["faster reload rate"] = 0.6,
					["fire rate bonus"] = 0.1,
					["clip size upgrade atomic"] = 6.0,
					["Projectile speed increased"] = 0.65,
				},
			},
			[4] = {
				Display = "Rapid Fire Soldier",
				Scale = 1.55,

				Items = { "Upgradeable TF_WEAPON_ROCKETLAUNCHER", "Soldier Drill Hat" },

				HealthIncrease = 200,

				Attributes = {
					-- ["damage bonus"] = 1.25,

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

				Attributes = {
					["damage bonus"] = 1.5,
					["faster reload rate"] = 0.5,
					["fire rate bonus"] = 2,
					["Projectile speed increased"] = 0.5,

					["move speed bonus"] = 0.5,

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
local BOT_SETUP_VSCRIPT = "activator.SetDifficulty(3); activator.SetMaxVisionRangeOverride(100000)"
local BOT_DISABLE_VISION_VSCRIPT = "activator.SetMaxVisionRangeOverride(0.1)"
local BOT_ENABLE_VISION_VSCRIPT = "activator.SetMaxVisionRangeOverride(100000)"
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
for _, packName in pairs(PACK_ITEMS) do
	ents.AddCreateCallback(packName, function(pack)
		local disablePickUp = pack:AddCallback(ON_SHOULD_COLLIDE, function()
			return false
		end)
		timer.Simple(0, function()
			-- failsafe for a glitch where spamming rebuild can very rarely drop cash
			if not inWave then
				pack:Remove()
			end

			local handle = pack.m_hOwnerEntity:GetHandleIndex()

			if not lingeringBuiltBots[handle] then
				pack:RemoveCallback(disablePickUp)
				return
			end

			pack:SetAbsOrigin(Vector(0, -100000, 0))

			local objectiveResource = ents.FindByClass("tf_objective_resource")

			local moneyBefore = objectiveResource.m_nMvMWorldMoney
			pack:Remove()
			local moneyAfter = objectiveResource.m_nMvMWorldMoney

			local packPrice = moneyBefore - moneyAfter
			-- print("price: "..tostring(packPrice))
			local mvmStats = ents.FindByClass("tf_mann_vs_machine_stats")

			local vscript = "NetProps.SetPropInt(activator, \"%s.nCreditsDropped\", NetProps.GetPropInt(activator, \"%s.nCreditsDropped\") - %s)"
			local curWave = "m_currentWaveStats"
			mvmStats:RunScriptCode(vscript:format(curWave, curWave, packPrice), mvmStats, mvmStats)

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
local function addGlobalDamageCallback(player)
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
end

function OnPlayerConnected(player)
	addGlobalDamageCallback(player)
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
		collisiongroup = TFCOLLISION_GROUP_ROCKETS, --COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)
	return trace.HitPos
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

	applyBotTier(bot, "soldier", tier)
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
			applyBotTier(botSpawn, "soldier", botTier)
		else
			applyDefaultData(botSpawn, "soldier")
		end

		botSpawn:RunScriptCode(BOT_SETUP_VSCRIPT, botSpawn, botSpawn)

		-- botSpawn:RunScriptCode((BOT_SET_WEPRESTRICTION_VSCRIPT):format("0"), botSpawn, botSpawn)
		botSpawn:RunScriptCode(BOT_CLEAR_RESTRICTIONS_VSCRIPT, botSpawn, botSpawn)

		-- set max health
		newBuilding.m_iMaxHealth = botSpawn.m_iHealth
		newBuilding.m_iHealth = botSpawn.m_iHealth

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

			for _, cond in pairs(REPLICATE_CONDS) do
				if owner:InCond(cond) ~= 0 then
					botSpawn:AddCond(cond, 0.25, owner)
				end
			end

			local pda = owner:GetPlayerItemBySlot(LOADOUT_POSITION_PDA)
			local ownerFireRateUpgrade = pda:GetAttributeValue("engy sentry fire rate increased")

			if ownerFireRateUpgrade then
				botSpawn:SetAttributeValue(SENTRY_FIRERATE_REPLICATE_ATTR, ownerFireRateUpgrade * SENTRY_FIRERATE_REPLICATE_MULT)
			else
				botSpawn:SetAttributeValue(SENTRY_FIRERATE_REPLICATE_ATTR, nil)
			end

			local botWeapon = botSpawn.m_hActiveWeapon
			local botWeaponClip = botWeapon.m_iClip1
			if botWeaponClip then
				local clipBonusMult = botSpawn:GetAttributeValueByClass("mult_clipsize", 1)
				local clipBonusAtomic = botSpawn:GetAttributeValueByClass("mult_clipsize_upgrade_atomic", 0)
		
				local maxClip = (4 * clipBonusMult) + clipBonusAtomic -- TODO: make this account for different classes other than soldier
				local clipCalcMult = 150 / maxClip
				-- m_iAmmoShells max is 150
				newBuilding.m_iAmmoShells = botWeaponClip * clipCalcMult
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
					cursorPos[1],
					cursorPos[2],
					cursorPos[3]
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

			local pos = owner:GetAbsOrigin()

			local stringStart = "interrupt_action"

			-- don't move if already close
			if pos:Distance(botSpawn:GetAbsOrigin()) <= 150 then
				botSpawn:BotCommand(stringStart .. " -duration 0.1")
				return
			end

			local interruptAction = ("%s -pos %s %s %s -duration 0.1"):format(stringStart, pos[1], pos[2], pos[3])

			botSpawn:BotCommand(interruptAction)
		end, 0)
	end)
end
