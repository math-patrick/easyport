local IconRenderer = _G.Nozmie_IconRenderer

local Button = {}

function Button.Create(parent, iconSize, rowHeight)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(1, rowHeight)
    button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    if button:GetHighlightTexture() then
        button:GetHighlightTexture():SetBlendMode("ADD")
        button:GetHighlightTexture():SetAllPoints(button)
        button:GetHighlightTexture():SetVertexColor(1, 0.82, 0.35, 0.28)
        button:GetHighlightTexture():SetAlpha(0.45)
    end
    button:SetClipsChildren(false)

    button.rowBg = button:CreateTexture(nil, "BACKGROUND")
    button.rowBg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.rowBg:SetBlendMode("ADD")
    button.rowBg:SetAllPoints(button)
    button.rowBg:SetVertexColor(1, 0.82, 0, 0.055)
    button.rowBg:Hide()

    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.accent:SetBlendMode("ADD")
    button.accent:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.accent:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    button.accent:SetHeight(rowHeight)
    button.accent:SetVertexColor(1, 0.82, 0, 0.075)
    button.accent:Hide()

    local iconFrame = IconRenderer.CreateIconFrame(button, iconSize)
    iconFrame:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.icon = iconFrame.icon
    
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.name:SetFontObject("GameFontNormal")
    button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 12, -2)
    button.name:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.name:SetJustifyH("LEFT")
    
    button.category = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.category:SetFontObject("GameFontHighlightSmall")
    button.category:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -4)
    button.category:SetPoint("RIGHT", button.name, "RIGHT", 0, 0)
    button.category:SetJustifyH("LEFT")
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:Hide()
    button.cooldownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.cooldownText:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
    button.cooldownText:SetText("")
    button.cooldownText:Hide()

    IconRenderer.ApplyTooltip(button)

    button:HookScript("OnEnter", function(self)
        if self.rowBg then self.rowBg:Show() end
        if self.accent then self.accent:Show() end
    end)

    button:HookScript("OnLeave", function(self)
        if self.rowBg then self.rowBg:Hide() end
        if self.accent and not self.nozmieFavouriteVisual then self.accent:Hide() end
    end)
    
    return button
end

_G.Nozmie_UtilityButton = Button
