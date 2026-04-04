-- ============================================================================
-- Nozmie - Main Initialization & Event Dispatcher
-- ============================================================================

local EventBus = require("core.events")
local State = require("core.state")
local Constants = require("utils.constants")
local Helpers = require("utils.helpers")
local Detection = require("features.detection")
local Keystones = require("features.keystones")
local Messaging = require("utils.messaging")

-- UI and settings resolved at runtime (loaded after core)
local function GetBannerUI() return _G.Nozmie_BannerUI end
local function GetBannerController() return _G.Nozmie_BannerController end
local function GetSettings() return _G.Nozmie_Settings end
local function GetMinimap() return _G.Nozmie_Minimap end

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

-- ============================================================================
-- Module State
-- ============================================================================

local Init = {}
local banner
local pendingMatches = {}
local recentKeyRequestsBySender = {}
local recentParsedKeyMessages = {}
local initialized = false

-- ============================================================================
-- Helper Functions (Refactored to use new infrastructure)
-- ============================================================================

local function shouldSkipDuplicateKeyMessage(sender, message)
    if not sender or not message then
        return false
    end
    
    local key = string.format("%s|%s", sender, message)
    local now = GetTime()
    local lastSeen = recentParsedKeyMessages[key]
    
    if lastSeen and (now - lastSeen) < Constants.DUPLICATE_MESSAGE_WINDOW then
        return true
    end
    
    recentParsedKeyMessages[key] = now
    return false
end

local function refreshGroupKeysUI()
    local utilityUI = _G.Nozmie_UtilityUI
    if utilityUI and utilityUI.RefreshGroupKeys then
        utilityUI.RefreshGroupKeys()
    end
end

local function updateDungeonUI(dungeonID)
    local utilityUI = _G.Nozmie_UtilityUI
    if utilityUI and utilityUI.UpdateDungeonUI then
        utilityUI.UpdateDungeonUI(dungeonID)
    else
        refreshGroupKeysUI()
    end
end

local function queueMatches(matches)
    if not matches or #matches == 0 then return end
    
    for _, match in ipairs(matches) do
        table.insert(pendingMatches, match)
    end
end

-- ============================================================================
-- Group Key Handling (Refactored)
-- ============================================================================

local function handleGroupKeyMessage(event, message, sender)
    local channel = Constants.GROUP_KEY_CHANNELS[event]
    if not channel or not message then
        return false
    end

    local trimmed = message:trim()
    local lowered = trimmed:lower()
    
    -- Handle !keys request
    if lowered == "!keys" then
        local Settings = GetSettings()
        if Settings and Settings.Get("disableAutoKeyResponse") then
            return true
        end

        local senderName = Helpers.NormalizePlayerName(sender) or "unknown"
        local now = GetTime()
        local lastSeen = recentKeyRequestsBySender[senderName]
        
        if lastSeen and (now - lastSeen) < Constants.DUPLICATE_KEY_REQUEST_WINDOW then
            return true
        end
        
        recentKeyRequestsBySender[senderName] = now
        
        if Keystones.SendOwnedKeystoneToChannel(channel) then
            refreshGroupKeysUI()
        end
        return true
    end

    -- Handle !nozmie and !mykey reports
    if lowered:find("!nozmie", 1, true) == 1 or lowered:find("!mykey", 1, true) == 1 then
        local report = Keystones.ParseKeystoneReportMessage(trimmed)
        if report then
            if report.hasKey then
                Keystones.RecordGroupKeyReport(sender, report.mapName, report.level, report.mapID, report.link)
            else
                Keystones.RecordGroupKeyReport(sender, nil, nil)
            end
            refreshGroupKeysUI()
            return true
        end
    end

    -- Handle keystone links from chat
    local Settings = GetSettings()
    local trackLinks = Settings and Settings.Get("trackGroupKeysFromChatLinks")
    if trackLinks ~= false and trimmed:find("|Hkeystone:", 1, true) and not shouldSkipDuplicateKeyMessage(sender, trimmed) then
        local parsed = Keystones.ParseKeystoneLink(trimmed, sender)
        if parsed and parsed.dungeonID and Keystones.StoreDetectedKey(parsed.playerName or sender, parsed.dungeonID, parsed.level, parsed.link) then
            refreshGroupKeysUI()
            return true
        end
    end

    return false
end

-- ============================================================================
-- Chat Message Filtering (Refactored)
-- ============================================================================

