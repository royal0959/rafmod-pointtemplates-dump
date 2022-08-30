local SPELL_GEN_INTERVAL = 5
local CHARGES = 6

local POSSIBLE_COMMONS = {
	"Fireball",
	"Ball O' Bats",
}

local POSSIBLE_RARES = {
	"Summon Monoculus",
	"Meteor Shower",
	"Summon Skeletons",
}

function SpellGenerator(rareWeight, activator)
	local timerId = false
	local callbacks = {}

	local function stopGenerator()
		timer.Stop(timerId)
		for _, id in pairs(callbacks) do
			activator:RemoveCallback(id)
		end
	end

	local function addSpell(chosenSpell)
		for _ = 1, CHARGES do
			activator:AddSpell(chosenSpell)
		end
	end

	timerId = timer.Create(SPELL_GEN_INTERVAL, function ()
		if not activator:IsAlive() then
		-- 	stopGenerator()
			return
		end

		local gen = math.random(1, 100)

		if gen <= tonumber(rareWeight) then
			local chosenSpell = POSSIBLE_RARES[math.random(#POSSIBLE_RARES)]
			print(chosenSpell)
			addSpell(chosenSpell)
		else
			local chosenSpell = POSSIBLE_COMMONS[math.random(#POSSIBLE_COMMONS)]
			print(chosenSpell)
			addSpell(chosenSpell)
		end
	end, 0)

	callbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		stopGenerator()
	end)
	callbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		stopGenerator()
	end)
end