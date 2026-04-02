-- ============================================================================
-- Nozmie - Utility UI Module
-- Main utility frame with tabs, item grid, and search
-- ============================================================================
local SharedUI = _G.Nozmie_SharedUI
local ConfigHelpers = _G.Nozmie_ConfigHelpers
local Helpers = _G.Nozmie_Helpers
local Settings = _G.Nozmie_Settings
local BannerController = _G.Nozmie_BannerController
local ClickBehavior = _G.Nozmie_ClickBehavior
local IconHandling = _G.Nozmie_IconHandling

local Locale = _G.Nozmie_Locale
local addon = _G.Nozmie_Addon or {
    name = "Nozmie"
}
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

local selectedTab = "CURRENT_DUNGEONS"
local TAB_CURRENT_DUNGEONS = "CURRENT_DUNGEONS"
local TAB_LEGACY_DUNGEONS = "LEGACY_DUNGEONS"
local TAB_TELEPORTS = "TELEPORTS"
local TAB_UTILITY = "UTILITY"
local TAB_HEARTHSTONE = "HEARTHSTONE"

local UtilityUI = {}
_G.Nozmie_UtilityUI = UtilityUI
local filteredData = {}
local buttons = {}
local GRID_PADDING = 8
local ROW_HEIGHT = 44
local ICON_SIZE = 36
local frame
local content
local searchBox
local scrollFrame
local dataCache = {}
local IsHearthstoneEntry
local IsUsableUtility
local ApplySelectedTabVisual
local EnsureFrame
local BuildDataCache
local RefreshLayout
local tabButtons = {}
local tabIndexById = {}
local tabHasContentById = {}
local tabOrder = {TAB_CURRENT_DUNGEONS, TAB_LEGACY_DUNGEONS, TAB_TELEPORTS, TAB_UTILITY, TAB_HEARTHSTONE}
local showAllEntriesToggle
local activeSearchQuery = ""

local SHOW_ALL_ENTRIES_DB_KEY = "showAllEntriesInUtilityUI"
local SHOW_ALL_TOYS_LEGACY_DB_KEY = "showAllToysInUtilityUI"
local FAVOURITES_DB_KEY = "favourites"
local WOWHEAD_POPUP_KEY = "NOZMIE_WOWHEAD_LINK"
local wowheadPopupRegistered = false
local pendingWowheadURL = nil
local favouritesBootstrapped = false
local contextMenuFrame = nil

local function IsKeystoneIndicatorEnabled()
    if Settings and Settings.Get then
        return Settings.Get("showKeystoneIndicators") ~= false
    end
    return true
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function NormalizeEntryToken(value)
    if value == nil then
        return nil
    end
    local text = tostring(value):lower()
    text = text:gsub("[^%w]", "")
    if text == "" then
        return nil
    end
    return text
end

local function GetEntryID(entry)
    if not entry then
        return nil
    end
    if entry.spellID then
        return "spell:" .. tostring(entry.spellID)
    end
    if entry.itemID then
        return "item:" .. tostring(entry.itemID)
    end
    if entry.mountId then
        return "mount:" .. tostring(entry.mountId)
    end
    if entry.petName then
        local token = NormalizeEntryToken(entry.petName)
        if token then
            return "pet:" .. token
        end
    end
    local fallback = NormalizeEntryToken(entry.name) or NormalizeEntryToken(entry.spellName) or
                         NormalizeEntryToken(entry.destination)
    if fallback then
        return "name:" .. fallback
    end
    return nil
end

local function GetFavouritesTable()
    if type(NozmieDB) ~= "table" then
        NozmieDB = {}
    end
    if type(NozmieDB[FAVOURITES_DB_KEY]) ~= "table" then
        NozmieDB[FAVOURITES_DB_KEY] = {}
    end
    return NozmieDB[FAVOURITES_DB_KEY]
end

local function IsFavourite(entryID)
    if not entryID then
        return false
    end
    return GetFavouritesTable()[entryID] == true
end

local function IsFavouriteEntry(entry)
    return IsFavourite(GetEntryID(entry))
end

local function ToggleFavourite(entryID)
    if not entryID then
        return false
    end
    local favourites = GetFavouritesTable()
    favourites[entryID] = not favourites[entryID]
    return favourites[entryID] == true
end

local function SeedDefaultFavourites()
    if favouritesBootstrapped then
        return
    end

    local favourites = GetFavouritesTable()
    if next(favourites) == nil and type(_G.Nozmie_Data) == "table" then
        for _, entry in ipairs(_G.Nozmie_Data) do
            if tonumber(entry and entry.current) == 1 then
                local entryID = GetEntryID(entry)
                if entryID then
                    favourites[entryID] = true
                end
            end
        end
    end

    favouritesBootstrapped = true
end

local function SortEntriesWithFavourites(list)
    table.sort(list, function(a, b)
        local aFav = IsFavouriteEntry(a)
        local bFav = IsFavouriteEntry(b)
        if aFav ~= bFav then
            return aFav
        end

        local aRandom = a and (a.actionType == "random_hearthstone" or a.name == "Random Hearthstone")
        local bRandom = b and (b.actionType == "random_hearthstone" or b.name == "Random Hearthstone")
        if aRandom ~= bRandom then
            return aRandom
        end

        local aUnavailable = not (IsUsableUtility and IsUsableUtility(a))
        local bUnavailable = not (IsUsableUtility and IsUsableUtility(b))
        if aUnavailable ~= bUnavailable then
            return not aUnavailable
        end
        return ConfigHelpers.GetEntryName(a) < ConfigHelpers.GetEntryName(b)
    end)
