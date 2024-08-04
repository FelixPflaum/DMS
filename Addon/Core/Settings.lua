---@class AddonEnv
local DMS = select(2, ...)

---@class (exact) SettingsTable
local defaultSettings = {
    firstStart = true,
    version = 1,
    debug = false,
    UI = {
        SessionWindow = {},
    },
    lootSession = {
        timeout = 90,
        responses = {
            buttonCount = 0,
            ---@type {response:string, color:[number,number,number], pointRoll:boolean}[]
            buttons = {},
        },
    },
}

---Fills missing entries in table.
---@param inputTable table<string, any>
---@param defaultTable table<string, any>
local function FillMissing(inputTable, defaultTable)
    for k, v in pairs(defaultTable) do
        if inputTable[k] == nil then
            if type(v) == "table" then
                inputTable[k] = {}
                FillMissing(inputTable[k], v)
            else
                inputTable[k] = v
            end
        end
    end
end

---Update settings table if neccessary.
local function UpdateSettings()
    --TODO: this is a dev placeholder
    if DMS_Settings.version < defaultSettings.version then
        DMS_Settings = defaultSettings
    end
end

--- Setup SV tables, check settings and setup settings menu
DMS:OnAddonLoaded(function()
    if DMS_Settings == nil then
        DMS_Settings = defaultSettings
    end

    UpdateSettings()
    FillMissing(DMS_Settings, defaultSettings)

    DMS.settings = DMS_Settings
end)
