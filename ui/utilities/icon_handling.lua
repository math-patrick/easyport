local ConfigHelpers = _G.Nozmie_ConfigHelpers

local IconHandling = {}

local function getItemCooldown(itemID)
    if not itemID then
        return 0, 0, 0
    end

    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
    end

    if _G.GetItemCooldown then
        return _G.GetItemCooldown(itemID)
    end

    return 0, 0, 0
end

local function getSpellCooldown(spellID)
    if not spellID then
        return 0, 0, 0
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            local enable = (info.enable ~= nil and info.enable) or ((info.isEnabled == false) and 0 or 1)
            return info.startTime or 0, info.duration or 0, enable
        end
    end

    if _G.GetSpellCooldown then
        return _G.GetSpellCooldown(spellID)
    end

    return 0, 0, 0
end

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
    if data.itemID then
        start, duration, enable = getItemCooldown(data.itemID)
    elseif data.spellID then
        start, duration, enable = getSpellCooldown(data.spellID)
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
