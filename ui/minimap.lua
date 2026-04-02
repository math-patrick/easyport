local ldb = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local State = require("core.state")

local dataobj = ldb:NewDataObject("Nozmie", {
    type = "launcher",
    text = "Nozmie",
    icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    OnClick = function(self, button)
        if button == "LeftButton" and _G.Nozmie_UtilityUI and _G.Nozmie_UtilityUI.Toggle then
            _G.Nozmie_UtilityUI.Toggle()
        elseif button == "MiddleButton" and _G.Nozmie_ShowLastBanner then
            _G.Nozmie_ShowLastBanner()
        elseif button == "RightButton" and _G.Nozmie_Settings then
            _G.Nozmie_Settings.Show()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Nozmie")
        tooltip:AddLine("Left-click: Open utility page", 1, 1, 1)
        tooltip:AddLine("Middle-click: Show last banner", 1, 1, 1)
        tooltip:AddLine("Right-click: Open settings", 1, 1, 1)
    end
})

local Minimap = {}
local isRegistered = false

local function GetSettings()
    return _G.Nozmie_Settings
end

local function GetMinimapDB()
    NozmieDB = NozmieDB or {}
    NozmieDB.minimap = NozmieDB.minimap or {}
    return NozmieDB.minimap
end

local function IsMinimapEnabled()
    local Settings = GetSettings()
    if Settings and Settings.Get then
        return Settings.Get("minimapIcon") == true
    end
    return State.GetSetting("minimapIcon") == true
end

local function SetMinimapEnabled(enabled)
    local Settings = GetSettings()
    if Settings and Settings.Set then
        Settings.Set("minimapIcon", enabled == true)
        return
    end

    State.SetSetting("minimapIcon", enabled == true)
end

function Minimap.UpdateVisibility()
    if not icon then
        return
    end

    local minimapDB = GetMinimapDB()
    local enabled = IsMinimapEnabled()
    minimapDB.hide = not enabled

    if enabled then
        icon:Show("Nozmie")
    else
        icon:Hide("Nozmie")
    end
end

function Minimap.Initialize()
    if not icon or not dataobj then
        return
    end

    local minimapDB = GetMinimapDB()
    minimapDB.hide = not IsMinimapEnabled()

    if not isRegistered then
        icon:Register("Nozmie", dataobj, minimapDB)
        icon:RegisterCallback("onMinimapIconMoved", function(event, name, position)
            if name == "Nozmie" then
                GetMinimapDB().minimapPos = position
            end
        end)
        isRegistered = true
    end

    Minimap.UpdateVisibility()
end

function Nozmie_ToggleMinimapIcon()
    SetMinimapEnabled(not IsMinimapEnabled())
    Minimap.UpdateVisibility()
end

_G.Nozmie_Minimap = Minimap
