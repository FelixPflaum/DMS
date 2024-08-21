---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("DB:", ...)
end

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

---@alias PointChangeType "ITEM_AWARD"|"ITEM_AWARD_REVERTED"|"RAID"|"PREP"|"CUSTOM"

---@class (exact) PointHistoryEntry
---@field timeStamp integer -- Unix timestamp.
---@field playerName string
---@field change integer
---@field newPoints integer
---@field type PointChangeType
---@field reason string|nil Misc data for type.

---@class (exact) PlayerEntry
---@field playerName string
---@field classId integer
---@field points integer

---@class (exact) LootHistoryEntry
---@field guid string Unique identifier for this loot distribution.
---@field timeStamp number Unix timestamp of the award time.
---@field playerName string The player the item was awarded to.
---@field itemId integer
---@field response string The response / award reason in the format {id,rgb_hexcolor}displayString
---@field reverted boolean Award was reverted.

---@class (exact) LootResponseUsed
---@field display string
---@field color number[]

Env:OnAddonLoaded(function()
    if DMS_Database == nil then
        ---@class (exact) Database
        ---@field players table<string, PlayerEntry>
        ---@field pointHistory PointHistoryEntry[]
        ---@field lootHistory LootHistoryEntry[]
        DMS_Database = {
            players = {},
            pointHistory = {},
            lootHistory = {},
        }
    end
    Env.Database.players = DMS_Database.players
    Env.Database.pointHistory = DMS_Database.pointHistory
    Env.Database.lootHistory = DMS_Database.lootHistory
end)

------------------------------------------------------------------
--- Events
------------------------------------------------------------------

---@class (exact) PlayerChangeEventEmitter
---@field RegisterCallback fun(self:PlayerChangeEventEmitter, cb:fun(playerName:string))
---@field Trigger fun(self:PlayerChangeEventEmitter, playerName:string)
Env.Database.OnPlayerChanged = Env:NewEventEmitter()

---@class (exact) PlayerPointsHistoryUpdateEmitter
---@field RegisterCallback fun(self:PlayerPointsHistoryUpdateEmitter, cb:fun(playerName:string))
---@field Trigger fun(self:PlayerPointsHistoryUpdateEmitter, playerName:string)
Env.Database.OnPlayerPointHistoryUpdate = Env:NewEventEmitter()

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
    if self.players[name] then
        return CopyTable(self.players[name])
    end
end

---Add or update a player entry.
---@param playerName string
---@param classId integer
---@param points integer
function Env.Database:AddPlayer(playerName, classId, points)
    if self.players[playerName] then
        error("Tried to create already existing player entry in database! " .. playerName)
    end
    self.players[playerName] = {
        playerName = playerName,
        classId = classId,
        points = points,
    }
    LogDebug("Added player to db", playerName, classId, points)
    self.OnPlayerChanged:Trigger(playerName)
end

---Update a player entry.
---@param playerName string
---@param points integer
function Env.Database:UpdatePlayer(playerName, points)
    if not self.players[playerName] then
        error("Tried to update non-existant player entry in database! " .. playerName)
    end
    self.players[playerName].points = points
    LogDebug("Updated player", playerName, points)
    self.OnPlayerChanged:Trigger(playerName)
end

------------------------------------------------------------------
--- Point History API
------------------------------------------------------------------

---@alias PointHistoryFilter {playerName:string|nil, fromTime:integer|nil, untilTime:integer|nil}

---@param entry PointHistoryEntry
---@param filter PointHistoryFilter
local function FilterPointEntry(entry, filter)
    if filter.playerName and filter.playerName ~= entry.playerName then
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

---Get filtered point history.
---@param filter PointHistoryFilter?
---@param maxResults integer? Default 100
---@return LootHistoryEntry[] history Will be a copy of the data.
function Env.Database:GetPlayerPointHistory(filter, maxResults)
    local toGo = maxResults or 100

    ---@type LootHistoryEntry[]
    local filtered = {}

    for _, v in ipairs(self.pointHistory) do
        if not filter or FilterPointEntry(v, filter) then
            table.insert(CopyTable(v))
            toGo = toGo - 1
            if toGo <= 0 then
                break
            end
        end
    end

    return filtered
