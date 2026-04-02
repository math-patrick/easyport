local Mage = {{
    name = "Conjure Refreshment",
    spellID = 190336,
    spellName = "Conjure Refreshment",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"cookies", "food", "mana buns", "refreshment", "table", "mage table"}
}, {
    name = "Arcane Intellect",
    spellID = 1459,
    spellName = "Arcane Intellect",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"intellect", "arcane intellect", "buff"}
}, {
    name = "Slow Fall",
    spellID = 130,
    spellName = "Slow Fall",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"slow fall", "slowfall", "slow", "sf"}
}}

local Warlock = {{
    name = "Ritual of Summoning",
    spellID = 698,
    spellName = "Ritual of Summoning",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"summon", "resummon", "summ", "summons", "lock summon", "warlock summon"}
}, {
    name = "Create Soulwell",
    spellID = 29893,
    spellName = "Create Soulwell",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"soulwell", "soul well", "lock well", "healthstones", "healthstone", "health stone", "hs", "lock rock",
                "cookie", "cookies", "buff"}
}, {
    name = "Soulstone",
    spellID = 20707,
    spellName = "Soulstone",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"soulstone", "soul stone", "buff", "ss", "ress", "rez", "brez", "resurrection"}
}}

local Priest = {{
    name = "Power Word: Fortitude",
    spellID = 21562,
    spellName = "Power Word: Fortitude",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"fort", "fortitude", "stamina", "buff", "pw:f"}
}, {
    name = "Levitate",
    spellID = 1706,
    spellName = "Levitate",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"levitate"}
}, {
    name = "Resurrection",
    spellID = 2006,
    spellName = "Resurrection",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "rez", "ress", "resurrection", "priest res", "priest"}
}}

local Warrior = {{
    name = "Battle Shout",
    spellID = 6673,
    spellName = "Battle Shout",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"battle shout", "shout", "buff"}
}}

local Druid = {{
    name = "Mark of the Wild",
    spellID = 1126,
    spellName = "Mark of the Wild",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"motw", "mark", "mark of the wild", "buff"}
}, {
    name = "Rebirth",
    spellID = 20484,
    spellName = "Rebirth",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "rebirth", "brez", "bress", "ress"}
}, {
    name = "Revive",
    spellID = 50769,
    spellName = "Revive",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "revive", "brez", "bress", "ress"}
}}

local Shaman = {{
    name = "Skyfury",
    spellID = 462854,
    spellName = "Skyfury",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"skyfury", "buff", "sky fury"}
}, {
    name = "Ancestral Spirit",
    spellID = 2008,
    spellName = "Ancestral Spirit",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "ancestral spirit", "rez", "brez", "bress", "ress"}
}}

local Paladin = {{
    name = "Redemption",
    spellID = 7328,
    spellName = "Redemption",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "redemption", "rez", "brez", "bress", "ress"}
}}

local Monk = {{
    name = "Resuscitate",
    spellID = 115178,
    spellName = "Resuscitate",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "resuscitate", "rez", "brez", "bress", "ress"}
}}

local DeathKnight = {{
    name = "Raise Ally",
    spellID = 61999,
    spellName = "Raise Ally",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "raise ally", "rez", "brez", "bress", "ress"}
}}

local Evoker = {{
    name = "Blessing of the Bronze",
    spellID = 364342,
    spellName = "Blessing of the Bronze",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"blessing of the bronze", "botb", "buff"}
}, {
    name = "Source of Magic",
    spellID = 369459,
    spellName = "Source of Magic",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"source", "source of magic", "evoker mana", "buff"}
}, {
    name = "Return",
    spellID = 361227,
    spellName = "Return",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"res", "rez", "brez", "bress", "ress"}
}}

local MassRes = {{
    name = "Mass Resurrection",
    spellID = 212036,
    priority = 1,
    spellName = "Mass Resurrection",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}, {
    name = "Revitalize",
    spellID = 212040,
    priority = 1,
    spellName = "Revitalize",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}, {
    name = "Ancestral Vision",
    spellID = 212048,
    priority = 1,
    spellName = "Ancestral Vision",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}, {
    name = "Absolution",
    spellID = 212056,
    priority = 1,
    spellName = "Absolution",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}, {
    name = "Reawaken",
    spellID = 212051,
    priority = 1,
    spellName = "Reawaken",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}, {
    name = "Mass Return",
    spellID = 361178,
    priority = 1,
    spellName = "Mass Return",
    actionType = "spell",
    category = "Class Utility",
    keywords = {"mass res", "rez", "mass rez", "mass revive", "ress"}
}}

local ClassTeleports = { -- Druid
{
    name = "Moonglade",
    spellID = 18960,
    spellName = "Teleport: Moonglade",
    actionType = "spell",
    category = "Class",
    keywords = {"moonglade", "class hall"}
}, {
    name = "Emerald Dreamway",
    spellID = 193753,
    spellName = "Dreamwalk",
    actionType = "spell",
    category = "Class",
    keywords = {"dreamway", "dream way", "emerald dreamway", "class hall"}
}, -- Death Knight
{
    name = "Ebon Hold",
    spellID = 50977,
    spellName = "Death Gate",
    actionType = "spell",
    category = "Class",
    keywords = {"ebon hold", "death gate", "acherus", "class hall"}
}, -- Monk
{
    name = "Peak of Serenity",
    spellID = 126892,
    spellName = "Zen Pilgrimage",
    actionType = "spell",
    category = "Class",
    keywords = {"peak of serenity", "class hall"}
}, -- Shaman
{
    name = "Astral Recall",
    spellID = 556,
    spellName = "Astral Recall",
    actionType = "spell",
    category = "Class",
    cooldown = "10 min",
    keywords = {"astral recall", "shaman hearth", "home"}
}, {
    name = "Hall of the Guardian",
    spellID = 193759,
    spellName = "Teleport: Hall of the Guardian",
    actionType = "spell",
    category = "Class",
    keywords = {"hall of the guardian", "class hall"}
}}

local ClassSpellsData = {}
for _, tbl in ipairs({Mage, Warlock, Priest, Warrior, Druid, Shaman, Paladin, Monk, DeathKnight, Evoker, MassRes}) do
    for _, entry in ipairs(tbl) do
        table.insert(ClassSpellsData, entry)
    end
end

ClassSpells = {
    ClassSpellsData = ClassSpellsData,
    ClassTeleports = ClassTeleports
}
