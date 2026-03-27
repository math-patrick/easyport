local Helpers = Nozmie_Helpers
local Detector = {}

local function ShuffleTable(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function EscapePattern(text)
    return (text:gsub("(%W)", "%%%1"))
end

local function MatchesKeyword(message, keyword)
    if not message or not keyword or keyword == "" then
        return false
    end
    local normalizedMessage = message:lower()
    local normalizedKeyword = tostring(keyword):lower()
    local pattern = "%f[%w]" .. EscapePattern(normalizedKeyword) .. "%f[%W]"
    return normalizedMessage:find(pattern) ~= nil
end

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

local function IsPortalSpell(teleportData)
    local spellName = teleportData.spellName or ""
    return spellName:find("^Portal:") or spellName:find("^Ancient Portal:")
end

local function IsServiceOption(data)
    local destination = data.destination or ""
    return destination:find("Repair") or destination:find("Mailbox") or destination:find("Anvil") or destination:find("Transmog")
end

local function IsHearthstone(data)
    return data.category == "Home"
end

local function ShouldSuppressOption(data, settings, inInstance)
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
    if isMPlus or isRaid or isTeleport or isPortal or isDelve or isHearthstone then
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

function Detector.FindMatchingTeleports(message, sender)
    local lowerMessage = message:lower()
    local matches, hearthstones, currents = {}, {}, {}
    local Settings = Nozmie_Settings
    local preferPortals = Settings and Settings.Get and Settings.Get("preferPortals")

    local idsInMessage = {}
    -- Match links like |Hitem:3577:0:0:276308480|h and |Hspell:12345|h
    for linkType, id in message:gmatch("|H(%a+):(%d+):.-|h") do
        idsInMessage[tonumber(id)] = true
    end
    for linkType, id in message:gmatch("|H(%a+):(%d+)|h") do
        idsInMessage[tonumber(id)] = true
    end

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

    -- Player/instance context
    local targetPlayer = sender and sender:match("([^-]+)") or sender
    local playerName = UnitName("player")
    if playerName and targetPlayer == playerName then
        targetPlayer = nil
    end
    local inInstance = IsInInstance()

    for _, teleportData in ipairs(Nozmie_Data) do
        local matched = false
        -- Match by spellID/itemID
        if (teleportData.spellID and idsInMessage[teleportData.spellID]) or (teleportData.itemID and idsInMessage[teleportData.itemID]) then
            matched = true
        elseif teleportData.keywords then
            for _, keyword in ipairs(teleportData.keywords) do
                if MatchesKeyword(lowerMessage, keyword) then
                    matched = true
                    break
                end
            end
        end
        if matched and Helpers.CanPlayerUseUtility(teleportData) then
            if not ShouldSuppressOption(teleportData, Settings, inInstance) then
                local teleportCopy = {}
                for k, v in pairs(teleportData) do
                    teleportCopy[k] = v
                end
                if targetPlayer and teleportCopy.category and
                    (teleportCopy.category:find("Utility") or teleportCopy.spellName == "Levitate" or
                        teleportCopy.spellName == "Slow Fall") then
                    teleportCopy.targetPlayer = targetPlayer
                end
                if teleportCopy.current then
                    table.insert(currents, teleportCopy)
                elseif IsHearthstone(teleportCopy) then
                    table.insert(hearthstones, teleportCopy)
                else
                    table.insert(matches, teleportCopy)
                end
            end
        end
    end

    -- Randomize hearthstones
    if #hearthstones > 1 then
        ShuffleTable(hearthstones)
    end

    -- Sort matches: cooldowns last, priority first
    local ready, oncd = {}, {}
    for _, t in ipairs(matches) do
        if Helpers.GetCooldownRemaining(t) > 0 then
            table.insert(oncd, t)
        else
            table.insert(ready, t)
        end
    end

    -- Priority sorting: priority=1 first, portals first if preferPortals
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

    -- Compose result: current > ready > hearthstones > cooldowns
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

_G.Nozmie_Detector = Detector
