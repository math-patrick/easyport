local Helpers = {}
local lastAnnounce = {
    message = nil,
    time = 0
}
local groupKeyReports = {}
local mapNameByIDCache = {}
local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

function Helpers.SaveBannerPosition(banner)
    local root = banner.stackRoot or banner
    local point, _, relativePoint, xOfs, yOfs = root:GetPoint()
    NozmieDB = NozmieDB or {}
    NozmieDB.position = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }
    if root.baseAnchor then
        root.baseAnchor = nil
    end
end

function Helpers.LoadBannerPosition(banner)
    if NozmieDB and NozmieDB.position then
        local p = NozmieDB.position
        banner:ClearAllPoints()
        banner:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs)
        return
    end
    banner:ClearAllPoints()
    banner:SetPoint("BOTTOM", ChatFrame1, "TOP", 0, 20)
end

function Helpers.FormatCooldownTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    end
    return string.format("%ds", secs)
end

function Helpers.IsInAnyGroup()
    return IsInGroup() or IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end

function Helpers.GetGroupChatChannel()
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    return "PARTY"
end

function Helpers.GetChannelFromEvent(event)
    if event == "CHAT_MSG_SAY" then
        return "SAY"
    end
    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_INSTANCE_CHAT" then
        return "PARTY"
    end
    if event == "CHAT_MSG_RAID" then
        return "RAID"
    end
    if event == "CHAT_MSG_GUILD" then
        return "GUILD"
    end
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        return "WHISPER"
    end
    if event == "CHAT_MSG_BN_WHISPER" then
        return "BN_WHISPER"
    end
    return nil
end

function Helpers.SendMessageForEvent(message, event, sender)
    -- Ignore non-channel events (like LEFT_CLICK)
    if event == "LEFT_CLICK" or event == "RIGHT_CLICK" then
        return false
    end
    local channel = Helpers.GetChannelFromEvent(event)
    if not channel then
        channel = "SAY"
    end
    if channel == "WHISPER" then
        if not sender or sender == "" then
            return false
        end
        C_ChatInfo.SendChatMessage(message, channel, nil, sender)
        return true
    elseif channel == "BN_WHISPER" then
        if not sender or sender == "" then
            return false
        end
        C_ChatInfo.SendAddonMessage("Nozmie", message, "BN_WHISPER", sender)
        return true
    end

    -- Only send if channel is a valid chat type
    local validChannels = {
        SAY = true,
        PARTY = true,
        RAID = true,
        GUILD = true,
        INSTANCE_CHAT = true,
        YELL = true
    }
    if not validChannels[channel] then
        channel = "SAY"
    end
    C_ChatInfo.SendChatMessage(message, channel)
    return true
end

function Helpers.MarkAnnounce(message)
    lastAnnounce.message = message
    lastAnnounce.time = GetTime()
end

function Helpers.IsRecentAnnounce(message, window)
    if not lastAnnounce.message then
        return false
    end
    local limit = window or 2
    return message == lastAnnounce.message and (GetTime() - lastAnnounce.time) <= limit
end

function Helpers.GetActionAndNoun(data)
    local actionVerb = Lstr("banner.action.use", "Use")
    local nounForm = data.destination or data.name or "utility"
    local announceVerb = string.format(Lstr("announce.using", "Using %s!"), nounForm)

    if data.actionType == "pet" or data.actionType == "mount" or (data.category == "Utility") then
        actionVerb = Lstr("banner.action.summon", "Summon")
        announceVerb = string.format(Lstr("announce.summoning", "Summoning %s!"), nounForm)
    elseif data.actionType == "spell" and data.category and
        (data.category:find("Class") or data.category:find("Class Utility")) then
        actionVerb = Lstr("banner.action.cast", "Cast")
        nounForm = data.spellName or data.name
        announceVerb = string.format(Lstr("announce.casting", "Casting %s!"), nounForm)
    elseif data.category and
        (data.category == "M+ Dungeon" or data.category == "Raid" or data.category == "Teleport") then
        actionVerb = Lstr("banner.action.teleport", "Teleport to")
        announceVerb = string.format(Lstr("announce.teleporting", "Teleporting to %s!"), nounForm)
    end

    return actionVerb, nounForm, announceVerb
