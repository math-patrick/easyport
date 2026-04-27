-- ============================================================================
-- Nozmie - Helpers Legacy Wrapper
-- Redirects to new modular infrastructure
-- ============================================================================

-- Load new modules
local Keystones = require("features.keystones")
local Cooldowns = require("features.cooldowns")
local Messaging = require("utils.messaging")
local BannerHelpers = require("ui.banner.helpers")
local Helpers = require("utils.helpers")

-- Create merged export for backward compatibility
local LegacyHelpers = {}

-- ============================================================================
-- Keystone Functions (from features/keystones.lua)
-- ============================================================================
LegacyHelpers.GetOwnedKeystoneInfo = Keystones.GetOwnedKeystone
LegacyHelpers.GetKeystoneInfoFromLink = Keystones.GetKeystoneInfoFromLink
LegacyHelpers.ParseKeystoneLink = Keystones.ParseKeystoneLink
LegacyHelpers.ParseKeystoneReportMessage = Keystones.ParseKeystoneReportMessage
LegacyHelpers.RecordGroupKeyReport = Keystones.RecordGroupKeyReport
LegacyHelpers.GetGroupKeyReports = Keystones.GetGroupKeyReports
LegacyHelpers.SendOwnedKeystoneToChannel = Keystones.SendOwnedKeystoneToChannel
LegacyHelpers.GetKeystoneOwnershipForEntry = Keystones.GetKeystoneOwnershipForEntry
LegacyHelpers.CleanupGroupKeyReportsForCurrentGroup = Keystones.CleanupGroupKeyReportsForCurrentGroup
LegacyHelpers.StoreDetectedKey = Keystones.StoreDetectedKey

-- ============================================================================
-- Availability Functions (from features/cooldowns.lua)
-- ============================================================================
LegacyHelpers.CanPlayerUseUtility = Cooldowns.CanPlayerUseUtility
LegacyHelpers.GetCooldownRemaining = Cooldowns.GetRemaining
LegacyHelpers.GetRandomHearthstoneMacro = Cooldowns.GetRandomHearthstoneMacro

-- ============================================================================
-- Banner Functions (from ui/banner/helpers.lua)
-- ============================================================================
LegacyHelpers.SaveBannerPosition = BannerHelpers.SaveBannerPosition
LegacyHelpers.LoadBannerPosition = BannerHelpers.LoadBannerPosition

-- ============================================================================
-- Messaging Functions (from utils/messaging.lua)
-- ============================================================================
LegacyHelpers.GetActionAndNoun = Messaging.GetActionAndNoun
LegacyHelpers.CreateAnnouncementMessage = Messaging.CreateAnnouncementMessage
LegacyHelpers.MarkAnnounce = Messaging.MarkAnnounce
LegacyHelpers.IsRecentAnnounce = Messaging.IsRecentAnnounce
LegacyHelpers.SendMessageForEvent = Messaging.SendMessageForEvent
LegacyHelpers.AnnounceUtility = Messaging.AnnounceUtility

-- ============================================================================
-- Generic Helpers (from utils/helpers.lua)
-- ============================================================================
LegacyHelpers.FormatCooldownTime = Helpers.FormatCooldownTime
LegacyHelpers.IsInAnyGroup = Helpers.IsInAnyGroup
LegacyHelpers.GetGroupChatChannel = Helpers.GetGroupChatChannel
LegacyHelpers.GetChannelFromEvent = Helpers.GetChannelFromEvent
LegacyHelpers.SendChatMessage = Helpers.SendChatMessage
LegacyHelpers.NormalizePlayerName = Helpers.NormalizePlayerName
LegacyHelpers.NormalizeMapName = Helpers.NormalizeMapName
LegacyHelpers.NormalizeDungeonName = Helpers.NormalizeDungeonName
LegacyHelpers.EscapePattern = Helpers.EscapePattern
LegacyHelpers.MatchesKeyword = Helpers.MatchesKeyword
LegacyHelpers.ShuffleTable = Helpers.ShuffleTable
LegacyHelpers.SafeCall = Helpers.SafeCall
LegacyHelpers.CreateCache = Helpers.CreateCache
LegacyHelpers.Trim = Helpers.Trim

_G.Nozmie_Helpers = LegacyHelpers
return LegacyHelpers
