-- ============================================================================
-- Nozmie - Banner Controller
-- Manages banner lifecycle, stacking, and display logic
-- ============================================================================
local Constants = require("utils.constants")
local Helpers = require("utils.helpers")
local Messaging = require("utils.messaging")
local Cooldowns = require("features.cooldowns")

local BannerController = {}
local RefreshBannerDisplay

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

-- ============================================================================
-- State
-- ============================================================================

local STACK_GAP = 8
local lastOptions
local trackedBanners = {}
local combatWatcher

-- ============================================================================
-- Combat State Management
-- ============================================================================

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function SetBannerInteractiveState(banner, enabled)
    if not banner then
        return
    end
    banner:EnableMouse(enabled)
    if banner.leftArrow then
        banner.leftArrow:EnableMouse(enabled)
    end
    if banner.rightArrow then
        banner.rightArrow:EnableMouse(enabled)
    end
    if banner.announceButton then
        banner.announceButton:EnableMouse(enabled)
    end
    if banner.dragButton then
        banner.dragButton:EnableMouse(enabled)
    end
end

local function CancelBannerAutoHideTimer(banner)
    if banner and banner.autoHideTimer then
        banner.autoHideTimer:Cancel()
        banner.autoHideTimer = nil
    end
end

local function StartBannerAutoHideTimer(banner)
    local Settings = _G.Nozmie_Settings
    if not banner or not Settings or not Settings.Get or not Settings.Get("autoHideBanner") then
        return
    end

    CancelBannerAutoHideTimer(banner)

    local timeout = Settings.Get("bannerTimeout") or 10
    banner.autoHideTimer = C_Timer.NewTimer(timeout, function()
        if banner:IsShown() and not banner.isOnCooldown and not IsCombatLocked() then
            UIFrameFadeOut(banner, 0.3, 1, 0)
            C_Timer.After(0.3, function()
                banner:Hide()
                if banner.updateTimer then
                    banner.updateTimer:Cancel()
                end
            end)
        end
    end)
end

local function ApplyBannerCombatState(banner)
    if not banner or not banner:IsShown() then
        return
    end
    if IsCombatLocked() then
        SetBannerInteractiveState(banner, false)
        banner:SetAlpha(0)
        banner.nozmieCombatHidden = true
        CancelBannerAutoHideTimer(banner)
    else
        SetBannerInteractiveState(banner, true)
        if banner.nozmieCombatHidden then
            banner:SetAlpha(1)
            banner.nozmieCombatHidden = false
            StartBannerAutoHideTimer(banner)
        end
    end
end

local function RefreshTrackedBannerCombatState()
    for banner in pairs(trackedBanners) do
        if banner and banner:IsShown() then
            ApplyBannerCombatState(banner)
        end
    end
end

local function EnsureCombatWatcher()
    if combatWatcher then
        return
    end
    combatWatcher = CreateFrame("Frame")
    combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatWatcher:SetScript("OnEvent", RefreshTrackedBannerCombatState)
end

-- ============================================================================
-- Options Key Hashing
-- ============================================================================

local function GetOptionKey(data)
    local target = data.targetPlayer and ("@" .. data.targetPlayer) or ""
    if data.spellID then
        return "spell:" .. data.spellID .. target
    end
    if data.itemID then
        return "item:" .. data.itemID .. target
    end
    return "name:" .. tostring(data.name or data.spellName or "") .. target
end

local function BuildOptionsKey(options)
    if not options or #options == 0 then
        return ""
    end
    local keys = {}
    for _, data in ipairs(options) do
        table.insert(keys, GetOptionKey(data))
    end
    table.sort(keys)
    return table.concat(keys, "|")
end

local function GetBannerOptionsKey(banner)
    if not banner then
        return ""
    end
    if banner.optionsKey then
        return banner.optionsKey
    end
    return BuildOptionsKey(banner.options)
end

-- ============================================================================
-- Anchor & Stack Layout
-- ============================================================================

local function GetBaseAnchor(root)
    if not root.baseAnchor then
        local point, relativeTo, relativePoint, xOfs, yOfs = root:GetPoint()
        root.baseAnchor = {
            point = point or "BOTTOM",
            relativeTo = relativeTo or UIParent,
            relativePoint = relativePoint or "BOTTOM",
            xOfs = xOfs or 0,
            yOfs = yOfs or 0
        }
    end
    return root.baseAnchor
