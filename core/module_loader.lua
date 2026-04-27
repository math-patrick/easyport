-- ============================================================================
-- Nozmie - Lightweight Module Loader
-- Provides a WoW-safe `require` shim backed by already-loaded global modules.
-- ============================================================================

local previousRequire = type(_G.require) == "function" and _G.require ~= _G.Nozmie_Require and _G.require or nil
local moduleCache = {}

local moduleToGlobal = {
    ["core.events"] = "Nozmie_EventBus",
    ["core.state"] = "Nozmie_State",
    ["utils.constants"] = "Nozmie_Constants",
    ["utils.helpers"] = "Nozmie_Helpers",
    ["utils.messaging"] = "Nozmie_Messaging",
    ["db.data"] = "Nozmie_DBData",
    ["db.savedvariables"] = "Nozmie_SavedVariables",
    ["features.detection"] = "Nozmie_Detection",
    ["features.keystones"] = "Nozmie_Keystones",
    ["features.favourites"] = "Nozmie_FeatureFavourites",
    ["features.cooldowns"] = "Nozmie_Cooldowns",
    ["ui.banner.helpers"] = "Nozmie_BannerHelpers",
    ["ui.banner.init"] = "Nozmie_BannerUI",
    ["ui.settings.init"] = "Nozmie_Settings",
    ["ui.utilities.config_helpers"] = "Nozmie_ConfigHelpers",
    ["ui.utilities.icon_renderer"] = "Nozmie_IconRenderer",
    ["ui.utilities.click_behavior"] = "Nozmie_ClickBehavior",
    ["ui.utilities.icon_handling"] = "Nozmie_IconHandling",
    ["ui.utilities.button"] = "Nozmie_UtilityButton",
    ["ui.utilities.init"] = "Nozmie_Utilities",
    ["ui.utilities.favourites"] = "Nozmie_UIFavourites",
    ["ui.utilities.context_menu"] = "Nozmie_ContextMenu",
    ["ui.utilities.keystone_indicators"] = "Nozmie_KeystoneIndicators",
    ["ui.utilities.panel"] = "Nozmie_UtilityUI",
    ["ui.banner.panel"] = "Nozmie_BannerUI",
    ["ui.banner.controller"] = "Nozmie_BannerController",
    ["ui.shared"] = "Nozmie_SharedUI",
    ["ui.minimap"] = "Nozmie_Minimap",
}

_G.Nozmie_Require = function(moduleName)
    if type(moduleName) ~= "string" or moduleName == "" then
        error("Nozmie require: invalid module name", 2)
    end

    local cached = moduleCache[moduleName]
    if cached ~= nil then
        return cached
    end

    local globalName = moduleToGlobal[moduleName]
    local module = globalName and _G[globalName] or nil
    if module ~= nil then
        moduleCache[moduleName] = module
        return module
    end

    if previousRequire then
        return previousRequire(moduleName)
    end

    error("Nozmie require: module not loaded: " .. moduleName, 2)
end

_G.require = _G.Nozmie_Require
