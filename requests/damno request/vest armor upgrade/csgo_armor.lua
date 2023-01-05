local BASE_ARMOR = 100

local armoredPlayers = {} -- handle indices
local gameTexts = {}

local armorMessage = "Armor %s"

local function makeGameText(activator)
    local gametext = ents.CreateWithKeys("game_text", {
        color = "255 255 255",
        channel = 4,
        holdtime = 198444444,
        effect = 0,
        fadein = 0,
        message = armorMessage:format("100"),
        X = 0.35,
        Y = 0.8
    }, true, true)

    gametext:SetParent(activator)
    gametext:AcceptInput("Display", true, activator)

    return gametext
end

local function setText(gametext, newMessage, activator)
    gametext:AddOutput("message " .. newMessage)
    gametext:AcceptInput("Display", true, activator)
end

local function addGlobalDamageCallback(player)
	player:AddCallback(ON_DAMAGE_RECEIVED_PRE, function(_, damageinfo)
        local handleIndex = player:GetHandleIndex()
        local remainingArmor = armoredPlayers[handleIndex]

        -- not armored
        if not remainingArmor then
            return
        end

        -- don't use armor while ubered
        if player:InCond(TF_COND_INVULNERABLE) ~= 0 or player:InCond(TF_COND_INVULNERABLE_USER_BUFF) ~= 0 then
            return
        end

        local damage = damageinfo.Damage
        local damageType = damageinfo.DamageType

        local reducedDamage
        if damageType ~= "DMG_CRITICAL" then
            reducedDamage = damage * 0.5
        else
            reducedDamage = damage * 0.25
        end

        -- print("Old damage: "..tostring(damageinfo.Damage).."    ".."New damage: "..tostring(reducedDamage))

        damageinfo.Damage = reducedDamage

        armoredPlayers[handleIndex] = math.floor(remainingArmor - reducedDamage)
        -- print("Armor: "..tostring(armoredPlayers[handleIndex]))
        -- no more armor
        if armoredPlayers[handleIndex] <= 0 then
            print("armor broke")
            armoredPlayers[handleIndex] = nil

            setText(gameTexts[handleIndex], "", player)
            gameTexts[handleIndex]:Remove()
            gameTexts[handleIndex] = nil
            -- allow repurchase
            player:SetAttributeValue("never craftable", nil)

            return true
        end

        setText(gameTexts[handleIndex], armorMessage:format(tostring(armoredPlayers[handleIndex])), player)

		return true
	end)
end

function OnPlayerConnected(player)
	addGlobalDamageCallback(player)
end

-- prevents memory leak
function OnPlayerDisconnected(player)
    armoredPlayers[player:GetHandleIndex()] = nil
end

function ArmorBought(_, activator)
    print("armor purchased")
    local index = activator:GetHandleIndex()
    armoredPlayers[index] = BASE_ARMOR

    timer.Simple(1, function ()
        gameTexts[index] = makeGameText(activator)
    end)
end

function ArmorRemoved(_, activator)
    print("armor refunded")
    local index = activator:GetHandleIndex()
    armoredPlayers[index] = nil
    setText(gameTexts[index], "", activator)
    gameTexts[index]:Remove()
    gameTexts[index] = nil
end