---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

Env.IS_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
Env.IS_CLASSIC_SOD = Env.IS_CLASSIC and C_Engraving and C_Engraving.IsEngravingEnabled()
Env.IS_WRATH = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
Env.IS_CATA = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
Env.IS_RETAIL = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

Env.classList = (function()
    ---@type {file:string, id:integer, displayText:string}[]
    local list = {}

    for i = 1, 99 do
        local className, classFile, classId = GetClassInfo(i)
        -- When calling GetClassInfo() it will return the next valid class on invalid classIds,
        -- or nil if classId is higher then the highest valid class Id.
        if classId == i then
            table.insert(list, { displayText = className, id = classId, file = classFile })
        elseif not className then
            break
        end
    end

    return list
end)()

-- Returns an iterator for looping over either raid or party.
function Env.MakeGroupIterator()
    local prefix = "raid"
    local size = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
    local i = 1
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid(LE_PARTY_CATEGORY_HOME) then
        prefix = "party"
        size = size - 1 -- party size includes player, party unitIds do not.
        i = 0
    end
    return function()
        local unit ---@type string?
        if i == 0 then
            unit = "player"
        elseif i <= size then
            unit = prefix .. i
        end
        i = i + 1
        return unit
    end
end

---Print msg to chat, replacing default color.
---@param msg string The message to print.
---@param defColor string The color to use as default given as color esc sequence.
local function PrintToChat(msg, defColor)
    msg = msg:gsub("|r", defColor)
    print(defColor .. addonName .. ": " .. msg)
end

---Print success message (green)
---@param msg string
function Env:PrintSuccess(msg)
    PrintToChat(msg, "|cFF33FF33")
end

---Print error message (red)
---@param msg string
function Env:PrintError(msg)
    PrintToChat(msg, "|cFFFF3333")
end

---Print warning message (orange)
---@param msg string
function Env:PrintWarn(msg)
    PrintToChat(msg, "|cFFFFAA22")
end

---Helper for printing tables.
---@param t table<any,any>
---@param depth integer
---@param maxDepth integer|nil
function Env.PrintTable(t, depth, maxDepth)
    for k, v in pairs(t) do
        if maxDepth and depth > maxDepth then return end
        print(string.rep("--", depth) .. " " .. k .. ": " .. tostring(v))
        if type(v) == "table" then
            Env.PrintTable(v, depth + 1)
        end
    end
end

---@param arg1 any
---@param ... any
local function PrintDebug(arg1, ...)
    if type(arg1) == "table" then
        Env.PrintTable(arg1, 1)
    else
        print(arg1, ...)
    end
end

---Print if debug output is on.
---@param arg1 any If table will print out its content.
---@param ... any Will be ignored if arg1 is a table, otherwise behaves like print()
function Env:PrintDebug(arg1, ...)
    if not DMS_Settings or DMS_Settings.logLevel == 1 then
        return
    end
    PrintDebug(arg1, ...)
end

---Print if verbose output is on.
---@param arg1 any If table will print out its content.
---@param ... any Will be ignored if arg1 is a table, otherwise behaves like print()
function Env:PrintVerbose(arg1, ...)
    if not DMS_Settings or DMS_Settings.logLevel < 3 then
        return
    end
    PrintDebug(arg1, ...)
end

---Returns seconds as days, hour, minutes or seconds, depending on whether input is at least the respective unit.
---@param seconds number
---@return string
function Env.ToShortTimeUnit(seconds)
    if seconds > 86400 then
        return math.floor((seconds / 86400) + 0.5) .. "d"
    elseif seconds > 3600 then
        return math.floor((seconds / 3600) + 0.5) .. "h"
    elseif seconds > 60 then
        return math.floor((seconds / 60) + 0.5) .. "m"
    else
        return seconds .. "s"
    end
end