end

local function GetStackAnchor(root, index)
    local base = GetBaseAnchor(root)
    return {
        point = base.point,
        relativeTo = base.relativeTo,
        relativePoint = base.relativePoint,
        xOfs = base.xOfs,
        yOfs = base.yOfs + (Constants.BANNER_HEIGHT + STACK_GAP) * index
    }
end

local function ApplyAnchor(frame, anchor)
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.xOfs, anchor.yOfs)
end

local function SlideToAnchor(frame, anchor, duration, onFinished)
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    relativeTo = relativeTo or UIParent
    local dx = (anchor.xOfs or 0) - (xOfs or 0)
    local dy = (anchor.yOfs or 0) - (yOfs or 0)

    if dx == 0 and dy == 0 then
        ApplyAnchor(frame, anchor)
        if onFinished then
            onFinished()
        end
        return
    end

    if frame.slideAnim then
        frame.slideAnim:Stop()
    end

    frame.slideAnim = frame:CreateAnimationGroup()
    local translate = frame.slideAnim:CreateAnimation("Translation")
    translate:SetDuration(duration or 0.2)
    translate:SetOffset(dx, dy)
    frame.slideAnim:SetScript("OnFinished", function()
        ApplyAnchor(frame, anchor)
        if onFinished then
            onFinished()
        end
    end)
    frame.slideAnim:Play()
end

local function ReflowStack(root)
    if not root.stack then
        return
    end
    for index, frame in ipairs(root.stack) do
        SlideToAnchor(frame, GetStackAnchor(root, index), 0.2)
    end
end

local function PromoteNextBanner(root)
    if not root.stack or #root.stack == 0 then
        return
    end

    local nextBanner = table.remove(root.stack, 1)
    local baseAnchor = GetBaseAnchor(root)

    root.ignoreHide = true
    root:SetAlpha(0)

    SlideToAnchor(nextBanner, baseAnchor, 0.2, function()
        root.options = nextBanner.options
        root.currentIndex = nextBanner.currentIndex or 1
        root.newItemUntil = nil
        root.isOnCooldown = false
        root.cooldownData = nil
        RefreshBannerDisplay(root)
        root:Show()
        UIFrameFadeIn(root, 0.2, 0, 1)
        nextBanner.ignoreHide = true
        nextBanner:Hide()
        nextBanner.ignoreHide = false
        ReflowStack(root)
        root.ignoreHide = false
    end)
end

-- ============================================================================
-- Banner Content Updates
-- ============================================================================

local function GetConfigHelpers()
    return _G.Nozmie_ConfigHelpers
end

local function GetIconHandling()
    return _G.Nozmie_IconHandling
end

local function GetClickBehavior()
    return _G.Nozmie_ClickBehavior
end

local function UpdateBannerForCooldown(banner, data, remaining)
    local IconHandling = GetIconHandling()
    if IconHandling and IconHandling.SetDesaturation then
        IconHandling.SetDesaturation(banner.icon, true)
    else
        banner.icon:SetDesaturated(true)
    end

    banner.title:SetTextColor(unpack(Constants.BANNER_COLORS.TEXT_COOLDOWN))
    banner:SetBackdropColor(unpack(Constants.BANNER_COLORS.BACKDROP_COOLDOWN))
    banner.isOnCooldown = true
    banner.cooldownData = {
        remaining = remaining,
        data = data
    }

    local ConfigHelpers = GetConfigHelpers()
    local name = ConfigHelpers and ConfigHelpers.GetEntryName(data) or (data.name or "?")
    banner.title:SetText(string.format(Lstr("banner.cooldownTitle", "%s is on cooldown"), name))

    local timeText = Helpers.FormatCooldownTime(remaining)
    if Helpers.IsInAnyGroup() then
        local suffix = Lstr("banner.cooldownSuffix", " - Click to announce")
        banner.subtitle:SetText("|cffff0000" .. timeText .. "|r |cff888888" .. suffix .. "|r")
    else
        banner.subtitle:SetText("|cffff0000" .. timeText .. "|r")
    end
end

