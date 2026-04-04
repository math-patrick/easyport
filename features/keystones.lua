-- ============================================================================
-- Nozmie - Keystones Feature Module
-- Keystone detection, tracking, and group key management
-- ============================================================================

local Keystones = {}
local Locale = _G.Nozmie_Locale

-- Internal state for group key reports and caching
local groupKeyReports = {}
local mapNameByIDCache = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function normalizePlayerName(name)
    if not name or name == "" then return nil end
    return name:match("([^-]+)") or name
end

local function removeGroupKeyReport(playerName)
    local shortName = normalizePlayerName(playerName)
    if not shortName then
        return false
    end
    if groupKeyReports[shortName] == nil then
        return false
    end
    groupKeyReports[shortName] = nil
    return true
end

local function normalizeMapName(name)
    if not name or name == "" then return nil end
    local normalized = name:lower()
    normalized = normalized:gsub("[^%w]", "")
    return normalized
end

local function normalizeDungeonName(name)
    local normalized = normalizeMapName(name)
    if not normalized then return nil end
    normalized = normalized:gsub("^the", "")
    return normalized
end

local function dungeonNamesMatch(a, b)
    local left = normalizeDungeonName(a)
    local right = normalizeDungeonName(b)
    if not left or not right then return false end
    return left == right
end

local function entryNameMatchesMapName(entry, mapName)
    if not entry or not mapName then
        return false
    end

    if dungeonNamesMatch(mapName, entry.name) then
        return true
    end

    if Locale and Locale.GetAllEntryNames then
        for _, localizedName in ipairs(Locale.GetAllEntryNames(entry, entry.name)) do
            if dungeonNamesMatch(mapName, localizedName) then
                return true
            end
        end
    end

    return false
end

local function getMapNameFromID(mapID)
    if not mapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end
    if mapNameByIDCache[mapID] ~= nil then
        return mapNameByIDCache[mapID]
    end
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if type(name) == "string" and name ~= "" then
        mapNameByIDCache[mapID] = name
        return name
    end
    mapNameByIDCache[mapID] = false
    return nil
end

local function entryMatchesKeystone(entry, report)
    if not entry or not report then return false end
    
    if report.mapName and entryNameMatchesMapName(entry, report.mapName) then
        return true
    end
    
    if type(entry.keywords) == "table" and report.mapName then
        for _, keyword in ipairs(entry.keywords) do
            if dungeonNamesMatch(report.mapName, keyword) then
                return true
            end
        end
    end
    
    if report.mapID then
        local mappedName = getMapNameFromID(report.mapID)
        if mappedName and entryNameMatchesMapName(entry, mappedName) then
            return true
        end
        if mappedName and type(entry.keywords) == "table" then
            for _, keyword in ipairs(entry.keywords) do
                if dungeonNamesMatch(mappedName, keyword) then
                    return true
                end
            end
        end
    end
    
    return false
end

-- ============================================================================
-- Player's Own Keystone
-- ============================================================================

--[[
    Get player's currently owned keystone info
    Returns: { mapID, mapName, level }
]]
function Keystones.GetOwnedKeystone()
    if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneChallengeMapID then
        return nil
    end

    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID or mapID == 0 then
        return nil
    end

    local mapName
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if type(name) == "string" and name ~= "" then
            mapName = name
        end
    end

    local level
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel then
        level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
    end

    return {
        mapID = mapID,
        mapName = mapName or tostring(mapID),
        level = level
    }
end

-- Get item link for player's keystone
function Keystones.GetOwnedKeystoneLink()
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLink then
        local link = C_MythicPlus.GetOwnedKeystoneLink()
        if type(link) == "string" and link ~= "" then
            return link
        end
    end

    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink then
        for bag = 0, NUM_BAG_SLOTS do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if type(link) == "string" and link:find("|Hkeystone:", 1, true) then
                    return link
                end
            end
        end
    end

    return nil
end

-- ============================================================================
-- Keystone Link Parsing
-- ============================================================================

-- Extract keystone info from item link
function Keystones.GetKeystoneInfoFromLink(link)
    if type(link) ~= "string" then return nil end
    
    local payload = link:match("|Hkeystone:([^|]+)|h")
    if not payload then return nil end
    
    local numericFields = {}
    for token in payload:gmatch("[^:]+") do
        local number = tonumber(token)
        if number then
            table.insert(numericFields, number)
        end
    end
    
    local mapID, mapName, mapIndex
    for index, value in ipairs(numericFields) do
        local candidateName = getMapNameFromID(value)
        if candidateName then
            mapID = value
            mapName = candidateName
            mapIndex = index
            break
        end
    end
    
    local level
    if mapIndex then
        for index = mapIndex + 1, #numericFields do
            local value = numericFields[index]
            if value >= 2 and value <= 40 then
                level = value
                break
            end
        end
    end
    
    if not level then
        for _, value in ipairs(numericFields) do
            if value >= 2 and value <= 40 and value ~= mapID then
                level = value
                break
            end
        end
    end
    
    if (not level or level <= 0) and link then
        local textLevel = link:match("%((%d+)%)") or link:match("%+(%d+)")
        level = tonumber(textLevel) or level
    end
    
    return { mapID = mapID, mapName = mapName, level = level, link = link }
