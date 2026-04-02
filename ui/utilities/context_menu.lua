-- ============================================================================
-- Nozmie - Context Menu & Wowhead UI
-- Wowhead link popup and right-click context menu presentation
-- ============================================================================

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then return Locale.GetString(key, fallback) end
    return fallback or key
end

local WOWHEAD_POPUP_KEY = "NOZMIE_WOWHEAD_LINK"
local wowheadPopupRegistered = false
local pendingWowheadURL = nil
local contextMenuFrame = nil

local ContextMenu = {}

-- ============================================================================
-- Wowhead Popup
-- ============================================================================

local function UrlEncode(str)
    str = tostring(str or ""):gsub("\n", " ")
    str = str:gsub("([^%w%-_%.~ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return str:gsub(" ", "+")
end

local function GetWowheadURL(item)
    if not item then return nil end
    if item.itemID then return "https://www.wowhead.com/item=" .. tostring(item.itemID) end
    if item.spellID then return "https://www.wowhead.com/spell=" .. tostring(item.spellID) end
    local searchText = item.spellName or item.name or item.destination
    if searchText and searchText ~= "" then
        return "https://www.wowhead.com/search?q=" .. UrlEncode(searchText)
    end
    return nil
end

local function EnsureWowheadPopupRegistered()
    if wowheadPopupRegistered then return end

    StaticPopupDialogs[WOWHEAD_POPUP_KEY] = {
        text = Lstr("utility.entry.wowhead.popup.title",
            "This entry is not available to use right now. Copy this Wowhead link to see details:"),
        button1 = Lstr("utility.entry.wowhead.popup.close", "Close"),
        hasEditBox = true,
        editBoxWidth = 360,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            local editBox = self.editBox or self:GetEditBox()
            editBox:SetText(pendingWowheadURL or "")
            editBox:SetAutoFocus(true)
            editBox:HighlightText()
        end,
        OnAccept = function(self)
            (self.editBox or self:GetEditBox()):SetText("")
        end,
        OnHide = function(self)
            (self.editBox or self:GetEditBox()):SetText("")
        end,
    }

    wowheadPopupRegistered = true
end

function ContextMenu.OpenWowheadForEntry(item)
    local url = GetWowheadURL(item)
    if not url then return end
    EnsureWowheadPopupRegistered()
    pendingWowheadURL = url
    StaticPopup_Show(WOWHEAD_POPUP_KEY)
end

-- ============================================================================
-- Context Menu Presentation
-- ============================================================================

local function EnsureContextMenuFrame()
    if not contextMenuFrame then
        contextMenuFrame = CreateFrame("Frame", "NozmieUtilityContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    return contextMenuFrame
end

local function OpenContextMenuWithEasyMenu(menuFrame, entries)
    if not EasyMenu then return false end
    local menu = {}
    for _, entry in ipairs(entries) do
        menu[#menu + 1] = { text = entry.text, notCheckable = true, func = entry.action }
    end
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
    return true
end

local function OpenContextMenuWithDropDown(menuFrame, entries)
    if not (UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton) then
        return false
    end
    UIDropDownMenu_Initialize(menuFrame, function(_, level)
        if level ~= 1 then return end
        for _, entry in ipairs(entries) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.notCheckable = true
            info.func = entry.action
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
    return true
end

-- Show a context menu for a button. menuEntries is a list of { text, action }.
-- fallbackAction is called when no dropdown API is available.
function ContextMenu.ShowMenu(button, menuEntries, fallbackAction)
    if not button or not menuEntries then return end
    local menuFrame = EnsureContextMenuFrame()
    if OpenContextMenuWithEasyMenu(menuFrame, menuEntries) then return end
    if OpenContextMenuWithDropDown(menuFrame, menuEntries) then return end
    if fallbackAction then fallbackAction() end
end

_G.Nozmie_ContextMenu = ContextMenu
return ContextMenu