end

function UtilityUI.ToggleFavourite(entryID)
    return ToggleFavourite(entryID)
end

function UtilityUI.IsFavourite(entryID)
    return IsFavourite(entryID)
end

function UtilityUI.GetFavourites()
    return GetFavouritesTable()
end

function UtilityUI.SortEntriesWithFavourites(list)
    SortEntriesWithFavourites(list)
end

local function GetShowAllEntriesEnabled()
    if type(NozmieDB) ~= "table" then
        return false
    end
    if NozmieDB[SHOW_ALL_ENTRIES_DB_KEY] ~= nil then
        return NozmieDB[SHOW_ALL_ENTRIES_DB_KEY] == true
    end
    return NozmieDB[SHOW_ALL_TOYS_LEGACY_DB_KEY] == true
end

local function SetShowAllEntriesEnabled(enabled)
    if type(NozmieDB) ~= "table" then
        NozmieDB = {}
    end
    NozmieDB[SHOW_ALL_ENTRIES_DB_KEY] = enabled == true
    NozmieDB[SHOW_ALL_TOYS_LEGACY_DB_KEY] = enabled == true
end

local function UrlEncode(str)
    str = tostring(str or "")
    str = str:gsub("\n", " ")
    str = str:gsub("([^%w%-_%.~ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return str:gsub(" ", "+")
end

local function ApplyUtilityButtonCombatState(button)
    if not button then
        return
    end

    if IsCombatLocked() then
        button:EnableMouse(false)
        button:SetAlpha(0.5)
    else
        button:EnableMouse(true)
        button:SetAlpha(1)
    end
end

local function RefreshCombatButtonState()
    if not buttons then
        return
    end

    for _, button in ipairs(buttons) do
        if button:IsShown() then
            ApplyUtilityButtonCombatState(button)
        end
    end
end

local function IsUtilityEntry(item)
    return item and (item.category == "Utility" or item.category == "Class Utility") and not item.easterEgg
end

local function IsUnavailableEntry(item)
    return not IsUsableUtility(item)
end

local function GetWowheadURL(item)
    if not item then
        return nil
    end

    if item.itemID then
        return "https://www.wowhead.com/item=" .. tostring(item.itemID)
    end
    if item.spellID then
        return "https://www.wowhead.com/spell=" .. tostring(item.spellID)
    end

    local searchText = item.spellName or item.name or item.destination
    if searchText and searchText ~= "" then
        return "https://www.wowhead.com/search?q=" .. UrlEncode(searchText)
    end

    return nil
end

local function EnsureWowheadPopupRegistered()
    if wowheadPopupRegistered then
        return
    end

    StaticPopupDialogs[WOWHEAD_POPUP_KEY] = {
        text = Lstr("utility.entry.wowhead.popup.title",
            "This entry is not available to use right now. Copy this Wowhead link to see details:"),
        button1 = Lstr("utility.entry.wowhead.popup.close", "Close"),
        hasEditBox = true,
        editBoxWidth = 360,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            local editBox = self.editBox or self:GetEditBox()
            editBox:SetText(pendingWowheadURL or "")
            editBox:SetAutoFocus(true)
            editBox:HighlightText()
        end,
        OnAccept = function(self)
            local editBox = self.editBox or self:GetEditBox()
            editBox:SetText("")
        end,
        OnHide = function(self)
            local editBox = self.editBox or self:GetEditBox()
            editBox:SetText("")
        end
    }

    wowheadPopupRegistered = true
end

local function OpenWowheadForEntry(item)
    local url = GetWowheadURL(item)
    if not url then
        return
    end

    EnsureWowheadPopupRegistered()
    pendingWowheadURL = url
    StaticPopup_Show(WOWHEAD_POPUP_KEY)
end

local function ShowEntryContextMenu(button)
    if not button then
        return
    end

    local data = button.nozmieTooltipData
    if not data then
        return
    end

    if not contextMenuFrame then
        contextMenuFrame = CreateFrame("Frame", "NozmieUtilityContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local entryID = button.nozmieEntryID
    local function ToggleFavouriteAction()
        if not entryID then
            return
        end
        ToggleFavourite(entryID)
        BuildDataCache()
        RefreshLayout()
    end

    local function AnnounceAction()
        if Helpers and Helpers.AnnounceUtility then
            Helpers.AnnounceUtility(data)
        end
    end

    local function CopyWowheadAction()
        OpenWowheadForEntry(data)
    end

    local isFav = entryID and IsFavourite(entryID) or false
    local favLabel = isFav and Lstr("utility.favourites.remove", "Remove from favourites") or
                         Lstr("utility.favourites.add", "Add to favourites")
    local announceLabel = Lstr("utility.context.announce", "Announce in chat")
    local wowheadLabel = Lstr("utility.context.copyWowhead", "Copy Wowhead link")
    local menuEntries = {
        {
            text = favLabel,
            action = ToggleFavouriteAction
        }, {
            text = announceLabel,
            action = AnnounceAction
        }, {
            text = wowheadLabel,
            action = CopyWowheadAction
        }
    }

    if EasyMenu then
        local menu = {}
        for _, entry in ipairs(menuEntries) do
            menu[#menu + 1] = {
                text = entry.text,
                notCheckable = true,
                func = entry.action
            }
        end

        EasyMenu(menu, contextMenuFrame, "cursor", 0, 0, "MENU", 2)
        return
    end

    if UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        UIDropDownMenu_Initialize(contextMenuFrame, function(_, level)
            if level ~= 1 then
                return
            end

            for _, entry in ipairs(menuEntries) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = entry.text
                info.notCheckable = true
                info.func = entry.action
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")

        ToggleDropDownMenu(1, nil, contextMenuFrame, "cursor", 0, 0)
        return
    end

    -- If menu APIs are unavailable in this client build, keep right-click useful.
    CopyWowheadAction()
end

local function IsTeleportEntry(item)
    if not item then
        return false
    end
    return item.category == "M+ Dungeon" or item.category == "Raid" or item.category == "Teleport" or item.isTeleport == true
end

local function IsCurrentDungeonEntry(item)
    return item and tonumber(item.current) == 1
end

local function IsRandomHearthstoneEntry(item)
    if not item then
        return false
    end
    return item.actionType == "random_hearthstone" or item.name == "Random Hearthstone"
end

local function IsLegacyEntry(item)
    if not item then
        return false
    end
    if item.legacy == true then
        return true
    end
    return tonumber(item.legacy) == 1
end

local function ShouldShowUnavailableEntry(item)
    if not item then
        return false
    end

    if item.category == "Class Utility" or item.category == "Class" then
        return false
    end

    return true
end

local function MatchesFilter(item)
    return item ~= nil
end

local function MatchesSearch(item, query)
    if not query or query == "" then
        return true
    end
    local text = string.lower(table.concat({tostring(item.name or ""), tostring(item.spellName or ""),
                                            tostring(item.destination or ""), tostring(item.category or "")}, " "))
    if text:find(query, 1, true) then
        return true
    end
    if item.keywords then
        for _, keyword in ipairs(item.keywords) do
            if type(keyword) == "string" and string.lower(keyword):find(query, 1, true) then
                return true
            end
        end
    end
    return false
end

local function GetEntryDescription(data)
    return data.destination or data.category or ""
end

local function ItemMatchesTab(item, tabId)
    if not item then
        return false
    end

    if tabId == TAB_CURRENT_DUNGEONS then
        return IsFavouriteEntry(item)
    elseif tabId == TAB_LEGACY_DUNGEONS then
        return item.category == "M+ Dungeon" or item.category == "Raid"
    elseif tabId == TAB_TELEPORTS then
        return IsTeleportEntry(item) and item.category ~= "M+ Dungeon" and item.category ~= "Raid" and
                   not IsHearthstoneEntry(item)
    elseif tabId == TAB_UTILITY then
        return IsUtilityEntry(item)
    elseif tabId == TAB_HEARTHSTONE then
        return IsHearthstoneEntry(item)
    end

    return false
end

local function TabHasContent(tabId)
    if not dataCache then
        return false
    end

    for _, item in ipairs(dataCache) do
        if MatchesFilter(item) and ItemMatchesTab(item, tabId) then
            return true
        end
    end

    return false
end

local function GetFirstEnabledTabId()
    for _, tabId in ipairs(tabOrder) do
        if tabHasContentById[tabId] then
            return tabId
        end
    end
    return nil
end

local function UpdateTabVisibility(parent)
    if not parent then
        return
    end

    local prevTab
    local tabCount = 0
    tabIndexById = {}
    tabHasContentById = {}

    for _, tabId in ipairs(tabOrder) do
        local tab = tabButtons[tabId]
        if tab then
            tabCount = tabCount + 1
            tabIndexById[tabId] = tabCount
            tab:SetID(tabCount)

            local hasContent = TabHasContent(tabId)
            tabHasContentById[tabId] = hasContent
            tab.nozmieHasContent = hasContent

            tab:ClearAllPoints()
            if prevTab then
                tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
            else
                tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 12, 2)
            end

            tab:Show()
            tab:SetEnabled(true)
            tab:EnableMouse(true)
            prevTab = tab
        end
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(parent, tabCount)
    end

    if not tabHasContentById[selectedTab] then
        selectedTab = GetFirstEnabledTabId() or TAB_CURRENT_DUNGEONS
    end
end

local function SetTabSelectedState(tab, selected)
    if not tab then
        return
    end

    local hasContent = tab.nozmieHasContent == true

    local fontString = tab.GetFontString and tab:GetFontString()
    if fontString then
        if selected then
            fontString:SetTextColor(1, 0.82, 0)
        elseif not hasContent then
            fontString:SetTextColor(0.45, 0.45, 0.45)
        else
            fontString:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
        if selected then
            PanelTemplates_SelectTab(tab)
        else
            PanelTemplates_DeselectTab(tab)
        end
    elseif tab.SetButtonState then
        if selected then
            tab:SetButtonState("PUSHED", true)
        else
            tab:SetButtonState("NORMAL", false)
        end
    end
end

local function ApplyFavouriteIcon(texture)
    if not texture then
        return
    end

    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    texture:SetTexCoord(0, 0.25, 0, 0.25)
end

local function ApplyFavouriteIconColor(toggle, isFav, isHover)
    if not toggle or not toggle.iconTexture then
        return
    end

    local icon = toggle.iconTexture
    if isFav then
        if isHover then
            icon:SetVertexColor(1, 0.95, 0.35, 1)
            icon:SetAlpha(1)
        else
            icon:SetVertexColor(1, 0.88, 0.25, 1)
            icon:SetAlpha(1)
        end
    else
        if isHover then
            icon:SetVertexColor(0.95, 0.95, 1, 1)
            icon:SetAlpha(0.95)
        else
            icon:SetVertexColor(0.72, 0.72, 0.72, 1)
            icon:SetAlpha(0.85)
        end
    end
end

local function EnsureButton(index)
    if buttons[index] then
        return buttons[index]
    end
    local utilityButtonModule = _G.Nozmie_UtilityButton
    local button = utilityButtonModule and utilityButtonModule.Create and
                       utilityButtonModule.Create(content, ICON_SIZE, ROW_HEIGHT) or
                       CreateFrame("Button", nil, content, "SecureActionButtonTemplate")
    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(ICON_SIZE, ICON_SIZE)
        button.icon:SetPoint("LEFT", button, "LEFT", 14, 0)
    end
    if not button.name then
        button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 12, -4)
        button.name:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        button.name:SetJustifyH("LEFT")
    end
    if not button.category then
        button.category = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.category:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -2)
        button.category:SetPoint("RIGHT", button.name, "RIGHT", 0, 0)
        button.category:SetJustifyH("LEFT")
    end
    if not button.cooldown then
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        button.cooldown:Hide()
    end
    if not button.cooldownText then
        button.cooldownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.cooldownText:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
        button.cooldownText:Hide()
    end
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    if not button.nozmieUnavailableHooked then
        button:HookScript("PostClick", function(self, mouseButton)
            if self.nozmieUnavailable and mouseButton == "LeftButton" then
                OpenWowheadForEntry(self.nozmieUnavailableData)
                return
            end

            if mouseButton == "RightButton" then
                ShowEntryContextMenu(self)
            end
        end)
        button.nozmieUnavailableHooked = true
    end

    if not button.favouriteToggle then
        local favouriteToggle = CreateFrame("Button", nil, button)
        favouriteToggle:SetSize(16, 16)
        favouriteToggle:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 3, 3)
        favouriteToggle:EnableMouse(false)
        if button.cooldown and button.cooldown.GetFrameLevel then
            favouriteToggle:SetFrameLevel((button.cooldown:GetFrameLevel() or button:GetFrameLevel()) + 3)
        else
            favouriteToggle:SetFrameLevel((button:GetFrameLevel() or 1) + 8)
        end

        local iconTexture = favouriteToggle:CreateTexture(nil, "OVERLAY")
        iconTexture:SetPoint("CENTER")
        iconTexture:SetSize(14, 14)
        ApplyFavouriteIcon(iconTexture)
        favouriteToggle.iconTexture = iconTexture

        local popAnim = iconTexture:CreateAnimationGroup()
        local popUp = popAnim:CreateAnimation("Scale")
        popUp:SetOrder(1)
        popUp:SetDuration(0.06)
        popUp:SetScale(1.2, 1.2)

        local popDown = popAnim:CreateAnimation("Scale")
        popDown:SetOrder(2)
        popDown:SetDuration(0.06)
        popDown:SetScale(0.8333, 0.8333)

        favouriteToggle.popAnim = popAnim

        button.favouriteToggle = favouriteToggle
    end

    buttons[index] = button
    return button
