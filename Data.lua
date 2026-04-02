Nozmie_Data = {}

local function AddAll(tbl)
    for _, v in ipairs(tbl or {}) do
        table.insert(Nozmie_Data, v)
    end
end

AddAll(ClassSpells.ClassSpellsData)
AddAll(ClassSpells.ClassTeleports)
AddAll(Expansions)
AddAll(Hearthstones)
AddAll(MageTeleports)
AddAll(TeleportToys)
AddAll(ServiceToys)
AddAll(DelveTeleports)
AddAll(Mounts)
AddAll(UtilityPets)
AddAll(EasterEggs)

if _G.Nozmie_Locale and _G.Nozmie_Locale.ApplyKeywordAliases then
    _G.Nozmie_Locale.ApplyKeywordAliases(Nozmie_Data)
end
