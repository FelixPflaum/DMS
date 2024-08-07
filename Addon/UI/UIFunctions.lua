---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

Env.UI = {}

---Get path to an image file of the addon.
---@param imgName string The name of the image.
function Env.UI.GetImagePath(imgName)
    return [[Interface\AddOns\]] .. addonName .. [[\UI\img\]] .. imgName
end

---@type table<string, {color:[number,number,number],argbstr:string}>
local classColors = {
    DEATHKNIGHT = { color = { 0.77, 0.12, 0.23 }, argbstr = "FFC41E3A" },
    DEMONHUNTER = { color = { 0.64, 0.19, 0.79 }, argbstr = "FFA330C9" },
    DRUID = { color = { 1.00, 0.49, 0.04 }, argbstr = "FFFF7C0A" },
    EVOKER = { color = { 0.20, 0.58, 0.50 }, argbstr = "FF33937F" },
    HUNTER = { color = { 0.67, 0.83, 0.45 }, argbstr = "FFAAD372" },
    MAGE = { color = { 0.25, 0.78, 0.92 }, argbstr = "FF3FC7EB" },
    MONK = { color = { 0.00, 1.00, 0.60 }, argbstr = "FF00FF98" },
    PALADIN = { color = { 0.96, 0.55, 0.73 }, argbstr = "FFF48CBA" },
    PRIEST = { color = { 1.00, 1.00, 1.00 }, argbstr = "FFFFFFFF" },
    ROGUE = { color = { 1.00, 0.96, 0.41 }, argbstr = "FFFFF468" },
    SHAMAN = { color = { 0.00, 0.44, 0.87 }, argbstr = "FF0070DD" },
    WARLOCK = { color = { 0.53, 0.53, 0.93 }, argbstr = "FF8788EE" },
    WARRIOR = { color = { 0.78, 0.61, 0.43 }, argbstr = "FFC69B6D" },
}

---@param classId integer|string
---@return {color:[number,number,number],argbstr:string}
function Env.UI.GetClassColor(classId)
    if type(classId) == "number" then
        local _, classFile = GetClassInfo(classId)
        return classColors[classFile]
    end
    return classColors[classId]
end
