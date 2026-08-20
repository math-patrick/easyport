-- ============================================================================
-- Nozmie - Utility Helpers Module
-- Generic, non-feature-specific utility functions
--
-- This module provides core utility functions for time formatting, group
-- detection, chat messaging, and string normalization. These are generic
-- helpers used across the addon, not tied to any specific feature.
--
-- All functions in this module should be side-effect free where possible,
-- taking only what they need and returning results without global state changes.
-- ============================================================================

local Constants = require("utils.constants")
local Locale = _G.Nozmie_Locale

local Helpers = {}

-- ============================================================================
-- Localization Helper
-- ============================================================================

local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

-- ============================================================================
-- Time Formatting
-- ============================================================================

function Helpers.FormatCooldownTime(seconds)
    if not seconds or type(seconds) ~= "number" then
        return "0s"
    end
    
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    end
    return string.format("%ds", secs)
end

-- ============================================================================
-- Group Detection
-- ============================================================================

function Helpers.IsInAnyGroup()
    return IsInGroup() or IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end

function Helpers.GetGroupChatChannel()
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    return "PARTY"
end

function Helpers.GetChannelFromEvent(event)
    if not event then return nil end
    
    if event == "CHAT_MSG_SAY" then
        return "SAY"
    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        return "PARTY"
    elseif event == "CHAT_MSG_INSTANCE_CHAT" then
        return "INSTANCE_CHAT"
    elseif event == "CHAT_MSG_RAID" then
        return "RAID"
    elseif event == "CHAT_MSG_GUILD" then
        return "GUILD"
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        return "WHISPER"
    elseif event == "CHAT_MSG_BN_WHISPER" then
        return "BN_WHISPER"
    end
    
    return nil
end

-- ============================================================================
-- Chat Messaging
-- ============================================================================

function Helpers.SendChatMessage(message, event, sender)
    if not message then return false end
    
    -- Ignore non-channel events
    if event == "LEFT_CLICK" or event == "RIGHT_CLICK" then
        return false
    end
    
    local channel = Helpers.GetChannelFromEvent(event) or "SAY"
    
    if channel == "WHISPER" then
        if not sender or sender == "" then
            return false
        end
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage(message, channel, nil, sender)
        else
            SendChatMessage(message, channel, nil, sender)
        end
        return true
    elseif channel == "BN_WHISPER" then
        if not sender or sender == "" then
            return false
        end
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(Constants.BN_WHISPER_PREFIX, message, "BN_WHISPER", sender)
            return true
        end
        return false
    else
        -- Validate channel
        if not Constants.VALID_CHAT_CHANNELS[channel] then
            channel = "SAY"
        end
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage(message, channel)
        else
            SendChatMessage(message, channel)
        end
        return true
    end
end

function Helpers.Trim(text)
    if text == nil then
        return ""
    end

    if strtrim then
        return strtrim(tostring(text))
    end

    return tostring(text):match("^%s*(.-)%s*$") or ""
end

-- ============================================================================
-- String Normalization
-- ============================================================================

function Helpers.NormalizePlayerName(name)
    if not name or name == "" then
        return nil
    end
    return name:match("([^-]+)") or name
end

function Helpers.NormalizeMapName(name)
    if not name or name == "" then
        return nil
    end
    
    local normalized = name:lower()
    normalized = normalized:gsub("[^%w]", "")
    return normalized
end

function Helpers.NormalizeDungeonName(name)
    local normalized = Helpers.NormalizeMapName(name)
    if not normalized then
        return nil
    end
    
    -- Remove common prefixes
    normalized = normalized:gsub("^the", "")
    return normalized
end

-- ============================================================================
-- Pattern Matching
-- ============================================================================

function Helpers.EscapePattern(text)
    if not text then return "" end
    return (text:gsub("(%W)", "%%%1"))
end

-- Chat detection runs this on every monitored chat message against every
-- keyword of every utility entry, so the compiled frontier-pattern for each
-- keyword is cached instead of being rebuilt (gsub + concat) on every call.
local keywordPatternCache = {}

local function GetKeywordPattern(normalizedKeyword)
    local pattern = keywordPatternCache[normalizedKeyword]
    if pattern == nil then
        pattern = "%f[%w]" .. Helpers.EscapePattern(normalizedKeyword) .. "%f[%W]"
        keywordPatternCache[normalizedKeyword] = pattern
    end
    return pattern
end

function Helpers.MatchesKeyword(message, keyword)
    if not message or not keyword or keyword == "" then
        return false
    end

    local normalizedMessage = message:lower()
    local normalizedKeyword = tostring(keyword):lower()
    local pattern = GetKeywordPattern(normalizedKeyword)

    return normalizedMessage:find(pattern) ~= nil
end

-- ============================================================================
-- Table Utilities
-- ============================================================================

function Helpers.ShuffleTable(tbl)
    if not tbl or #tbl == 0 then return end
    
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

-- ============================================================================
-- Error Handling
-- ============================================================================

function Helpers.SafeCall(func, ...)
    if not func or type(func) ~= "function" then
        return false
    end
    
    local ok, result = xpcall(func, geterrorhandler(), ...)
    return ok, result
end

-- ============================================================================
-- Cache Management
-- ============================================================================

function Helpers.CreateCache(maxAge)
    local cache = {}
    local metadata = {}
    
    return {
        Get = function(key)
            if not metadata[key] then return nil end
            if maxAge and (GetTime() - metadata[key].time) > maxAge then
                metadata[key] = nil
                cache[key] = nil
                return nil
            end
            return cache[key]
        end,
        Set = function(key, value)
            cache[key] = value
            metadata[key] = { time = GetTime() }
        end,
        Clear = function(key)
            cache[key] = nil
            metadata[key] = nil
        end,
        ClearAll = function()
            wipe(cache)
            wipe(metadata)
        end
    }
end

_G.Nozmie_Helpers = Helpers
return Helpers
