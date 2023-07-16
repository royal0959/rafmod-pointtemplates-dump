local canteens = {
	{
		-- Name of canteen to display in chat when using
		Display = "SPEED BOOST",
		-- Any attribute, should be one that has no effect
		Attribute = "mvm completed challenges bitmask",
		-- Custom item description to apply to the canteen
		Description = "Consumable: Gain a speed boost for 5 seconds",
		-- Effect function
		Effect = function(activator)
			activator:AddCond(TF_COND_SPEED_BOOST, 5, activator)
		end
	},
	{
		Display = "BULLET RESIST",
		Attribute = "throwable fire speed",
		Description = "Consumable: Gain resistance to bullets for 5 seconds",
		Effect = function(activator)
			activator:AddCond(TF_COND_MEDIGUN_UBER_BULLET_RESIST, 5, activator)
		end
	},
	-- TODO: finish this
	{
		Display = "REPROGRAM",
		Attribute = "throwable damage",
		Description = "Consumable: Reprogram nearby non-giant robots to fight for you for 8 seconds",
		Effect = function(activator)
			local RANGE = 30
			
		end
	},
}

for _, canteen in pairs(canteens) do
	table.insert(CUSTOM_CANTEENS, canteen)
end