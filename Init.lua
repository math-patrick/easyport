-- ============================================================================
-- Nozmie - Initialization Module
-- Event registration, chat filtering, and slash commands
-- ============================================================================
local Config = Nozmie_Config
local Detector = Nozmie_Detector
local BannerUI = Nozmie_BannerUI
local BannerController = Nozmie_BannerController
local Settings = Nozmie_Settings
local Minimap = Nozmie_Minimap
local Helpers = Nozmie_Helpers

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

local addon = CreateFrame("Frame")
local banner
local pendingMatches = {}
local chatEventKeys = {
    CHAT_MSG_SAY = "say",
    CHAT_MSG_PARTY = "party",
    CHAT_MSG_PARTY_LEADER = "party",
    CHAT_MSG_INSTANCE_CHAT = "party",
    CHAT_MSG_RAID = "raid",
    CHAT_MSG_GUILD = "guild",
    CHAT_MSG_WHISPER = "whisper",
    CHAT_MSG_WHISPER_INFORM = "whisper",
    CHAT_MSG_BN_WHISPER = "bn_whisper"
}

local function QueueMatches(matches)
    for _, match in ipairs(matches) do
        table.insert(pendingMatches, match)
    end
end

_G.Nozmie_ShowOptions = function(options)
    if not options or #options == 0 then
        return
    end
    if InCombatLockdown() then
        QueueMatches(options)
        return
    end
    BannerController.ShowWithOptions(banner, options)
end

_G.Nozmie_ShowLastBanner = function()
    local last = BannerController.GetLastOptions()
    if last and #last > 0 then
        _G.Nozmie_ShowOptions(last)
    else
        print("|cff00ff00Nozmie:|r " .. Lstr("banner.noRecent", "No recent banner to show."))
    end
end

local function OnChatMessage(self, event, message, sender)
    -- Check if addon is enabled
    if not Settings.Get("enabled") then
        return false
    end

    -- Check if this chat type should be monitored
    local shouldMonitor = false
    local chatList = Settings.Get("detectChatList")
    if type(chatList) == "table" then
        local key = chatEventKeys[event]
        if key then
            for _, entry in ipairs(chatList) do
                if entry == key then
                    shouldMonitor = true
                    break
                end
            end
        end
    else
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

    local playerName = UnitName("player")
    if sender and playerName then
        local senderShort = sender:match("([^-]+)") or sender
        if senderShort == playerName and Helpers and Helpers.IsRecentAnnounce and Helpers.IsRecentAnnounce(message) then
            return false
        end
    end

    local matches = Detector.FindMatchingTeleports(message, sender)
    if #matches > 0 then
        for _, match in ipairs(matches) do
            match.sourceEvent = event
            match.sourceSender = sender
        end
    end
    if #matches > 0 and Settings.Get("showBanner") then
        if InCombatLockdown() then
            QueueMatches(matches)
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

local function HandleCommand(args)
    local cmd = args:lower():trim()

    if cmd == "settings" or cmd == "config" or cmd == "options" then
        Settings.Show()
    elseif cmd:match("^blacklist%s+(.+)") then
        local words = args:match("^blacklist%s+(.+)")
        Settings.Set("blacklistedWords", words)
        local message = string.format(Lstr("cmd.blacklist.updated", "Blacklist updated to: %s"),
            "|cffFFFFFF" .. words .. "|r")
        print("|cff00ff00Nozmie:|r " .. message)
    elseif cmd == "blacklist" then
        local current = Settings.Get("blacklistedWords") or ""
        if current == "" then
            print("|cff00ff00Nozmie:|r " .. Lstr("cmd.blacklist.none", "No blacklisted words set."))
        else
            local message = string.format(Lstr("cmd.blacklist.current", "Current blacklist: %s"),
                "|cffFFFFFF" .. current .. "|r")
            print("|cff00ff00Nozmie:|r " .. message)
        end
        print("|cffFFFFFF" .. Lstr("cmd.blacklist.usage", "  Usage: /noz blacklist <word1, word2, ...>"))
    elseif cmd == "minimap" or cmd == "mm" then
        Settings.Set("minimapIcon", not Settings.Get("minimapIcon"))
        if Minimap then
            Minimap.UpdateVisibility()
        end
        local state = Settings.Get("minimapIcon") and Lstr("state.enabled", "enabled") or
                          Lstr("state.disabled", "disabled")
        local message = string.format(Lstr("cmd.minimap.toggled", "Minimap icon %s."), state)
        print("|cff00ff00Nozmie:|r " .. message)
    elseif cmd == "last" then
        _G.Nozmie_ShowLastBanner()
    elseif cmd == "help" then
        print("|cff00ff00Nozmie:|r " .. Lstr("cmd.title", "Commands:"))
        print(Lstr("cmd.open", "  /noz - Open utility UI"))
        print(Lstr("cmd.openAlt", "  /noz settings - Open settings"))
        print(Lstr("cmd.minimap", "  /noz minimap - Toggle minimap icon"))
        print(Lstr("cmd.last", "  /noz last - Show last banner"))
        print(Lstr("cmd.blacklist", "  /noz blacklist - View current blacklist"))
        print(Lstr("cmd.blacklistSet", "  /noz blacklist <words> - Set blacklisted words (comma-separated)"))
    end
end

local function Initialize()
    -- Initialize settings database
    Settings.InitializeDB()

    -- Create settings panel
    Settings.CreatePanel()

    -- Create banner
    banner = BannerUI.CreateBanner()

    if Minimap then
        Minimap.Initialize()
        Minimap.UpdateVisibility()
    end

    -- Register chat event filters
    for _, event in ipairs(Config.CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, OnChatMessage)
    end

    -- Register slash commands
    SlashCmdList["NOZMIE"] = HandleCommand
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")
addon:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "PLAYER_REGEN_ENABLED" then
        if #pendingMatches > 0 and Settings.Get("showBanner") then
            local queued = pendingMatches
            pendingMatches = {}
            BannerController.ShowWithOptions(banner, queued)
        end
        return
    end
    if loadedAddon == "Nozmie" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
