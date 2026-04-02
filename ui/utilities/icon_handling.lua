local ConfigHelpers = _G.Nozmie_ConfigHelpers

local IconHandling = {}

function IconHandling.SetDesaturation(icon, isDesaturated)
    if icon and icon.SetDesaturated then
        icon:SetDesaturated(isDesaturated and true or false)
    end
end

function IconHandling.ApplyIcon(textureRegion, data)
    if not textureRegion or not data then
        return
    end

    local iconTexture = ConfigHelpers and ConfigHelpers.GetIconForEntry and ConfigHelpers.GetIconForEntry(data)
    if iconTexture then
        textureRegion:SetTexture(iconTexture)
    end
end

function IconHandling.GetActiveCooldown(data)
    if not data then
        return false, 0, 0, 0
    end

    local start, duration, enable = 0, 0, 0
    if data.itemID and C_Item and C_Item.GetItemCooldown then
        start, duration, enable = C_Item.GetItemCooldown(data.itemID)
    elseif data.spellID and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(data.spellID)
        if info then
            start = info.startTime or 0
            duration = info.duration or 0
            enable = (info.enable ~= nil and info.enable) or ((info.isEnabled == false) and 0 or 1)
        end
    end

    local remaining = 0
    if start and duration and start > 0 and duration > 0 then
        remaining = (start + duration) - GetTime()
    end
    local isOnCooldown = (enable and enable ~= 0 and duration and duration > 0 and remaining > 0) and true or false

    return isOnCooldown, start or 0, duration or 0, remaining or 0
end

function IconHandling.ApplyCooldownVisual(icon, cooldownFrame, cooldownText, data)
    local isOnCooldown, start, duration, remaining = IconHandling.GetActiveCooldown(data)

    IconHandling.SetDesaturation(icon, isOnCooldown)

    if cooldownFrame then
        if isOnCooldown then
            cooldownFrame:SetCooldown(start, duration)
            cooldownFrame:Show()
        else
            cooldownFrame:Hide()
        end
    end

    if cooldownText then
        if isOnCooldown and remaining > 0 then
            cooldownText:SetText(math.ceil(remaining))
            cooldownText:Show()
        else
            cooldownText:SetText("")
            cooldownText:Hide()
        end
    end

    return isOnCooldown, remaining
end

_G.Nozmie_IconHandling = IconHandling
