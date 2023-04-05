
timer.Simple(5, function ()
    local spyChosen = 0
    timer.Create(0, function ()
        spyChosen = spyChosen + 1

        local objResource = ents.FindByClass("tf_objective_resource")
    
        if not objResource then
            print("no objResource. epic fail")
            return
        end
    
        objResource.m_nMannVsMachineWaveEnemyCount = 1000

        local icon = "scout"

        if spyChosen >= 4 then
            icon = "spy"
            spyChosen = 0
        end
        for i = 1, #objResource.m_iszMannVsMachineWaveClassNames do
            if objResource.m_nMannVsMachineWaveClassFlags[i] == 4 then
                objResource.m_iszMannVsMachineWaveClassNames[i] = icon
            end
        end
        for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
            objResource.m_nMannVsMachineWaveClassCounts[i] = 255
        end
        for i = 1, #objResource.m_bMannVsMachineWaveClassActive do
            -- objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive$" .. i - 1, true)
            objResource.m_bMannVsMachineWaveClassActive[i] = true
        end
        for i = 1, #objResource.m_bMannVsMachineWaveClassActive2 do
            -- objResource:AcceptInput("$setprop$m_bMannVsMachineWaveClassActive2$" .. i - 1, true)
            objResource.m_bMannVsMachineWaveClassActive2[i] = true
        end
    end, 0)
end)