end

function Helpers.CreateAnnouncementMessage(data)
    local cooldown = Helpers.GetCooldownRemaining(data)
    local actionVerb, nounForm = Helpers.GetActionAndNoun(data)
    if cooldown > 0 then
        local timeText = Helpers.FormatCooldownTime(cooldown)
        if actionVerb == Lstr("banner.action.teleport", "Teleport to") then
            local portalNoun = Lstr("announce.noun.portal", "Portal")
            return string.format(Lstr("announce.portalReadyIn", "%s to %s ready in %s"), portalNoun,
                data.destination or data.name, timeText)
        end
        return string.format(Lstr("announce.readyIn", "%s ready in %s"), nounForm, timeText)
    end
    if actionVerb == Lstr("banner.action.teleport", "Teleport to") then
        return string.format(Lstr("announce.canTeleport", "I can teleport to %s!"), data.destination or data.name)
    end
    if data.destination and
        (data.destination:find("Repair") or data.destination:find("Mailbox") or data.destination:find("Anvil")) then
        return string.format(Lstr("announce.canUseDestination", "I can use %s!"), data.destination)
    end
    return string.format(Lstr("announce.canUseName", "I can use %s!"), data.name)
end

function Helpers.AnnounceUtility(data, event, sender)
    local Settings = _G.Nozmie_Settings
    local announceToGroup = Settings and Settings.Get and Settings.Get("announceToGroup")
    local message

    if announceToGroup and (not event or event == "LEFT_CLICK") then
        local _, _, announceVerb = Helpers.GetActionAndNoun(data)
        message = string.format("[Nozmie] %s", announceVerb)
    else
        message = Helpers.CreateAnnouncementMessage(data)
    end

    if event then
        Helpers.SendMessageForEvent(message, event, sender)
        Helpers.MarkAnnounce(message)
        return
    end

    if Helpers.IsInAnyGroup() then
        C_ChatInfo.SendChatMessage(message, Helpers.GetGroupChatChannel())
    else
        C_ChatInfo.SendChatMessage(message, "SAY")
    end
    Helpers.MarkAnnounce(message)
end

function Helpers.GetCooldownRemaining(data)
    if data.preferItem and data.itemID then
        local start, duration = C_Item.GetItemCooldown(data.itemID)
        if start and duration and type(start) == "number" and type(duration) == "number" then
            local ok, remaining = pcall(function()
                if start > 0 and duration > 0 then
                    return start + duration - GetTime()
                end
                return 0
            end)
            if ok and remaining and remaining > 0 then
                return remaining
            end
        end
    end
    if data.spellID then
        local info = C_Spell.GetSpellCooldown(data.spellID)
        if info and info.startTime and info.duration and type(info.startTime) == "number" and type(info.duration) ==
            "number" then
            local ok, remaining = pcall(function()
                if info.startTime > 0 and info.duration > 0 then
                    return info.startTime + info.duration - GetTime()
                end
                return 0
            end)
            if ok and remaining and remaining > 0 then
                return remaining
            end
        end
    elseif data.itemID then
        local start, duration = C_Item.GetItemCooldown(data.itemID)
        if start and duration and type(start) == "number" and type(duration) == "number" then
            local ok, remaining = pcall(function()
                if start > 0 and duration > 0 then
                    return start + duration - GetTime()
                end
                return 0
            end)
            if ok and remaining and remaining > 0 then
                return remaining
            end
        end
    end
    return 0
end

function Helpers.GetOwnedKeystoneInfo()
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
        level = C_MythicPlus.GetOwnedKeystoneLevel()
    end

    return {
        mapID = mapID,
        mapName = mapName or tostring(mapID),
        level = level
    }
end

