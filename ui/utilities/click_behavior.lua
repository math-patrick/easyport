local Messaging = require("utils.messaging")
local Cooldowns = require("features.cooldowns")

local ClickBehavior = {}
local pendingCloseFrames = {}
local closeWatcher

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function EnsureCloseWatcher()
    if closeWatcher then
        return
    end

    closeWatcher = CreateFrame("Frame")
    closeWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    closeWatcher:SetScript("OnEvent", function()
        for frame in pairs(pendingCloseFrames) do
            if frame then
                pendingCloseFrames[frame] = nil
                frame.nozmieCloseAfterCombat = nil
                frame:SetAlpha(1)
                frame:Hide()
            end
        end
    end)
end

local function GetSpellName(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then
            return info.name
        end
        if type(info) == "string" then
            return info
        end
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end

    return nil
end

local function CloseFrame(frame)
    if IsCombatLocked() then
        frame.nozmieCloseAfterCombat = true
        pendingCloseFrames[frame] = true
        EnsureCloseWatcher()
        frame:SetAlpha(0)
        return
    end

    UIFrameFadeOut(frame, 0.2, 1, 0)
    C_Timer.After(0.2, function()
        if IsCombatLocked() then
            frame.nozmieCloseAfterCombat = true
            pendingCloseFrames[frame] = true
            EnsureCloseWatcher()
            frame:SetAlpha(0)
            return
        end
        frame:Hide()
    end)
end

local function GetFrameActionData(frame)
    if not frame then
        return nil
    end
    if frame.activeData then
        return frame.activeData
    end
    if frame.options and frame.currentIndex then
        return frame.options[frame.currentIndex]
    end
    return frame.data
end

function ClickBehavior.ClearActionAttributes(frame)
    if not frame then
        return false
    end

    if IsCombatLocked() then
        frame.nozmiePendingClearActionAttributes = true
        return false
    end

    frame.nozmiePendingClearActionAttributes = nil
    frame:SetScript("PreClick", nil)
    frame:SetAttribute("type", nil)
    frame:SetAttribute("type1", nil)
    frame:SetAttribute("type2", nil)
    frame:SetAttribute("macrotext", nil)
    frame:SetAttribute("macrotext1", nil)
    frame:SetAttribute("macrotext2", nil)
    frame:SetAttribute("spell", nil)
    frame:SetAttribute("spell1", nil)
    frame:SetAttribute("spell2", nil)
    frame:SetAttribute("item", nil)
    frame:SetAttribute("item1", nil)
    frame:SetAttribute("item2", nil)
    return true
end

function ClickBehavior.PreventRightClickAction(frame)
    if not frame then
        return false
    end

    if IsCombatLocked() then
        frame.nozmiePendingPreventRightClickAction = true
        return false
    end

    frame.nozmiePendingPreventRightClickAction = nil
    frame:SetAttribute("type2", "none")
    frame:SetAttribute("macrotext2", nil)
    frame:SetAttribute("spell2", nil)
    frame:SetAttribute("item2", nil)
    return true
end

function ClickBehavior.ApplyActionAttributes(frame, data)
    if not frame or not data then
        return false
    end

    if IsCombatLocked() then
        frame.nozmiePendingActionData = data
        return false
    end

    frame.nozmiePendingActionData = nil
    ClickBehavior.ClearActionAttributes(frame)
    ClickBehavior.PreventRightClickAction(frame)

    if data.actionType == "mount" and data.mountId and C_MountJournal and C_MountJournal.SummonByID then
        frame:SetScript("PreClick", function()
            C_MountJournal.SummonByID(data.mountId)
        end)
        return true
    end

    if data.actionType == "random_hearthstone" then
        local macro = "/use item:6948"
        if Cooldowns and Cooldowns.GetRandomHearthstoneMacro then
            macro = Cooldowns.GetRandomHearthstoneMacro() or macro
        end
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", macro)
        frame:SetAttribute("macrotext1", macro)
        return true
    end

    if data.actionType == "spell" and data.spellID then
        local spellName = data.spellName or GetSpellName(data.spellID)
        if data.targetPlayer and data.targetPlayer ~= UnitName("player") and data.category and data.category:find("Utility") then
            local macro = "/cast [@" .. data.targetPlayer .. "] " .. (spellName or "")
            frame:SetAttribute("type", "macro")
            frame:SetAttribute("type1", "macro")
            frame:SetAttribute("macrotext", macro)
            frame:SetAttribute("macrotext1", macro)
        else
            frame:SetAttribute("type", "spell")
            frame:SetAttribute("type1", "spell")
            frame:SetAttribute("spell", data.spellID or spellName)
            frame:SetAttribute("spell1", data.spellID or spellName)
        end
        return true
    end

    if (data.actionType == "item" or data.actionType == "toy") and data.itemID then
        local macro = "/use item:" .. tostring(data.itemID)
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", macro)
        frame:SetAttribute("macrotext1", macro)
        return true
    end

    if data.actionType == "pet" then
        local petName = data.name or ""
        local macro = data.macrotext or (petName ~= "" and ("/summonpet " .. petName) or "")
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", macro)
        frame:SetAttribute("macrotext1", macro)
        return true
    end

    if data.macrotext then
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", data.macrotext)
        frame:SetAttribute("macrotext1", data.macrotext)
        return true
    end

    return true
end

function ClickBehavior.ApplyPendingActionAttributes(frame)
    if not frame or IsCombatLocked() then
        return false
    end

    if frame.nozmiePendingActionData then
        return ClickBehavior.ApplyActionAttributes(frame, frame.nozmiePendingActionData)
    end

    if frame.nozmiePendingClearActionAttributes then
        ClickBehavior.ClearActionAttributes(frame)
    end

    if frame.nozmiePendingPreventRightClickAction then
        ClickBehavior.PreventRightClickAction(frame)
    end

    return true
end

function ClickBehavior.Apply(frame, opts)
    if not frame then
        return
    end

    opts = opts or {}
    frame.nozmieClickBehaviorOptions = {
        closeOnRight = opts.closeOnRight == true,
        closeOnLeft = opts.closeOnLeft == true,
        cancelAutoHide = opts.cancelAutoHide ~= false
    }

    frame.lastAnnounceTime = frame.lastAnnounceTime or 0

    if not frame.nozmieClickBehaviorHooked then
        frame:HookScript("PostClick", function(self, button)
            local options = self.nozmieClickBehaviorOptions or {}
            if options.cancelAutoHide and self.autoHideTimer then
                self.autoHideTimer:Cancel()
            end

            local data = GetFrameActionData(self)

            if button == "RightButton" then
                if options.closeOnRight then
                    CloseFrame(self)
                end
                return
            end

            if button == "LeftButton" then
                local Settings = _G.Nozmie_Settings
                local announceToGroup = Settings and Settings.Get and Settings.Get("announceToGroup")

                if announceToGroup and data and (not self.lastAnnounceTime or GetTime() - self.lastAnnounceTime > 1) then
                    if Messaging.AnnounceUtility(data) then
                        self.lastAnnounceTime = GetTime()
                    end
                end

                if options.closeOnLeft then
                    CloseFrame(self)
                end
            end
        end)
        frame.nozmieClickBehaviorHooked = true
    end

    frame.HandleAnnounce = function(self)
        local data = GetFrameActionData(self)
        local now = GetTime()
        if data and (not self.lastAnnounceTime or now - self.lastAnnounceTime > 1) then
            if Messaging.AnnounceUtility(data) then
                self.lastAnnounceTime = now
            end
        end
    end
end

_G.Nozmie_ClickBehavior = ClickBehavior
