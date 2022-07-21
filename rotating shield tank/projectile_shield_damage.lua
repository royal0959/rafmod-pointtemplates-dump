local LEVELS_INFO = {
	[1] = {
		Damage = 3,
		Cooldown = 0.1
	},
	[2] = {
		Damage = 6,
		Cooldown = 0.1
	}
}

local registeredShields = {} --value is debounce players

function _register(shieldEnt, level, ownerTeamnum, activator)
	local handle = shieldEnt:GetHandleIndex()

	-- shieldEnt:AcceptInput("$SetKey$teamnum", ownerTeamnum)
	-- shieldEnt:AcceptInput("$SetKey$skin", ownerTeamnum == 3 and 1 or 2)

	registeredShields[handle] = {}

	shieldEnt:AddCallback(
		ON_REMOVE,
		function()
			registeredShields[handle] = nil
		end
	)

	local levelInfo = LEVELS_INFO[level]

	shieldEnt:AddCallback(
		ON_TOUCH,
		function(_, target, hitPos)
			if not target or not target:IsPlayer() then
				return
			end

			local visualHitPost = hitPos + Vector(0, 0, 50)

			local targetHandle = target:GetHandleIndex()

			local nextAllowedDamageTickOnTarget = registeredShields[handle][targetHandle] or -1

			if CurTime() < nextAllowedDamageTickOnTarget then
				return
			end

			local targetTeamnum = target:DumpProperties()["m_iTeamNum"]

			if targetTeamnum == ownerTeamnum then
				return
			end

			local damageInfo = {
				Attacker = activator or target,
				Inflictor = nil,
				Weapon = nil,
				Damage = levelInfo.Damage,
				DamageType = DMG_SHOCK,
				DamageCustom = 0,
				DamagePosition = visualHitPost,
				DamageForce = Vector(0, 0, 0),
				ReportedPosition = visualHitPost
			}

			local dmg = target:TakeDamage(damageInfo)

			registeredShields[handle][targetHandle] = CurTime() + levelInfo.Cooldown

			-- print("damage dealt " .. dmg)
		end
	)
end

function registerShieldLvl1(shieldEntName, activator)
	local shieldEnt = ents.FindByName(shieldEntName)

	local ownerTeamnum = activator:DumpProperties()["m_iTeamNum"]

	_register(shieldEnt, 1, ownerTeamnum, activator:IsBot() and activator)
end

function registerShieldLvl2(shieldEntName, activator)
	local shieldEnt = ents.FindByName(shieldEntName)

	local ownerTeamnum = activator:DumpProperties()["m_iTeamNum"]

	_register(shieldEnt, 2, ownerTeamnum, activator:IsBot() and activator)
end