function Init.OnChatMessage(self, event, message, sender)
    local Settings = GetSettings()
    local BannerController = GetBannerController()
    -- Check if addon is enabled
    if not (Settings and Settings.Get("enabled")) then
        return false
    end

    -- Handle group key coordination
    if handleGroupKeyMessage(event, message, sender) then
        return false
    end

    -- Check if we should monitor this chat type
    local shouldMonitor = false
    local chatList = Settings.Get("detectChatList")
    
    if type(chatList) == "table" then
        local key = Constants.CHAT_EVENT_KEYS[event]
        if key then
            for _, entry in ipairs(chatList) do
                if entry == key then
                    shouldMonitor = true
                    break
                end
            end
        end
    else
        -- Fallback to individual settings
        if event == "CHAT_MSG_SAY" and Settings.Get("detectInSay") then
            shouldMonitor = true
        elseif event == "CHAT_MSG_PARTY" and Settings.Get("detectInParty") then
            shouldMonitor = true
        elseif event == "CHAT_MSG_RAID" and Settings.Get("detectInRaid") then
            shouldMonitor = true
        elseif event == "CHAT_MSG_GUILD" and Settings.Get("detectInGuild") then
            shouldMonitor = true
        elseif event == "CHAT_MSG_WHISPER" and Settings.Get("detectInWhisper") then
            shouldMonitor = true
        end
    end

    if not shouldMonitor then
        return false
    end

    -- Skip our own recent announcements
    local playerName = UnitName("player")
    if sender and playerName then
        local senderShort = Helpers.NormalizePlayerName(sender)
        if senderShort == playerName then
            if Messaging.IsRecentAnnounce and Messaging.IsRecentAnnounce(message) then
                return false
            end
        end
    end

    -- Find matching utilities
    local matches = Detection.FindMatchingUtilities(message, sender)
    if #matches > 0 then
        for _, match in ipairs(matches) do
            match.sourceEvent = event
            match.sourceSender = sender
        end
    end
    
    -- Show banner or queue matches
    if #matches > 0 and Settings.Get("showBanner") then
        if InCombatLockdown() then
            queueMatches(matches)
            return false
        end
        
        if BannerController.FindBannerByOptions and banner and banner:IsShown() then
            local existingBanner = BannerController.FindBannerByOptions(banner, matches)
            if existingBanner then
                local isStacked = existingBanner ~= banner
                BannerController.ShowWithOptions(existingBanner, matches, isStacked, false)
                return false
            end
        end
        
        BannerController.ShowWithOptions(banner, matches)
    end
    
    return false
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

function Init.HandleCommand(args)
    local Settings = GetSettings()
    local Minimap = GetMinimap()
    local cmd = tostring(args or ""):lower():trim()

    if cmd == "settings" or cmd == "config" or cmd == "options" then
        if Settings and Settings.Show then
            Settings.Show()
        end
    elseif cmd:match("^blacklist%s+(.+)") then
        local words = args:match("^blacklist%s+(.+)")
        if Settings and Settings.Set then
            Settings.Set("blacklistedWords", words)
        end
        local message = string.format(Lstr("cmd.blacklist.updated", "Blacklist updated to: %s"),
            "|cffFFFFFF" .. words .. "|r")
        print("|cff00ff00Nozmie:|r " .. message)
    elseif cmd == "blacklist" then
        local current = Settings and Settings.Get and Settings.Get("blacklistedWords") or ""
        if current == "" then
            print("|cff00ff00Nozmie:|r " .. Lstr("cmd.blacklist.none", "No blacklisted words set."))
        else
            local message = string.format(Lstr("cmd.blacklist.current", "Current blacklist: %s"),
                "|cffFFFFFF" .. current .. "|r")
            print("|cff00ff00Nozmie:|r " .. message)
        end
        print("|cffFFFFFF" .. Lstr("cmd.blacklist.usage", "  Usage: /noz blacklist <word1, word2, ...>"))
    elseif cmd == "minimap" or cmd == "mm" then
        if Settings and Settings.Set and Settings.Get then
            Settings.Set("minimapIcon", not Settings.Get("minimapIcon"))
        end
        if Minimap then
            Minimap.UpdateVisibility()
        end
        local minimapEnabled = Settings and Settings.Get and Settings.Get("minimapIcon")
        local state = minimapEnabled and Lstr("state.enabled", "enabled") or
                          Lstr("state.disabled", "disabled")
        local message = string.format(Lstr("cmd.minimap.toggled", "Minimap icon %s."), state)
        print("|cff00ff00Nozmie:|r " .. message)
    elseif cmd == "last" then
        _G.Nozmie_ShowLastBanner()
    elseif cmd == "key" or cmd == "keystone" or cmd == "mykey" then
        local keyInfo = Keystones.GetOwnedKeystone()
        if not keyInfo then
            print("|cff00ff00Nozmie:|r " .. Lstr("cmd.keystone.none", "No keystone found in your bags."))
        else
            local levelSuffix = ""
            if type(keyInfo.level) == "number" and keyInfo.level > 0 then
                levelSuffix = string.format(Lstr("cmd.keystone.levelSuffix", " (+%d)"), keyInfo.level)
            end
            local message = string.format(Lstr("cmd.keystone.current", "Current keystone: %s%s"), keyInfo.mapName,
                levelSuffix)
            print("|cff00ff00Nozmie:|r " .. message)
        end
    elseif cmd == "help" then
        print("|cff00ff00Nozmie:|r " .. Lstr("cmd.title", "Commands:"))
        print(Lstr("cmd.open", "  /noz - Open utility UI"))
        print(Lstr("cmd.openAlt", "  /noz settings - Open settings"))
        print(Lstr("cmd.minimap", "  /noz minimap - Toggle minimap icon"))
        print(Lstr("cmd.last", "  /noz last - Show last banner"))
        print(Lstr("cmd.key", "  /noz key - Show current keystone dungeon"))
        print(Lstr("cmd.keys", "  !keys (party/raid/guild chat) - Request everyone's keystone"))
        print(Lstr("cmd.blacklist", "  /noz blacklist - View current blacklist"))
        print(Lstr("cmd.blacklistSet", "  /noz blacklist <words> - Set blacklisted words (comma-separated)"))
    end
