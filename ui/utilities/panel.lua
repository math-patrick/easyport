-- ============================================================================
-- Nozmie - Utility UI Panel
-- Main utility frame with tabs, item grid, and search
-- ============================================================================
local SharedUI = _G.Nozmie_SharedUI
local ConfigHelpers = _G.Nozmie_ConfigHelpers
local Helpers = require("utils.helpers")
local State = require("core.state")
local BannerController = _G.Nozmie_BannerController
local ClickBehavior = _G.Nozmie_ClickBehavior
local IconHandling = _G.Nozmie_IconHandling
local Cooldowns = require("features.cooldowns")
local Keystones = require("features.keystones")
local Messaging = require("utils.messaging")
local Favourites = require("ui.utilities.favourites")
local ContextMenu = require("ui.utilities.context_menu")
local KeystoneIndicators = require("ui.utilities.keystone_indicators")

-- Local aliases for frequently used favourites functions
local GetEntryID = Favourites.GetEntryID
local IsFavourite = Favourites.IsFavourite
local IsFavouriteEntry = Favourites.IsFavouriteEntry
local ToggleFavourite = Favourites.ToggleFavourite

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
local tabHasContentById = {}
local tabOrder = {TAB_CURRENT_DUNGEONS, TAB_LEGACY_DUNGEONS, TAB_TELEPORTS, TAB_UTILITY, TAB_HEARTHSTONE}
local showAllEntriesToggle
local activeSearchQuery = ""
local cooldownUpdateElapsed = 0
local COOLDOWN_UPDATE_INTERVAL = 0.15

local SHOW_ALL_ENTRIES_DB_KEY = "showAllEntriesInUtilityUI"
local SHOW_ALL_TOYS_LEGACY_DB_KEY = "showAllToysInUtilityUI"

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function GetSettings()
    return _G.Nozmie_Settings
end

-- Favourites public API (delegates to ui.utilities.favourites)
function UtilityUI.ToggleFavourite(entryID)   return Favourites.ToggleFavourite(entryID) end
function UtilityUI.IsFavourite(entryID)        return Favourites.IsFavourite(entryID) end
function UtilityUI.GetFavourites()             return Favourites.GetFavouritesTable() end
function UtilityUI.SortEntriesWithFavourites(list) Favourites.SortEntriesWithFavourites(list) end

local function GetShowAllEntriesEnabled()
    local Settings = GetSettings()
    if Settings and Settings.Get then
        local value = Settings.Get(SHOW_ALL_ENTRIES_DB_KEY)
        if value ~= nil then
            return value == true
        end

        return Settings.Get(SHOW_ALL_TOYS_LEGACY_DB_KEY) == true
    end

    local value = State.GetSetting(SHOW_ALL_ENTRIES_DB_KEY)
    if value ~= nil then
        return value == true
    end

    return State.GetSetting(SHOW_ALL_TOYS_LEGACY_DB_KEY) == true
end

local function SetShowAllEntriesEnabled(enabled)
    local Settings = GetSettings()
    if Settings and Settings.Set then
        Settings.Set(SHOW_ALL_ENTRIES_DB_KEY, enabled == true)
        Settings.Set(SHOW_ALL_TOYS_LEGACY_DB_KEY, enabled == true)
        return
    end

    State.SetSetting(SHOW_ALL_ENTRIES_DB_KEY, enabled == true)
    State.SetSetting(SHOW_ALL_TOYS_LEGACY_DB_KEY, enabled == true)
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

local function BuildEntryContextMenuEntries(entryID, data)
    local isFav = entryID and IsFavourite(entryID) or false
    local favLabel = isFav and Lstr("utility.favourites.remove", "Remove from favourites") or
                         Lstr("utility.favourites.add", "Add to favourites")
    return {
        {
            text = favLabel,
            action = function()
                if entryID then
                    ToggleFavourite(entryID)
                    BuildDataCache()
                    RefreshLayout()
                end
            end
        },
        {
            text = Lstr("utility.context.announce", "Announce in chat"),
            action = function()
                Messaging.AnnounceUtility(data)
            end
        },
        {
            text = Lstr("utility.context.copyWowhead", "Copy Wowhead link"),
            action = function() ContextMenu.OpenWowheadForEntry(data) end
        },
    }, function() ContextMenu.OpenWowheadForEntry(data) end
end

local function ShowEntryContextMenu(button)
    if not button or not button.nozmieTooltipData then return end
    local menuEntries, fallback = BuildEntryContextMenuEntries(button.nozmieEntryID, button.nozmieTooltipData)
    ContextMenu.ShowMenu(button, menuEntries, fallback)
