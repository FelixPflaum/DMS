---@class AddonEnv
local Env = select(2, ...);

---Make a shallow copy of a table.
---@generic T : table
---@param inTable T
---@return T
local function CopyTable(inTable)
    local outTable = {}
    ---@diagnostic disable-next-line: no-unknown
    for k, v in pairs(inTable) do
        ---@diagnostic disable-next-line: no-unknown
        outTable[k] = v
    end
    return outTable
end

Env.Database = {}

---@class (exact) PlayerPointsChange
---@field timeStamp integer
---@field playerName string
---@field change integer
---@field oldPoints integer
---@field newPoints integer
---@field reason string
---@field lootHistoryGuid string|nil If this change was due to a loot distribution.

---@class (exact) PlayerEntry
---@field playerName string
---@field classId integer
---@field points integer

---@class (exact) LootHistoryEntry
---@field guid string Unique identifier for this loot distribution.
---@field timeStamp number Unix timestamp of the award time.
---@field playerName string
---@field classId integer
---@field itemId integer
---@field response string The response / award reason.
---@field roll integer The roll result.
---@field pointRoll boolean If points were used to win.
---@field reverted boolean Award was reverted.
---@field revertReason string|nil An optional reason why the award was reverted.

Env:OnAddonLoaded(function()
    if DMS_Database == nil then
        ---@class (exact) Database
        ---@field players table<string, PlayerEntry>
        ---@field pointHistory table<string, PlayerPointsChange[]>
        ---@field lootHistory LootHistoryEntry[]
        DMS_Database = {
            players = {},
            pointHistory = {},
            lootHistory = {},
        }
    end
end)

------------------------------------------------------------------
--- Events
------------------------------------------------------------------

---@class (exact) PlayerChangeEventEmitter
---@field RegisterCallback fun(self:PlayerChangeEventEmitter, cb:fun(arg:string))
---@field Trigger fun(self:PlayerChangeEventEmitter, arg:string)
Env.Database.OnPlayerChanged = Env:NewEventEmitter()

---@class (exact) LootHistoryDbEventEmitter
---@field RegisterCallback fun(self:LootHistoryDbEventEmitter, cb:fun(entryGuid:string))
---@field Trigger fun(self:LootHistoryDbEventEmitter, entryGuid:string)
Env.Database.OnLootHistoryEntryChanged = Env:NewEventEmitter()

------------------------------------------------------------------
--- Player API
------------------------------------------------------------------

---Get player entry.
---@param name string
---@return PlayerEntry|nil playerEntry Will be a copy of the data.
function Env.Database:GetPlayer(name)
    if DMS_Database.players[name] then
        return CopyTable(DMS_Database.players[name])
    end
end

---Add or update a player entry.
---@param entry PlayerEntry
function Env.Database:AddOrUpdatePlayer(entry)
    DMS_Database.players[entry.playerName] = entry
    self.OnPlayerChanged:Trigger(entry.playerName)
end

------------------------------------------------------------------
--- Loot History API
------------------------------------------------------------------

---@alias HistoryFilter {playerName:string|nil, fromTime:integer|nil, untilTime:integer|nil, response:table<string,boolean>|nil}

---@param entry LootHistoryEntry
---@param filter HistoryFilter
local function FilterLootEntry(entry, filter)
    if filter.playerName and filter.playerName ~= entry.playerName then
        return false
    end

    if filter.response and filter.response ~= entry.response then
        return false
    end

    if filter.fromTime and filter.fromTime <= entry.timeStamp then
        return false
    end

    if filter.untilTime and filter.untilTime >= entry.timeStamp then
        return false
    end

    return true
end

---Get filtered loot history.
---@param filter HistoryFilter
---@param maxResults integer Default 100
---@return LootHistoryEntry[] history Will be a copy of the data.
function Env.Database:GetLootHistory(filter, maxResults)
    local toGo = maxResults or 100

    ---@type LootHistoryEntry[]
    local filtered = {}

    for _, v in ipairs(DMS_Database.lootHistory) do
        if FilterLootEntry(v, filter) then
            table.insert(CopyTable(v))
            toGo = toGo - 1
            if toGo <= 0 then
                break
            end
        end
    end

    return filtered
end

---Get specific loot history entry.
---@param indexOrGUID integer|string
---@return LootHistoryEntry|nil entry Will be a copy of the data.
function Env.Database:GetLootHistoryEntry(indexOrGUID)
    if type(indexOrGUID) == "number" then
        return CopyTable(DMS_Database.lootHistory[indexOrGUID])
    end
    for _, v in ipairs(DMS_Database.lootHistory) do
        if v.guid == indexOrGUID then
            return CopyTable(v)
        end
    end
end

---Add or update an entry to the loot history.
---@param entry LootHistoryEntry
function Env.Database:AddOrUpdateLootHistoryEntry(entry)
    local existing = false
    for k, v in ipairs(DMS_Database.lootHistory) do
        if v.guid == entry.guid then
            DMS_Database.lootHistory[k] = entry
            existing = true
            break
        end
    end
    if not existing then
        table.insert(DMS_Database.lootHistory, entry)
    end
    self.OnLootHistoryEntryChanged:Trigger(entry.guid)
end
