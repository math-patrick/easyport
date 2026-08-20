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

_G.Nozmie_State = State
return State
