---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("Worldbuffs:", ...)
end

local CHRONOBOON_BUFF_ID = 349981

---@enum WorldbuffFlags
local WB_FLAGS = {
    Diremaul = 0x1,
    Dragonslayer = 0x2,
    Warchief = 0x4,
    Darkmoon = 0x8,
    Zandalar = 0x10,
    Songflower = 0x20,
}

---@type table<integer,WorldbuffFlags>
local CHRONOBOON_WB_INDICES = {
    [17] = WB_FLAGS.Diremaul,
    [18] = WB_FLAGS.Diremaul,
    [19] = WB_FLAGS.Diremaul,
    [20] = WB_FLAGS.Dragonslayer,
    [21] = WB_FLAGS.Warchief,
    [22] = WB_FLAGS.Zandalar,
    [23] = WB_FLAGS.Songflower,
    [24] = WB_FLAGS.Darkmoon,
    [29] = WB_FLAGS.Warchief,
}

---@type table<integer,WorldbuffFlags>
local WB_IDS = {
    [22817]  = WB_FLAGS.Diremaul, -- Fengus' Ferocity
    [22818]  = WB_FLAGS.Diremaul, -- Mol'dar's Moxie
    [22820]  = WB_FLAGS.Diremaul, -- Slip'kik's Savvy
    [22888]  = WB_FLAGS.Dragonslayer,
    [355363] = WB_FLAGS.Dragonslayer,
    [16609]  = WB_FLAGS.Warchief,
    [355366] = WB_FLAGS.Warchief,
    [460939] = WB_FLAGS.Warchief, -- Might of Stormwind
    [460940] = WB_FLAGS.Warchief, -- Might of Stormwind
    [23768]  = WB_FLAGS.Darkmoon, -- Fortune of Damage
    [23769]  = WB_FLAGS.Darkmoon, -- Fortune of Resistance
    [23766]  = WB_FLAGS.Darkmoon, -- Fortune of Intelligence
    [23735]  = WB_FLAGS.Darkmoon, -- Fortune of Strength
    [23736]  = WB_FLAGS.Darkmoon, -- Fortune of Agility
    [23737]  = WB_FLAGS.Darkmoon, -- Fortune of Stamina
    [23738]  = WB_FLAGS.Darkmoon, -- Fortune of Spirit
    [24425]  = WB_FLAGS.Zandalar,
    [15366]  = WB_FLAGS.Songflower,
}

local Worldbuffs = {}
Env.Worldbuffs = Worldbuffs

---Get points for buff count.
---@param count integer
---@return integer
local function GetPoints(count)
    local points = count * Env.settings.pointDistrib.worldBuffPoints
    points = math.floor(points + 0.5)
    return math.min(Env.settings.pointDistrib.worldBuffPointsMax, points)
end

---@param spellId integer
local function IsSpellIdWorldbuff(spellId)
    if WB_IDS[spellId] then
        return WB_IDS[spellId]
    end
    return 0
end

---Get mask of WBs in Chronoboon.
---@param unit string
---@param index integer
local function GetChronoboonBuffs(unit, index)
    local minDuration = Env.settings.pointDistrib.worldBuffMinDuration
    local data = { UnitBuff(unit, index) }
    local worldbuffs = 0
    for wbIndex, wbFlag in pairs(CHRONOBOON_WB_INDICES) do
        if data[wbIndex] and data[wbIndex] >= minDuration then
            worldbuffs = bit.bor(worldbuffs, wbFlag)
        end
    end
    return worldbuffs
end

---Get WB count for unit.
---@param unit string
local function GetWorldbuffCount(unit)
    local worldBuffs = 0
    local i = 1
    local spellId ---@type integer?
    while true do
        spellId = select(10, UnitAura(unit, i, "HELPFUL"))
        if not spellId then break end
        if spellId == CHRONOBOON_BUFF_ID then
            worldBuffs = bit.bor(worldBuffs, GetChronoboonBuffs(unit, i))
        else
            worldBuffs = bit.bor(worldBuffs, IsSpellIdWorldbuff(spellId))
        end
        i = i + 1
    end

    local count = 0
    for _, flag in pairs(WB_FLAGS) do
        if bit.band(worldBuffs, flag) > 0 then
            count = count + 1
        end
    end
    LogDebug("WB unit/mask/count:", unit, worldBuffs, count)
    return count
end

---Get worldbuff points for unit.
---@param unit string
---@return integer count
---@return integer points
function Worldbuffs.GetWorldbuffPoints(unit)
    local count = GetWorldbuffCount(unit)
    return count, GetPoints(count)
end
