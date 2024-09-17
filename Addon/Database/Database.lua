---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("DB:", ...)
end

Env.Database = {}

---@alias PointChangeType "ITEM_AWARD"|"ITEM_AWARD_REVERTED"|"PLAYER_ADDED"|"CUSTOM"|"READY"|"RAID"

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
---@return PlayerEntry|nil playerEntry
function Env.Database:GetPlayer(name)
    return self.players[name]
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
    if points ~= 0 then
        Env.Database:AddPlayerPointHistory(playerName, points, points, "PLAYER_ADDED")
    end
    LogDebug("Added player to db", playerName, classId, points)
    self.OnPlayerChanged:Trigger(playerName)
end

---Update a player.
---@param playerName string
---@param classId integer
function Env.Database:UpdatePlayerEntry(playerName, classId)
    if not self.players[playerName] then
        error("Tried to update non-existant player entry in database! " .. playerName)
    end
    self.players[playerName].classId = classId
    LogDebug("Updated player", playerName, classId)
    self.OnPlayerChanged:Trigger(playerName)
end

---Add a new entry to the player's point history.
---@param playerName string
---@param change integer
---@param newPoints integer
---@param type PointChangeType
---@param reason string?
local function AddPlayerPointHistory(playerName, change, newPoints, type, reason)
    Env.Database.pointHistory[playerName] = Env.Database.pointHistory[playerName] or {}
    local newEntry = { ---@type PointHistoryEntry
        timeStamp = time(),
        playerName = playerName,
        change = change,
        newPoints = newPoints,
        type = type,
        reason = reason,
    }
    LogDebug("Added player point history entry", playerName, change, newPoints, type, reason)
    table.insert(Env.Database.pointHistory, newEntry)
    Env.Database.OnPlayerPointHistoryUpdate:Trigger(playerName)
end

---Add (or remove) points to player.
---@param playerName string
---@param change integer
---@param type PointChangeType
---@param reason string?
function Env.Database:AddPointsToPlayer(playerName, change, type, reason)
    local pentry = self.players[playerName]
    if not pentry then
        error("Tried to update non-existant player entry in database! " .. playerName)
    end
    pentry.points = pentry.points + change
    AddPlayerPointHistory(playerName, change, pentry.points, type, reason)
    LogDebug("Added player points", playerName, change)
    self.OnPlayerChanged:Trigger(playerName)
end

---Update player points.
---@param playerName string
---@param points integer
---@param type PointChangeType
---@param reason string?
function Env.Database:UpdatePlayerPoints(playerName, points, type, reason)
    if not self.players[playerName] then
        error("Tried to update non-existant player entry in database! " .. playerName)
    end
    local old = self.players[playerName].points
    if old ~= points then
        self.players[playerName].points = points
        local change = points - old
        AddPlayerPointHistory(playerName, change, points, type, reason)
    end
    LogDebug("Updated player points", playerName, old, "->", points)
    self.OnPlayerChanged:Trigger(playerName)
end

---Remove player from addon database.
---@param playerName string
function Env.Database:RemovePlayer(playerName)
    self.players[playerName] = nil
    LogDebug("Removed player", playerName, "from DB")
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

    for _, entry in ipairs(self.pointHistory) do
        if not filter or FilterPointEntry(entry, filter) then
            table.insert(entry)
            toGo = toGo - 1
            if toGo <= 0 then
                break
            end
        end
    end

    return filtered
end

---Remove player point history from addon database.
---@param playerName string
function Env.Database:RemovePlayerPointHistory(playerName)
    local filter = { playerName = playerName } ---@type PointHistoryFilter
    for idx = #self.pointHistory, 1, -1 do
        local entry = self.pointHistory[idx]
        if FilterPointEntry(entry, filter) then
            table.remove(self.pointHistory, idx)
        end
    end
    LogDebug("Removed player point hsitory entries for", playerName, "from DB")
    Env.Database.OnPlayerPointHistoryUpdate:Trigger(playerName)
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

    if filter.fromTime and filter.fromTime > entry.timeStamp then
        return false
    end

    if filter.untilTime and filter.untilTime < entry.timeStamp then
        return false
    end

    if not filter.includeReverted and entry.reverted then
        return false
    end

    return true
end

---Get filtered loot history.
---@param filter HistoryFilter
---@param maxResults integer? Default 100
---@return LootHistoryEntry[] history Will be a copy of the data.
function Env.Database:GetLootHistory(filter, maxResults)
    local toGo = maxResults or 100

    ---@type LootHistoryEntry[]
    local filtered = {}

    for _, entry in ipairs(self.lootHistory) do
        if FilterLootEntry(entry, filter) then
            table.insert(filtered, entry)
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
        return self.lootHistory[indexOrGUID]
    end
    for _, entry in ipairs(self.lootHistory) do
        if entry.guid == indexOrGUID then
            return entry
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
---@return integer id
---@return string hexColor RGB
---@return string displayString
function Env.Database.FormatResponseStringForUI(rstr)
    local idStr, hexColor, display = rstr:match("{(%d+),(%w+)}(.+)")
    if not idStr then
        LogDebug("Response string from DB is missing id and color data: " .. rstr)
        return 0, "FFFFFF", rstr
    end
    local id = tonumber(idStr)
    ---@cast id integer?
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
            v.reverted = reverted ~= nil and reverted or v.reverted
            LogDebug("Updated loot history entry", guid, playerName, response, reverted)
            self.OnLootHistoryEntryChanged:Trigger(guid)
            return
        end
    end
    error("Tried to update non-existant entry in loot history! " .. guid)
end

---Remove player loot history from addon database.
---@param playerName string
function Env.Database:RemovePlayerLootHistory(playerName)
    local filter = { playerName = playerName } ---@type HistoryFilter
    for idx = #self.lootHistory, 1, -1 do
        local entry = self.lootHistory[idx]
        if FilterLootEntry(entry, filter) then
            table.remove(self.lootHistory, idx)
        end
    end
    LogDebug("Removed player loot history entries for", playerName, "from DB")
    Env.Database.OnLootHistoryEntryChanged:Trigger("") -- TODO: remove GUID from this event?
end
