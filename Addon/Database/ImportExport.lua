---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local LibDialog = LibStub("LibDialog-1.1")

------------------------------------------------------------------
--- Export
------------------------------------------------------------------

---@class (exact) AddonExport
---@field time number;
---@field minTimestamp number;
---@field players PlayerEntry[]
---@field pointHistory PointHistoryEntry[]
---@field lootHistory LootHistoryEntry[]

local EXPORT_PREFIX = "DMSAE"
local EXPORT_SUFFIX = "END"

---Export database.
---@param maxAge integer How far back to export, in seconds.
---@return string encoded Deflated and base64ed json of DB.
local function Export(maxAge)
    local minTimestamp = time() - maxAge

    local toExport = { ---@type AddonExport
        time = time(),
        minTimestamp = minTimestamp,
        players = {}, ---@type PlayerEntry[]
        pointHistory = {}, ---@type PointHistoryEntry[]
        lootHistory = {}, ---@type LootHistoryEntry[]
    }

    for _, playerEntry in pairs(Env.Database.db.players) do
        table.insert(toExport.players, playerEntry)
    end

    for _, historyEntry in ipairs(Env.Database.db.pointHistory) do
        if (historyEntry.timeStamp > minTimestamp) then
            table.insert(toExport.pointHistory, historyEntry)
        end
    end

    for _, historyEntry in ipairs(Env.Database.db.lootHistory) do
        if (historyEntry.timeStamp > minTimestamp) then
            table.insert(toExport.lootHistory, historyEntry)
        end
    end

    local encoded = Env.TableToJsonExport(toExport);

    return EXPORT_PREFIX .. encoded .. EXPORT_SUFFIX
end

Env.CreateExportString = Export

------------------------------------------------------------------
--- Import
------------------------------------------------------------------

