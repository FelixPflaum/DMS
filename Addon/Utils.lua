---@type string
local addonName = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

DMS.IS_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
DMS.IS_CLASSIC_SOD = DMS.IS_CLASSIC and C_Engraving and C_Engraving.IsEngravingEnabled()
DMS.IS_WRATH = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

---Create a simple unique identifier.
function DMS:MakeGUID()
    return time() .. "-" .. string.format("%08x", math.floor(math.random(0,0x7FFFFFFF)))
end

---Return RAID or PARTY depending on the group type currently in.
---@return "RAID"|"PARTY"|nil channelIdentifier nil if not in raid or party
function DMS:SelectGroupChannel()
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
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
function DMS:PrintSuccess(msg)
    PrintToChat(msg, "|cFF33FF33")
end

---Print error message (red)
---@param msg string
function DMS:PrintError(msg)
    PrintToChat(msg, "|cFFFF3333")
end

---Print warning message (orange)
---@param msg string
function DMS:PrintWarn(msg)
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

---Print if debug output is on.
---@param arg1 any If table will print out its content.
---@param ... any Will be ignored if arg1 is a table, otherwise beahves like print()
function DMS:PrintDebug(arg1, ...)
    if not DMS_Settings or not DMS_Settings.debug then
        return
    end
    if type(arg1) == "table" then
        PrintTable(arg1, 1)
    else
        print(arg1, ...)
    end
end