end

local function UpdateFavouriteToggle(button, entry)
    if not button or not button.favouriteToggle then
        return
    end

    local entryID = GetEntryID(entry)
    button.nozmieEntryID = entryID

    if not entryID then
        button.favouriteToggle:Hide()
        return
    end

    local isFav = IsFavourite(entryID)
    local icon = button.favouriteToggle.iconTexture
    local oldState = button.nozmieLastFavState
    if icon then
        ApplyFavouriteIcon(icon)
        ApplyFavouriteIconColor(button.favouriteToggle, isFav, false)
    end

    button.favouriteToggle:SetShown(isFav)

    if oldState ~= nil and oldState ~= isFav and isFav and button.favouriteToggle.popAnim then
        button.favouriteToggle.popAnim:Stop()
        button.favouriteToggle.popAnim:Play()
    end
    button.nozmieLastFavState = isFav
end

local function EnsureKeystoneIndicatorVisuals(button)
    if not button or not button.icon then
        return
    end

    if not button.nozmieKeyBackGlow then
        local backGlow = button:CreateTexture(nil, "BACKGROUND")
        backGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        backGlow:SetBlendMode("ADD")
        backGlow:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
        backGlow:SetSize(60, 60)
        backGlow:SetAlpha(0)
        button.nozmieKeyBackGlow = backGlow
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

