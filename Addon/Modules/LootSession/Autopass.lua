---@class AddonEnv
local Env = select(2, ...)

local classFlags = {
    WARRIOR = 0x1,
    PALADIN = 0x2,
    HUNTER = 0x4,
    ROGUE = 0x8,
    PRIEST = 0x10,
    DEATHKNIGHT = 0x20,
    SHAMAN = 0x40,
    MAGE = 0x80,
    WARLOCK = 0x100,
    MONK = 0x200,
    DRUID = 0x400,
    DEMONHUNTER = 0x800,
    EVOKER = 0x1000,
    ALL_CLASSES = 0xFFFF,
}

---@type table<integer, table<integer,integer|nil>|nil>
local itemClassMasks = {
    [Enum.ItemClass.Container] = {
        [1] = classFlags.WARLOCK, -- Soul bags
    },
    [Enum.ItemClass.Weapon] = {
        [Enum.ItemWeaponSubclass.Axe1H] = classFlags.HUNTER + classFlags.PALADIN + classFlags.SHAMAN + classFlags.WARRIOR,  -- One-Handed Axes
        [Enum.ItemWeaponSubclass.Axe2H] = classFlags.HUNTER + classFlags.PALADIN + classFlags.SHAMAN + classFlags.WARRIOR,  -- Two-Handed Axes
        [Enum.ItemWeaponSubclass.Bows] = classFlags.HUNTER + classFlags.ROGUE + classFlags.WARRIOR,                         -- Bows
        [Enum.ItemWeaponSubclass.Guns] = classFlags.HUNTER + classFlags.ROGUE + classFlags.WARRIOR,                         -- Guns
        [Enum.ItemWeaponSubclass.Mace1H] = classFlags.DRUID + classFlags.PALADIN + classFlags.PRIEST + classFlags.ROGUE +
            classFlags.SHAMAN + classFlags.WARRIOR,                                                                         -- One-Handed Maces
        [Enum.ItemWeaponSubclass.Mace2H] = classFlags.DRUID + classFlags.PALADIN + classFlags.SHAMAN + classFlags.WARRIOR,  -- Two-Handed Maces
        [Enum.ItemWeaponSubclass.Polearm] = classFlags.DRUID + classFlags.HUNTER + classFlags.PALADIN + classFlags.WARRIOR, -- Polearms
        [Enum.ItemWeaponSubclass.Sword1H] = classFlags.HUNTER + classFlags.MAGE + classFlags.PALADIN + classFlags.ROGUE +
            classFlags.WARLOCK + classFlags.WARRIOR,                                                                        -- One-Handed Swords
        [Enum.ItemWeaponSubclass.Sword2H] = classFlags.HUNTER + classFlags.PALADIN + classFlags.WARRIOR,                    -- Two-Handed Swords
        [Enum.ItemWeaponSubclass.Staff] = classFlags.DRUID + classFlags.HUNTER + classFlags.MAGE + classFlags.PRIEST +
            classFlags.SHAMAN + classFlags.WARLOCK + classFlags.WARRIOR,                                                    -- Staves
        [Enum.ItemWeaponSubclass.Unarmed] = classFlags.DRUID + classFlags.HUNTER + classFlags.ROGUE + classFlags.SHAMAN +
            classFlags.WARRIOR,                                                                                             -- Fist Weapons
        [Enum.ItemWeaponSubclass.Dagger] = classFlags.DRUID + classFlags.HUNTER + classFlags.MAGE + classFlags.PRIEST +
            classFlags.ROGUE + classFlags.SHAMAN + classFlags.WARLOCK + classFlags.WARRIOR,                                 -- Daggers
        [Enum.ItemWeaponSubclass.Thrown] = classFlags.HUNTER + classFlags.ROGUE + classFlags.WARRIOR,                       -- Thrown Classic
        [Enum.ItemWeaponSubclass.Crossbow] = classFlags.HUNTER + classFlags.ROGUE + classFlags.WARRIOR,                     -- Crossbows
        [Enum.ItemWeaponSubclass.Wand] = classFlags.MAGE + classFlags.PRIEST + classFlags.WARLOCK,                          -- Wands
    },
    [Enum.ItemClass.Armor] = {
        [Enum.ItemArmorSubclass.Cloth] = classFlags.ALL_CLASSES,                                                                -- Cloth
        [Enum.ItemArmorSubclass.Leather] = classFlags.ALL_CLASSES - (classFlags.MAGE + classFlags.PRIEST + classFlags.WARLOCK), -- Leather
        [Enum.ItemArmorSubclass.Mail] = classFlags.DEATHKNIGHT + classFlags.EVOKER + classFlags.HUNTER + classFlags.PALADIN +
            classFlags.SHAMAN + classFlags.WARRIOR,                                                                             -- Mail
        [Enum.ItemArmorSubclass.Plate] = classFlags.DEATHKNIGHT + classFlags.PALADIN + classFlags.WARRIOR,                      -- Plate
        [Enum.ItemArmorSubclass.Shield] = classFlags.PALADIN + classFlags.WARRIOR + classFlags.SHAMAN,                          -- Shields
        [Enum.ItemArmorSubclass.Libram] = classFlags.PALADIN,                                                                   -- Librams  Classic
        [Enum.ItemArmorSubclass.Idol] = classFlags.DRUID,                                                                       -- Idols  Classic
        [Enum.ItemArmorSubclass.Totem] = classFlags.SHAMAN,                                                                     -- Totems  Classic
        [Enum.ItemArmorSubclass.Sigil] = classFlags.DEATHKNIGHT,                                                                -- Sigils  Classic
    },
}

---@param classId integer
---@param subClassId integer
---@return integer
local function GetItemAllowedClassMask(classId, subClassId)
    if itemClassMasks[classId] and itemClassMasks[classId][subClassId] then
        return itemClassMasks[classId][subClassId]
    end
    return classFlags.ALL_CLASSES
end

-- Map classIds to the default localized name. Needed due to gendered class names using UnitClass().
local classIdToDefaultLocalized = (function()
    local list = {} ---@type table<integer, string>
    for _, v in ipairs(Env.classList) do
        list[v.id] = v.displayText
    end
    return list
end)()

---Should we auto pass on the item.
---@param itemLink string
---@param itemClassId integer
---@param itemSubClassId integer
function Env.Session.ShouldAutopass(itemLink, itemClassId, itemSubClassId)
    -- Check weapon and armor type restrictions
    local _, playerClassKey, classId = UnitClass("player")
    if bit.band(GetItemAllowedClassMask(itemClassId, itemSubClassId), classFlags[playerClassKey]) == 0 then
        Env:PrintDebug("Autopassing on",itemLink,"because of item type restrictions.")
        return true
    end

    -- Check class restriction
    local classesString = Env.Item.GetItemClassRestrictionString(itemLink)
    if classesString and not classesString:find(classIdToDefaultLocalized[classId]) then
        Env:PrintDebug("Autopassing on",itemLink,"because of class restrictions.")
        return true
    end

    Env:PrintDebug("Do not autopass on", itemLink)
    return false
end
