-- ============================================================================
-- Nozmie - Data Aggregation Module
-- Consolidates all static data files into a single dataset
-- ============================================================================

local Data = {}

-- Aggregate all data sources
local function AggregateData()
    local allData = {}
    
    -- Load all data from Data/ folder
    local dataSources = {
        _G.ClassSpells and _G.ClassSpells.ClassSpellsData or {},
        _G.ClassSpells and _G.ClassSpells.ClassTeleports or {},
        _G.Expansions or {},
        _G.Hearthstones or {},
        _G.MageTeleports or {},
        _G.TeleportToys or {},
        _G.ServiceToys or {},
        _G.DelveTeleports or {},
        _G.Mounts or {},
        _G.UtilityPets or {},
        _G.EasterEggs or {}
    }
    
    for _, source in ipairs(dataSources) do
        if type(source) == "table" then
            for _, item in ipairs(source) do
                if item then
                    table.insert(allData, item)
                end
            end
        end
    end
    
    return allData
end

-- Get the aggregated dataset
function Data.GetAllData()
    if not Data._cached then
        Data._cached = AggregateData()
        
        -- Apply locale aliases if available
        if _G.Nozmie_Locale and _G.Nozmie_Locale.ApplyKeywordAliases then
            _G.Nozmie_Locale.ApplyKeywordAliases(Data._cached)
        end
    end
    
    return Data._cached
end

-- Backward-compatible alias used by newer detection code.
function Data.GetAllUtilities()
    return Data.GetAllData()
end

-- Get data by category
function Data.GetByCategory(category)
    if not category then return {} end
    
    local allData = Data.GetAllData()
    local results = {}
    
    for _, item in ipairs(allData) do
        if item and item.category == category then
            table.insert(results, item)
        end
    end
    
    return results
end

-- Find item by ID
function Data.FindByID(id, idField)
    idField = idField or "id"
    if not id then return nil end
    
    local allData = Data.GetAllData()
    
    for _, item in ipairs(allData) do
        if item and item[idField] == id then
            return item
        end
    end
    
    return nil
end

-- Find item by name
function Data.FindByName(name)
    if not name then return nil end
    
    local allData = Data.GetAllData()
    
    for _, item in ipairs(allData) do
        if item and item.name == name then
            return item
        end
    end
    
    return nil
end

-- Clear cache (for hot reloading)
function Data.ClearCache()
    Data._cached = nil
end

_G.Nozmie_DBData = Data
return Data
