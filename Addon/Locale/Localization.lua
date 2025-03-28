---@class AddonEnv
local Env = select(2, ...)

local clientlocale = GetLocale()
---@type table<string, string>
local localStrings = setmetatable({}, {
    __index = function(self, key)
        rawset(self, key, key)
        return key
    end
})

--- Add localization
---@param locale string
function Env:AddLocalization(locale)
    if locale ~= clientlocale then
        return
    end
    return localStrings
end

--- Get localization table
function Env:GetLocalization()
    return localStrings
end
