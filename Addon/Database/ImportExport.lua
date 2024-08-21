---@class AddonEnv
local Env = select(2, ...)

---@param data table
---@param headerDef string[]
local function MapToCsv(data, headerDef)
    local csv = table.concat(headerDef, ",") .. "\n"
    local tempt = {}
    for _, v in pairs(data) do
        wipe(tempt)
        for hk, hv in ipairs(headerDef) do
            tempt[hk] = v[hv]
        end
        csv = csv .. table.concat(tempt, ",") .. "\n"
    end
    return csv
end

---@param data table<string,any>
---@return string
local function MapToJson(data)
    local json = "{"
    local i = 0
    for k, v in pairs(data) do
        if i > 0 then
            json = json .. ","
        end
        local valStr ---@type string
        if type(v) == "string" then
            valStr = ([["%s"]]):format(v)
        elseif type(v) == "number" then
            valStr = tostring(v)
        elseif type(v) == "table" then
            valStr = MapToJson(v)
        else
            error("Unhandled type in JSON conversion!")
        end
        json = json .. ([["%s"=%s]]):format(k, valStr)
        i = i + 1
    end
    return json .. "}"
end