local function NormalizePlayerName(name)
    if not name or name == "" then
        return nil
    end
    return name:match("([^-]+)") or name
end

local function NormalizeMapName(name)
    if not name or name == "" then
        return nil
    end
    local normalized = name:lower()
    normalized = normalized:gsub("[^%w]", "")
    return normalized
end

local function NormalizeDungeonName(name)
    local normalized = NormalizeMapName(name)
    if not normalized then
        return nil
    end
    normalized = normalized:gsub("^the", "")
    return normalized
end

local function DungeonNamesMatch(a, b)
    local left = NormalizeDungeonName(a)
    local right = NormalizeDungeonName(b)
    if not left or not right then
        return false
    end
    return left == right or left:find(right, 1, true) ~= nil or right:find(left, 1, true) ~= nil
end

local function GetMapNameFromID(mapID)
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

local function EntryMatchesKeystone(entry, report)
    if not entry or not report then
        return false
    end

    if report.mapName and DungeonNamesMatch(report.mapName, entry.name) then
        return true
    end

    if type(entry.keywords) == "table" and report.mapName then
        for _, keyword in ipairs(entry.keywords) do
            if DungeonNamesMatch(report.mapName, keyword) then
                return true
            end
        end
    end

    if report.mapID then
        local mappedName = GetMapNameFromID(report.mapID)
        if mappedName and DungeonNamesMatch(mappedName, entry.name) then
            return true
        end
        if mappedName and type(entry.keywords) == "table" then
            for _, keyword in ipairs(entry.keywords) do
                if DungeonNamesMatch(mappedName, keyword) then
                    return true
                end
            end
        end
    end

    return false
end

function Helpers.ParseKeystoneLink(message, sender)
    local parsed = Helpers.ParseKeystoneReportMessage(message)
    if not parsed or not parsed.hasKey then
        return nil
    end

    return {
        playerName = NormalizePlayerName(sender or UnitName("player")),
        dungeonID = parsed.mapID,
        level = tonumber(parsed.level),
        mapName = parsed.mapName,
        link = parsed.link
    }
end

function Helpers.GetOwnedKeystoneLink()
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

