---@class AddonEnv
local DMS = select(2, ...)

---@class (exact) UniqueTimers
---@field _timers table<string, FunctionContainer>
local UniqueTimers = {}
---@diagnostic disable-next-line: inject-field
UniqueTimers.__index = UniqueTimers

---Set a timer if one with key doesn't already exist.
---@param key string
---@param callback fun()|string
---@param obj table|nil
function UniqueTimers:StartUnique(key, duration, callback, obj, noError)
    if self._timers[key] then
        if noError then
            return
        end
        error("Timer with key " .. key .. " already exists!")
    end

    local s = self

    if type(callback) == "function" then
        s._timers[key] = C_Timer.NewTicker(GetTime() + duration, function(t)
            s._timers[key] = nil
            callback()
        end)
        return
    end

    assert(obj, "obj can't be nil if callback is a string!")

    s._timers[key] = C_Timer.NewTicker(GetTime() + duration, function(t)
        s._timers[key] = nil
        obj["callback"](obj)
    end)
end

function UniqueTimers:CancelAll()
    for _, fc in pairs(self._timers) do
        fc:Cancel()
    end
end

---@param key string
function UniqueTimers:Cancel(key)
    if self._timers[key] then
        self._timers[key]:Cancel()
    end
end

---Get a new UniqueRoll instance. Can be used to generate unique rolls.
---@return UniqueTimers
function DMS:NewUniqueTimers()
    ---@type UniqueTimers
    local t = { _timers = {} }
    setmetatable(t, UniqueTimers)
    return t
end
