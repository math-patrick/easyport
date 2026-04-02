-- ============================================================================
-- Nozmie - SavedVariables Schema Module
-- Defines SavedVariables structure and migrations
-- ============================================================================

local SavedVariables = {}

-- Default schema
local DEFAULT_SCHEMA = {
    position = {
        point = "BOTTOM",
        relativePoint = "TOP",
        xOfs = 0,
        yOfs = 20
    },
    settings = {},
    groupKeys = {},
    favourites = {},
    cooldowns = {}
}

-- Migrate old schema to new
function SavedVariables.Migrate()
    if not NozmieDB then
        NozmieDB = {}
    end
    
    -- Ensure all keys exist
    for key, defaultValue in pairs(DEFAULT_SCHEMA) do
        if NozmieDB[key] == nil then
            if type(defaultValue) == "table" then
                NozmieDB[key] = {}
            else
                NozmieDB[key] = defaultValue
            end
        end
    end
end

-- Get the schema
function SavedVariables.GetSchema()
    return DEFAULT_SCHEMA
end

-- Validate a data object
function SavedVariables.Validate(data)
    if type(data) ~= "table" then
        return false
    end
    
    -- Check required keys
    for key in pairs(DEFAULT_SCHEMA) do
        if data[key] == nil then
            if type(DEFAULT_SCHEMA[key]) == "table" then
                data[key] = {}
            else
                data[key] = DEFAULT_SCHEMA[key]
            end
        end
    end
    
    return true
end

_G.Nozmie_SavedVariables = SavedVariables
return SavedVariables
