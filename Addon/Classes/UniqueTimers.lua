---@class AddonEnv
local Env = select(2, ...)

---@class (exact) UniqueTimers
---@field _timers table<string, TimerHandle>
local UniqueTimers = {}
---@diagnostic disable-next-line: inject-field
UniqueTimers.__index = UniqueTimers

---Set a timer if one with key doesn't already exist.
---@param key string The key for the timer. Must be unique, will error if it already exist.
---@param callback fun(key:string)|string Callback function or name of the function to call on object. If string then the function object[callback](object, key, ...) will be the callback.
---@param object table|nil
---@param noError boolean|nil If true will not error if timer with key already exists.
---@param ... any Arbitrary args that will be given to the callback function, after key.
function UniqueTimers:StartUnique(key, duration, callback, object, noError, ...)
    if self._timers[key] then
        if noError then
            return
        end
        error("Timer with key " .. key .. " already exists!")
    end

    local _self = self
    local args = {...}

    if type(callback) == "function" then
        _self._timers[key] = C_Timer.NewTicker(GetTime() + duration, function(t)
            _self._timers[key] = nil
            callback(key, unpack(args))
        end)
        return
    end

    assert(object, "obj can't be nil if callback is a string!")

    _self._timers[key] = C_Timer.NewTicker(GetTime() + duration, function(t)
        _self._timers[key] = nil
        object["callback"](object, key, unpack(args))
    end)
end

---Cancel all timers and clear timer list.
function UniqueTimers:CancelAll()
    for _, fc in pairs(self._timers) do
        fc:Cancel()
    end
    self._timers = {}
end

---@param key string
function UniqueTimers:HasTimer(key)
    return self._timers[key] ~= nil
end

---@param key string
function UniqueTimers:Cancel(key)
    if self._timers[key] then
        self._timers[key]:Cancel()
    end
end

---@return UniqueTimers
function Env.NewUniqueTimers()
    ---@type UniqueTimers
    local t = { _timers = {} }
    setmetatable(t, UniqueTimers)
    return t
end
