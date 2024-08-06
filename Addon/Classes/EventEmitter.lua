---@class AddonEnv
local Env = select(2, ...)

local EventEmitter = {}
EventEmitter.__index = EventEmitter

---Regsiter a callback for the event.
function EventEmitter:RegisterCallback(callback)
    table.insert(self._callbacks, callback)
end

---Trigger registered callbacks.
function EventEmitter:Trigger(...)
    ---@diagnostic disable-next-line: no-unknown
    for _, callback in ipairs(self._callbacks) do
        callback(...)
    end
end

--[[
Create an EventEmitter that provides callback registration and trigger functions.
The following template can be copy&pasted to use luals type support.

---@class EventEmitter
---@field RegisterCallback fun(self:EventEmitter, cb:fun(arg:any))
---@field Trigger fun(self:EventEmitter, arg:any)
]]

function Env:NewEventEmitter()
    return setmetatable({ _callbacks = {} }, EventEmitter)
end
