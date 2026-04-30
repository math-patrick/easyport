-- ============================================================================
-- Nozmie - Banner UI Helpers
-- Manage banner positioning and persistence
-- ============================================================================

local BannerHelpers = {}

-- ============================================================================
-- Banner Position Persistence
-- ============================================================================

-- Save banner position to persistent storage
function BannerHelpers.SaveBannerPosition(frame)
    if not frame or not frame:IsVisible() then
        return
    end

    local State = require("core.state")
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()

    local position = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        xOfs = tonumber(xOfs) or 0,
        yOfs = tonumber(yOfs) or 0
    }

    if relativeTo and relativeTo ~= UIParent then
        position.relativePoint = point or "CENTER"
    end

    State.SetBannerPosition(position)
end

-- Load banner position from persistent storage
function BannerHelpers.LoadBannerPosition(frame)
    if not frame then
        return
    end
    
    local State = require("core.state")
    local position = State.GetBannerPosition()
    
    if type(position) == "table" then
        local point = position.point or "CENTER"
        local relativePoint = position.relativePoint or "CENTER"
        local x = tonumber(position.xOfs) or tonumber(position.x) or 0
        local y = tonumber(position.yOfs) or tonumber(position.y) or 0

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, x, y)

        return
    end

    -- Default position: center of screen
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

_G.Nozmie_BannerHelpers = BannerHelpers
return BannerHelpers
