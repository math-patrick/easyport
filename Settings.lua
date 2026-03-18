-- ============================================================================
-- Nozmie - Settings Module
-- In-game settings panel accessible via ESC > Options > Addons > Nozmie
-- ============================================================================
local SettingsModule = {}
local category

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

_G.NozmieSettingsMultiSelectDropDownMixin = _G.NozmieSettingsMultiSelectDropDownMixin or {}

local function SetupMultiSelectDropdown(dropdown, setting, options, initTooltip)
    local function Inserter(setting, rootDescription)
        local function IsSelected(value)
            local values = NozmieDB and NozmieDB[setting.variableKey]
            if values == nil then
                return false
            end
            for _, entry in ipairs(values) do
                if entry == value then
                    return true
                end
            end
            return false
        end

        local function SetSelected(value)
            if not NozmieDB then
                return
            end
            local values = NozmieDB[setting.variableKey]
            if type(values) ~= "table" then
                values = {}
                NozmieDB[setting.variableKey] = values
            end
            for i, entry in ipairs(values) do
                if entry == value then
                    table.remove(values, i)
                    return
                end
            end
            table.insert(values, value)
        end

        local data = options()
        for _, option in ipairs(data) do
            rootDescription:CreateCheckbox(option.label, IsSelected, SetSelected, option.value)
        end
    end

    _G.Settings.InitDropdown(dropdown, setting, Inserter, initTooltip)
end

function _G.NozmieSettingsMultiSelectDropDownMixin:SetupDropdownMenu(button, setting, options, initTooltip)
    SetupMultiSelectDropdown(self.Control.Dropdown, setting, options, initTooltip)
    self.Control.Dropdown:SetSelectionText(function()
        local values = NozmieDB and NozmieDB[setting.variableKey]
        local count = values and #values or 0
        return string.format(Lstr("settings.multiselect.count", "%d selected"), count)
    end)
    self.Control.Dropdown:GenerateMenu()
    self.Control.IncrementButton:Hide()
    self.Control.DecrementButton:Hide()
end

local function CreateMultiSelectDropdown(category, variable, key, name, options, tooltip)
    local function GetValue()
        return ""
    end

    local function SetValue()
    end

    local setting = _G.Settings.RegisterProxySetting(category, variable, _G.Settings.VarType.String, name, "", GetValue,
        SetValue)
    local initializer = _G.Settings.CreateControlInitializer("NozmieSettingsMultiSelectDropDownTemplate", setting,
        options, tooltip)

    initializer.data.setting.variableKey = key

    local layout = _G.SettingsPanel:GetLayout(category)
    layout:AddInitializer(initializer)
end

