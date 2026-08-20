-- ============================================================================
-- Nozmie - Cooldowns Feature Module
-- Track and manage ability cooldowns and utility availability
-- ============================================================================

local Cooldowns = {}

-- ============================================================================
-- WoW Cooldown Queries
-- ============================================================================

-- Minimum duration to be considered a real cooldown (filters out GCD ~1.5s)
local GCD_THRESHOLD = 1.5

local function getItemCooldown(itemID)
    if not itemID then
        return nil, nil
    end

    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
    end

    if GetItemCooldown then
        return GetItemCooldown(itemID)
    end

    return nil, nil
end

local function getSpellCooldown(spellID)
    if not spellID then
        return nil, nil
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration
        end
    end

    if GetSpellCooldown then
        return GetSpellCooldown(spellID)
    end

    return nil, nil
end

-- Get remaining cooldown for a utility (spell, item, or both if applicable)
function Cooldowns.GetRemaining(data)
    if not data then return 0 end
    
    local remaining = 0
    
    -- Check preferred item first
    if data.preferItem and data.itemID then
        local start, duration = getItemCooldown(data.itemID)
        if start and duration and start > 0 and duration > GCD_THRESHOLD then
            remaining = start + duration - GetTime()
            if remaining > 0 then return remaining end
        end
    end
    
    -- Check spell cooldown (ignore GCD)
    if data.spellID then
        local start, duration = getSpellCooldown(data.spellID)
        if start and duration and start > 0 and duration > GCD_THRESHOLD then
            remaining = start + duration - GetTime()
            if remaining > 0 then return remaining end
        end
    end
    
    -- Check item cooldown
    if data.itemID then
        local start, duration = getItemCooldown(data.itemID)
        if start and duration and start > 0 and duration > GCD_THRESHOLD then
            remaining = start + duration - GetTime()
            if remaining > 0 then return remaining end
        end
    end
    
    return 0
end

-- Check if ability is on cooldown
function Cooldowns.IsOnCooldown(data)
    return Cooldowns.GetRemaining(data) > 0
end

-- ============================================================================
-- Utility Availability Checking
-- ============================================================================

-- ============================================================================
-- Pet Journal Ownership Cache
-- ============================================================================
-- canUsePet() is called for every pet-type utility entry during panel
-- rebuilds and chat detection. Scanning the whole pet journal every single
-- call is wasteful, so the owned-pet name set is built once and invalidated
-- only when the journal actually changes.

local ownedPetNameCache
local petCacheWatcher

local function InvalidateOwnedPetCache()
    ownedPetNameCache = nil
end

local function EnsurePetCacheWatcher()
    if petCacheWatcher then
        return
    end
    petCacheWatcher = CreateFrame("Frame")
    petCacheWatcher:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    petCacheWatcher:RegisterEvent("COMPANION_UPDATE")
    petCacheWatcher:SetScript("OnEvent", InvalidateOwnedPetCache)
end

-- Set of lowercased names (journal name and custom name) for owned pets.
local function GetOwnedPetNameSet()
    if ownedPetNameCache then
        return ownedPetNameCache
    end

    EnsurePetCacheWatcher()

    local names = {}
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local _, _, isOwned, customName, _, _, _, petNameFromJournal = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned then
            local journalName = string.lower(tostring(petNameFromJournal or ""))
            local journalCustomName = string.lower(tostring(customName or ""))
            if journalName ~= "" then names[journalName] = true end
            if journalCustomName ~= "" then names[journalCustomName] = true end
        end
    end

    ownedPetNameCache = names
    return names
end

-- Check if player has a specific pet
local function canUsePet(data)
    local petName = data and data.name
    local wantedSpeciesID = tonumber(data and data.petID)
    local wantedName = string.lower(tostring(petName or ""))

    if not C_PetJournal then
        return false
    end

    if wantedSpeciesID and C_PetJournal.GetNumCollectedInfo then
        local ownedCount = select(1, C_PetJournal.GetNumCollectedInfo(wantedSpeciesID))
        if tonumber(ownedCount) and ownedCount > 0 then
            return true
        end
    end

    if not C_PetJournal.GetNumPets or wantedName == "" then
        return false
    end

    if GetOwnedPetNameSet()[wantedName] then
        return true
    end

    if C_PetJournal.PetIsSummonable and C_PetJournal.FindPetIDByName then
        local foundPetID = C_PetJournal.FindPetIDByName(petName)
        if foundPetID then
            return C_PetJournal.PetIsSummonable(foundPetID) == true
        end
    end

    return false
