-- ============================================================================
-- Nozmie - Favourites Management
-- Entry ID generation, favouriting, sorting, and default seeding
-- ============================================================================

local Cooldowns = require("features.cooldowns")
local State = require("core.state")

local bootstrapped = false

local Favourites = {}

-- ============================================================================
-- Entry Identity
-- ============================================================================

local function NormalizeToken(value)
    if value == nil then return nil end
    local text = tostring(value):lower():gsub("[^%w]", "")
    return text ~= "" and text or nil
end

function Favourites.GetEntryID(entry)
    if not entry then return nil end
    if entry.spellID then return "spell:" .. tostring(entry.spellID) end
    if entry.itemID  then return "item:"  .. tostring(entry.itemID)  end
    if entry.mountId then return "mount:" .. tostring(entry.mountId) end
    if entry.petName then
        local token = NormalizeToken(entry.petName)
        if token then return "pet:" .. token end
    end
    local fallback = NormalizeToken(entry.name) or NormalizeToken(entry.spellName) or NormalizeToken(entry.destination)
    return fallback and ("name:" .. fallback) or nil
end

-- ============================================================================
-- Persistence
-- ============================================================================

function Favourites.GetFavouritesTable()
    State.InitializeDB()
    return State.GetFavourites()
end

function Favourites.IsFavourite(entryID)
    if not entryID then return false end
    return Favourites.GetFavouritesTable()[entryID] == true
end

function Favourites.IsFavouriteEntry(entry)
    return Favourites.IsFavourite(Favourites.GetEntryID(entry))
end

function Favourites.ToggleFavourite(entryID)
    if not entryID then return false end
    if Favourites.IsFavourite(entryID) then
        State.RemoveFavourite(entryID)
        return false
    end

    State.AddFavourite(entryID)
    return true
end

-- Seed current-expansion entries as favourites on first run
function Favourites.SeedDefaultFavourites()
    if bootstrapped then return end
    local favs = Favourites.GetFavouritesTable()
    if next(favs) == nil and type(_G.Nozmie_Data) == "table" then
        for _, entry in ipairs(_G.Nozmie_Data) do
            if tonumber(entry and entry.current) == 1 then
                local id = Favourites.GetEntryID(entry)
                if id then favs[id] = true end
            end
        end
    end
    bootstrapped = true
end

-- ============================================================================
-- Sorting
-- ============================================================================

function Favourites.SortEntriesWithFavourites(list)
    local CH = _G.Nozmie_ConfigHelpers
    table.sort(list, function(a, b)
        local aFav = Favourites.IsFavouriteEntry(a)
        local bFav = Favourites.IsFavouriteEntry(b)
        if aFav ~= bFav then return aFav end

        local aRandom = a and (a.actionType == "random_hearthstone" or a.name == "Random Hearthstone")
        local bRandom = b and (b.actionType == "random_hearthstone" or b.name == "Random Hearthstone")
        if aRandom ~= bRandom then return aRandom end

        local canUse = Cooldowns and Cooldowns.CanPlayerUseUtility
        local aUnavailable = not (canUse and canUse(a))
        local bUnavailable = not (canUse and canUse(b))
        if aUnavailable ~= bUnavailable then return not aUnavailable end

        if CH and CH.GetEntryName then
            return CH.GetEntryName(a) < CH.GetEntryName(b)
        end
        return false
    end)
end

_G.Nozmie_Favourites = Favourites
_G.Nozmie_UIFavourites = Favourites
return Favourites
