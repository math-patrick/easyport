-- ============================================================================
-- Nozmie - Messaging Utilities
-- Handle announcement creation, transmission, and tracking
-- ============================================================================

local Messaging = {}

-- ============================================================================
-- Announcement Creation
-- ============================================================================

-- Get action text and noun for a utility
function Messaging.GetActionAndNoun(data)
    if not data then
        return nil, nil
    end
    
    local actionType = data.actionType or ""
    
    if actionType == "spell" then
        return "cast", data.name or "spell"
    elseif actionType == "item" then
        return "use", data.name or "item"
    elseif actionType == "pet" then
        return "summon", data.petName or "pet"
    elseif actionType == "mount" then
        return "mount", data.name or "mount"
    elseif actionType == "toy" then
        return "use", data.name or "toy"
    else
        return "use", data.name or "ability"
    end
end

-- Create formatted announcement message
function Messaging.CreateAnnouncementMessage(action, noun, eventName)
    local message = "!nozmie " .. eventName
    
    if action and noun then
        message = message .. " " .. action .. " " .. noun
    end
    
    return message
end

-- ============================================================================
-- Announcement Tracking
-- ============================================================================

-- Local storage for recent announcements
local recentAnnouncements = {}
local ANNOUNCEMENT_COOLDOWN = 3  -- Seconds

-- Mark an announcement as sent
function Messaging.MarkAnnounce(key)
    recentAnnouncements[key] = GetTime()
end

-- Check if an announcement was recently sent
function Messaging.IsRecentAnnounce(key)
    local lastTime = recentAnnouncements[key]
    if not lastTime then
        return false
    end
    
    local elapsed = GetTime() - lastTime
    return elapsed < ANNOUNCEMENT_COOLDOWN
end

-- ============================================================================
-- Message Transmission
-- ============================================================================

-- Send a message to appropriate channel based on group status
function Messaging.SendMessageForEvent(eventName, action, noun)
    local Helpers = require("utils.helpers")
    local message = Messaging.CreateAnnouncementMessage(action, noun, eventName)
    
    if Helpers.IsInAnyGroup() then
        local channel = Helpers.GetGroupChatChannel()
        if channel then
            if C_ChatInfo and C_ChatInfo.SendChatMessage then
                C_ChatInfo.SendChatMessage(message, channel)
            else
                SendChatMessage(message, channel, nil, nil)
            end
            return true
        end
    end

    return false
end

-- ============================================================================
-- Utility Announcement
-- ============================================================================

local function NormalizeAnnounceLabel(label)
    label = tostring(label or "")
    if label == "" then
        return label
    end

    label = label:gsub("Auction House", "AH")
    label = label:gsub("%s+", " ")
    return label
end

-- Format a human-readable announcement message for a utility data entry
function Messaging.FormatAnnounceMessage(data)
    if not data then return nil end

    local locale = _G.Nozmie_Locale
    local function Lstr(key, fallback)
        if locale and locale.GetString then return locale.GetString(key, fallback) end
        return fallback or key
    end

    local spellName = data.spellName or ""
    local isTeleport = data.category == "Teleport" or
        data.category == "M+ Dungeon" or
        data.category == "Raid" or
        spellName:find("^Portal:") or
        spellName:find("^Teleport:") or
        spellName:find("^Ancient Portal:")

    local prefix = string.format("[%s] ", Lstr("addon.name", "Nozmie"))
    local destination = NormalizeAnnounceLabel(data.destination or data.name)
    local castName = NormalizeAnnounceLabel(data.spellName or data.name)
    local summonName = NormalizeAnnounceLabel(data.destination or data.name or data.petName)

    if isTeleport and destination ~= "" then
        return prefix .. string.format(Lstr("announce.teleporting", "Teleporting to %s!"), destination)
    end

    if data.category == "Home" and castName ~= "" then
        return prefix .. string.format(Lstr("announce.casting", "Casting %s!"), castName)
    end

    if (data.category == "Utility" or data.actionType == "mount" or data.actionType == "pet") and summonName ~= "" then
        return prefix .. string.format(Lstr("announce.summoning", "Summoning %s!"), summonName)
    end

    if data.actionType == "spell" and castName ~= "" then
        return prefix .. string.format(Lstr("announce.casting", "Casting %s!"), castName)
    end

    if castName ~= "" then
        return prefix .. string.format(Lstr("announce.casting", "Casting %s!"), castName)
    end

    return nil
end

-- Announce a utility to group chat with echo prevention
function Messaging.AnnounceUtility(data)
    if not data then return false end

    local Helpers = require("utils.helpers")
    local Cooldowns = require("features.cooldowns")
    if not Helpers.IsInAnyGroup() then return false end

    if Cooldowns and Cooldowns.IsOnCooldown and Cooldowns.IsOnCooldown(data) then
        return false
    end

    local channel = Helpers.GetGroupChatChannel()
    if not channel then return false end

    local message = Messaging.FormatAnnounceMessage(data)
    if not message then return false end

    if Messaging.IsRecentAnnounce(message) then
        return false
    end

    Messaging.MarkAnnounce(message)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
    else
        SendChatMessage(message, channel)
    end
    return true
end

-- ============================================================================
-- Message Content
-- ============================================================================

-- Get default action text for an event type
function Messaging.GetDefaultAction(eventType)
    local actions = {
        portal = "cast",
        hearthstone = "use",
        mount = "mount",
        pet = "summon",
        utility = "use"
    }
    return actions[eventType] or "use"
end

_G.Nozmie_Messaging = Messaging
return Messaging