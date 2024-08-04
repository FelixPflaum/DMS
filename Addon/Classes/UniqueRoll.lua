--- Allows picking random unique numbers in [1, 100] range.

---@class AddonEnv
local DMS = select(2, ...)

---@class (exact) UniqueRoller
---@field _rolls integer[]
local UniqueRoller = {}
---@diagnostic disable-next-line: inject-field
UniqueRoller.__index = UniqueRoller

---Get a random roll from the remaining roll options.
---@return integer
function UniqueRoller:GetRoll()
    local count = #self._rolls
    if count == 0 then
        error("Tried to get too many rolls from a UniqueRoller instance!")
    end
    return table.remove(self._rolls, math.random(count))
end

---Get table with numbers from 1 to 100.
---@return integer[]
local function MakeRollTable()
    ---@type integer[]
    local rolls = {}
    for i = 1, 100 do
        rolls[i] = i
    end
    return rolls
end

---Get a new UniqueRoll instance. Can be used to generate unique rolls.
---@return UniqueRoller
function DMS:NewUniqueRoller()
    ---@type UniqueRoller
    local ur = { _rolls = MakeRollTable() }
    setmetatable(ur, UniqueRoller)
    return ur
end
