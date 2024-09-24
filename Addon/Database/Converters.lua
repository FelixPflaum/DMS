---@class AddonEnv
local Env = select(2, ...)

local LibDeflate = LibStub("LibDeflate")

---Lua table to JSON converter. Should work fine for the simple table structure used in the addon, hopefully.
---@param data table<string|number,any>
---@return string
local function TableToJson(data)
    local isArray = true
    for k, v in pairs(data) do
        if type(k) ~= "number" then
            isArray = false
            break
        end
    end
    local json = isArray and "[" or "{"
    local i = 0
    for k, v in pairs(data) do
        if i > 0 then
            json = json .. ","
        end
        local valStr ---@type string
        if type(v) == "string" then
            valStr = ([["%s"]]):format(v)
        elseif type(v) == "number" or type(v) == "boolean" then
            valStr = tostring(v)
        elseif type(v) == "table" then
            valStr = TableToJson(v)
        else
            error(("Unhandled type %s in JSON conversion! Key: %s, Value: %s"):format(type(v), tostring(k), tostring(v)))
        end
        if isArray then
            json = json .. valStr
        else
            json = json .. ([["%s":%s]]):format(k, valStr)
        end
        i = i + 1
    end
    return json .. (isArray and "]" or "}")
end

-- Convert JSON to Lua table.
-- Probably hilariously bad implementation I just came up with, but it works for now.
-- Not tested but at least it's probably slow.
local JsonToTable = {}

---@param json string
---@param start integer
function JsonToTable:ReadString(json, start)
    local char ---@type string
    local isEscape = false
    local i = start
    while true do
        char = json:sub(i, i)
        if not char then
            error("Unexpected end of string when reading string starting at pos: " .. start)
        elseif char == "\"" then
            if isEscape then
                isEscape = false
            else
                return json:sub(start, i - 1), i
            end
        elseif char == "\\" then
            isEscape = true
        end
        i = i + 1
    end
end

---@param json string
---@param start integer
function JsonToTable:ReadNumber(json, start)
    local char ---@type string
    local i = start
    while true do
        char = json:sub(i, i)
        if char ~= "." and char ~= "-" and not char:match("%d") then
            return tonumber(json:sub(start, i - 1)), i - 1
        end
        i = i + 1
    end
end

---@param json string
---@param start integer
function JsonToTable:ReadArray(json, start)
    local resArray = {} ---@type any[]
    local i = start
    local canValue = true
    local canClose = true
    while true do
        local char = json:sub(i, i);
        if not char:match("%s") then
            if canClose and char == "]" then
                return resArray, i
            elseif canValue then
                local val, lastChar = self:ReadValue(json, i)
                table.insert(resArray, val)
                i = lastChar
                canClose = true
                canValue = false
            elseif char == "," then
                canValue = true
                canClose = false
            else
                error(("Unexpected character at pos %d in array."):format(i))
            end
        end
        i = i + 1
    end
end

---Now this is just hot garbage.
---@param json string
---@param start integer
function JsonToTable:ReadObject(json, start)
    local resDict = {} ---@type table<string,any>
    local i = start
    local key ---@type nil|string
    local wantValue = false
    local canClose = true
    local afterValue = false
    while true do
        local char = json:sub(i, i);
        if not char then error("Unexpected end of JSON at pos: " .. i) end
        if not char:match("%s") then
            if canClose and char == "}" then
                return resDict, i
            elseif afterValue then
                if char == "," then
                    afterValue = false
                    canClose = false
                else
                    error("Unexpected char after object key-value pair at position: " .. i)
                end
            elseif not key then
                if char ~= "\"" then
                    error("Expected char at start of string key at pos: " .. i)
                end
                local k, lastChar = self:ReadString(json, i + 1)
                key = k
                i = lastChar
                canClose = false
            elseif not wantValue then
                if char == ":" then
                    wantValue = true
                else
                    error("Unexted char after object key at position: " .. i)
                end
            elseif wantValue then
                local val, lastChar = self:ReadValue(json, i)
                resDict[key] = val
                i = lastChar
                canClose = true
                wantValue = false
                key = nil
                afterValue = true
            else
                error("Broken object parse state? Pos: " .. i)
            end
        end
        i = i + 1
    end
end

---@param json string
---@param start integer
function JsonToTable:ReadValue(json, start)
    local initChar = json:sub(start, start)
    if initChar == "\"" then
        return self:ReadString(json, start + 1)
    elseif initChar == "[" then
        return self:ReadArray(json, start + 1)
    elseif initChar == "{" then
        return self:ReadObject(json, start + 1)
    elseif initChar == "-" or initChar:match("%d") then
        return self:ReadNumber(json, start)
    elseif json:sub(start, start + 3) == "true" then
        return true, start + 3
    elseif json:sub(start, start + 4) == "false" then
        return false, start + 4
    else
        error("Invalid start of value at position: " .. start)
    end
end

---@param json string
function JsonToTable:Convert(json)
    local initChar = json:sub(1, 1)
    if initChar == "[" then
        return self:ReadArray(json, 2)
    elseif initChar == "{" then
        return self:ReadObject(json, 2)
    else
        error("Invalid start of JSON.")
    end
end

---Conver Lua table to deflated JSON encoded to base64.
---@param tab table<string|number,any>
---@param noCompress boolean? Don't compress, just return JSON.
function Env.TableToJsonExport(tab, noCompress)
    local json = TableToJson(tab)
    if (noCompress) then return json end
    local deflated = LibDeflate:CompressDeflate(json) ---@type string
    local b64 = Env.Base64.encode(deflated)
    return b64
end

---Conver Lua table to deflated JSON encoded to base64.
---@param input string
---@param isJson boolean? Is uncompressen JSON.
function Env.JsonToTableImport(input, isJson)
    if isJson then
        return JsonToTable:Convert(input)
    end
    local deflated = Env.Base64.decode(input)
    local json = LibDeflate:DecompressDeflate(deflated) ---@type string
    local tab = JsonToTable:Convert(json)
    return tab
end