end

-- Check if player has an item in bags
local function canUseItem(data)
    return data.itemID and GetItemCount and GetItemCount(data.itemID, false, false) > 0
end

-- Check if player has collected a mount
local function canUseMount(data)
    local mountID = data.mountId or
                        (C_MountJournal and C_MountJournal.GetMountFromItem and
                            C_MountJournal.GetMountFromItem(data.itemID))
    
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return false
    end
    
    local _, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    
    -- Treat mounts as available when owned/collected, even if temporarily unusable
    -- (indoors, restricted zone, shapeshift/form restrictions, etc.)
    if isCollected ~= nil then
        return isCollected == true
    end
    
    return isUsable == true
end

-- Check if player has a toy
local function canUseToy(data)
    return (type(PlayerHasToy) == "function" and PlayerHasToy(data.itemID))
end

-- Check if player has a usable hearthstone
local function canUseRandomHearthstone()
    local entries = _G.Hearthstones
    if type(entries) == "table" and type(PlayerHasToy) == "function" then
        for _, entry in ipairs(entries) do
            if entry and entry.actionType == "toy" and entry.category == "Home" and entry.itemID and PlayerHasToy(entry.itemID) then
                return true
            end
        end
    end
    
    return GetItemCount and GetItemCount(6948, false, false) > 0
end

-- Check if player knows a spell
local function canUseSpell(data)
    if not data.spellID or type(data.spellID) ~= "number" then
        return false
    end
    return IsSpellKnown and IsSpellKnown(data.spellID)
end

-- Check if player has required profession
local function canUseProfession(data)
    if not data or not data.requiredProfession then
        return true
    end
    
    local prof1, prof2 = GetProfessions()
    local isPrimary = false
    local isSecondary = false
    
    if prof1 then
        isPrimary = select(1, GetProfessionInfo(prof1)) == data.requiredProfession.name
    end
    if prof2 then
        isSecondary = select(1, GetProfessionInfo(prof2)) == data.requiredProfession.name
    end
    
    return isPrimary or isSecondary
end

-- ============================================================================
-- High-Level Utility Availability
-- ============================================================================

-- Check if player can use a given utility (spell, item, pet, mount, etc.)
function Cooldowns.CanPlayerUseUtility(data)
    if type(data) ~= "table" then
        return false
    end

    if not canUseProfession(data) then
        return false
    end
    
    if data.actionType == "pet" then
        return canUsePet(data)
    elseif data.actionType == "item" then
        return canUseItem(data)
    elseif data.actionType == "mount" then
        return canUseMount(data)
    elseif data.actionType == "toy" then
        return canUseToy(data)
    elseif data.actionType == "random_hearthstone" then
        return canUseRandomHearthstone()
    elseif data.actionType == "spell" then
        return canUseSpell(data)
    end
    return false
end

-- Get a macro to use a random hearthstone
function Cooldowns.GetRandomHearthstoneMacro()
    local entries = _G.Hearthstones
    local candidates = {}
    
    if type(entries) == "table" and type(PlayerHasToy) == "function" then
        for _, entry in ipairs(entries) do
            if entry and entry.actionType == "toy" and entry.category == "Home" and entry.itemID and PlayerHasToy(entry.itemID) then
                -- Only add if not on cooldown
                if Cooldowns.GetRemaining(entry) == 0 then
                    table.insert(candidates, entry)
                end
            end
        end
    end
    
    -- Add basic hearthstone if available
    if GetItemCount and GetItemCount(6948, false, false) > 0 then
        local hs = { itemID = 6948 }
        if Cooldowns.GetRemaining(hs) == 0 then
            table.insert(candidates, hs)
        end
    end

    -- If every hearthstone option is unavailable or on cooldown, fall back to the
    -- basic hearthstone macro instead of crashing on math.random(1, 0).
    if #candidates == 0 then
        return "/use item:6948"
    end

    local index = math.random(1, #candidates)
    local choice = candidates[index]
    return "/use item:" .. tostring(choice.itemID)
end

_G.Nozmie_Cooldowns = Cooldowns
return Cooldowns
