-- ============================================================================
-- Nozmie - UI Settings Module Index
-- Manages in-game settings panel and persistent variables
-- ============================================================================

local State = require("core.state")

local SettingsUI = {}
local settingsCategoryID

-- Blacklist edit popup (defined at module level so it's available regardless of load order)
StaticPopupDialogs["NOZMIE_BLACKLIST_EDIT"] = StaticPopupDialogs["NOZMIE_BLACKLIST_EDIT"] or {
    text    = "Set blacklisted words (comma-separated):",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 255,
    OnShow = function(self)
        if self.editBox then
            self.editBox:SetText((_G.Nozmie_Settings and _G.Nozmie_Settings.Get and _G.Nozmie_Settings.Get("blacklistedWords")) or "")
            self.editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        if self.editBox and _G.Nozmie_Settings and _G.Nozmie_Settings.Set then
            local text = self.editBox:GetText() or ""
            _G.Nozmie_Settings.Set("blacklistedWords", text:match("^%s*(.-)%s*$"))
        end
    end,
    EditBoxOnEnterPressed = function(self)
        if _G.Nozmie_Settings and _G.Nozmie_Settings.Set then
            local text = self:GetText() or ""
            _G.Nozmie_Settings.Set("blacklistedWords", text:match("^%s*(.-)%s*$"))
        end
        StaticPopup_Hide("NOZMIE_BLACKLIST_EDIT")
    end,
    timeout = 0,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CopyDefaultValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = CopyDefaultValue(nestedValue)
    end
    return copy
end

-- ============================================================================
-- Settings Database Management
-- ============================================================================

-- Initialize settings database with defaults
function SettingsUI.InitializeDB()
    State.InitializeDB()
    
    -- Default settings structure
    local defaults = {
        enabled = true,
        showBanner = true,
        autoHideBanner = true,
        bannerTimeout = 10,
        minimapIcon = true,
        hideDragIcon = false,
        detectInSay = true,
        detectInParty = true,
        detectInRaid = true,
        detectInGuild = false,
        detectInWhisper = true,
        detectChatList = {"say", "party", "raid", "whisper"},
        trackGroupKeysFromChatLinks = true,
        disableAutoKeyResponse = false,
        showKeystoneIndicators = true,
        announceToGroup = false,
        showAllEntriesInUtilityUI = false,
        showAllToysInUtilityUI = false,
        bannerPosition = { x = 0, y = 0, width = 300, height = 100, point = "CENTER" },
        suppressGlobalList = { "teleports" },
        suppressInstanceList = {},
        blacklistedWords = "",
        preferPortals = false,
        announceCustoms = true,
        announceKeystones = true
    }
    
    -- Apply defaults for missing keys
    for key, value in pairs(defaults) do
        if State.GetSetting(key) == nil then
            State.SetSetting(key, CopyDefaultValue(value))
        end
    end
end

-- ============================================================================
-- Settings Access
-- ============================================================================

-- Get a setting value
function SettingsUI.Get(key)
    SettingsUI.InitializeDB()
    return State.GetSetting(key)
end

-- Set a setting value
function SettingsUI.Set(key, value)
    SettingsUI.InitializeDB()
    State.SetSetting(key, value)
end

-- Toggle a boolean setting
function SettingsUI.Toggle(key)
    local current = SettingsUI.Get(key)
    SettingsUI.Set(key, not current)
    return not current
end

-- ============================================================================
-- Settings Panel Integration
-- ============================================================================

-- Register a setting with the WoW settings panel
function SettingsUI.RegisterSetting(category, variable, varType, name, default, getter, setter)
    if _G.Settings and _G.Settings.RegisterProxySetting then
        return _G.Settings.RegisterProxySetting(category, variable, varType, name, default, getter, setter)
    end
end

-- Get or create settings category
function SettingsUI.GetCategory()
    if _G.SettingsPanel and _G.Settings then
        return _G.SettingsPanel:GetCategory("Nozmie") or _G.SettingsPanel:New("Nozmie")
    end
end

function SettingsUI.CreatePanel()
    if settingsCategoryID then
        return settingsCategoryID
    end

    if not (_G.Settings and _G.Settings.RegisterVerticalLayoutCategory and _G.Settings.RegisterAddOnCategory) then
        return nil
    end

    SettingsUI.InitializeDB()

    local locale = _G.Nozmie_Locale
    local function Lstr(key, fallback)
        if locale and locale.GetString then return locale.GetString(key, fallback) end
        return fallback or key
    end

    -- RegisterVerticalLayoutCategory returns (category, layout)
    local category, layout = _G.Settings.RegisterVerticalLayoutCategory(Lstr("addon.name", "Nozmie"))

    local function Header(text)
        if layout and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end

    local function AddCheckbox(settingKey, labelKey, labelFallback, tooltipKey, tooltipFallback, default)
        local var = _G.Settings.RegisterProxySetting(
            category, "Nozmie_" .. settingKey,
            _G.Settings.VarType.Boolean, Lstr(labelKey, labelFallback), default,
            function() return SettingsUI.Get(settingKey) end,
            function(value) SettingsUI.Set(settingKey, value) end)
        _G.Settings.CreateCheckbox(category, var, function()
            return Lstr(tooltipKey, tooltipFallback)
        end)
        return var
    end

    -- === General ===
    Header(Lstr("settings.section.general", "General"))
    AddCheckbox("enabled",        "settings.enable",        "Enable Nozmie",      "settings.enable.tooltip",        "Enable or disable utility detection",                  true)
    AddCheckbox("showBanner",     "settings.showBanner",    "Show Banner",        "settings.showBanner.tooltip",    "Display the utility banner when matches are found",    true)
    AddCheckbox("preferPortals",  "settings.preferPortals", "Prefer Portals",     "settings.preferPortals.tooltip", "Prioritize portals over teleports when both match",    false)
    AddCheckbox("announceToGroup","settings.announceToGroup","Announce to Group", "settings.announceToGroup.tooltip","Announce to group when you click a utility",           false)

    -- === Chat Detection ===
    Header(Lstr("settings.section.chat", "Chat Detection"))

    -- Multi-select dropdown (detectChatList is mirrored to NozmieDB.detectChatList by State.SetSetting)
    if layout and _G.Settings.CreateControlTextContainer and _G.Settings.CreateControlInitializer then
        local function GetChatOptions()
            local container = _G.Settings.CreateControlTextContainer()
            container:Add("say",     Lstr("settings.chat.option.say",     "Say"))
            container:Add("party",   Lstr("settings.chat.option.party",   "Party"))
            container:Add("raid",    Lstr("settings.chat.option.raid",    "Raid"))
            container:Add("guild",   Lstr("settings.chat.option.guild",   "Guild"))
            container:Add("whisper", Lstr("settings.chat.option.whisper", "Whisper"))
            return container:GetData()
        end
        local chatVar = _G.Settings.RegisterProxySetting(category, "NOZMIE_CHAT_CHANNELS",
            _G.Settings.VarType.String, Lstr("settings.detectChat.label", "Chat Channels"), "",
            function() return "" end, function() end)
        chatVar.variableKey = "detectChatList"
        local chatInit = _G.Settings.CreateControlInitializer("NozmieSettingsMultiSelectDropDownTemplate",
            chatVar, GetChatOptions,
            Lstr("settings.detectChat.tooltip", "Select chat channels to monitor for utility requests."))
        layout:AddInitializer(chatInit)
    end

    AddCheckbox("disableAutoKeyResponse",     "settings.disableAutoKeyResponse",     "Do not auto-share my key on !keys", "settings.disableAutoKeyResponse.tooltip",     "Nozmie will not post your keystone in response to !keys",  false)
    AddCheckbox("trackGroupKeysFromChatLinks","settings.trackGroupKeysFromChatLinks","Track group keys from chat links",  "settings.trackGroupKeysFromChatLinks.tooltip","Parse keystone links posted by addons in party/raid chat",  true)
    AddCheckbox("showKeystoneIndicators",     "settings.showKeystoneIndicators",     "Show keystone indicators",         "settings.showKeystoneIndicators.tooltip",     "Adds a key marker on M+ dungeon entries in the utility UI", true)

    -- === Suppression ===
    if layout and _G.Settings.CreateControlTextContainer and _G.Settings.CreateControlInitializer then
        Header(Lstr("settings.suppression.heading", "Suppression Filters"))
        local function GetSuppressionOptions()
            local container = _G.Settings.CreateControlTextContainer()
            container:Add("mount",          Lstr("settings.suppress.option.mount",          "Mounts"))
            container:Add("class",          Lstr("settings.suppress.option.class",          "Class Utility"))
            container:Add("utilityservice", Lstr("settings.suppress.option.utilityservice", "Utility/Service"))
            container:Add("teleports",      Lstr("settings.suppress.option.teleports",      "Portals/Teleports"))
            return container:GetData()
        end
        local function AddSuppressDropdown(varName, dbKey, labelKey, labelFallback, tooltipKey, tooltipFallback)
            local sv = _G.Settings.RegisterProxySetting(category, varName,
                _G.Settings.VarType.String, Lstr(labelKey, labelFallback), "",
                function() return "" end, function() end)
            sv.variableKey = dbKey
            layout:AddInitializer(_G.Settings.CreateControlInitializer(
                "NozmieSettingsMultiSelectDropDownTemplate", sv, GetSuppressionOptions,
                Lstr(tooltipKey, tooltipFallback)))
        end
        AddSuppressDropdown("NOZMIE_SUPPRESS_GLOBAL",   "suppressGlobalList",
            "settings.suppress.global.label",   "Global Suppressions",
            "settings.suppress.global.tooltip", "Select categories to suppress everywhere.")
        AddSuppressDropdown("NOZMIE_SUPPRESS_INSTANCE", "suppressInstanceList",
            "settings.suppress.instance.label",   "Instance Suppressions",
            "settings.suppress.instance.tooltip", "Select categories to suppress only while in instances.")
    end

    -- === Banner ===
    Header(Lstr("settings.section.banner", "Banner"))
    AddCheckbox("autoHideBanner", "settings.autoHideBanner", "Auto-hide Banner", "settings.autoHideBanner.tooltip", "Automatically hide banner after timeout", true)

    if _G.Settings.CreateSlider and _G.Settings.CreateSliderOptions then
        local sliderVar = _G.Settings.RegisterProxySetting(
            category, "Nozmie_bannerTimeout",
            _G.Settings.VarType.Number, Lstr("settings.bannerTimeout", "Banner Timeout (Seconds)"), 10,
            function() return SettingsUI.Get("bannerTimeout") end,
            function(value) SettingsUI.Set("bannerTimeout", math.floor(value)) end)
        local sliderOpts = _G.Settings.CreateSliderOptions(3, 30, 1)
        sliderOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format("%d sec", math.floor(value)) end)
        _G.Settings.CreateSlider(category, sliderVar, sliderOpts, function()
            return Lstr("settings.bannerTimeout.tooltip", "How long the banner stays visible before auto-hiding (3-30 seconds)")
        end)
    end

    -- === Appearance ===
    Header(Lstr("settings.section.appearance", "Appearance"))
    AddCheckbox("hideDragIcon", "settings.hideDragIcon", "Hide Drag Icon",  "settings.hideDragIcon.tooltip",  "Hide the drag handle on the banner",               false)
    local minimapVar = AddCheckbox("minimapIcon", "settings.minimapIcon", "Minimap Icon", "settings.minimapIcon.tooltip", "Show a minimap icon for reopening the last banner", true)
    if minimapVar then
        minimapVar:SetValueChangedCallback(function()
            if _G.Nozmie_Minimap then _G.Nozmie_Minimap.UpdateVisibility() end
        end)
    end

    -- === Blacklist ===
    Header(Lstr("settings.section.blacklist", "Blacklist"))
    if layout and _G.Settings.RegisterProxySetting and _G.Settings.CreateControlInitializer then
        local blVar = _G.Settings.RegisterProxySetting(category, "NOZMIE_BLACKLIST_BUTTON",
            _G.Settings.VarType.String, Lstr("blacklist.edit.label", "Blacklisted Words"), "",
            function() return "" end, function() end)
        local blInit = _G.Settings.CreateControlInitializer("NozmieSettingsActionButtonTemplate", blVar, nil,
            Lstr("blacklist.edit.tooltip", "Open a dialog to edit blacklisted words (comma-separated)."))
        blInit.data = {
            buttonText = Lstr("blacklist.edit.button", "Edit"),
            tooltip    = Lstr("blacklist.edit.tooltip", "Open a dialog to edit blacklisted words (comma-separated)."),
            onClick    = function() StaticPopup_Show("NOZMIE_BLACKLIST_EDIT") end,
        }
        layout:AddInitializer(blInit)
    end

    _G.Settings.RegisterAddOnCategory(category)

    if category and category.GetID then
        settingsCategoryID = category:GetID()
    end

    return settingsCategoryID
end

function SettingsUI.Show()
    if not (_G.Settings and _G.Settings.OpenToCategory) then
        return
    end

    if not settingsCategoryID then
        SettingsUI.CreatePanel()
    end

    if settingsCategoryID then
        _G.Settings.OpenToCategory(settingsCategoryID)
    end
end

_G.Nozmie_Settings = SettingsUI
return SettingsUI