---@type string
local ADDON_NAME = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

local eventFrame = CreateFrame("Frame")
---@type table<string, (table|fun(...))[]>
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        local handlers = eventHandlers[event]
        for _, funcOrObj in ipairs(handlers) do
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
function DMS:RegisterEvent(event, callbackOrObject)
    eventHandlers[event] = eventHandlers[event] or {}
    table.insert(eventHandlers[event], callbackOrObject)
    if #eventHandlers[event] == 1 then
        eventFrame:RegisterEvent(event)
        self:PrintDebug("Registered event", event)
    end
    self:PrintDebug("Added event callback", event, callbackOrObject)
end

---Remove event callback.
---@param event string
---@param callbackOrObject table|fun(...:any):boolean|nil
function DMS:UnregisterEvent(event, callbackOrObject)
    if not eventHandlers[event] then return end
    for i, v in ipairs(eventHandlers[event]) do
        if v == callbackOrObject then
            table.remove(eventHandlers[event], i)
            self:PrintDebug("Removed event callback", event, callbackOrObject)
            if #eventHandlers[event] == 0 then
                eventFrame:UnregisterEvent(event)
                self:PrintDebug("Unregistered event", event)
            end
            return
        end
    end
end

---@type nil|(fun(...:any):nil)[]
local addonLoadCallbacks = {}

---Add callback for when addon is loaded.
---@param callback fun(...:any):nil
function DMS:OnAddonLoaded(callback)
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
        DMS:UnregisterEvent("ADDON_LOADED", AddonLoadedCallback)
    end
end
DMS:RegisterEvent("ADDON_LOADED", AddonLoadedCallback)