end

-- ============================================================================
-- Public API Exports
-- ============================================================================

function _G.Nozmie_ShowOptions(options)
    if not options or #options == 0 then
        return
    end
    if InCombatLockdown() then
        queueMatches(options)
        return
    end
    local BannerController = GetBannerController()
    if banner and BannerController then
        BannerController.ShowWithOptions(banner, options)
    end
end

function _G.Nozmie_ShowLastBanner()
    local BannerController = GetBannerController()
    local last = BannerController and BannerController.GetLastOptions()
    if last and #last > 0 then
        _G.Nozmie_ShowOptions(last)
    else
        print("|cff00ff00Nozmie:|r " .. Lstr("banner.noRecent", "No recent banner to show."))
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Init.ProcessPendingMatches()
    local Settings = GetSettings()
    local BannerController = GetBannerController()
    if #pendingMatches > 0 and Settings and Settings.Get("showBanner") then
        local queued = pendingMatches
        pendingMatches = {}
        if banner and BannerController then
            BannerController.ShowWithOptions(banner, queued)
        end
    end
end

function Init.OnGroupRosterUpdate()
    Keystones.CleanupGroupKeyReportsForCurrentGroup()
    Keystones.RefreshOwnedKeystoneReport()
    refreshGroupKeysUI()
end

function Init.OnOwnedKeystoneUpdated()
    local changed = Keystones.RefreshOwnedKeystoneReport()
    if changed then
        refreshGroupKeysUI()
    end
end

function Init.Initialize()
    if initialized then
        return
    end
    initialized = true

    local Settings = GetSettings()
    local BannerUI = GetBannerUI()
    local Minimap = GetMinimap()

    -- Initialize state
    State.InitializeDB()
    
    -- Initialize settings
    if Settings and Settings.InitializeDB then
        Settings.InitializeDB()
    end
    
    -- Create banner
    if BannerUI and BannerUI.CreateBanner then
        banner = BannerUI.CreateBanner()
        _G.Nozmie_Banner = banner
    end
    
    -- Create settings panel
    if Settings and Settings.CreatePanel then
        Settings.CreatePanel()
    end
    
    -- Initialize minimap
    if Minimap and Minimap.Initialize then
        Minimap.Initialize()
        Minimap.UpdateVisibility()
    end
    
    -- Register chat event filters
    for event, _ in pairs(Constants.CHAT_EVENT_KEYS) do
        ChatFrame_AddMessageEventFilter(event, Init.OnChatMessage)
    end
   
    -- Register slash commands
    SlashCmdList["NOZMIE"] = Init.HandleCommand
    
    -- Register events with event bus
    EventBus.Register("PLAYER_REGEN_ENABLED", function()
        Init.ProcessPendingMatches()
    end)
    
    EventBus.Register("GROUP_ROSTER_UPDATE", function()
        Init.OnGroupRosterUpdate()
    end)

    EventBus.Register("BAG_UPDATE_DELAYED", function()
        Init.OnOwnedKeystoneUpdated()
    end)

    EventBus.Register("PLAYER_ENTERING_WORLD", function()
        Init.OnOwnedKeystoneUpdated()
    end)
end

-- Bootstrap once when addon files are fully loaded.
EventBus.Register("ADDON_LOADED", function(event, loadedAddon)
    if loadedAddon ~= "Nozmie" then
        return
    end

    Init.Initialize()
end)

-- Export module
_G.Nozmie_Init = Init
return Init
