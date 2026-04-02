-- ============================================================================
-- Nozmie - Favourites Feature Module
-- Manage favorite utilities and sorting
-- ============================================================================

local State = require("core.state")

local Favourites = {}

-- Add utility to favourites
function Favourites.Add(itemID)
    if not itemID then return false end
    return State.AddFavourite(itemID)
end

-- Remove utility from favourites
function Favourites.Remove(itemID)
    if not itemID then return false end
    return State.RemoveFavourite(itemID)
end

-- Check if utility is favourite
function Favourites.IsFavourite(itemID)
    if not itemID then return false end
    return State.IsFavourite(itemID)
end

-- Toggle favourite status
function Favourites.Toggle(itemID)
    if not itemID then return false end
    
    if Favourites.IsFavourite(itemID) then
        return Favourites.Remove(itemID)
    else
        return Favourites.Add(itemID)
    end
end

-- Get all favourites
function Favourites.GetAll()
    return State.GetFavourites()
end

-- Sort a list of utilities with favourites first
function Favourites.SortWithFavourites(utilities)
    if not utilities or #utilities == 0 then return utilities end
    
    local favourite = {}
    local regular = {}
    
    for _, util in ipairs(utilities) do
        if util and util.id and Favourites.IsFavourite(util.id) then
            table.insert(favourite, util)
        else
            table.insert(regular, util)
        end
    end
    
    -- Merge: favourites first
    for _, util in ipairs(regular) do
        table.insert(favourite, util)
    end
    
    return favourite
end

_G.Nozmie_Favourites = Favourites
_G.Nozmie_FeatureFavourites = Favourites
return Favourites
