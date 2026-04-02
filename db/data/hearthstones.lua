local keywords = {"hearthstone", "hearth", "home", "inn"}

local function Hearth(name, itemID, overrides)
    local t = {
        name        = name,
        itemID      = itemID,
        spellName   = name,
        actionType  = "toy",
        category    = "Home",
        cooldown    = "15 min",
        destination = "Hearthstone",
        keywords    = keywords,
    }
    if overrides then
        for k, v in pairs(overrides) do t[k] = v end
    end
    return t
end

Hearthstones = {
    {
        name        = "Random Hearthstone",
        itemID      = 6948,
        spellName   = "Random Hearthstone",
        actionType  = "random_hearthstone",
        category    = "Home",
        cooldown    = "15 min",
        destination = "Hearthstone",
        keywords    = keywords,
        current     = 1,
    },
    {
        name        = "Hearthstone",
        itemID      = 6948,
        spellName   = "Hearthstone",
        actionType  = "item",
        category    = "Home",
        cooldown    = "15 min",
        destination = "Hearthstone",
        keywords    = keywords,
    },

    Hearth("The Innkeeper's Daughter",               64488),
    Hearth("Dark Portal",                            93672),
    Hearth("Ethereal Portal",                        54452),
    Hearth("Eternal Traveler's Hearthstone",         172179),
    Hearth("Brewfest Reveler's Hearthstone",         166747),
    Hearth("Headless Horseman's Hearthstone",        163045),
    Hearth("Lunar Elder's Hearthstone",              165669),
    Hearth("Peddlefeet's Lovely Hearthstone",        165670),
    Hearth("Noble Gardener's Hearthstone",           165802),
    Hearth("Fire Eater's Hearthstone",               166746),
    Hearth("Greatfather Winter's Hearthstone",       162973),
    Hearth("Holographic Digitalization Hearthstone", 168907),
    Hearth("Dominated Hearthstone",                  188952),
    Hearth("Enlightened Hearthstone",                190196),
    Hearth("Broker Translocation Matrix",            190237),
    Hearth("Deepdweller's Earthen Hearthstone",      208704),
    Hearth("Hearthstone of the Flame",               209035),
    Hearth("Stone of the Hearth",                    212337),
    Hearth("Timewalker's Hearthstone",               193588),
    Hearth("Ohn'ir Windsage's Hearthstone",          200630),
    Hearth("Notorious Thread's Hearthstone",         228940),
    Hearth("Explosive Hearthstone",                  236687),
    Hearth("P.O.S.T. Master's Express Hearthstone",  245970),
    Hearth("Cosmic Hearthstone",                     246565),
    Hearth("Corewarden's Hearthstone",               265100),
    Hearth("Corewarden's Hearthstone",               265100),
    Hearth("Fire Eater's Hearthstone",               166746),
    Hearth("Lightcalled Hearthstone",                257736),
    Hearth("Lunar Elder's Hearthstone",              165669),
    Hearth("Ohn'ir Windsage's Hearthstone",          200630),
    Hearth("Preyseeker's Hearthstone",               263933),
    Hearth("Timewalker's Hearthstone",               193588),
    Hearth("Astonishingly Scarlet Slippers",         142298),
    Hearth("Scroll of Town Portal",                  142543),
    Hearth("Tome of Town Portal",                    142542),
    Hearth("Path of the Naaru",                      206195),
    Hearth("Redeployment Module",                    235016),
    -- Hearth("Naaru's Enfold",                      263489),
    -- Hearth("Draenic Hologem",                     210455),
}