function Helpers.GetKeystoneInfoFromLink(link)
    if type(link) ~= "string" then
        return nil
    end

    local payload = link:match("|Hkeystone:([^|]+)|h")
    if not payload then
        return nil
    end

    local numericFields = {}
    for token in payload:gmatch("[^:]+") do
        local number = tonumber(token)
        if number then
            numericFields[#numericFields + 1] = number
        end
    end

    local mapID
    local mapName
    local mapIndex
    for index, value in ipairs(numericFields) do
        local candidateName = GetMapNameFromID(value)
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

    return {
        mapID = mapID,
        mapName = mapName,
        level = level,
        link = link
    }
end

function Helpers.ClearGroupKeyReports()
    wipe(groupKeyReports)
end

function Helpers.RecordGroupKeyReport(playerName, mapName, level, mapID, link)
    local shortName = NormalizePlayerName(playerName)
    if not shortName then
        return
    end

    local resolvedMapName = mapName
    if (not resolvedMapName or resolvedMapName == "") and mapID then
        resolvedMapName = GetMapNameFromID(mapID)
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

function Helpers.StoreDetectedKey(playerName, dungeonID, level, link)
    local shortName = NormalizePlayerName(playerName)
    if not shortName then
        return false
    end

    local mapID = tonumber(dungeonID)
    if not mapID or mapID <= 0 then
        return false
    end

    local mapName = GetMapNameFromID(mapID)
    Helpers.RecordGroupKeyReport(shortName, mapName, tonumber(level), mapID, link)
    return true
end

function Helpers.GetGroupKeyReports()
    local reports = {}
    for _, info in pairs(groupKeyReports) do
        reports[#reports + 1] = info
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

function Helpers.SendOwnedKeystoneToChannel(channel)
    if not channel or channel == "" then
        return false
    end

    local keyInfo = Helpers.GetOwnedKeystoneInfo()
    local message
    if keyInfo and keyInfo.level and keyInfo.level > 0 then
        local link = Helpers.GetOwnedKeystoneLink()
        if link and link ~= "" then
            message = string.format("!nozmie %s", link)
        else
            message = string.format("!nozmie %s +%d", keyInfo.mapName, keyInfo.level)
        end
    else
        message = "!nozmie none"
    end

    C_ChatInfo.SendChatMessage(message, channel)

    local playerName = UnitName("player")
    if keyInfo and keyInfo.level and keyInfo.level > 0 then
        Helpers.RecordGroupKeyReport(playerName, keyInfo.mapName, keyInfo.level, keyInfo.mapID,
            Helpers.GetOwnedKeystoneLink())
    else
        Helpers.RecordGroupKeyReport(playerName, nil, nil)
    end

    return true
end

function Helpers.ParseKeystoneReportMessage(message)
    if type(message) ~= "string" then
        return nil
    end

    local trimmed = message:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end

    local lowered = trimmed:lower()
    if lowered == "!nozmie none" or lowered == "!mykey none" then
        return {
            hasKey = false
        }
    end

    local cleanLink = trimmed:match("(%|c.-%|Hkeystone:[^|]+%|h%[.-%]%|h%|r)")
    if not cleanLink then
        cleanLink = trimmed:match("(%|Hkeystone:[^|]+%|h%[.-%]%|h)")
    end
    if cleanLink then
        local info = Helpers.GetKeystoneInfoFromLink(cleanLink)
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

    local mapName, level = trimmed:match("^!nozmie%s+(.+)%s+%+(%d+)%s*$")
    if not (mapName and level) then
        mapName, level = trimmed:match("^!mykey%s+(.+)%s+%+(%d+)%s*$")
    end
    if mapName and level then
        return {
            hasKey = true,
            mapName = mapName,
            level = tonumber(level)
        }
    end

    return nil
end

function Helpers.GetKeystoneOwnershipForEntry(entry)
    if not entry or entry.category ~= "M+ Dungeon" then
        return nil
    end

    local entryName = entry.name
    if not entryName then
        return nil
    end

    local own = Helpers.GetOwnedKeystoneInfo()
    if own and EntryMatchesKeystone(entry, own) then
        return "own"
    end

    local reports = Helpers.GetGroupKeyReports()
    local playerName = NormalizePlayerName(UnitName("player"))
    for _, report in ipairs(reports) do
        if report and report.playerName ~= playerName and EntryMatchesKeystone(entry, report) then
            return "group"
        end
    end

    return nil
end

function Helpers.GetGroupKeystoneOwnersForEntry(entry)
    local owners = {}
    if not entry or entry.category ~= "M+ Dungeon" then
        return owners
    end

    local entryName = entry.name
    if not entryName then
        return owners
    end

    local playerName = NormalizePlayerName(UnitName("player"))
    local reports = Helpers.GetGroupKeyReports()
    for _, report in ipairs(reports) do
        if report and report.playerName ~= playerName and EntryMatchesKeystone(entry, report) then
            owners[#owners + 1] = {
                playerName = report.playerName,
                level = report.level,
                mapName = report.mapName
            }
        end
    end

    return owners
end

function Helpers.GetKeystoneOwnerTooltipText(entry)
    if not entry or entry.category ~= "M+ Dungeon" then
        return nil
    end

    local ownership = Helpers.GetKeystoneOwnershipForEntry(entry)
    if ownership == "own" then
        local own = Helpers.GetOwnedKeystoneInfo()
        if own and own.level and own.level > 0 then
            return string.format("You have a +%d key", own.level)
        end
        return "You have a key"
    end

    if ownership == "group" then
        local owners = Helpers.GetGroupKeystoneOwnersForEntry(entry)
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

function Helpers.CleanupGroupKeyReportsForCurrentGroup()
    local playerName = NormalizePlayerName(UnitName("player"))
    if not Helpers.IsInAnyGroup() then
        wipe(groupKeyReports)
        return
    end

    local allowed = {}
    if playerName then
        allowed[playerName] = true
    end

    if IsInRaid() and GetNumGroupMembers then
        for index = 1, GetNumGroupMembers() do
            local unit = "raid" .. tostring(index)
            local name = NormalizePlayerName(UnitName(unit))
            if name then
                allowed[name] = true
            end
        end
    elseif GetNumSubgroupMembers then
        for index = 1, GetNumSubgroupMembers() do
            local unit = "party" .. tostring(index)
            local name = NormalizePlayerName(UnitName(unit))
            if name then
                allowed[name] = true
            end
        end
    end

    for name in pairs(groupKeyReports) do
        if not allowed[name] then
            groupKeyReports[name] = nil
        end
    end
end

local function CanUsePet(data)
    if not C_PetJournal or not C_PetJournal.GetNumPets or not data.petName then
        return false
    end
    for i = 1, C_PetJournal.GetNumPets() do
        local _, _, _, customName, _, _, _, petNameFromJournal = C_PetJournal.GetPetInfoByIndex(i)
        if petNameFromJournal == data.petName or customName == data.petName then
            return true
        end
    end
    return false
end

local function CanUseItem(data)
    return data.itemID and GetItemCount and GetItemCount(data.itemID, false, false) > 0
end

local function CanUseMount(data)
    local mountID = data.mountId or
                        (C_MountJournal and C_MountJournal.GetMountFromItem and
                            C_MountJournal.GetMountFromItem(data.itemID))

    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return false
    end

    local _, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)

    -- Treat mounts as available when owned/collected, even if temporarily unusable
    -- (indoors, restricted zone, shapeshift/form restrictions, etc.).
    if isCollected ~= nil then
        return isCollected == true
    end

    return isUsable == true
end

local function CanUseToy(data)
    return (type(PlayerHasToy) == "function" and PlayerHasToy(data.itemID))
end

local function CanUseRandomHearthstone()
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

function Helpers.GetRandomHearthstoneMacro()
    local entries = _G.Hearthstones
    local candidates = {}

    if type(entries) == "table" and type(PlayerHasToy) == "function" then
        for _, entry in ipairs(entries) do
            if entry and entry.actionType == "toy" and entry.category == "Home" and entry.itemID and PlayerHasToy(entry.itemID) then
                -- Only add if not on cooldown
                if Helpers.GetCooldownRemaining(entry) == 0 then
                    table.insert(candidates, entry)
                end
            end
        end
    end

    -- Basic hearthstone
    if GetItemCount and GetItemCount(6948, false, false) > 0 then
        local hs = {itemID = 6948}
        if Helpers.GetCooldownRemaining(hs) == 0 then
            table.insert(candidates, hs)
        end
    end

    if #candidates == 0 then
        -- Optionally, print a message to the user
        if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
            UIErrorsFrame:AddMessage("No usable hearthstones available!", 1, 0, 0)
        end
        return nil
    end

    local index = math.random(1, #candidates)
    local choice = candidates[index]
    return "/use item:" .. tostring(choice.itemID)
end

local function CanUseSpell(data)
    if not data.spellID or type(data.spellID) ~= "number" then
        return false
    end
    return IsSpellKnown and IsSpellKnown(data.spellID)
end

local function CanUseProfession(data)
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

function Helpers.CanPlayerUseUtility(data)
    if not CanUseProfession(data) then
        return false
    end
    if data.actionType == "pet" then
        return CanUsePet(data)
    elseif data.actionType == "item" then
        return CanUseItem(data)
    elseif data.actionType == "mount" then
        return CanUseMount(data)
    elseif data.actionType == "toy" then
        return CanUseToy(data)
    elseif data.actionType == "random_hearthstone" then
        return CanUseRandomHearthstone()
    elseif data.actionType == "spell" then
        return CanUseSpell(data)
    end
    return false
end

_G.Nozmie_Helpers = Helpers
