---@type string
local ADDON_NAME = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local eventFrame = CreateFrame("Frame")
---@type table<string, {handlers:table<(table|fun(...)),boolean>, count:integer}>
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        local eventTable = eventHandlers[event]
        for funcOrObj in pairs(eventTable.handlers) do
            if type(funcOrObj) == "table" then
                funcOrObj[event](funcOrObj, ...)
            else
                funcOrObj(...)
            end
        end
    end
end)

---Register event callback.
---@param event string
---@param callbackOrObject table|fun(...:any):boolean|nil If table then the function table:EVENT(args) will be called.
function Env:RegisterEvent(event, callbackOrObject)
    eventHandlers[event] = eventHandlers[event] or { handlers = {}, count = 0 }
    if not eventHandlers[event].handlers[callbackOrObject] then
        eventHandlers[event].handlers[callbackOrObject] = true
        eventHandlers[event].count = eventHandlers[event].count + 1
        if eventHandlers[event].count == 1 then
            eventFrame:RegisterEvent(event)
            self:PrintDebug("Registered game event", event)
        end
        self:PrintDebug("Added event callback", event, callbackOrObject)
    end
end

---Remove event callback.
---@param event string
---@param callbackOrObject table|fun(...:any):boolean|nil
function Env:UnregisterEvent(event, callbackOrObject)
    if not eventHandlers[event] then return end
    for funcOrObj in pairs(eventHandlers[event].handlers) do
        if funcOrObj == callbackOrObject then
            eventHandlers[event].handlers[funcOrObj] = nil
            eventHandlers[event].count = eventHandlers[event].count - 1
            self:PrintDebug("Removed event callback", event, callbackOrObject)
            if eventHandlers[event].count == 0 then
                eventFrame:UnregisterEvent(event)
                self:PrintDebug("Unregistered game event", event)
            end
            return
        end
    end
end

---@type nil|(fun(...:any):nil)[]
local addonLoadCallbacks = {}

---Add callback for when addon is loaded.
---@param callback fun(...:any):nil
function Env:OnAddonLoaded(callback)
    if not addonLoadCallbacks then return end
    table.insert(addonLoadCallbacks, callback)
end

local function AddonLoadedCallback(addonName)
    if addonName ~= ADDON_NAME then return end
    if addonLoadCallbacks then
        for _, f in ipairs(addonLoadCallbacks) do
            f()
        end
        addonLoadCallbacks = nil
        Env:UnregisterEvent("ADDON_LOADED", AddonLoadedCallback)
    end
end
Env:RegisterEvent("ADDON_LOADED", AddonLoadedCallback)
