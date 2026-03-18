local Helpers = {}
local lastAnnounce = {
    message = nil,
    time = 0
}
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
        (data.category == "M+ Dungeon" or data.category == "Raid" or data.category == "Delve" or data.category == "Toy") then
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
                table.insert(candidates, entry.itemID)
            end
        end
    end

    if #candidates == 0 then
        return "/use item:6948"
    end

    local index = math.random(1, #candidates)
    return "/use item:" .. tostring(candidates[index])
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
