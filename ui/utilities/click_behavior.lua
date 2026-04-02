local Messaging = require("utils.messaging")
local Cooldowns = require("features.cooldowns")

local ClickBehavior = {}

local function CloseFrame(frame)
    UIFrameFadeOut(frame, 0.2, 1, 0)
    C_Timer.After(0.2, function()
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
        return
    end

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
end

function ClickBehavior.PreventRightClickAction(frame)
    if not frame then
        return
    end

    frame:SetAttribute("type2", "none")
    frame:SetAttribute("macrotext2", nil)
    frame:SetAttribute("spell2", nil)
    frame:SetAttribute("item2", nil)
end

function ClickBehavior.ApplyActionAttributes(frame, data)
    if not frame or not data then
        return
    end

    ClickBehavior.ClearActionAttributes(frame)
    ClickBehavior.PreventRightClickAction(frame)

    if data.actionType == "mount" and data.mountId and C_MountJournal and C_MountJournal.SummonByID then
        frame:SetScript("PreClick", function()
            C_MountJournal.SummonByID(data.mountId)
        end)
        return
    end

    if data.actionType == "random_hearthstone" then
        frame:SetScript("PreClick", function(self)
            local macro = "/use item:6948"
            if Cooldowns and Cooldowns.GetRandomHearthstoneMacro then
                macro = Cooldowns.GetRandomHearthstoneMacro() or macro
            end
            self:SetAttribute("type", "macro")
            self:SetAttribute("type1", "macro")
            self:SetAttribute("macrotext", macro)
            self:SetAttribute("macrotext1", macro)
        end)
        return
    end

    if data.actionType == "spell" and data.spellID then
        local spellName = data.spellName or (data.spellID and GetSpellInfo(data.spellID))
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
        return
    end

    if (data.actionType == "item" or data.actionType == "toy") and data.itemID then
        local macro = "/use item:" .. tostring(data.itemID)
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", macro)
        frame:SetAttribute("macrotext1", macro)
        return
    end

    if data.actionType == "pet" then
        local petName = data.name or ""
        local macro = data.macrotext or (petName ~= "" and ("/summonpet " .. petName) or "")
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", macro)
        frame:SetAttribute("macrotext1", macro)
        return
    end

    if data.macrotext then
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("macrotext", data.macrotext)
        frame:SetAttribute("macrotext1", data.macrotext)
    end
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