local function ApplyKeystoneIndicator(button, entry)
    if not button then
        return
    end

    button.nozmieKeystoneTooltipText = nil
    EnsureKeystoneIndicatorVisuals(button)

    if not IsKeystoneIndicatorEnabled() or not Helpers or not Helpers.GetKeystoneOwnershipForEntry then
        if button.nozmieKeyBackGlow then
            button.nozmieKeyBackGlow:SetAlpha(0)
        end
        if button.nozmieKeyGlow then
            button.nozmieKeyGlow:SetAlpha(0)
        end
        if button.nozmieKeyBadge then
            button.nozmieKeyBadge:SetAlpha(0)
        end
        if button.nozmieKeyBadgeRing then
            button.nozmieKeyBadgeRing:SetAlpha(0)
        end
        return
    end

    local ownership = Helpers.GetKeystoneOwnershipForEntry(entry)
    if not ownership then
        if button.nozmieKeyBackGlow then
            button.nozmieKeyBackGlow:SetAlpha(0)
        end
        if button.nozmieKeyGlow then
            button.nozmieKeyGlow:SetAlpha(0)
        end
        if button.nozmieKeyBadge then
            button.nozmieKeyBadge:SetAlpha(0)
        end
        if button.nozmieKeyBadgeRing then
            button.nozmieKeyBadgeRing:SetAlpha(0)
        end
        return
    end

    if Helpers.GetKeystoneOwnerTooltipText then
        button.nozmieKeystoneTooltipText = Helpers.GetKeystoneOwnerTooltipText(entry)
    end

    local isOwn = ownership == "own"
    if button.nozmieKeyBackGlow then
        button.nozmieKeyBackGlow:SetVertexColor(isOwn and 1 or 0.65, isOwn and 0.78 or 0.88, isOwn and 0.24 or 1, 1)
        button.nozmieKeyBackGlow:SetAlpha(0.14)
    end
    if button.nozmieKeyBadge then
        button.nozmieKeyBadge:SetVertexColor(isOwn and 1 or 0.78, isOwn and 0.86 or 0.92, isOwn and 0.22 or 1, 1)
        button.nozmieKeyBadge:SetAlpha(1)
    end
    if button.nozmieKeyBadgeRing then
        button.nozmieKeyBadgeRing:SetAlpha(0.68)
    end
    if button.nozmieKeyGlow then
        button.nozmieKeyGlow:SetVertexColor(isOwn and 1 or 0.65, isOwn and 0.76 or 0.85, isOwn and 0.22 or 1, 1)
        button.nozmieKeyGlow:SetAlpha(0.22)
    end
