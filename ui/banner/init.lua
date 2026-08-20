-- ============================================================================
-- Nozmie - UI Banner Module Index
-- ============================================================================

-- Note: this module intentionally does not assign _G.Nozmie_BannerUI.
-- ui/banner/panel.lua (loaded later) owns that global with the real banner
-- factory API; an earlier assignment here was immediately overwritten by
-- panel.lua's load and nothing ever read it in between.
local BannerHelpers = require("ui.banner.helpers")

return {
    helpers = BannerHelpers
}