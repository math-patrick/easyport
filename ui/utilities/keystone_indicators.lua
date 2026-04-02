-- ============================================================================
-- Nozmie - Keystone Indicator Visuals
-- Glow, badge, and ring effects on utility buttons for keystone ownership
-- ============================================================================

local Keystones = require("features.keystones")

local KeystoneIndicators = {}

-- ============================================================================
-- Internal
-- ============================================================================

local function IsEnabled()
    local Settings = _G.Nozmie_Settings
    if Settings and Settings.Get then
        return Settings.Get("showKeystoneIndicators") ~= false
    end
    return true
end

local function EnsureVisuals(button)
    if not button or not button.icon then return end

    if not button.nozmieKeyBackGlow then
        local glow = button:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
        glow:SetSize(60, 60)
        glow:SetAlpha(0)
        button.nozmieKeyBackGlow = glow
    end

    if not button.nozmieKeyLayer then
        local layer = CreateFrame("Frame", nil, button)
        layer:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 0, 0)
        layer:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0, 0)
        if button.cooldown and button.cooldown.GetFrameLevel then
            layer:SetFrameLevel((button.cooldown:GetFrameLevel() or button:GetFrameLevel()) + 3)
        else
            layer:SetFrameLevel((button:GetFrameLevel() or 1) + 8)
        end
        button.nozmieKeyLayer = layer
    end

    if not button.nozmieKeyGlow then
        local glow = button.nozmieKeyLayer:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
        glow:SetSize(54, 54)
        glow:SetAlpha(0)
        button.nozmieKeyGlow = glow
    end

    if not button.nozmieKeyBadge then
        local badge = button.nozmieKeyLayer:CreateTexture(nil, "OVERLAY")
        badge:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
        badge:SetSize(12, 12)
        badge:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 2, -2)
        badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        badge:SetAlpha(0)
        button.nozmieKeyBadge = badge
    end

    if not button.nozmieKeyBadgeRing then
        local ring = button.nozmieKeyLayer:CreateTexture(nil, "OVERLAY")
        ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        ring:SetSize(18, 18)
        ring:SetPoint("CENTER", button.nozmieKeyBadge, "CENTER", 0, 0)
        ring:SetAlpha(0)
        button.nozmieKeyBadgeRing = ring
    end
end

local function Reset(button)
    if not button then return end
    if button.nozmieKeyBackGlow  then button.nozmieKeyBackGlow:SetAlpha(0)  end
    if button.nozmieKeyGlow      then button.nozmieKeyGlow:SetAlpha(0)      end
    if button.nozmieKeyBadge     then button.nozmieKeyBadge:SetAlpha(0)     end
    if button.nozmieKeyBadgeRing then button.nozmieKeyBadgeRing:SetAlpha(0) end
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Apply or remove keystone ownership indicator on a single button.
function KeystoneIndicators.Apply(button, entry)
    if not button then return end

    button.nozmieKeystoneTooltipText = nil
    EnsureVisuals(button)

    if not IsEnabled() then Reset(button); return end

    local ownership = Keystones.GetKeystoneOwnershipForEntry(entry)
    if not ownership then Reset(button); return end

    button.nozmieKeystoneTooltipText = Keystones.GetKeystoneOwnerTooltipText(entry)

    local isOwn = ownership == "own"
    if button.nozmieKeyBackGlow then
        button.nozmieKeyBackGlow:SetVertexColor(isOwn and 1 or 0.65, isOwn and 0.78 or 0.88, isOwn and 0.24 or 1, 1)
        button.nozmieKeyBackGlow:SetAlpha(0.14)
    end
    if button.nozmieKeyBadge then
        button.nozmieKeyBadge:SetVertexColor(isOwn and 1 or 0.78, isOwn and 0.86 or 0.92, isOwn and 0.22 or 1, 1)
        button.nozmieKeyBadge:SetAlpha(1)
    end
    if button.nozmieKeyBadgeRing then button.nozmieKeyBadgeRing:SetAlpha(0.68) end
    if button.nozmieKeyGlow then
        button.nozmieKeyGlow:SetVertexColor(isOwn and 1 or 0.65, isOwn and 0.76 or 0.85, isOwn and 0.22 or 1, 1)
        button.nozmieKeyGlow:SetAlpha(0.22)
    end
end

-- Refresh indicators for all shown M+ buttons in the pool.
-- Pass dungeonID to update only buttons matching that dungeon; nil refreshes all.
function KeystoneIndicators.RefreshAll(buttons, dungeonID)
    if not buttons then return end

    local filterMapName
    if dungeonID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        filterMapName = C_ChallengeMode.GetMapUIInfo(tonumber(dungeonID))
        if type(filterMapName) == "string" then filterMapName = filterMapName:lower() end
    end

    for _, button in ipairs(buttons) do
        if button:IsShown() and button.nozmieTooltipData and button.nozmieTooltipData.category == "M+ Dungeon" then
            local entry = button.nozmieTooltipData
            if not filterMapName or (entry.name and entry.name:lower() == filterMapName) then
                KeystoneIndicators.Apply(button, entry)
            end
        end
    end
end

_G.Nozmie_KeystoneIndicators = KeystoneIndicators
return KeystoneIndicators
