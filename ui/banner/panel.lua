-- ============================================================================
-- Nozmie - Banner UI Panel
-- Creates and manages the banner frame
-- ============================================================================

local Constants = require("utils.constants")
local BannerHelpers = require("ui.banner.helpers")

local BannerUI = {}

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

local function CreateButton(parent, size, point, textures, tooltip, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetPoint(unpack(point))

    if textures then
        if textures.normal or textures[1] then
            btn:SetNormalTexture(textures.normal or textures[1])
        end
        if textures.highlight then
            btn:SetHighlightTexture(textures.highlight)
        end
        if textures.pushed then
            btn:SetPushedTexture(textures.pushed)
        end
    end

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return btn
end

local function CreateBannerIcon(parent)
    local IconRenderer = _G.Nozmie_IconRenderer
    local iconFrame = IconRenderer.CreateIconFrame(parent, 32)
    iconFrame:SetPoint("LEFT", 4, 0)
    local texture = iconFrame.icon
    texture:SetSize(32, 32)
    IconRenderer.ApplyTooltip(iconFrame)
    return texture, iconFrame
end

local function CreateBannerText(parent, iconFrame)
    local title = parent:CreateFontString(nil, "OVERLAY")
    title:SetFontObject("SystemFont_Shadow_Large")
    title:SetFont(title:GetFont(), 14)
    title:SetPoint("LEFT", iconFrame, "RIGHT", -6, 8)
    title:SetTextColor(0.9, 0.9, 0.95)
    title:SetJustifyH("LEFT")
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)

    local subtitle = parent:CreateFontString(nil, "OVERLAY")
    subtitle:SetFontObject("GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", -40, 0)
    subtitle:SetText("|cff999999" .. Lstr("banner.clickToTeleport", "Click to teleport") .. "|r")
    subtitle:SetJustifyH("LEFT")
    subtitle:SetShadowColor(0, 0, 0, 1)
    subtitle:SetShadowOffset(1, -1)

    return title, subtitle
end

-- ============================================================================
-- Banner Factory
-- ============================================================================

function BannerUI.CreateBanner()
    local banner = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    banner:SetSize(Constants.BANNER_WIDTH, Constants.BANNER_HEIGHT)
    banner:SetFrameStrata("HIGH")
    banner:SetAttribute("type", "macro")
    banner:RegisterForClicks("AnyUp", "AnyDown")
    banner:SetMovable(true)
    banner:SetClampedToScreen(true)
    banner:SetUserPlaced(true)
    banner:EnableMouse(true)
    banner:SetClipsChildren(false)
    banner:Hide()

    banner:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    banner:SetBackdropColor(unpack(Constants.BANNER_COLORS.BACKDROP_NORMAL))
    banner:SetBackdropBorderColor(1, 0.85, 0.4, 0.9)

    local inner = banner:CreateTexture(nil, "BACKGROUND")
    inner:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    inner:SetPoint("TOPLEFT", 6, -6)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
    inner:SetVertexColor(1, 1, 1, 0.85)

    banner:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(Constants.BANNER_COLORS.BORDER_HOVER))
    end)
    banner:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(Constants.BANNER_COLORS.BORDER_NORMAL))
    end)

    local iconFrame
    banner.icon, iconFrame = CreateBannerIcon(banner)
    banner.title, banner.subtitle = CreateBannerText(banner, iconFrame)

    local dragButton = CreateButton(banner, 16, {"BOTTOMRIGHT", -10, 10}, {
        normal = "Interface\\Cursor\\UI-Cursor-Move",
        highlight = "Interface\\Cursor\\UI-Cursor-Move"
    }, Lstr("ui.dragToMove", "Drag to move"))
    if dragButton:GetHighlightTexture() then
        dragButton:GetHighlightTexture():SetAlpha(0.5)
    end
    dragButton:EnableMouse(true)
    dragButton:RegisterForDrag("LeftButton")
    dragButton:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            banner:StartMoving()
        end
    end)
    dragButton:SetScript("OnDragStop", function()
        banner:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = banner:GetPoint()
        banner:ClearAllPoints()
        banner:SetPoint(point or "CENTER", UIParent, relativePoint or "CENTER", xOfs or 0, yOfs or 0)
        BannerHelpers.SaveBannerPosition(banner)
    end)
    banner.dragButton = dragButton

    local announceBtn = CreateButton(banner, 16, {"TOPRIGHT", -34, -10}, {
        normal = "Interface\\Buttons\\UI-GuildButton-MOTD-Up",
        highlight = "Interface\\Buttons\\UI-GuildButton-MOTD-Highlight",
        pushed = "Interface\\Buttons\\UI-GuildButton-MOTD-Down"
    }, Lstr("ui.announce", "Announce"), function()
        if banner.HandleAnnounce then
            banner:HandleAnnounce()
        end
    end)
    banner.announceButton = announceBtn

    CreateButton(banner, 16, {"TOPRIGHT", -10, -10}, {
        normal = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        highlight = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
        pushed = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"
    }, Lstr("ui.close", "Close"), function()
        banner:Hide()
    end)

    banner:SetScript("OnShow", function(self)
        local Settings = _G.Nozmie_Settings
        local hide = Settings and Settings.Get and Settings.Get("hideDragIcon")
        if self.dragButton then
            if hide then self.dragButton:Hide() else self.dragButton:Show() end
        end
    end)

    BannerHelpers.LoadBannerPosition(banner)
    return banner
end

_G.Nozmie_BannerUI = BannerUI
return BannerUI