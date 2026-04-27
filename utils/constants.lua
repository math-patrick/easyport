-- ============================================================================
-- Nozmie - Constants Module
-- All magic numbers, strings, and configuration constants
--
-- This module centralizes all hardcoded values to make tuning and maintenance
-- easier. Prefer using these constants throughout the codebase rather than
-- embedding magic numbers directly.
-- ============================================================================

local Constants = {}

-- CHAT EVENTS MAPPING
Constants.CHAT_EVENT_KEYS = {
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

Constants.GROUP_KEY_CHANNELS = {
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_GUILD = "GUILD"
}

-- VALID CHAT CHANNELS FOR SENDING
Constants.VALID_CHAT_CHANNELS = {
    SAY = true,
    PARTY = true,
    RAID = true,
    GUILD = true,
    INSTANCE_CHAT = true,
    YELL = true,
    WHISPER = true,
    BN_WHISPER = true
}

-- DUPLICATE MESSAGE WINDOW (seconds)
Constants.DUPLICATE_MESSAGE_WINDOW = 1.0

-- DUPLICATE KEY REQUEST WINDOW (seconds)
Constants.DUPLICATE_KEY_REQUEST_WINDOW = 1.5

-- ANNOUNCE DEDUP WINDOW (seconds)
Constants.ANNOUNCE_DEDUP_WINDOW = 2

-- BASIC HEARTHSTONE ITEM ID
Constants.BASIC_HEARTHSTONE_ITEM_ID = 6948

-- KEYSTONE LEVEL RANGE
Constants.MIN_KEYSTONE_LEVEL = 2
Constants.MAX_KEYSTONE_LEVEL = 40

-- ACTION TYPES
Constants.ACTION_TYPES = {
    SPELL = "spell",
    ITEM = "item",
    PET = "pet",
    MOUNT = "mount",
    TOY = "toy",
    RANDOM_HEARTHSTONE = "random_hearthstone"
}

-- ITEM CATEGORIES
Constants.ITEM_CATEGORIES = {
    CLASS = "Class",
    CLASS_UTILITY = "Class Utility",
    UTILITY = "Utility",
    MPLUS_DUNGEON = "M+ Dungeon",
    RAID = "Raid",
    TELEPORT = "Teleport",
    HOME = "Home"
}

-- SUPPRESSION KEYS
Constants.SUPPRESSION_KEYS = {
    MOUNT = "mount",
    CLASS = "class",
    TELEPORTS = "teleports",
    UTILITY_SERVICE = "utilityservice"
}

-- BANNER DIMENSIONS
Constants.BANNER_WIDTH = 440
Constants.BANNER_HEIGHT = 72

-- BANNER COLORS
Constants.BANNER_COLORS = {
    BACKDROP_NORMAL = {0.08, 0.055, 0.025, 0.9},
    BACKDROP_COOLDOWN = {0.06, 0.045, 0.03, 0.82},
    BORDER_NORMAL = {0.78, 0.62, 0.28, 0.9},
    BORDER_HOVER = {1, 0.82, 0.32, 1},
    TEXT_NORMAL = {1, 0.82, 0},
    TEXT_COOLDOWN = {0.65, 0.58, 0.48},
    ACCENT = {1, 0.82, 0, 1},
    ACCENT_SOFT = {1, 0.82, 0, 0.28},
    ACCENT_GREEN = {0.35, 0.9, 0.45, 1}
}

-- ADDON NAME
Constants.ADDON_NAME = "Nozmie"

-- SLASH COMMAND
Constants.SLASH_COMMAND = "NOZMIE"

-- BN WHISPER PREFIX
Constants.BN_WHISPER_PREFIX = "Nozmie"

_G.Nozmie_Constants = Constants
return Constants
