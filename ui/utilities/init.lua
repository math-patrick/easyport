-- ============================================================================
-- Nozmie - UI Library Index
-- Centralizes UI support utilities
-- ============================================================================

-- Re-export existing UI utility modules for backward compatibility
local Utilities = {
    button = _G.Nozmie_UtilityButton,
    icon_renderer = _G.Nozmie_IconRenderer,
    icon_handling = _G.Nozmie_IconHandling,
    click_behavior = _G.Nozmie_ClickBehavior,
    config_helpers = _G.Nozmie_ConfigHelpers
}

_G.Nozmie_Utilities = Utilities
return Utilities
