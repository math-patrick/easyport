local libStub = _G.LibStub
local ldb = libStub and libStub("LibDataBroker-1.1", true)
local icon = libStub and libStub("LibDBIcon-1.0", true)
local State = require("core.state")

local Locale = _G.Nozmie_Locale
local function Lstr(key, fallback)
    if Locale and Locale.GetString then
        return Locale.GetString(key, fallback)
    end
    return fallback or key
end

local function HandleClick(button)
    if button == "LeftButton" and _G.Nozmie_UtilityUI and _G.Nozmie_UtilityUI.Toggle then
        _G.Nozmie_UtilityUI.Toggle()
    elseif button == "MiddleButton" and _G.Nozmie_ShowLastBanner then
        _G.Nozmie_ShowLastBanner()
    elseif button == "RightButton" and _G.Nozmie_Settings then
        _G.Nozmie_Settings.Show()
    end
end

local function ShowTooltip(owner, tooltip)
    tooltip:AddLine(Lstr("minimap.title", "Nozmie"))
    tooltip:AddLine(Lstr("minimap.leftClick", "Left-click: Open utility page"), 1, 1, 1)
    tooltip:AddLine(Lstr("minimap.middleClick", "Middle-click: Show last banner"), 1, 1, 1)
    tooltip:AddLine(Lstr("minimap.rightClick", "Right-click: Open settings"), 1, 1, 1)
    tooltip:AddLine(Lstr("minimap.drag", "Drag: Move minimap icon"), 0.75, 0.75, 0.75)
end

local dataobj = ldb and ldb:NewDataObject("Nozmie", {
    type = "launcher",
    text = "Nozmie",
    icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    OnClick = function(self, button)
        HandleClick(button)
    end,
    OnTooltipShow = function(tooltip)
        ShowTooltip(nil, tooltip)
    end
})

local Minimap = {}
local isRegistered = false
local nativeButton

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

local function UpdateNativeButtonPosition(position)
    if not nativeButton or not _G.Minimap then
        return
    end

    local angle = math.rad(position or GetMinimapDB().minimapPos or 225)
    local radius = 82
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    nativeButton:ClearAllPoints()
    nativeButton:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)
end

local function SaveNativeButtonPosition()
    if not nativeButton or not _G.Minimap then
        return
    end

    local mx, my = _G.Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = _G.Minimap:GetEffectiveScale()
    if not mx or not my or not px or not py or not scale or scale == 0 then
        return
    end

    px, py = px / scale, py / scale
    local position = math.deg(math.atan2(py - my, px - mx)) % 360
    GetMinimapDB().minimapPos = position
    UpdateNativeButtonPosition(position)
end

local function CreateNativeButton()
    if nativeButton or not _G.Minimap or not _G.CreateFrame then
        return nativeButton
    end

    local button = CreateFrame("Button", "NozmieNativeMinimapButton", _G.Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(50, 50)
    overlay:SetTexture(136430)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(136467)
    background:SetPoint("CENTER", button, "CENTER")

    local buttonIcon = button:CreateTexture(nil, "ARTWORK")
    buttonIcon:SetSize(18, 18)
    buttonIcon:SetTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")
    buttonIcon:SetPoint("CENTER", button, "CENTER")
    button.icon = buttonIcon

    button:SetScript("OnClick", function(self, buttonName)
        HandleClick(buttonName)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        ShowTooltip(self, GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", SaveNativeButtonPosition)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        SaveNativeButtonPosition()
    end)

    nativeButton = button
    UpdateNativeButtonPosition()
    return nativeButton
end

local function UpdateNativeVisibility(enabled)
    local button = nativeButton or CreateNativeButton()
    if not button then
        return
    end

    if enabled then
        UpdateNativeButtonPosition()
        button:Show()
    else
        button:Hide()
    end
end

function Minimap.UpdateVisibility()
    local minimapDB = GetMinimapDB()
    local enabled = IsMinimapEnabled()
    minimapDB.hide = not enabled

    if icon and dataobj and isRegistered then
        if nativeButton then
            nativeButton:Hide()
        end

        if enabled then
            icon:Show("Nozmie")
        else
            icon:Hide("Nozmie")
        end
    else
        UpdateNativeVisibility(enabled)
    end
end

function Minimap.Initialize()
    local minimapDB = GetMinimapDB()
    minimapDB.hide = not IsMinimapEnabled()

    if icon and dataobj and not isRegistered then
        if icon.IsRegistered and icon:IsRegistered("Nozmie") then
            isRegistered = true
            if icon.Refresh then
                pcall(icon.Refresh, icon, "Nozmie", minimapDB)
            end
        end
    end

    if icon and dataobj and not isRegistered then
        local ok = pcall(icon.Register, icon, "Nozmie", dataobj, minimapDB)
        if ok then
            if icon.RegisterCallback then
                pcall(icon.RegisterCallback, icon, "onMinimapIconMoved", function(event, name, position)
                    if name == "Nozmie" then
                        GetMinimapDB().minimapPos = position
                    end
                end)
            end
            isRegistered = true
        end
    end

    Minimap.UpdateVisibility()
end

function Nozmie_ToggleMinimapIcon()
    SetMinimapEnabled(not IsMinimapEnabled())
    Minimap.UpdateVisibility()
end

-- ============================================================================
-- Addon Compartment (available since patch 10.1.0)
-- Gives players a second, more discoverable entry point next to the
-- minimap icon; reuses the same click/tooltip behavior.
-- ============================================================================

function _G.Nozmie_OnAddonCompartmentClick(addonName, buttonName)
    HandleClick(buttonName or "LeftButton")
end

function _G.Nozmie_OnAddonCompartmentEnter(addonName, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    ShowTooltip(menuButtonFrame, GameTooltip)
    GameTooltip:Show()
end

function _G.Nozmie_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

_G.Nozmie_Minimap = Minimap