end

-- Parse keystone from chat message (like "!nozmie" reports)
function Keystones.ParseKeystoneReportMessage(message)
    if type(message) ~= "string" then return nil end
    
    local trimmed = message:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    
    local lowered = trimmed:lower()
    if lowered == "!nozmie none" or lowered == "!mykey none" then
        return { hasKey = false }
    end
    
    -- Try to parse keystone link
    local cleanLink = trimmed:match("(%|c.-%|Hkeystone:[^|]+%|h%[.-%]%|h%|r)")
    if not cleanLink then
        cleanLink = trimmed:match("(%|Hkeystone:[^|]+%|h%[.-%]%|h)")
    end
    if cleanLink then
        local info = Keystones.GetKeystoneInfoFromLink(cleanLink)
        if info then
            return {
                hasKey = true,
                mapName = info.mapName,
                level = info.level,
                mapID = info.mapID,
                link = cleanLink
            }
        end
    end
    
    -- Try to parse text format
    local mapName, level = trimmed:match("^!nozmie%s+(.+)%s+%+(%d+)%s*$")
    if not (mapName and level) then
        mapName, level = trimmed:match("^!mykey%s+(.+)%s+%+(%d+)%s*$")
    end
    if mapName and level then
        return { hasKey = true, mapName = mapName, level = tonumber(level) }
    end
    
    return nil
end

-- Parse keystone from message/link with sender
function Keystones.ParseKeystoneLink(message, sender)
    local parsed = Keystones.ParseKeystoneReportMessage(message)
    if not parsed or not parsed.hasKey then
        return nil
    end

    return {
        playerName = normalizePlayerName(sender or UnitName("player")),
        dungeonID = parsed.mapID,
        level = tonumber(parsed.level),
        mapName = parsed.mapName,
        link = parsed.link
    }
end

-- ============================================================================
-- Group Key Tracking
-- ============================================================================

-- Record a group member's keystone
function Keystones.RecordGroupKeyReport(playerName, mapName, level, mapID, link)
    local shortName = normalizePlayerName(playerName)
    if not shortName then return end

    if (not mapName or mapName == "") and (not mapID or mapID == 0) then
        removeGroupKeyReport(shortName)
        return
    end
    
    local resolvedMapName = mapName
    if (not resolvedMapName or resolvedMapName == "") and mapID then
        resolvedMapName = getMapNameFromID(mapID)
    end
    
    groupKeyReports[shortName] = {
        playerName = shortName,
        mapName = resolvedMapName,
        level = level,
        mapID = mapID,
        link = link,
        timestamp = GetTime()
    }
end

function Keystones.RefreshOwnedKeystoneReport()
    local playerName = normalizePlayerName(UnitName("player"))
    if not playerName then
        return false, nil
    end

    local keyInfo = Keystones.GetOwnedKeystone()
    if not (keyInfo and keyInfo.mapID and keyInfo.mapID > 0) then
        return removeGroupKeyReport(playerName), nil
    end

    local level = tonumber(keyInfo.level) or 0
    local link = Keystones.GetOwnedKeystoneLink()
    local existing = groupKeyReports[playerName]
    local changed = not existing or existing.mapID ~= keyInfo.mapID or (tonumber(existing.level) or 0) ~= level or
        existing.mapName ~= keyInfo.mapName or existing.link ~= link

    if changed then
        Keystones.RecordGroupKeyReport(playerName, keyInfo.mapName, level, keyInfo.mapID, link)
    end

    return changed, keyInfo.mapID
end

-- Store a detected keystone (from chat link)
function Keystones.StoreDetectedKey(playerName, dungeonID, level, link)
    local shortName = normalizePlayerName(playerName)
    if not shortName then return false end
    
    local mapID = tonumber(dungeonID)
    if not mapID or mapID <= 0 then return false end
    
    local mapName = getMapNameFromID(mapID)
    Keystones.RecordGroupKeyReport(shortName, mapName, tonumber(level), mapID, link)
    return true
end

-- Get all group members' keystones (sorted by level desc, then name asc)
function Keystones.GetGroupKeyReports()
    local reports = {}
    for _, info in pairs(groupKeyReports) do
        table.insert(reports, info)
    end
    
    table.sort(reports, function(a, b)
        local levelA = tonumber(a and a.level) or -1
        local levelB = tonumber(b and b.level) or -1
        if levelA ~= levelB then
            return levelA > levelB
        end
        local nameA = a and a.playerName or ""
        local nameB = b and b.playerName or ""
        return nameA < nameB
    end)
    
    return reports