end

local function RefreshDungeonIndicators(dungeonID)
    if not buttons then
        return
    end

    local filterMapName
    if dungeonID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        filterMapName = C_ChallengeMode.GetMapUIInfo(tonumber(dungeonID))
        if type(filterMapName) == "string" then
            filterMapName = filterMapName:lower()
        end
    end

    for _, button in ipairs(buttons) do
        if button:IsShown() and button.nozmieTooltipData and button.nozmieTooltipData.category == "M+ Dungeon" then
            local entry = button.nozmieTooltipData
            if not filterMapName or (entry.name and entry.name:lower() == filterMapName) then
                ApplyKeystoneIndicator(button, entry)
            end
        end
    end
end

function UtilityUI.Toggle()
    local host = EnsureFrame()
    if host:IsShown() then
        host:Hide()
    else
        host:Show()
    end
end

function UtilityUI.Show()
    EnsureFrame():Show()
end

function UtilityUI.Hide()
    if frame then
        frame:Hide()
    end
end

function UtilityUI.RefreshGroupKeys()
    if not frame or not frame:IsShown() then
        return
    end
    RefreshDungeonIndicators(nil)
end

function UtilityUI.UpdateDungeonUI(dungeonID)
    if not frame or not frame:IsShown() then
        return
    end
    RefreshDungeonIndicators(dungeonID)
end

IsUsableUtility = function(item)
    if Helpers and Helpers.CanPlayerUseUtility then
        return Helpers.CanPlayerUseUtility(item)
    end
    if item.itemID then
        if C_Item and C_Item.GetItemCount then
            return C_Item.GetItemCount(item.itemID, true, false, false) > 0
        end
        return false
    end
    if item.spellID and (IsSpellKnown(item.spellID) or IsPlayerSpell(item.spellID)) then
        return true
    end
    return false
end

BuildDataCache = function()
    local showAllEntries = GetShowAllEntriesEnabled()

    SeedDefaultFavourites()

    dataCache = {}
    if not _G.Nozmie_Data then
        return
    end
    for _, item in ipairs(_G.Nozmie_Data) do
        local isUsable = IsUsableUtility(item)
        if (IsUtilityEntry(item) or IsTeleportEntry(item) or IsHearthstoneEntry(item)) and
            (isUsable or (showAllEntries and not isUsable and ShouldShowUnavailableEntry(item))) then
            table.insert(dataCache, item)
        end
    end

    SortEntriesWithFavourites(dataCache)
end

IsHearthstoneEntry = function(item)
    if not item then
        return false
    end
    if item.category == "Home" then
        return true
    end
    return false
end

local function BuildFilteredData()
    local query = ""
    if searchBox and searchBox.GetText then
        query = searchBox:GetText() or ""
        query = query:lower()
        if strtrim then
            query = strtrim(query)
        end
    end

    filteredData = {}
    activeSearchQuery = query
    if not dataCache then
        return
    end

    -- If searching, search across all items; otherwise filter by tab
    if query and query ~= "" then
        for _, item in ipairs(dataCache) do
            if MatchesFilter(item) and MatchesSearch(item, query) then
                table.insert(filteredData, item)
            end
        end
    else
        for _, item in ipairs(dataCache) do
            local matchesTab = ItemMatchesTab(item, selectedTab)

            if matchesTab and MatchesFilter(item) then
                table.insert(filteredData, item)
            end
        end
    end
