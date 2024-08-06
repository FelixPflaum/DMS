---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

Env.IS_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
Env.IS_CLASSIC_SOD = Env.IS_CLASSIC and C_Engraving and C_Engraving.IsEngravingEnabled()
Env.IS_WRATH = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

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
---@param d integer
---@param maxDepth integer|nil
local function PrintTable(t, d, maxDepth)
    for k, v in pairs(t) do
        if maxDepth and d > maxDepth then return end
        print(string.rep("--", d) .. " " .. k .. ": " .. tostring(v))
        if type(v) == "table" then
            PrintTable(v, d + 1)
        end
    end
end

---@param arg1 any
---@param ... any 
local function PrintDebug(arg1, ...)
    if type(arg1) == "table" then
        PrintTable(arg1, 1)
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
