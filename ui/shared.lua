-- SharedUI.lua
-- Shared logic for text/label rendering for Nozmie UI elements

local SharedUI = {}
local Locale = _G.Nozmie_Locale

-- Text/label logic (was in BannerController)
function SharedUI.GetEntryLabel(item)
    if not item then return "?" end
    if item.spellName then return item.spellName end
    if item.name then
        if Locale and Locale.GetEntryName then
            return Locale.GetEntryName(item, item.name)
        end
        return item.name
    end
    if item.destination then return item.destination end
    return "?"
end

_G.Nozmie_SharedUI = SharedUI
return SharedUI
