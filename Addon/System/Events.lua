---@type string
local ADDON_NAME = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local eventFrame = CreateFrame("Frame")
---@type table<string, (table|fun(...))[]>
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        local handlers = eventHandlers[event]
        for i = #handlers, 1, -1 do
            local funcOrObj = handlers[i]
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
    eventHandlers[event] = eventHandlers[event] or {}
    table.insert(eventHandlers[event], callbackOrObject)
    if #eventHandlers[event] == 1 then
        eventFrame:RegisterEvent(event)
        self:PrintDebug("Registered game event", event)
    end
    self:PrintDebug("Added event callback", event, callbackOrObject)
end

---Remove event callback.
---@param event string
---@param callbackOrObject table|fun(...:any):boolean|nil
function Env:UnregisterEvent(event, callbackOrObject)
    if not eventHandlers[event] then return end
    for i = #eventHandlers[event], 1, -1 do
        local funcOrObj = eventHandlers[event][i]
        if funcOrObj == callbackOrObject then
            table.remove(eventHandlers[event], i)
            self:PrintDebug("Removed event callback", event, callbackOrObject)
            if #eventHandlers[event] == 0 then
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