end

local function ApplyActionAttributes(button, item)
    if ClickBehavior and ClickBehavior.ApplyActionAttributes then
        ClickBehavior.ApplyActionAttributes(button, item)
    elseif BannerController and BannerController.ApplyActionAttributes then
        BannerController.ApplyActionAttributes(button, item)
    end
end

local function ClearButtonActions(button)
    if ClickBehavior and ClickBehavior.ClearActionAttributes then
        ClickBehavior.ClearActionAttributes(button)
    else
        button:SetScript("PreClick", nil)
        button:SetAttribute("type", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("type2", nil)
        button:SetAttribute("macrotext", nil)
        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("macrotext2", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("spell1", nil)
        button:SetAttribute("spell2", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("item1", nil)
        button:SetAttribute("item2", nil)
    end
end

local function ConfigureUnavailableButton(button, item)
    ClearButtonActions(button)
    button.data = nil
    button.activeData = nil
    button.options = nil
    button.currentIndex = nil
    button.nozmieClickBehaviorOptions = nil
end

local function ConfigureOwnedButton(button, item)
    ApplyActionAttributes(button, item)
    if ClickBehavior and ClickBehavior.Apply then
        button.data = item
        ClickBehavior.Apply(button, {
            closeOnRight = false,
            closeOnLeft = false,
            cancelAutoHide = false
        })
    end
end

local function LayoutButtons()
    if not content or not scrollFrame then
        return
    end
    local width = scrollFrame:GetWidth() or 0
    if width <= 0 then
        width = frame and frame.Inset and frame.Inset:GetWidth() or 520
    end
    content:SetWidth(width)
    local columns = math.max(2, math.floor((width + GRID_PADDING) / 220))

    for i, button in ipairs(buttons) do
        button:Hide()
    end

    if frame and frame.nozmieEmptyStateText then
        frame.nozmieEmptyStateText:Hide()
    end

    if not filteredData then
        return
    end

    if #filteredData == 0 then
        if frame and frame.nozmieEmptyStateText and selectedTab == TAB_CURRENT_DUNGEONS and activeSearchQuery == "" then
            frame.nozmieEmptyStateText:SetText(Lstr("utility.favourites.empty", "No favourites yet") .. "\n" ..
                                               Lstr("utility.favourites.empty.hint",
                "Right-click an item and choose Add to favourites"))
            frame.nozmieEmptyStateText:Show()
        end
        content:SetHeight(ROW_HEIGHT + GRID_PADDING)
        return
    end

    local col, row = 0, 0

    for index, entry in ipairs(filteredData) do
        local button = EnsureButton(index)
        local data = entry
        local isUnavailable = IsUnavailableEntry(data)
        local isFav = IsFavouriteEntry(data)

        -- Tooltip state should always be available, including while in combat.
        button.nozmieTooltipData = data
        button.nozmieUnavailable = isUnavailable
        button.nozmieUnavailableData = isUnavailable and data or nil
        UpdateFavouriteToggle(button, data)
        ApplyKeystoneIndicator(button, data)

        -- Configure button
        button:SetAlpha(1)
        button:EnableMouse(true)
        button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        local highlightTexture = button:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:SetBlendMode("ADD")
            highlightTexture:SetAlpha(1)
        end
        button.icon:SetAlpha(1)

        button.name:SetFont(button.name:GetFont(), 12, "")
        button.name:ClearAllPoints()
        button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 12, -2)
        button.name:SetPoint("RIGHT", button, "RIGHT", -10, 0)

        if SharedUI and SharedUI.GetEntryLabel then
            button.name:SetText(SharedUI.GetEntryLabel(data))
        else
            button.name:SetText(ConfigHelpers.GetEntryName(data))
        end

        if isUnavailable then
            button.name:SetTextColor(0.78, 0.78, 0.78)
            button.category:SetTextColor(1, 0.82, 0.35)
            button.category:SetText(Lstr("utility.entry.unavailable.hint", "Unavailable - click to copy Wowhead link"))
        else
            button.name:SetTextColor(1, 1, 1)
            button.category:SetTextColor(0.7, 0.7, 0.7)
            button.category:SetText(GetEntryDescription(data))
        end

        if isFav and not isUnavailable then
            button.category:SetTextColor(0.86, 0.78, 0.36)
        end

        if IconHandling and IconHandling.ApplyIcon then
            IconHandling.ApplyIcon(button.icon, data)
        else
            button.icon:SetTexture(ConfigHelpers.GetIconForEntry(data))
        end

        if button.icon and button.icon.SetDesaturated then
            button.icon:SetDesaturated(isUnavailable)
        end
        button.icon:SetAlpha(isUnavailable and 0.75 or 1)
        if isUnavailable then
            button:SetAlpha(0.92)
        end

        if not IsCombatLocked() then
            if isUnavailable then
                ConfigureUnavailableButton(button, data)
            else
                ConfigureOwnedButton(button, data)
            end
        end

        if button.leftArrow then
            button.leftArrow:Hide()
        end
        if button.rightArrow then
            button.rightArrow:Hide()
        end

        if button.hotkey then
            local key, btnName = nil, button:GetName()
            if not isUnavailable and btnName then
                if data.itemID then
                    key = GetBindingKey("CLICK " .. btnName .. ":LeftButton")
                elseif data.spellID then
                    key = GetBindingKey("CLICK " .. btnName .. ":LeftButton")
                end
            end
            if key then
                button.hotkey:SetText(key)
                button.hotkey:Show()
            else
                button.hotkey:SetText("")
                button.hotkey:Hide()
            end
        end

        -- Cooldown logic
        if not isUnavailable and IconHandling and IconHandling.ApplyCooldownVisual then
            button.data = data
            IconHandling.ApplyCooldownVisual(button.icon, button.cooldown, button.cooldownText, data)
        elseif button.cooldown then
            button.data = nil
            button.cooldown:Hide()
            if button.cooldownText then
                button.cooldownText:SetText("")
                button.cooldownText:Hide()
            end
        end
        local x = col * (width / columns)
        local y = row * (ROW_HEIGHT + GRID_PADDING)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
        button:SetWidth((width / columns) - GRID_PADDING)
        ApplyUtilityButtonCombatState(button)
        button:Show()
        col = col + 1
        if col >= columns then
            col = 0
            row = row + 1
        end
    end
    local rows = math.max(1, row + (col > 0 and 1 or 0))

    content:SetHeight(rows * (ROW_HEIGHT + GRID_PADDING))
end

RefreshLayout = function()
    if frame then
        UpdateTabVisibility(frame)
    end
    BuildFilteredData()
    LayoutButtons()
    if frame then
        ApplySelectedTabVisual(frame)
    end
end

ApplySelectedTabVisual = function(parent)
    if not parent then
        return
    end

    if not tabButtons[selectedTab] then
        selectedTab = GetFirstEnabledTabId() or TAB_CURRENT_DUNGEONS
    end

    local activeTab = tabButtons[selectedTab]
    for _, tabId in ipairs(tabOrder) do
        local tab = tabButtons[tabId]
        if tab then
            local selected = tab == activeTab
            SetTabSelectedState(tab, selected)
        end
    end
end

local function UpdateCooldowns()
    if not buttons then
        return
    end
    for _, button in ipairs(buttons) do
        if button:IsShown() and button.data and IconHandling and IconHandling.ApplyCooldownVisual then
            IconHandling.ApplyCooldownVisual(button.icon, button.cooldown, button.cooldownText, button.data)
        end
    end
end

local function UpdateTabSelection(value, parent)
    UpdateTabVisibility(parent)
    if not tabHasContentById[value] then
        value = GetFirstEnabledTabId() or TAB_CURRENT_DUNGEONS
    end
    selectedTab = value or TAB_CURRENT_DUNGEONS
    RefreshLayout()
    ApplySelectedTabVisual(parent)
end

local function AddDisabledTabTooltip(tab, tabId)
    if not tab then
        return
    end

    tab:HookScript("OnEnter", function(self)
        if tabHasContentById[tabId] then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Lstr("utility.tab.disabled.tooltip", "No entries available for this character."), 1, 1,
            1, 1, true)
        GameTooltip:Show()
    end)

    tab:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateTabButtons(parent)
    local currentDungeonsTab = CreateFrame("Button", "$parentTab1", parent, "PanelTabButtonTemplate")
    local legacyDungeonsTab = CreateFrame("Button", "$parentTab2", parent, "PanelTabButtonTemplate")
    local teleportsTab = CreateFrame("Button", "$parentTab3", parent, "PanelTabButtonTemplate")
    local utilityTab = CreateFrame("Button", "$parentTab4", parent, "PanelTabButtonTemplate")
    local hearthTab = CreateFrame("Button", "$parentTab5", parent, "PanelTabButtonTemplate")

    tabButtons[TAB_CURRENT_DUNGEONS] = currentDungeonsTab
    tabButtons[TAB_LEGACY_DUNGEONS] = legacyDungeonsTab
    tabButtons[TAB_TELEPORTS] = teleportsTab
    tabButtons[TAB_UTILITY] = utilityTab
    tabButtons[TAB_HEARTHSTONE] = hearthTab

    currentDungeonsTab:SetText(Lstr("utility.tab.favourites", "Favourites"))
    currentDungeonsTab:SetScript("OnClick", function()
        if not tabHasContentById[TAB_CURRENT_DUNGEONS] then
            return
        end
        UpdateTabSelection(TAB_CURRENT_DUNGEONS, parent)
    end)

    legacyDungeonsTab:SetText(Lstr("utility.tab.dungeons", "Dungeons"))
    legacyDungeonsTab:SetScript("OnClick", function()
        if not tabHasContentById[TAB_LEGACY_DUNGEONS] then
            return
        end
        UpdateTabSelection(TAB_LEGACY_DUNGEONS, parent)
    end)

    teleportsTab:SetText(Lstr("utility.tab.teleports", "Teleports"))
    teleportsTab:SetScript("OnClick", function()
        if not tabHasContentById[TAB_TELEPORTS] then
            return
        end
        UpdateTabSelection(TAB_TELEPORTS, parent)
    end)

    utilityTab:SetText(Lstr("utility.tab.utility", "Utility"))
    utilityTab:SetScript("OnClick", function()
        if not tabHasContentById[TAB_UTILITY] then
            return
        end
        UpdateTabSelection(TAB_UTILITY, parent)
    end)

    hearthTab:SetText(Lstr("utility.tab.hearthstone", "Hearthstones"))
    hearthTab:SetScript("OnClick", function()
        if not tabHasContentById[TAB_HEARTHSTONE] then
            return
        end
        UpdateTabSelection(TAB_HEARTHSTONE, parent)
    end)

    AddDisabledTabTooltip(currentDungeonsTab, TAB_CURRENT_DUNGEONS)
    AddDisabledTabTooltip(legacyDungeonsTab, TAB_LEGACY_DUNGEONS)
    AddDisabledTabTooltip(teleportsTab, TAB_TELEPORTS)
    AddDisabledTabTooltip(utilityTab, TAB_UTILITY)
    AddDisabledTabTooltip(hearthTab, TAB_HEARTHSTONE)

    UpdateTabVisibility(parent)
    UpdateTabSelection(selectedTab, parent)
end

EnsureFrame = function()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "NozmieUtilityFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(700, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = Lstr("utility.title", addon.name)

    if frame.SetTitle then
        frame:SetTitle(title)
    end
    if frame.TitleBg and frame.TitleBg.Text then
        frame.TitleBg.Text:SetText(title)
    end
    if frame.TitleText then
        frame.TitleText:SetText(title)
    end
    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(title)
    end

    local icon = "Interface\\Icons\\Spell_Holy_BorrowedTime"
    if frame.Portrait then
        frame.Portrait:SetTexture(icon)
    elseif frame.PortraitContainer and frame.PortraitContainer.portrait then
        frame.PortraitContainer.portrait:SetTexture(icon)
    end
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    frame.Inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.Inset:SetPoint("TOPLEFT", 4, -56)
    frame.Inset:SetPoint("BOTTOMRIGHT", -6, 28)

    searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -32)
    searchBox:SetScript("OnTextChanged", function()
        if searchBox.Instructions then
            if searchBox:GetText() == "" then
                searchBox.Instructions:Show()
            else
                searchBox.Instructions:Hide()
            end
        end
        RefreshLayout()
    end)
    if searchBox.Instructions then
        searchBox.Instructions:SetText(Lstr("utility.search.placeholder", "Search utility...") or "Search utility...")
        searchBox.Instructions:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
        searchBox.Instructions:SetJustifyH("LEFT")
        searchBox.Instructions:Show()
    end

    showAllEntriesToggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showAllEntriesToggle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 4)
    showAllEntriesToggle:SetScript("OnClick", function(self)
        SetShowAllEntriesEnabled(self:GetChecked())
        BuildDataCache()
        RefreshLayout()
    end)

    showAllEntriesToggle.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showAllEntriesToggle.label:SetPoint("LEFT", showAllEntriesToggle, "RIGHT", -2, 0)
    showAllEntriesToggle.label:SetText(Lstr("utility.showAllEntries.toggle", "Show all entries"))
    showAllEntriesToggle.label:SetTextColor(0.9, 0.9, 0.9)

    showAllEntriesToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Lstr("utility.showAllEntries.tooltip", "Show entries you cannot use right now."), 1, 1, 1)
        GameTooltip:AddLine(Lstr("utility.showAllEntries.tooltip.detail",
            "Unavailable entries are dimmed, listed last, and copy a Wowhead link when clicked."), 0.85, 0.85, 0.85,
            true)
        GameTooltip:Show()
    end)
    showAllEntriesToggle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    CreateTabButtons(frame)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame.Inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    content:SetClipsChildren(false)
    scrollFrame:SetScrollChild(content)

    frame.nozmieEmptyStateText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.nozmieEmptyStateText:SetPoint("TOP", content, "TOP", 0, -28)
    frame.nozmieEmptyStateText:SetWidth(520)
    frame.nozmieEmptyStateText:SetJustifyH("CENTER")
    frame.nozmieEmptyStateText:SetJustifyV("TOP")
    frame.nozmieEmptyStateText:SetTextColor(0.72, 0.72, 0.72)
    frame.nozmieEmptyStateText:Hide()

    scrollFrame:SetScript("OnSizeChanged", function()
        LayoutButtons()
    end)

    frame:SetScript("OnShow", function()
        if showAllEntriesToggle then
            showAllEntriesToggle:SetChecked(GetShowAllEntriesEnabled())
        end
        BuildDataCache()
        RefreshLayout()
        RefreshCombatButtonState()
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        UpdateCooldowns()
    end)

    frame.Inset:SetScript("OnSizeChanged", function()
        LayoutButtons()
    end)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("NEW_TOY_ADDED")
    frame:RegisterEvent("TOYS_UPDATED")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RefreshCombatButtonState()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            RefreshLayout()
            RefreshCombatButtonState()
            return
        end

        if event == "GROUP_ROSTER_UPDATE" then
            if Helpers and Helpers.CleanupGroupKeyReportsForCurrentGroup then
                Helpers.CleanupGroupKeyReportsForCurrentGroup()
            end
            RefreshDungeonIndicators(nil)
            return
        end

        if event == "NEW_TOY_ADDED" or event == "TOYS_UPDATED" then
            BuildDataCache()
            RefreshLayout()
        end
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "NozmieUtilityFrame")
    end

    frame:Hide()
    return frame
end

SLASH_NOZUI1 = "/nozui"
SLASH_NOZUI2 = "/noz"
SLASH_NOZUI3 = "/nozmie"
SlashCmdList["NOZUI"] = function()
    UtilityUI.Show()
end
