local RAGE_DURATION = 10
local UPDATE_INTERVAL = 0.015

local knockbackHandles = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function applyKnockbackRageEffect(activator)
    activator:AddCond(11)
end

local function removeKnockbackRageEffect(activator)
    activator:RemoveCond(11)
end

function KnockbackRageStart(_, activator)
    local handleIndex = activator:GetHandleIndex()

    local draining = false
    local fakeMeter = 0
    local meterLerp = 0

    knockbackHandles[handleIndex] = timer.Create(UPDATE_INTERVAL, function ()
        if not IsValid(activator) then
            KnockbackRageStop(nil, activator)
            return
        end

        if draining then
            -- fakeMeter = math.max(fakeMeter - (UPDATE_INTERVAL * RAGE_DURATION) * 10, 0)
            meterLerp = meterLerp + (UPDATE_INTERVAL / RAGE_DURATION * 2)
            fakeMeter = math.max(100 - lerp(0, 100, meterLerp), 0)

            activator:SetFakeSendProp("m_flRageMeter", fakeMeter)

            if fakeMeter <= 0 then
                activator:GetPlayerItemBySlot(LOADOUT_POSITION_PRIMARY):SetAttributeValue("increase buff duration HIDDEN", nil)
                activator:ResetFakeSendProp("m_bRageDraining")
                activator:ResetFakeSendProp("m_flRageMeter")
                activator.m_flRageMeter = 0

                fakeMeter = 0
                meterLerp = 0
                draining = false

                removeKnockbackRageEffect(activator)
            end

            return
        end

        if activator.m_bRageDraining == 0 then
            return
        end

        activator:GetPlayerItemBySlot(LOADOUT_POSITION_PRIMARY):SetAttributeValue("increase buff duration HIDDEN", 100)
        activator:SetFakeSendProp("m_bRageDraining", 1)
        activator.m_bRageDraining = 0
        activator.m_flRageMeter = -100000
        fakeMeter = 100
        meterLerp = 0
        draining  = true

        applyKnockbackRageEffect(activator)
    end, 0)
end

function KnockbackRageStop(_, activator)
    activator:ResetFakeSendProp("m_bRageDraining")
    activator:ResetFakeSendProp("m_flRageMeter")
    local handleIndex = activator:GetHandleIndex()

    timer.Stop(knockbackHandles[handleIndex])
    knockbackHandles[handleIndex] = nil
end