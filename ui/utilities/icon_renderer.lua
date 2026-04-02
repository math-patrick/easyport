local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

local IconRenderer = {}

function IconRenderer.CreateIconFrame(parent, iconSize)
    iconSize = iconSize or 36
    local frameSize = iconSize + 30
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(frameSize, frameSize)
    frame:SetClipsChildren(false)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetSize(frameSize, frameSize)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetAlpha(0.85)
    
    frame.icon = icon
    frame.border = border

    return frame
end

function IconRenderer.ApplyTooltip(iconFrame)
    iconFrame:EnableMouse(true)
    if iconFrame.nozmieTooltipHooked then
        return
    end

    iconFrame:SetScript("OnEnter", function(self)
        local parent = self:GetParent()
        local data = parent.nozmieTooltipData or parent.activeData or parent.data or parent.nozmieUnavailableData or
                         self.data
        if not data then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown = false
        if data.preferItem and data.itemID then
            shown = GameTooltip:SetItemByID(data.itemID)
        elseif data.spellID then
            shown = GameTooltip:SetSpellByID(data.spellID)
        elseif data.itemID then
            if data.actionType == "toy" then
                shown = GameTooltip:SetToyByItemID(data.itemID)
            else
                shown = GameTooltip:SetItemByID(data.itemID)
            end
        end

        if not shown then
            GameTooltip:SetText(data.spellName or data.name or Lstr("minimap.title", "Nozmie"))
            if data.destination then
                GameTooltip:AddLine(data.destination, 0.8, 0.8, 0.8)
            end
        end

        local keyText = self.nozmieKeystoneTooltipText or parent.nozmieKeystoneTooltipText
        if keyText and keyText ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(keyText, 0.98, 0.9, 0.35, true)
        end
        GameTooltip:Show()
    end)
    iconFrame.nozmieTooltipHooked = true

    iconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

_G.Nozmie_IconRenderer = IconRenderer
