---@class AddonEnv
local Env = select(2, ...)

---@enum LogLevel
Env.LogLevel = {
    NORMAL = 1,
    DEBUG = 2,
    VERBOSE = 3,
}

---@class SettingsTable
local defaultSettings = {
    firstStart = true,
    version = 2,
    logLevel = 1, ---@type LogLevel
    UI = {
        SessionWindow = {},
        LootAddWindow = {},
    },
    lootSession = {
        timeout = 90,
        responses = {
            buttonCount = 0,
            buttons = {}, ---@type {response:string, color:[number,number,number], pointRoll:boolean}[]
        },
    },
}

---Fills missing entries in table.
---@param inputTable table<string, any>
---@param defaultTable table<string, any>
local function FillMissing(inputTable, defaultTable)
    for k, v in pairs(defaultTable) do
        if type(v) == "table" then
            if inputTable[k] == nil then
                inputTable[k] = {}
            end
            FillMissing(inputTable[k], v)
        elseif inputTable[k] == nil then
            inputTable[k] = v
        end
    end
end

---Update settings table if neccessary.
local function UpdateSettings()
    --TODO: this is a dev placeholder
    if DMS_Settings.version ~= defaultSettings.version then
        DMS_Settings = defaultSettings
    end
end

--- Setup SV tables, check settings and setup settings menu
Env:OnAddonLoaded(function()
    if DMS_Settings == nil then
        DMS_Settings = defaultSettings
    end

    UpdateSettings()
    FillMissing(DMS_Settings, defaultSettings)

    ---@class (exact) AddonSettings : SettingsTable
    Env.settings = DMS_Settings
end)