-- Initialize settings database
function SettingsModule.InitializeDB()
    if not NozmieDB then
        NozmieDB = {}
    end

    -- Default settings with their default values
    local defaults = {
        enabled = true,
        showBanner = true,
        preferPortals = true,
        autoHideBanner = true,
        hideDragIcon = false,
        minimapIcon = true,
        bannerTimeout = 10,
        detectInSay = true,
        detectInParty = true,
        detectInRaid = true,
        detectInGuild = false,
        detectInWhisper = true,
        suppressInInstances = false,
        suppressGlobalList = {},
        suppressInstanceList = {},
        suppressGlobalMount = false,
        suppressGlobalClass = false,
        suppressGlobalToy = false,
        suppressGlobalHome = false,
        suppressGlobalUtility = false,
        suppressGlobalMPlus = false,
        suppressGlobalRaid = false,
        suppressGlobalDelve = false,
        suppressGlobalService = false,
        suppressGlobalTransmog = false,
        suppressGlobalHearthstone = false,
        suppressInstanceMount = false,
        suppressInstanceClass = false,
        suppressInstanceToy = false,
        suppressInstanceHome = false,
        suppressInstanceUtility = false,
        suppressInstanceMPlus = false,
        suppressInstanceRaid = false,
        suppressInstanceDelve = false,
        suppressInstanceService = false,
        suppressInstanceTransmog = false,
        suppressInstanceHearthstone = false,
        blacklistedWords = "",
        announceToGroup = false,
        showAllEntriesInUtilityUI = false,
        showAllToysInUtilityUI = false
    }

    -- Apply defaults for any missing settings
    for key, value in pairs(defaults) do
        if NozmieDB[key] == nil then
            NozmieDB[key] = value
        end
    end

    if type(NozmieDB.minimap) ~= "table" then
        NozmieDB.minimap = {}
    end
    if NozmieDB.minimap.minimapPos == nil then
        NozmieDB.minimap.minimapPos = 220
    end
    NozmieDB.minimap.hide = not NozmieDB.minimapIcon

    do
        local list = {}
        local migration = {
            mount = "suppressGlobalMount",
            class = "suppressGlobalClass",
            toy = "suppressGlobalToy",
            home = "suppressGlobalHome",
            utility = "suppressGlobalUtility",
            mplus = "suppressGlobalMPlus",
            raid = "suppressGlobalRaid",
            delve = "suppressGlobalDelve",
            service = "suppressGlobalService",
            transmog = "suppressGlobalTransmog",
            hearthstone = "suppressGlobalHearthstone"
        }
        local hasLegacy = false
        for key, oldKey in pairs(migration) do
            if NozmieDB[oldKey] then
                hasLegacy = true
                table.insert(list, key)
            end
        end
        if NozmieDB.suppressGlobalList == nil or (#NozmieDB.suppressGlobalList == 0 and hasLegacy) then
            NozmieDB.suppressGlobalList = list
        end
    end

    do
        local list = {}
        local migration = {
            mount = "suppressInstanceMount",
            class = "suppressInstanceClass",
            toy = "suppressInstanceToy",
            home = "suppressInstanceHome",
            utility = "suppressInstanceUtility",
            mplus = "suppressInstanceMPlus",
            raid = "suppressInstanceRaid",
            delve = "suppressInstanceDelve",
            service = "suppressInstanceService",
            transmog = "suppressInstanceTransmog",
            hearthstone = "suppressInstanceHearthstone"
        }
        local hasLegacy = false
        for key, oldKey in pairs(migration) do
            if NozmieDB[oldKey] then
                hasLegacy = true
                table.insert(list, key)
            end
        end
        if NozmieDB.suppressInstanceList == nil or (#NozmieDB.suppressInstanceList == 0 and hasLegacy) then
            NozmieDB.suppressInstanceList = list
        end
    end

    if type(NozmieDB.detectChatList) ~= "table" then
        local list = {}
        if NozmieDB.detectInSay then
            table.insert(list, "say")
        end
        if NozmieDB.detectInParty then
            table.insert(list, "party")
        end
        if NozmieDB.detectInRaid then
            table.insert(list, "raid")
        end
        if NozmieDB.detectInGuild then
            table.insert(list, "guild")
        end
        if NozmieDB.detectInWhisper then
            table.insert(list, "whisper")
        end
        if #list == 0 then
            list = {"say", "party", "raid", "whisper"}
        end
        NozmieDB.detectChatList = list
    end
end

-- Get a setting value
function SettingsModule.Get(key)
    SettingsModule.InitializeDB()
    return NozmieDB[key]
end

-- Set a setting value
function SettingsModule.Set(key, value)
    SettingsModule.InitializeDB()
    NozmieDB[key] = value
end

local function AddSuppressionSection(category, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        Lstr("settings.suppression.heading", "Suppression Filters")))

    local function GetSuppressionOptions()
        local container = _G.Settings.CreateControlTextContainer()
        container:Add("mount", Lstr("settings.suppress.option.mount", "Mounts"))
        container:Add("class", Lstr("settings.suppress.option.class", "Class Utility"))
        container:Add("utilityservice", Lstr("settings.suppress.option.utilityservice", "Utility/Service"))
        container:Add("teleports", Lstr("settings.suppress.option.teleports", "Portals/Teleports"))
        return container:GetData()
    end

    CreateMultiSelectDropdown(category, "NOZMIE_SUPPRESS_GLOBAL", "suppressGlobalList",
        Lstr("settings.suppress.global.label", "Global Suppressions"), GetSuppressionOptions,
        Lstr("settings.suppress.global.tooltip", "Select categories to suppress everywhere."))

    CreateMultiSelectDropdown(category, "NOZMIE_SUPPRESS_INSTANCE", "suppressInstanceList",
        Lstr("settings.suppress.instance.label", "Instance Suppressions"), GetSuppressionOptions, Lstr(
            "settings.suppress.instance.tooltip", "Select categories to suppress only while in instances."))
end

-- Create the settings panel using modern Settings API
function SettingsModule.CreatePanel()
    -- Initialize database first
    SettingsModule.InitializeDB()

    -- Create main category with vertical layout
    local categoryName = Lstr("addon.name", "Nozmie")
    category, layout = _G.Settings.RegisterVerticalLayoutCategory(categoryName)
    _G.Settings.RegisterAddOnCategory(category)

    -- General Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(Lstr("settings.section.general", "General")))

    local variable, name, tooltip = "enabled", Lstr("settings.enable", "Enable Nozmie"),
        Lstr("settings.enable.tooltip", "Enable or disable teleport detection")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, true)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    -- Chat Detection Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(Lstr("settings.section.chat", "Chat Detection")))

    local function GetChatOptions()
        local container = _G.Settings.CreateControlTextContainer()
        container:Add("say", Lstr("settings.chat.option.say", "Say"))
        container:Add("party", Lstr("settings.chat.option.party", "Party"))
        container:Add("raid", Lstr("settings.chat.option.raid", "Raid"))
        container:Add("guild", Lstr("settings.chat.option.guild", "Guild"))
        container:Add("whisper", Lstr("settings.chat.option.whisper", "Whisper"))
        return container:GetData()
    end

    CreateMultiSelectDropdown(category, "NOZMIE_CHAT_CHANNELS", "detectChatList",
        Lstr("settings.detectChat.label", "Chat Channels"), GetChatOptions, Lstr("settings.detectChat.tooltip",
            "Select chat channels to monitor for teleport requests."))

    -- Suppression Section
    AddSuppressionSection(category, layout)

    -- Banner Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(Lstr("settings.section.banner", "Banner")))

    local variable, name, tooltip = "showBanner", Lstr("settings.showBanner", "Show Banner"), Lstr(
        "settings.showBanner.tooltip", "Display the teleport banner when matches are found")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, true)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    -- Prefer Portals Option
    local variable, name, tooltip = "preferPortals", Lstr("settings.preferPortals", "Prefer Portals"), Lstr(
        "settings.preferPortals.tooltip", "Prioritize portals over teleports when both match")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, true)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    -- Announce to Group Option
    local variable, name, tooltip = "announceToGroup", Lstr("settings.announceToGroup", "Announce to Group"), Lstr(
        "settings.announceToGroup.tooltip", "Announce to group when casting utility spells, mounts, repair, mail, etc.")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, false)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    local variable, name, tooltip = "autoHideBanner", Lstr("settings.autoHideBanner", "Auto-hide Banner"),
        Lstr("settings.autoHideBanner.tooltip", "Automatically hide banner after timeout")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, true)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    local variable, name, tooltip = "bannerTimeout", Lstr("settings.bannerTimeout", "Banner Timeout (Seconds)"), Lstr(
        "settings.bannerTimeout.tooltip", "How long to display the banner before auto-hiding (3-30 seconds)")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Number, name, 10)
    local options = _G.Settings.CreateSliderOptions(3, 30, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return string.format("%d sec", value)
    end)
    _G.Settings.CreateSlider(category, setting, options, tooltip)

    -- Appearance Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(Lstr("settings.section.appearance", "Appearance")))

    local variable, name, tooltip = "hideDragIcon", Lstr("settings.hideDragIcon", "Hide Drag Icon"),
        Lstr("settings.hideDragIcon.tooltip", "Hide the drag handle on the banner")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, false)
    _G.Settings.CreateCheckbox(category, setting, tooltip)

    local variable, name, tooltip = "minimapIcon", Lstr("settings.minimapIcon", "Minimap Icon"), Lstr(
        "settings.minimapIcon.tooltip", "Show a minimap icon for reopening the last banner")
    local setting = _G.Settings.RegisterAddOnSetting(category, "Nozmie_" .. variable, variable, NozmieDB,
        _G.Settings.VarType.Boolean, name, false)
    _G.Settings.CreateCheckbox(category, setting, tooltip)
    setting:SetValueChangedCallback(function()
        if _G.Nozmie_Minimap then
            _G.Nozmie_Minimap.UpdateVisibility()
        end
    end)

    -- Blacklist Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(Lstr("settings.section.blacklist", "Blacklist")))

    local function GetValue()
        return ""
    end

    local function SetValue()
    end

    local setting = _G.Settings.RegisterProxySetting(category, "NOZMIE_BLACKLIST_BUTTON", _G.Settings.VarType.String,
        Lstr("blacklist.edit.label", "Blacklisted Words"), "", GetValue, SetValue)
    local initializer = _G.Settings.CreateControlInitializer("NozmieSettingsActionButtonTemplate", setting, nil, Lstr(
        "blacklist.edit.tooltip", "Open a dialog to edit blacklisted words (comma-separated)."))
    initializer.data = {
        buttonText = Lstr("blacklist.edit.button", "Edit Blacklisted Words"),
        tooltip = Lstr("blacklist.edit.tooltip", "Open a dialog to edit blacklisted words (comma-separated)."),
        onClick = function()
            StaticPopup_Show("NOZMIE_BLACKLIST_INPUT")
        end
    }
    local layout = _G.SettingsPanel:GetLayout(category)
    layout:AddInitializer(initializer)

    return category
