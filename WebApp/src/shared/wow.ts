export const enum ItemQuality {
    Poor = 0,
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary,
    Artifact,
    Heirloom,
    WoWToken,
}

export const itemQualityData = {
    [ItemQuality.Poor]: { name: "Poor", rgbhex: "#9d9d9d" },
    [ItemQuality.Common]: { name: "Common", rgbhex: "#ffffff" },
    [ItemQuality.Uncommon]: { name: "Uncommon", rgbhex: "#1eff00" },
    [ItemQuality.Rare]: { name: "Rare", rgbhex: "#0070dd" },
    [ItemQuality.Epic]: { name: "Epic", rgbhex: "#a335ee" },
    [ItemQuality.Legendary]: { name: "Legendary", rgbhex: "#ff8000" },
    [ItemQuality.Artifact]: { name: "Artifact", rgbhex: "#e6cc80" },
    [ItemQuality.Heirloom]: { name: "Heirloom", rgbhex: "#00ccff" },
    [ItemQuality.WoWToken]: { name: "WoWToken", rgbhex: "#00ccff" },
};

export const enum ClassId {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

export const classData: Record<ClassId, { name: string; rgbhex: string }> = {
    [ClassId.WARRIOR]: { name: "Warrior", rgbhex: "#C69B6D" },
    [ClassId.PALADIN]: { name: "Paladin", rgbhex: "#F48CBA" },
    [ClassId.HUNTER]: { name: "Hunter", rgbhex: "#AAD372" },
    [ClassId.ROGUE]: { name: "Rogue", rgbhex: "#FFF468" },
    [ClassId.PRIEST]: { name: "Priest", rgbhex: "#FFFFFF" },
    [ClassId.DEATHKNIGHT]: { name: "Death Knight", rgbhex: "#C41E3A" },
    [ClassId.SHAMAN]: { name: "Shaman", rgbhex: "#0070DD" },
    [ClassId.MAGE]: { name: "Mage", rgbhex: "#3FC7EB" },
    [ClassId.WARLOCK]: { name: "Warlock", rgbhex: "#8788EE" },
    [ClassId.MONK]: { name: "Monk", rgbhex: "#00FF98" },
    [ClassId.DRUID]: { name: "Druid", rgbhex: "#FF7C0A" },
    [ClassId.DEMONHUNTER]: { name: "Demon Hunter", rgbhex: "#A330C9" },
    [ClassId.EVOKER]: { name: "Evoker", rgbhex: "#33937F" },
};