---Import database.
---@param data string
---@return string|nil error
local function Import(data)
    if data:sub(1, EXPORT_PREFIX:len()) ~= EXPORT_PREFIX or
        data:sub(data:len() - EXPORT_SUFFIX:len() + 1, data:len()) ~= EXPORT_SUFFIX then
        return L["Import string is not complete"];
    end
    local tab = Env.JsonToTableImport(data:sub(EXPORT_PREFIX:len() + 1, data:len() - EXPORT_SUFFIX:len())) ---@type table<string,any>

    local timeOfExport = tab.time and tab.time or false
    if not timeOfExport then
        return L["Import data is missing the time field!"]
    end

    local importPlayers = tab.players
    do
        if importPlayers and type(importPlayers) == "table" then
            ---@cast importPlayers any[]
            local exPlayer = { ---@type PlayerEntry
                playerName = "",
                classId = 1,
                points = 1,
            }
            for _, iPlayer in ipairs(importPlayers) do
                if type(iPlayer) ~= "table" then
                    return L["Player entry has invalid type."]
                end
                ---@cast iPlayer table<string,any>
                for iKey, iVal in pairs(iPlayer) do
                    if not exPlayer[iKey] then
                        return L["Player entry has invalid key %s"]:format(iKey)
                    end
                    if type(iVal) ~= type(exPlayer[iKey]) then
                        return L["Player entry has invalid value type for key %s"]:format(iKey)
                    end
                end
                for exKey, exVal in pairs(exPlayer) do
                    if not iPlayer[exKey] then
                        return L["Player entry is missing key %s"]:format(exKey)
                    end
                end
            end
        else
            return L["Import is missing player field."]
        end
        ---@cast importPlayers PlayerEntry[]
        Env:PrintDebug(("Import has %d valid player entries."):format(#importPlayers))
    end

    local importPointHistory = tab.pointHistory
    local oldestPointHistory = time() + 100000
    do
        if not importPointHistory or type(importPointHistory) ~= "table" then
            return L["Import is missing pointHistory field."]
        end
        ---@cast importPointHistory any[]
        local exHist = { ---@type PointHistoryEntry
            guid = "",
            timeStamp = 1,
            playerName = "",
            change = 1,
            newPoints = 1,
            type = "ITEM_AWARD",
            reason = "OPT",
        }
        for _, iHist in ipairs(importPointHistory) do
            if type(iHist) ~= "table" then
                return L["History entry has invalid type."]
            end
            ---@cast iHist table<string,any>
            for iKey, iVal in pairs(iHist) do
                if not exHist[iKey] then
                    return L["History entry has invalid key %s"]:format(iKey)
                end
                if type(iVal) ~= type(exHist[iKey]) then
                    return L["History entry has invalid value type %s for key %s, expected %s"]:format(type(iVal), iKey, type(exHist[iKey]))
                end
            end
            for exKey, exVal in pairs(exHist) do
                if not iHist[exKey] and not exVal == "OPT" then
                    return L["History entry is missing key %s"]:format(exKey)
                end
            end
            ---@cast iHist PointHistoryEntry
            if oldestPointHistory > iHist.timeStamp then
                oldestPointHistory = iHist.timeStamp
            end
        end
        ---@cast importPointHistory PointHistoryEntry[]
        Env:PrintDebug(("Import has %d valid sanity history entries."):format(#importPointHistory))
    end

    local importLootHistory = tab.lootHistory
    local oldestLootHistory = time() + 100000
    do
        if not importLootHistory or type(importLootHistory) ~= "table" then
            return L["Import is missing lootHistory field."]
        end
        ---@cast importLootHistory any[]
        local exHistP = { ---@type LootHistoryEntry
            guid = "",
            timeStamp = 1,
            playerName = "",
            itemId = 1,
            response = "ITEM_AWARD",
        }
        for _, iHist in ipairs(importLootHistory) do
            if type(iHist) ~= "table" then
                return L["History entry has invalid type."]
            end
            ---@cast iHist table<string,any>
            for iKey, iVal in pairs(iHist) do
                if not exHistP[iKey] then
                    return L["History entry has invalid key %s"]:format(iKey)
                end
                if type(iVal) ~= type(exHistP[iKey]) then
                    return L["History entry has invalid value type for key %s"]:format(iKey)
                end
            end
            for exKey, exVal in pairs(exHistP) do
                if not iHist[exKey] and not exVal == "OPT" then
                    return L["History entry is missing key %s"]:format(exKey)
                end
            end
            ---@cast iHist LootHistoryEntry
            if oldestLootHistory > iHist.timeStamp then
                oldestLootHistory = iHist.timeStamp
            end
        end
        ---@cast importLootHistory LootHistoryEntry[]
        Env:PrintDebug(("Import has %d valid loot history entries."):format(#importLootHistory))
    end

    Env.Database:MakeBackup("Automatic backup on import.")

    table.sort(importPointHistory, function(a, b)
        return a.timeStamp < b.timeStamp
    end)
    table.sort(importLootHistory, function(a, b)
        return a.timeStamp < b.timeStamp
    end)

    Env.Database.db.players = {}
    for _, newPlayerEntry in ipairs(importPlayers) do
        Env.Database.db.players[newPlayerEntry.playerName] = newPlayerEntry
    end
    Env.Database.db.pointHistory = importPointHistory
    Env.Database.db.lootHistory = importLootHistory
    Env.Database.db.lastImport = timeOfExport

    -- TODO: This probably doesn't really work
    Env.Database.OnPlayerChanged:Trigger("")
    Env.Database.OnLootHistoryEntryChanged:Trigger("")
    Env.Database.OnPlayerPointHistoryUpdate:Trigger("")
end

Env.ImportDataFromWeb = Import

local exportDialog = {
    text = "Export",
    on_cancel = function(self, data, source) end,
    show_while_dead = true,
    editboxes = {
        {
            on_enter_pressed = EditBox_ClearFocus,
            on_escape_pressed = EditBox_ClearFocus,
            on_show = function(self, arg)
                C_Timer.NewTimer(0.1, function(t)
                    self:SetText(arg)
                end)
            end,
            auto_focus = false,
            label = "Export Data",
            width = 200,
        },
    },
    buttons = {
        { text = "Ok", on_click = function(self, source) LibDialog:Dismiss(self) end },
    },
}

Env:RegisterSlashCommand("et", "", function()
    if LibDialog:ActiveDialog(exportDialog) then
        LibDialog:Dismiss(exportDialog)
    end
    local json = Export(86400 * 60)
    LibDialog:Spawn(exportDialog, json) ---@type any
end)

local lazyValueCache = nil ---@type string|nil
local importDialog = {
    text = "Import Database",
    show_while_dead = true,
    on_cancel = function(self, data, source) end,
    editboxes = {
        {
            on_enter_pressed = EditBox_ClearFocus,
            on_escape_pressed = EditBox_ClearFocus,
            on_text_changed = function(self, userInput)
                lazyValueCache = self:GetText() ---@type string
            end,
            auto_focus = false,
            label = "Import Data",
            width = 200,
        },
    },
    buttons = {
        {
            text = L["Import"],
            on_click = function(self, source)
                if lazyValueCache then
                    local error = Import(lazyValueCache)
                    if error then
                        Env:PrintError(error)
                    else
                        Env:PrintSuccess(L["Database set to import data. Old data was backed up."])
                    end
                end
            end
        },
    },
}

Env:RegisterSlashCommand("it", "", function()
    if LibDialog:ActiveDialog(importDialog) then
        LibDialog:Dismiss(importDialog)
    end
    LibDialog:Spawn(importDialog)
end)