end

-- Show settings panel
function SettingsModule.Show()
    if category then
        _G.Settings.OpenToCategory(category:GetID())
    end
end

-- Confirmation dialog for blacklist editing
StaticPopupDialogs["NOZMIE_BLACKLIST_INPUT"] = {
    text = Lstr("popup.blacklist.text", "Set blacklisted words (comma-separated):"),
    button1 = Lstr("popup.blacklist.save", "Save"),
    button2 = Lstr("popup.blacklist.cancel", "Cancel"),
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local editBox = self.editBox or self:GetEditBox()
        local current = SettingsModule.Get("blacklistedWords") or ""
        editBox:SetText(current)
        editBox:SetAutoFocus(true)
        editBox:HighlightText()
    end,
    OnAccept = function(self)
        local editBox = self.editBox or self:GetEditBox()
        local value = editBox:GetText() or ""
        SettingsModule.Set("blacklistedWords", value)
        local message = string.format(Lstr("cmd.blacklist.updated", "Blacklist updated to: %s"),
            "|cffFFFFFF" .. value .. "|r")
        print("|cff00ff00Nozmie:|r " .. message)
    end,
    OnHide = function(self)
        local editBox = self.editBox or self:GetEditBox()
        editBox:SetText("")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

_G.Nozmie_Settings = SettingsModule