end

local function IsTeleportEntry(item)
    if not item then
        return false
    end
    return item.category == "M+ Dungeon" or item.category == "Raid" or item.category == "Teleport" or item.isTeleport == true
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

local function GetEmptyStateMessage()
    if activeSearchQuery ~= "" then
        return string.format(Lstr("utility.search.empty", "No results for '%s'."), activeSearchQuery)
    end

    if selectedTab == TAB_CURRENT_DUNGEONS then
        return Lstr("utility.favourites.empty", "No favourites yet") .. "\n" ..
                   Lstr("utility.favourites.empty.hint", "Right-click an item and choose Add to favourites")
    end

    return Lstr("utility.tab.empty", "No entries available in this tab.")
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
        if item and ItemMatchesTab(item, tabId) then
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
    tabHasContentById = {}

    for _, tabId in ipairs(tabOrder) do
        local tab = tabButtons[tabId]
        if tab then
            tabCount = tabCount + 1
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
        if not hasContent then
            fontString:SetTextColor(0.45, 0.45, 0.45)
        else
            fontString:SetTextColor(1, 0.82, 0)
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

local function ApplyFavouriteIconColor(toggle, isFav)
    if not toggle or not toggle.iconTexture then
        return
    end

    local icon = toggle.iconTexture
    if isFav then
        icon:SetVertexColor(1, 0.88, 0.25, 1)
        icon:SetAlpha(1)
    else
        icon:SetVertexColor(0.72, 0.72, 0.72, 1)
        icon:SetAlpha(0.85)
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
                 ContextMenu.OpenWowheadForEntry(self.nozmieUnavailableData)
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
        favouriteToggle:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 6, 6)
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
        ApplyFavouriteIconColor(button.favouriteToggle, isFav)
    end

    button.favouriteToggle:SetShown(isFav)

    if oldState ~= nil and oldState ~= isFav and isFav and button.favouriteToggle.popAnim then
        button.favouriteToggle.popAnim:Stop()
        button.favouriteToggle.popAnim:Play()
    end
    button.nozmieLastFavState = isFav
end

local function RefreshDungeonIndicators(dungeonID)
    KeystoneIndicators.RefreshAll(buttons, dungeonID)
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
    if Cooldowns and Cooldowns.CanPlayerUseUtility then
        return Cooldowns.CanPlayerUseUtility(item)
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

    Favourites.SeedDefaultFavourites()

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

    Favourites.SortEntriesWithFavourites(dataCache)
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

    if query and query ~= "" then
        for _, item in ipairs(dataCache) do
            if item and MatchesSearch(item, query) then
                table.insert(filteredData, item)
            end
        end
    else
        for _, item in ipairs(dataCache) do
            local matchesTab = ItemMatchesTab(item, selectedTab)

            if item and matchesTab then
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

local function ConfigureUnavailableButton(button)
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

local function ApplyEntryTextAndStyle(button, data, isUnavailable, isFav)
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
end

local function UpdateEntryHotkey(button, data, isUnavailable)
    if not button.hotkey then
        return
    end

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

local function UpdateEntryCooldown(button, data, isUnavailable)
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
end

local function PositionGridButton(button, contentWidth, columns, col, row)
    local x = col * (contentWidth / columns)
    local y = row * (ROW_HEIGHT + GRID_PADDING)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    button:SetWidth((contentWidth / columns) - GRID_PADDING)
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
        if frame and frame.nozmieEmptyStateText then
            frame.nozmieEmptyStateText:SetText(GetEmptyStateMessage())
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

        button.nozmieTooltipData = data
        button.nozmieUnavailable = isUnavailable
        button.nozmieUnavailableData = isUnavailable and data or nil
        UpdateFavouriteToggle(button, data)
        KeystoneIndicators.Apply(button, data)
        ApplyEntryTextAndStyle(button, data, isUnavailable, isFav)

        if not IsCombatLocked() then
            if isUnavailable then
                ConfigureUnavailableButton(button)
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

        UpdateEntryHotkey(button, data, isUnavailable)
        UpdateEntryCooldown(button, data, isUnavailable)
        PositionGridButton(button, width, columns, col, row)
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
    showAllEntriesToggle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 0)
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
        cooldownUpdateElapsed = cooldownUpdateElapsed + (elapsed or 0)
        if cooldownUpdateElapsed < COOLDOWN_UPDATE_INTERVAL then
            return
        end
        cooldownUpdateElapsed = 0
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
            Keystones.CleanupGroupKeyReportsForCurrentGroup()
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
