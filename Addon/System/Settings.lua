---@class AddonEnv
local Env = select(2, ...)

---@enum LogLevel
Env.LogLevel = {
    NORMAL = 1,
    DEBUG = 2,
    VERBOSE = 3,
}

---@alias FlatAndPctVal {flat:integer,pct:integer}

---@class SettingsTable
local defaultSettings = {
    firstStart = true,
    version = 6,
    logLevel = 1, ---@type LogLevel
    testMode = false,
    autoOpenOnStart = "yes", ---@type "yes"|"ask"|"no"
    autoSwitchToNextItem = false,
    startPermissions = { -- TODO: use this?
        leader = true,
        masterLooter = true,
        guildRanks = {},
    },
    moreInfoEnabled = true,
    moreInfoItemCount = 8,
    moreInfoTimeframe = 60 * 86400, -- 60 days
    UI = {
        SessionWindow = {},
        LootWindow = {},
        ResponseWindow = {},
        DatabaseWindow = {},
        SyncWindow = {},
        TradeWindow = {},
        DistWindow = {},
        DeciderWindow = {},
    },
    lootSession = {
        timeout = 90,
        responseCount = 0,
        responseButtons = {}, ---@type {response:string, color:[number,number,number], pointRoll:boolean, isNeed:boolean}[]
        pointsMaxRange = 50,
        pointsMinForRoll = 30,
        pointsRemoveIfCompetition = { flat = 0, pct = 50 }, ---@type FlatAndPctVal
        pointsRemoveIfSoloRoll = { flat = 0, pct = 0 }, ---@type FlatAndPctVal
        unveilWaitAllRolls = false,
    },
    pointDistrib = {
        worldBuffPoints = 1,
        worldBuffPointsMax = 5,
        worldBuffMinDuration = 40,
        inRangeReadyPoints = 3,
        inRangeReadyMaxDistance = 100,
        raidCompleteDefaultPoints = 15,
    },
    misc = {
        deciderAutoClose = 5,
        deciderPlaySound = true,
    }
}

---@class (exact) AddonSettingsChangedEmitter
---@field RegisterCallback fun(self:AddonSettingsChangedEmitter, cb:fun(settings:AddonSettings))
---@field Trigger fun(self:AddonSettingsChangedEmitter, settings:AddonSettings)
Env.OnSettingsChange = Env:NewEventEmitter()

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

    Env.OnSettingsChange:Trigger(Env.settings)
end)
