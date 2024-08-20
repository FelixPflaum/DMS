---@class AddonEnv
local Env = select(2, ...)

---Allows picking random unique numbers in [1, n] range.
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

---Get the remaining roll count.
function UniqueRoller:Remaining()
    return #self._rolls
end

---Get table with numbers from 1 to 100.
---@param max integer
---@return integer[]
local function MakeRollTable(max)
    ---@type integer[]
    local rolls = {}
    for i = 1, max do
        rolls[i] = i
    end
    return rolls
end

---Get a new UniqueRoll instance. Can be used to generate unique rolls.
---@param max integer? The maximum to roll for. Default 100.
---@return UniqueRoller
function Env:NewUniqueRoller(max)
    ---@type UniqueRoller
    local ur = { _rolls = MakeRollTable(max or 100) }
    setmetatable(ur, UniqueRoller)
    return ur
end
