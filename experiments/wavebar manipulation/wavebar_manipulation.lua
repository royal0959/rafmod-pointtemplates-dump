
print("here")

timer.Simple(0.1, function ()
    local objResource = ents.FindByClass("tf_objective_resource")

    if not objResource then
        print("no objResource. epic fail")
        return
    end

    objResource.m_nMannVsMachineWaveEnemyCount = 1000


    for i = 1, #objResource.m_nMannVsMachineWaveClassFlags do
        if i > 5 then
            break
        end
        local flag = 1
        if i > 3 then
            flag = 9
        end
        -- objResource:AcceptInput("$setprop$m_nMannVsMachineWaveClassFlags$" .. i - 1, flag)
        objResource.m_nMannVsMachineWaveClassFlags[i] = flag
        print(i, flag)
    end
    for i = 1, #objResource.m_iszMannVsMachineWaveClassNames do
        if i > 5 then
            break
        end

        local class = "scout"
        if i > 1 then
            class = "soldier"
        end
        if i > 3 then
            class = "soldier_barrage"
        end
        -- objResource:AcceptInput("$setprop$m_iszMannVsMachineWaveClassNames$" .. i - 1, "soldier_barrage")
        objResource.m_iszMannVsMachineWaveClassNames[i] = class
    end
    for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
        if i > 5 then
            break
        end
		-- objResource:AcceptInput("$setprop$m_nMannVsMachineWaveClassCounts$" .. i - 1, 1)
        objResource.m_nMannVsMachineWaveClassCounts[i] = 255
	end
	for i = 1, #objResource.m_bMannVsMachineWaveClassActive do
        if i > 5 then
            break
        end
		-- objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive$" .. i - 1, true)
        objResource.m_bMannVsMachineWaveClassActive[i] = true
	end
	for i = 1, #objResource.m_bMannVsMachineWaveClassActive2 do
        if i > 5 then
            break
        end
		-- objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive2$" .. i - 1, true)
        objResource.m_bMannVsMachineWaveClassActive2[i] = true
	end
end)

-- for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
-- 	objResource:AcceptInput("$setprop$m_nMannVsMachineWaveClassCounts$" .. i - 1, 1)
-- end
-- for i = 1, #objResource.m_bMannVsMachineWaveClassActive do
-- 	objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive$" .. i - 1, true)
-- end
-- for i = 1, #objResource.m_bMannVsMachineWaveClassActive2 do
-- 	objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive2$" .. i - 1, true)
-- end