-- ============================================================================
-- Nozmie - Detection Feature Module
-- Finds matching utilities/teleports in chat messages
-- ============================================================================

local Detection = {}

-- ============================================================================
-- Suppression & Filtering
-- ============================================================================

-- Check if suppression list contains key
local function HasSuppression(list, key)
    if not list then
        return false
    end
    for _, entry in ipairs(list) do
        if entry == key then
            return true
        end
    end
    return false
end

-- Check if item should be suppressed by category list
local function ShouldSuppressByList(list, keys)
    if not list or #list == 0 then
        return false
    end
    for _, key in ipairs(keys) do
        if HasSuppression(list, key) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Utility Classification
-- ============================================================================

-- Check if spell is a portal spell
local function IsPortalSpell(teleportData)
    local spellName = teleportData.spellName or ""
    return spellName:find("^Portal:") or spellName:find("^Ancient Portal:")
end

-- Check if utility is a service (repair, mailbox, etc)
local function IsServiceOption(data)
    local destination = data.destination or ""
    return destination:find("Repair") or destination:find("Mailbox") or destination:find("Anvil") or destination:find("Transmog")
end

-- Check if utility is a hearthstone
local function IsHearthstone(data)
    return data.category == "Home"
end

-- ============================================================================
-- Suppression Decision Logic
-- ============================================================================

-- Determine if a utility should be suppressed based on settings and context
function Detection.ShouldSuppressOption(data, settings, inInstance)
    if not settings or not settings.Get then
        return false
    end

    local isClass = data.category == "Class" or data.category == "Class Utility"
    local isUtility = data.category and data.category == "Utility"
    local isMPlus = data.category == "M+ Dungeon"
    local isRaid = data.category == "Raid"
    local isPortal = IsPortalSpell(data)
    local isTeleport = data.category == "Teleport"
    local isHearthstone = IsHearthstone(data)
    local isMount = data.actionType == "mount"
    local isService = IsServiceOption(data)

    local keys = {}
    if isMount then table.insert(keys, "mount") end
    if isClass then table.insert(keys, "class") end

    -- Grouped: Portals/Teleports/M+ Dungeons/Raids
    if isMPlus or isRaid or isTeleport or isPortal or isHearthstone then
        table.insert(keys, "teleports")
    end

    -- Grouped: Utility/Service (Mail, Repair, Transmog)
    if isUtility or isService then
        table.insert(keys, "utilityservice")
    end

    if ShouldSuppressByList(settings.Get("suppressGlobalList"), keys) then
        return true
    end

    if inInstance and ShouldSuppressByList(settings.Get("suppressInstanceList"), keys) then
        return true
    end

    return false
end

-- ============================================================================
-- Message Matching & Filtering
-- ============================================================================

-- Find all matching utilities in a chat message
function Detection.FindMatchingUtilities(message, sender)
    local Cooldowns = require("features.cooldowns")
    local Data = require("db.data")
    local Helpers = require("utils.helpers")
    local lowerMessage = message:lower()
    
    local matches, hearthstones, currents = {}, {}, {}
    local Settings = _G.Nozmie_Settings
    local preferPortals = Settings and Settings.Get and Settings.Get("preferPortals")

    -- Extract WoW links (|Hitem:id|h, |Hspell:id|h)
    local idsInMessage = {}
    for linkType, id in message:gmatch("|H(%a+):(%d+):.-|h") do
        idsInMessage[tonumber(id)] = true
    end
    for linkType, id in message:gmatch("|H(%a+):(%d+)|h") do
        idsInMessage[tonumber(id)] = true
    end

    -- Check blacklist
    if Settings then
        local blacklist = Settings.Get("blacklistedWords") or ""
        if blacklist ~= "" then
            for word in blacklist:gmatch("([^,]+)") do
                local trimmedWord = word:match("^%s*(.-)%s*$"):lower()
                if trimmedWord ~= "" and lowerMessage:find(trimmedWord, 1, true) then
                    return {}
                end
            end
        end
    end

    -- Player/Instance context
    local targetPlayer = sender and sender:match("([^-]+)") or sender
    local playerName = UnitName("player")
    if playerName and targetPlayer == playerName then
        targetPlayer = nil
    end
    local inInstance = IsInInstance()

    -- Find matches
    local allData = {}
    if Data and type(Data.GetAllUtilities) == "function" then
        allData = Data.GetAllUtilities()
    elseif Data and type(Data.GetAllData) == "function" then
        allData = Data.GetAllData()
    elseif type(_G.Nozmie_Data) == "table" then
        allData = _G.Nozmie_Data
    end

    for _, utilityData in ipairs(allData) do
        local matched = false
        
        -- Match by ID
        if (utilityData.spellID and idsInMessage[utilityData.spellID]) or 
           (utilityData.itemID and idsInMessage[utilityData.itemID]) then
            matched = true
        elseif utilityData.keywords then
            -- Match by keyword
            for _, keyword in ipairs(utilityData.keywords) do
                if Helpers.MatchesKeyword(lowerMessage, keyword) then
                    matched = true
                    break
                end
            end
        end
        
        if matched and Cooldowns.CanPlayerUseUtility(utilityData) then
            if not Detection.ShouldSuppressOption(utilityData, Settings, inInstance) then
                local utilityCopy = {}
                for k, v in pairs(utilityData) do
                    utilityCopy[k] = v
                end
                
                -- Set target player for utility spells
                if targetPlayer and utilityCopy.category and
                    (utilityCopy.category:find("Utility") or utilityCopy.spellName == "Levitate" or
                        utilityCopy.spellName == "Slow Fall") then
                    utilityCopy.targetPlayer = targetPlayer
                end
                
                -- Categorize result
                if utilityCopy.current then
                    table.insert(currents, utilityCopy)
                elseif IsHearthstone(utilityCopy) then
                    table.insert(hearthstones, utilityCopy)
                else
                    table.insert(matches, utilityCopy)
                end
            end
        end
    end

    -- Randomize hearthstones
    if #hearthstones > 1 then
        Helpers.ShuffleTable(hearthstones)
    end

    -- Sort by cooldown and priority
    local ready, oncd = {}, {}
    for _, t in ipairs(matches) do
        if Cooldowns.GetRemaining(t) > 0 then
            table.insert(oncd, t)
        else
            table.insert(ready, t)
        end
    end

    -- Priority sorting function
    local function sortPriority(a, b)
        local pa = tonumber(a.priority) or 0
        local pb = tonumber(b.priority) or 0
        if preferPortals then
            local aPortal = a.spellName and a.spellName:find("^Portal:")
            local bPortal = b.spellName and b.spellName:find("^Portal:")
            if aPortal and not bPortal then return true end
            if bPortal and not aPortal then return false end
        end
        if pa ~= pb then
            return pa > pb
        end
        return false
    end
    
    table.sort(ready, sortPriority)
    table.sort(oncd, sortPriority)

    -- Compose result: current > ready > hearthstones > on-cooldown
    local result = {}
    for _, t in ipairs(currents) do
        table.insert(result, t)
    end
    for _, t in ipairs(ready) do
        table.insert(result, t)
    end
    for _, t in ipairs(hearthstones) do
        table.insert(result, t)
    end
    for _, t in ipairs(oncd) do
        table.insert(result, t)
    end

    return result
end

_G.Nozmie_Detection = Detection
return Detection
