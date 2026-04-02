-- SharedUI.lua
-- Shared logic for icon, text, and click/action for Nozmie UI elements

local SharedUI = {}

-- Icon logic (was in BannerController)
function SharedUI.GetIconForEntry(item)
    if not item then return "Interface/Icons/INV_Misc_QuestionMark" end
    if item.macrotext or item.actionType == "pet" then
        if item.iconTexture then return item.iconTexture end
        if item.petName and C_PetJournal and C_PetJournal.GetNumPets then
            local numPets = C_PetJournal.GetNumPets()
            for index = 1, numPets do
                local _, _, _, customName, _, _, _, petNameFromJournal, icon = C_PetJournal.GetPetInfoByIndex(index)
                if petNameFromJournal == item.petName or customName == item.petName then
                    return icon
                end
            end
        end
        return "Interface/Icons/INV_Misc_QuestionMark"
    end
    local preferItem = item.itemID and (item.actionType == "item" or item.actionType == "toy" or item.category == "Home")
    if item.spellID and item.keywords and tContains and tContains(item.keywords, "mount") then
        preferItem = false
    end
    if preferItem and item.itemID and C_Item and C_Item.GetItemIcon then
        local ok, icon = pcall(C_Item.GetItemIcon, item.itemID)
        if ok and icon then return icon end
    end
    if item.spellID and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, item.spellID)
        if ok and icon then return icon end
    end
    if item.icon then return item.icon end
    return "Interface/Icons/INV_Misc_QuestionMark"
end

-- Text/label logic (was in BannerController)
function SharedUI.GetEntryLabel(item)
    if not item then return "?" end
    if item.spellName then return item.spellName end
    if item.name then return item.name end
    if item.destination then return item.destination end
    return "?"
end

-- Click/action logic (was in BannerController)
function SharedUI.ApplyActionAttributes(button, item)
    if not button or not item then return end
    button:SetAttribute("type", nil)
    button:SetAttribute("type1", nil)
    button:SetAttribute("macrotext", nil)
    button:SetAttribute("macrotext1", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("item1", nil)
    if item.macrotext or item.actionType == "pet" then
        local macrotext = item.macrotext or (item.petName and ("/summonpet " .. item.petName) or "")
        button:SetAttribute("type", "macro")
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext", macrotext)
        button:SetAttribute("macrotext1", macrotext)
    else
        local preferItem = item.itemID and (item.actionType == "item" or item.actionType == "toy" or item.category == "Home")
        if item.spellID and item.keywords and tContains and tContains(item.keywords, "mount") then
            preferItem = false
        end
        if item.spellID and not preferItem then
            button:SetAttribute("type", "spell")
            button:SetAttribute("type1", "spell")
            button:SetAttribute("spell", item.spellName)
            button:SetAttribute("spell1", item.spellName)
        elseif item.itemID then
            button:SetAttribute("type", "macro")
            button:SetAttribute("type1", "macro")
            button:SetAttribute("macrotext", "/use item:" .. item.itemID)
            button:SetAttribute("macrotext1", "/use item:" .. item.itemID)
        end
    end
    button:SetAttribute("type2", "none")
    button:SetAttribute("macrotext2", nil)
    button:SetAttribute("spell2", nil)
    button:SetAttribute("item2", nil)
end

_G.Nozmie_SharedUI = SharedUI
return SharedUI
