-- ============================================================================
-- Nozmie - State Management Module
-- Centralized SavedVariables management and state orchestration
--
-- This module is the single source of truth for all addon state and persisted
-- data. All modules should access state through this interface rather than
-- directly manipulating NozmieDB. This ensures consistency and allows for
-- future migrations of the storage layer.
-- ============================================================================

local State = {}

-- ============================================================================
-- Database Initialization
-- ============================================================================

-- Initialize SavedVariables with default structure
-- Ensures NozmieDB exists and has all required keys on first load
function State.InitializeDB()
    if not NozmieDB then
        NozmieDB = {
            position = nil,
            enabled = true,
            settings = {},
            groupKeys = {},
            favourites = {},
            cooldowns = {}
        }
    end
    
    -- Ensure all core keys exist (missing keys from older versions)
    NozmieDB.position = NozmieDB.position or {}
    NozmieDB.settings = NozmieDB.settings or {}
    NozmieDB.groupKeys = NozmieDB.groupKeys or {}
    NozmieDB.favourites = NozmieDB.favourites or {}
    NozmieDB.cooldowns = NozmieDB.cooldowns or {}
    
    return NozmieDB
end

-- ============================================================================
-- Database Access
-- ============================================================================

-- Get the global database (raw access, use specific getters when possible)
function State.GetDB()
    return NozmieDB
end

-- ============================================================================
-- Settings Management
-- ============================================================================

-- Get a setting value with optional default fallback
function State.GetSetting(key, default)
    return State.GetSettingValue(key, default)
end

-- Set a setting value (persisted to SavedVariables)
function State.SetSetting(key, value)
    State.InitializeDB()
    NozmieDB.settings[key] = value
    NozmieDB[key] = value
end

-- Get a setting value from either the centralized settings table or the
-- legacy root-level SavedVariables layout.
function State.GetSettingValue(key, default)
    State.InitializeDB()

    local value = NozmieDB.settings[key]
    if value ~= nil then
        return value
    end

    value = NozmieDB[key]
    if value ~= nil then
        NozmieDB.settings[key] = value
        return value
    end

    return default
end

-- ============================================================================
-- Banner Position (persisted state)
-- ============================================================================

-- Get banner position as table {point, relativePoint, xOfs, yOfs}
function State.GetBannerPosition()
    return NozmieDB and NozmieDB.position or {}
end

-- Save banner position for restoration on next login
function State.SetBannerPosition(point, relativePoint, xOfs, yOfs)
    State.InitializeDB()
    if type(point) == "table" then
        local position = point
        NozmieDB.position = {
            point = position.point or "CENTER",
            relativePoint = position.relativePoint or "CENTER",
            xOfs = tonumber(position.xOfs) or tonumber(position.x) or 0,
            yOfs = tonumber(position.yOfs) or tonumber(position.y) or 0,
            width = tonumber(position.width),
            height = tonumber(position.height)
        }
        return
    end

    NozmieDB.position = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }
end

-- ============================================================================
-- Group Keys Management (tracked keystones from group)
-- ============================================================================

-- Get all currently tracked group member keystones
function State.GetGroupKeys()
    return NozmieDB and NozmieDB.groupKeys or {}
end

-- Track a group member's keystone at a specific timestamp
function State.SetGroupKey(sender, dungeonID, level, mapName, link)
    State.InitializeDB()
    if not sender or not dungeonID then return false end
    
    NozmieDB.groupKeys[sender] = {
        dungeonID = dungeonID,
        level = level or 0,
        mapName = mapName,
        link = link,
        timestamp = GetTime()
    }
    return true
end

-- Clear a specific group member's tracked keystone
function State.ClearGroupKey(sender)
    State.InitializeDB()
    if NozmieDB.groupKeys[sender] then
        NozmieDB.groupKeys[sender] = nil
        return true
    end
    return false
end

-- Clear all group member keystones (called when leaving group)
function State.ClearAllGroupKeys()
    State.InitializeDB()
    NozmieDB.groupKeys = {}
end

-- ============================================================================
-- Favourites Management (saved utilities user likes)
-- ============================================================================

-- Get all user-marked favourite utilities
function State.GetFavourites()
    return NozmieDB and NozmieDB.favourites or {}
end

-- Mark a utility as favourite
function State.AddFavourite(itemID)
    if not itemID then return false end
    State.InitializeDB()
    NozmieDB.favourites[itemID] = true
    return true
end

-- Unmark a utility from favourites
function State.RemoveFavourite(itemID)
    if not itemID then return false end
    State.InitializeDB()
    if NozmieDB.favourites[itemID] then
        NozmieDB.favourites[itemID] = nil
        return true
    end
    return false
end

-- Check if utility is marked as favourite
function State.IsFavourite(itemID)
    return NozmieDB and NozmieDB.favourites and NozmieDB.favourites[itemID] or false
end

-- ============================================================================
-- Cooldowns Management (custom cooldown tracking)
-- ============================================================================

-- Get all tracked custom cooldowns
function State.GetCooldowns()
    return NozmieDB and NozmieDB.cooldowns or {}
end

-- Set a custom cooldown with expiry time (for non-WoW cooldowns)
function State.SetCooldown(key, expiryTime)
    State.InitializeDB()
    NozmieDB.cooldowns[key] = expiryTime
end

-- Get a specific custom cooldown expiry time
function State.GetCooldown(key)
    if not NozmieDB or not NozmieDB.cooldowns then return nil end
    return NozmieDB.cooldowns[key]
end

-- Clear a custom cooldown
function State.ClearCooldown(key)
    State.InitializeDB()
    if NozmieDB.cooldowns[key] then
        NozmieDB.cooldowns[key] = nil
        return true
    end
    return false
end

_G.Nozmie_State = State
return State