local function UpdateBannerForReady(banner, data, totalOptions, currentIndex)
    local IconHandling = GetIconHandling()
    if IconHandling and IconHandling.SetDesaturation then
        IconHandling.SetDesaturation(banner.icon, false)
    else
        banner.icon:SetDesaturated(false)
    end

    banner.title:SetTextColor(unpack(Constants.BANNER_COLORS.TEXT_NORMAL))
    banner:SetBackdropColor(unpack(Constants.BANNER_COLORS.BACKDROP_NORMAL))
    banner.isOnCooldown = false

    local _, nounForm = Messaging.GetActionAndNoun(data)

    local spellName = data.spellName or ""
    local isTeleport = data.category == "Teleport" or data.category == "M+ Dungeon" or data.category == "Raid" or
                           spellName:find("^Portal:") or spellName:find("^Teleport:") or
                           spellName:find("^Ancient Portal:")
    local actionType = data.actionType or ""

    local displayVerb, actionText
    if isTeleport then
        displayVerb = Lstr("banner.action.teleport", "Teleport to")
        actionText = Lstr("banner.actionText.teleport", "teleport")
    elseif actionType == "pet" or actionType == "mount" or data.category == "Utility" then
        displayVerb = Lstr("banner.action.summon", "Summon")
        actionText = Lstr("banner.actionText.summon", "summon")
    elseif actionType == "spell" then
        displayVerb = Lstr("banner.action.cast", "Cast")
        actionText = Lstr("banner.actionText.cast", "cast")
    else
        displayVerb = Lstr("banner.action.use", "Use")
        actionText = Lstr("banner.actionText.use", "use")
    end

    banner.title:SetText(string.format(Lstr("banner.titleWithDestination", "%s %s?"), displayVerb,
        data.destination or nounForm))

    local targetInfo = ""
    local playerName = UnitName("player")
    if data.targetPlayer and data.targetPlayer ~= playerName then
        targetInfo = string.format(" |cff00ff00" .. Lstr("banner.targetInfo", " on %s") .. "|r", data.targetPlayer)
    end

    if totalOptions > 1 then
        local prefix = string.format(Lstr("banner.subtitlePrefix", "Click to %s%s"), actionText, targetInfo)
        local count = string.format(Lstr("banner.subtitleCount", "%d/%d"), currentIndex, totalOptions)
        local suffix = Lstr("banner.subtitleSuffix", "Right-click to close")
        banner.subtitle:SetText(
            "|cff888888" .. prefix .. " • |r|cff00ff00" .. count .. "|r |cff888888• " .. suffix .. "|r")
    else
        local prefix = string.format(Lstr("banner.subtitlePrefix", "Click to %s%s"), actionText, targetInfo)
        local suffix = Lstr("banner.subtitleSuffix", "Right-click to close")
        banner.subtitle:SetText("|cff888888" .. prefix .. " • " .. suffix .. "|r")
    end
end

local function UpdateBannerIcon(banner, data)
    local IconHandling = GetIconHandling()
    if IconHandling and IconHandling.ApplyIcon then
        IconHandling.ApplyIcon(banner.icon, data)
    end
    local ClickBehavior = GetClickBehavior()
    if ClickBehavior and ClickBehavior.ApplyActionAttributes then
        ClickBehavior.ApplyActionAttributes(banner, data)
    end
end