end

---Add a new entry to the player's point history.
---@param playerName string
---@param change integer
---@param newPoints integer
---@param type PointChangeType
---@param reason string?
function Env.Database:AddPlayerPointHistory(playerName, change, newPoints, type, reason)
    self.pointHistory[playerName] = self.pointHistory[playerName] or {}
    local newEntry = { ---@type PointHistoryEntry
        timeStamp = time(),
        playerName = playerName,
        change = change,
        newPoints = newPoints,
        type = type,
        reason = reason,
    }
    LogDebug("Added player point history entry", playerName, change, newPoints, type, reason)
    table.insert(self.pointHistory, newEntry)
    self.OnPlayerPointHistoryUpdate:Trigger(playerName)
end

------------------------------------------------------------------
--- Loot History API
------------------------------------------------------------------

---@alias HistoryFilter {playerName:string|nil, fromTime:integer|nil, untilTime:integer|nil, response:table<string,boolean>|nil, includeReverted:boolean|nil}

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

    if not filter.includeReverted and entry.reverted then
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

    for _, v in ipairs(self.lootHistory) do
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
        return CopyTable(self.lootHistory[indexOrGUID])
    end
    for _, v in ipairs(self.lootHistory) do
        if v.guid == indexOrGUID then
            return CopyTable(v)
        end
    end
end

---@param color number[]
local function ColorArrayToRgbHex(color)
    return string.format("%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

---@param response LootResponse
---@return string fromatted {id,rgb_hexcolor}displayString
local function FormatResponseForDb(response)
    return ("{%d,%s}%s"):format(response.id, ColorArrayToRgbHex(response.color), response.displayString)
end

---Get id, hexcolor and display string from database response string.
---@param rstr string The string from the DB in the format {id,rgb_hexcolor}displayString
---@return number id
---@return string hexColor RGB
---@return string displayString
function Env.Database.FormatResponseStringForUI(rstr)
    local idStr, hexColor, display = rstr:match("{(%d+),(%w+)}(.+)")
    if not idStr then
        LogDebug("Response string from DB is missing id and color data: " .. rstr)
        return 0, "FFFFFF", rstr
    end
    local id = tonumber(idStr)
    return id and id or 0, hexColor, display
end

---Add an entry to the loot history.
---@param guid string
---@param timeStamp integer
---@param playerName string
---@param itemId integer
---@param response LootResponse
---@param reverted boolean
function Env.Database:AddLootHistoryEntry(guid, timeStamp, playerName, itemId, response, reverted)
    for _, v in ipairs(self.lootHistory) do
        if v.guid == guid then
            error("Tried to add already existing loot entry to loot history! " .. guid)
            break
        end
    end
    local newEntry = { ---@type LootHistoryEntry
        guid = guid,
        timeStamp = timeStamp,
        playerName = playerName,
        itemId = itemId,
        response = FormatResponseForDb(response),
        reverted = reverted,
    }
    table.insert(self.lootHistory, newEntry)
    LogDebug("Added loot history entry", guid, timeStamp, playerName, itemId, response, reverted)
    self.OnLootHistoryEntryChanged:Trigger(newEntry.guid)
end

---Update an entry in the loot history.
---@param guid string
---@param playerName string?
---@param response LootResponse?
---@param reverted boolean?
function Env.Database:UpdateLootHistoryEntry(guid, playerName, response, reverted)
    for _, v in ipairs(self.lootHistory) do
        if v.guid == guid then
            v.playerName = playerName and playerName or v.playerName
            v.response = response and FormatResponseForDb(response) or v.response
            v.reverted = reverted and reverted or v.reverted
            LogDebug("Updated loot history entry", guid, playerName, response, reverted)
            self.OnLootHistoryEntryChanged:Trigger(guid)
            return
        end
    end
    error("Tried to update non-existant entry in loot history! " .. guid)
end
