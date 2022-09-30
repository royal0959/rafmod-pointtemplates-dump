local function weaponMimic(properties)
	local mimic = Entity("tf_point_weapon_mimic")
	mimic:SetAbsOrigin(properties.Origin)
	mimic:SetAbsAngles(properties.Angles)

	return mimic
end

local SPELLS = {
	[1] = {
		Name = "Kritz",
		Description = "Grants Kritz to the caster for 3 seconds",
		Charges = 1,

		FakeIconIndex = 2, -- heal spell

		Func = function (player)
			player:AddCond(37, 3)
		end,
	},

	[2] = {
		Name = "Giant",
		Description = "Becomes giant for 8 seconds",
		Charges = 1,

		FakeIconIndex = 8, -- minify spell

		Func = function (player)
			player:AddCond(74, 8)
		end,
	},

	[3] = {
		Name = "Rocket",
		Description = "Fires a rocket",
		Charges = 10,

		FakeIconIndex = 0, -- fireball

		Func = function (player, projectileProperties)
			local mimic = weaponMimic(projectileProperties)

			mimic:AcceptInput("$SetOwner", player)

			local properties = {
				["TeamNum"] = player.m_iTeamNum,
				["WeaponType"] = 0, -- rocket

				["SpeedMax"] = 700,
				["SpeedMin"] = 700,

				["SplashRadius"] = 146,
				["Damage"] = 90,
			}

			for propName, value in pairs(properties) do
				mimic:AcceptInput("$SetKey$"..propName, value)
			end

			mimic:AcceptInput("FireOnce")

			mimic:Remove()
		end,
	},
}

local players = {}
local activePlayers = {} -- players with an active custom spell, used for quick index

local timerLoops = {}

function RemoveTimerLoops(player)
	local handle = player:GetHandleIndex()

	if not timerLoops[handle] then
		return
	end

	for _, id in pairs(timerLoops[handle]) do
		timer.Stop(id)
	end
end

function CastCustomSpell(player, data, projectileProperties)
	local handle = player:GetHandleIndex()

	local spellbook = player:GetPlayerItemBySlot(9)

	data.Charges = data.Charges - 1

	if data.Charges <= 0 then
		players[handle] = nil
		player:AcceptInput("$RemoveItemAttribute", "special item description|9")
		spellbook:ResetFakeSendProp("m_iSelectedSpellIndex")
	end

	SPELLS[data.Index].Func(player, projectileProperties)
end

function SetCustomSpell(player, customSpellIndex)
	local handle = player:GetHandleIndex()

	local spellData = SPELLS[customSpellIndex]
	
	local charges = spellData.Charges
	
	--action slot
	local spellbook = player:GetPlayerItemBySlot(9)

	if spellData.FakeIconIndex then
		-- set fake icon
		spellbook:SetFakeSendProp("m_iSelectedSpellIndex", spellData.FakeIconIndex)
	end
	
	-- set spell book description
	local spellDescriptionString = "Spell: "..spellData.Name.." - "..spellData.Description
	player:AcceptInput("$AddItemAttribute", "special item description|"..spellDescriptionString.."|9")

	spellbook:AcceptInput("$SetProp$m_iSelectedSpellIndex", "0")
	spellbook:AcceptInput("$SetProp$m_iSpellCharges", tostring(charges))

	players[handle] = { Index = customSpellIndex, Charges = charges }
end

-- detect when fireballs spawned and check if the caster is using a custom spell
-- if they are, that means this fireball should be overriden with the custom spell's effect
ents.AddCreateCallback("tf_projectile_spellfireball", function(entity)
	timer.Simple(0, function()
		local owner = entity.m_hOwnerEntity

		local customSpellData = players[owner:GetHandleIndex()]

		if not owner or not customSpellData then
			return
		end

		local properties = {
			Origin = entity:GetAbsOrigin(),
			Angles = entity:GetAbsAngles()
		}
		entity:Remove()

		CastCustomSpell(owner, customSpellData, properties)
	end)
end)

function OnPlayerConnected(player)
	if not player:IsRealPlayer() then
		return
	end

	local handle = player:GetHandleIndex()

	timerLoops[handle] = {}

	-- on death
	player:AddCallback(9, function()
		activePlayers[handle] = nil
		RemoveTimerLoops(player)
	end)

	-- on spawn
	player:AddCallback(1, function()
		local spellbook = player:GetPlayerItemBySlot(9)

		if spellbook.m_iClassname ~= "tf_weapon_spellbook" then
			RemoveTimerLoops(player)
			return
		end

		activePlayers[handle] = true

		-- placeholder
		SetCustomSpell(player, 3)

		-- timerLoops[handle][1] = timer.Create(0.2, function()
		-- 	local props = player:DumpProperties()

		-- 	if props.m_bUsingActionSlot ~= 1 then
		-- 		return
		-- 	end

		-- 	CustomSpellUsed(player)
		-- end, 0)
	end)
end

function OnPlayerDisconnected(player)
	if not player:IsRealPlayer() then
		return
	end

	local handle = player:GetHandleIndex()

	players[handle] = nil
	activePlayers[handle] = nil
end