RefreshBannerDisplay = function(banner)
    local data = banner.options[banner.currentIndex]
    banner.activeData = data
    UpdateBannerIcon(banner, data)
    local cooldown = Cooldowns.GetRemaining(data)
    if cooldown > 0 then
        UpdateBannerForCooldown(banner, data, cooldown)
    else
        UpdateBannerForReady(banner, data, #banner.options, banner.currentIndex)
    end
end

-- ============================================================================
-- Navigation Arrows
-- ============================================================================

local function CreateNavigationArrows(banner)
    if not banner.leftArrow then
        banner.leftArrow = CreateFrame("Button", nil, banner)
        banner.leftArrow:SetSize(20, 20)
        banner.leftArrow:SetToplevel(true)
        banner.leftArrow:SetPoint("TOP", banner.icon, "BOTTOM", -11, 2)
        banner.leftArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        banner.leftArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        banner.leftArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        banner.leftArrow:SetScript("OnClick", function()
            banner.currentIndex = (banner.currentIndex - 2) % #banner.options + 1
            RefreshBannerDisplay(banner)
        end)
    end

    if not banner.rightArrow then
        banner.rightArrow = CreateFrame("Button", nil, banner)
        banner.rightArrow:SetToplevel(true)
        banner.rightArrow:SetSize(20, 20)
        banner.rightArrow:SetPoint("LEFT", banner.leftArrow, "RIGHT", 2, 0)
        banner.rightArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        banner.rightArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        banner.rightArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        banner.rightArrow:SetScript("OnClick", function()
            banner.currentIndex = banner.currentIndex % #banner.options + 1
            RefreshBannerDisplay(banner)
        end)
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

function BannerController.ShowWithOptions(banner, teleportOptions, isStacked, allowStack)
    EnsureCombatWatcher()
    lastOptions = teleportOptions
    if allowStack == nil then
        allowStack = true
    end

    if not isStacked and banner:IsShown() and allowStack then
        banner.stack = banner.stack or {}
        local BannerUI = _G.Nozmie_BannerUI
        local stackedBanner = BannerUI.CreateBanner()
        stackedBanner.stackRoot = banner
        table.insert(banner.stack, stackedBanner)
        BannerController.ShowWithOptions(stackedBanner, teleportOptions, true)
        ApplyAnchor(stackedBanner, GetStackAnchor(banner, #banner.stack))
        return
    end

    if banner.updateTimer then
        banner.updateTimer:Cancel()
    end
    CancelBannerAutoHideTimer(banner)

    banner.options = teleportOptions
    banner.optionsKey = BuildOptionsKey(teleportOptions)
    banner.currentIndex = 1

    if #banner.options > 1 then
        CreateNavigationArrows(banner)
        banner.leftArrow:Show()
        banner.rightArrow:Show()
    else
        if banner.leftArrow then
            banner.leftArrow:Hide()
        end
        if banner.rightArrow then
            banner.rightArrow:Hide()
        end
    end

    RefreshBannerDisplay(banner)
    banner.updateTimer = C_Timer.NewTicker(0.5, function()
        RefreshBannerDisplay(banner)
    end)

    local ClickBehavior = GetClickBehavior()
    if ClickBehavior then
        ClickBehavior.Apply(banner, {
            closeOnRight = true,
            closeOnLeft = true,
            cancelAutoHide = true
        })
    end

    banner:SetScript("OnHide", function(self)
        if self.ignoreHide then
            return
        end
        if self.updateTimer then
            self.updateTimer:Cancel();
            self.updateTimer = nil
        end
        CancelBannerAutoHideTimer(self)

        local root = self.stackRoot or self
        if self ~= root then
            if root.stack then
                for index, frame in ipairs(root.stack) do
                    if frame == self then
                        table.remove(root.stack, index);
                        break
                    end
                end
            end
            ReflowStack(root)
            return
        end

        if root.stack and #root.stack > 0 then
            PromoteNextBanner(root)
        end
    end)

    if not banner.stackRoot then
        local BannerHelpers = require("ui.banner.helpers")
        BannerHelpers.LoadBannerPosition(banner)
        banner.baseAnchor = nil
        GetBaseAnchor(banner)
    end

    local isRefresh = banner:IsShown() and not isStacked and not allowStack
    if isRefresh then
        banner:SetAlpha(1)
        banner:Show()
    else
        banner:SetAlpha(0)
        banner:Show()
        if IsCombatLocked() then
            banner:SetAlpha(0)
        else
            UIFrameFadeIn(banner, 0.4, 0, 1)
        end
    end

    trackedBanners[banner] = true
    ApplyBannerCombatState(banner)

    if not IsCombatLocked() then
        StartBannerAutoHideTimer(banner)
    end

    if not banner.nozmieTrackedHooked then
        banner:HookScript("OnHide", function(self)
            trackedBanners[self] = nil
        end)
        banner.nozmieTrackedHooked = true
    end
end

function BannerController.FindBannerByOptions(root, options)
    if not root then
        return nil
    end
    local optionsKey = BuildOptionsKey(options)
    if optionsKey == "" then
        return nil
    end
    if GetBannerOptionsKey(root) == optionsKey then
        return root
    end
    if root.stack then
        for _, frame in ipairs(root.stack) do
            if GetBannerOptionsKey(frame) == optionsKey then
                return frame
            end
        end
    end
    return nil
end

function BannerController.GetLastOptions()
    return lastOptions
end

_G.Nozmie_BannerController = BannerController
BannerController.ApplyActionAttributes = function()
    return GetClickBehavior() and GetClickBehavior().ApplyActionAttributes
end
BannerController.ApplyClickBehavior = function()
    return GetClickBehavior() and GetClickBehavior().Apply
end
return BannerController
