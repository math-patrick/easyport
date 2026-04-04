Nozmie_Locales = Nozmie_Locales or {}

local Locale = {}

function Locale.GetLocale()
    return GetLocale() or "enUS"
end

local function GetLocaleTable(locale)
    return Nozmie_Locales[locale] or Nozmie_Locales["enUS"] or {}
end

local function AddUniqueString(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end
    seen[value] = true
    table.insert(list, value)
end

function Locale.GetString(key, fallback)
    local locale = Locale.GetLocale()
    local data = GetLocaleTable(locale)
    local strings = data.strings or {}
    local value = strings[key]
    if value == nil then
        local en = Nozmie_Locales["enUS"]
        value = en and en.strings and en.strings[key] or nil
    end
    return value or fallback or key
end

function Locale.GetEntryName(itemOrName, fallback)
    local baseName = itemOrName
    if type(itemOrName) == "table" then
        baseName = itemOrName.name
    end

    if type(baseName) ~= "string" or baseName == "" then
        return fallback or baseName
    end

    local locale = Locale.GetLocale()
    local data = GetLocaleTable(locale)
    local namesByName = data.namesByName or {}
    local value = namesByName[baseName]
    if value == nil then
        local en = Nozmie_Locales["enUS"]
        value = en and en.namesByName and en.namesByName[baseName] or nil
    end

    return value or fallback or baseName
end

function Locale.GetAllEntryNames(itemOrName, fallback)
    local baseName = itemOrName
    if type(itemOrName) == "table" then
        baseName = itemOrName.name
    end

    local names = {}
    local seen = {}

    AddUniqueString(names, seen, baseName)
    AddUniqueString(names, seen, fallback)

    if type(baseName) ~= "string" or baseName == "" then
        return names
    end

    for _, localeData in pairs(Nozmie_Locales or {}) do
        local localized = localeData and localeData.namesByName and localeData.namesByName[baseName]
        AddUniqueString(names, seen, localized)
    end

    return names
end

function Locale.ApplyKeywordAliases(dataList)
    local locale = Locale.GetLocale()
    local data = GetLocaleTable(locale)
    local aliases = data.keywordsByName or {}
    local enAliases = (Nozmie_Locales["enUS"] and Nozmie_Locales["enUS"].keywordsByName) or {}

    for _, item in ipairs(dataList or {}) do
        if item and item.name and item.keywords then
            local extra = aliases[item.name] or enAliases[item.name]
            if extra then
                for _, kw in ipairs(extra) do
                    local found = false
                    for _, existing in ipairs(item.keywords) do
                        if existing == kw then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(item.keywords, kw)
                    end
                end
            end

            for _, localizedName in ipairs(Locale.GetAllEntryNames(item.name, item.name)) do
                local found = false
                for _, existing in ipairs(item.keywords) do
                    if existing == localizedName then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(item.keywords, localizedName)
                end
            end
        end
    end
end

_G.Nozmie_Locale = Locale