end

-- Clear all group key reports
function Keystones.ClearGroupKeyReports()
    wipe(groupKeyReports)
end

-- Clean up reports for group members no longer in group
function Keystones.CleanupGroupKeyReportsForCurrentGroup()
    local playerName = normalizePlayerName(UnitName("player"))
    
    -- Clear all if not in group
    if not (IsInGroup() or IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        wipe(groupKeyReports)
        return
    end
    
    -- Build list of current group members
    local allowed = {}
    if playerName then
        allowed[playerName] = true
    end
    
    if IsInRaid() and GetNumGroupMembers then
        for index = 1, GetNumGroupMembers() do
            local unit = "raid" .. tostring(index)
            local name = normalizePlayerName(UnitName(unit))
            if name then
                allowed[name] = true
            end
        end
    elseif GetNumSubgroupMembers then
        for index = 1, GetNumSubgroupMembers() do
            local unit = "party" .. tostring(index)
            local name = normalizePlayerName(UnitName(unit))
            if name then
                allowed[name] = true
            end
        end
    end
    
    -- Remove reports for members not in group
    for name in pairs(groupKeyReports) do
        if not allowed[name] then
            groupKeyReports[name] = nil
        end
    end
end

-- ============================================================================
-- Group Communications
-- ============================================================================

-- Send player's keystone to group chat
function Keystones.SendOwnedKeystoneToChannel(channel)
    if not channel or channel == "" then
        return false
    end
    
    local keyInfo = Keystones.GetOwnedKeystone()
    local message
    if keyInfo and keyInfo.level and keyInfo.level > 0 then
        local link = Keystones.GetOwnedKeystoneLink()
        if link and link ~= "" then
            message = string.format("!nozmie %s", link)
        else
            message = string.format("!nozmie %s +%d", keyInfo.mapName, keyInfo.level)
        end
    else
        message = "!nozmie none"
    end
    
    C_ChatInfo.SendChatMessage(message, channel)

    Keystones.RefreshOwnedKeystoneReport()
    
    return true
end

-- ============================================================================
-- Utility Entry Analysis
-- ============================================================================

-- Check if player owns a keystone matching this dungeon entry
function Keystones.GetKeystoneOwnershipForEntry(entry)
    if not entry or entry.category ~= "M+ Dungeon" then
        return nil
    end
    
    local entryName = entry.name
    if not entryName then
        return nil
    end
    
    -- Check if we own a matching keystone
    local own = Keystones.GetOwnedKeystone()
    if own and entryMatchesKeystone(entry, own) then
        return "own"
    end
    
    -- Check if anyone in group owns a matching keystone
    local reports = Keystones.GetGroupKeyReports()
    local playerName = normalizePlayerName(UnitName("player"))
    for _, report in ipairs(reports) do
        if report and report.playerName ~= playerName and entryMatchesKeystone(entry, report) then
            return "group"
        end
    end
    
    return nil
end

-- Get group members who own a keystone for this dungeon entry
function Keystones.GetGroupKeystoneOwnersForEntry(entry)
    local owners = {}
    if not entry or entry.category ~= "M+ Dungeon" then
        return owners
    end
    
    local entryName = entry.name
    if not entryName then
        return owners
    end
    
    local playerName = normalizePlayerName(UnitName("player"))
    local reports = Keystones.GetGroupKeyReports()
    for _, report in ipairs(reports) do
        if report and report.playerName ~= playerName and entryMatchesKeystone(entry, report) then
            table.insert(owners, {
                playerName = report.playerName,
                level = report.level,
                mapName = report.mapName
            })
        end
    end
    
    return owners
end

-- Get descriptive text for keystone ownership tooltip
function Keystones.GetKeystoneOwnerTooltipText(entry)
    if not entry or entry.category ~= "M+ Dungeon" then
        return nil
    end
    
    local ownership = Keystones.GetKeystoneOwnershipForEntry(entry)
    if ownership == "own" then
        local own = Keystones.GetOwnedKeystone()
        if own and own.level and own.level > 0 then
            return string.format("You have a +%d key", own.level)
        end
        return "You have a key"
    end
    
    if ownership == "group" then
        local owners = Keystones.GetGroupKeystoneOwnersForEntry(entry)
        if #owners == 0 then
            return "Party member has a key"
        end
        local topOwner = owners[1]
        local level = tonumber(topOwner and topOwner.level) or 0
        local playerName = (topOwner and topOwner.playerName) or "?"
        if level > 0 then
            return string.format("Party member (%s) has a +%d key", playerName, level)
        end
        return string.format("Party member (%s) has a key", playerName)
    end
    
    return nil
end

_G.Nozmie_Keystones = Keystones
return Keystones
