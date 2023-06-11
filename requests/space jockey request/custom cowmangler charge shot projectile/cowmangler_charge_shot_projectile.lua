ents.AddCreateCallback("tf_projectile_energy_ball", function(ent)
	timer.Simple(0, function ()
		if not IsValid(ent) then
			return
		end

		if ent.m_bChargedShot == 0 then
			return
		end

		local owner = ent.m_hOwnerEntity

		local mimic = ents.CreateWithKeys("tf_point_weapon_mimic", {
			["$preventshootparent"] = 1,

			TeamNum = owner.m_iTeamNum,
			-- edit the custom weapon to change projectile
			["$weaponname"] = "CUSTOM_CHARGE_SHOT",
		}, true, true)

		mimic["$SetOwner"](mimic, owner)
		mimic:SetAbsAngles(ent:GetAbsAngles())
		mimic:SetAbsOrigin(ent:GetAbsOrigin())

		ent:Remove()

		mimic:FireOnce()
		mimic:Remove()
	end)
end)