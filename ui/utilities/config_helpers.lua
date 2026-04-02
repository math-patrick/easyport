local ConfigHelpers = {}

local petIconCache = {}
function ConfigHelpers.GetPetIconByName(petName)
    if not petName or not C_PetJournal or not C_PetJournal.GetNumPets then return nil end
    if petIconCache[petName] ~= nil then return petIconCache[petName] end
    for index = 1, C_PetJournal.GetNumPets() do
        local _, _, _, customName, _, _, _, petNameFromJournal, icon = C_PetJournal.GetPetInfoByIndex(index)
        if petNameFromJournal == petName or customName == petName then
            petIconCache[petName] = icon
            return icon
        end
    end
    petIconCache[petName] = nil
    return nil
end

function ConfigHelpers.GetIconForEntry(data)
    if data.iconTexture then return data.iconTexture end
    if data.actionType == "pet" then
        local petIcon = ConfigHelpers.GetPetIconByName(data.name)
        if petIcon then return petIcon end
    end
    if data.mountId and C_MountJournal and C_MountJournal.GetMountInfoByID then
        local _, _, icon = C_MountJournal.GetMountInfoByID(data.mountId)
        if icon then return icon end
    end
    if data.itemID and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(data.itemID)
    end
    if data.spellID and C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(data.spellID) end
    if data.actionType == "toy" and data.itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        local _, icon = C_ToyBox.GetToyInfo(data.itemID)
        return icon
    end
    return "Interface/Icons/INV_Misc_QuestionMark"
end

function ConfigHelpers.GetEntryName(data)
    return data.name or data.spellName or data.destination or "?"
end

function ConfigHelpers.GetMacroText(data)
    if data.macroText then return data.macroText end
    if data.spellID then return string.format("/cast %s", data.spellName or "") end
    if data.itemID then return string.format("/use item:%d", data.itemID) end
    if data.actionType == "pet" and data.name then return string.format("/summonpet %s", data.name) end
    return nil
end

_G.Nozmie_ConfigHelpers = ConfigHelpers
return ConfigHelpers
