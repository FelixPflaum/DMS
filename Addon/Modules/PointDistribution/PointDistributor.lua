---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

local function LogDebug(...)
    Env:PrintDebug("PointDistrib:", ...)
end

---Send message as raid warning if assistant or lead in raid, otherwise in raid or party depending on group type.
---@param message string
local function SendRaidOrGroup(message)
    local channel
    if IsInRaid() then
        if UnitIsGroupAssistant("player") or UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
            channel = "RAID_WARNING"
        else
            channel = "RAID"
        end
    elseif IsInGroup() then
        channel = "PARTY"
    end
    SendChatMessage(message, channel)
end

--------------------------------------------------------------------------
--- Preperation points (distance and worldbuffs)
--------------------------------------------------------------------------

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
local function GetDistance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

---@param unit string
---@return boolean isInRange
---@return number distance
---@return boolean sameInstance
local function IsUnitInRange(unit)
    local maxDist = Env.settings.pointDistrib.inRangeReadyMaxDistance
    local myX, myY, _, myMapID = UnitPosition("player")
    local x, y, _, mapID = UnitPosition(unit)
    local sameMap = myMapID == mapID
    if not IsInInstance() then
        if sameMap and x and myX then
            local dist = GetDistance(myX, myY, x, y)
            return dist <= maxDist, dist, false
        end
    elseif sameMap then
        return true, 0, true
    end
    return false, 0, false
end

local PointDistributor = {}
Env.PointDistributor = PointDistributor

---Get list of players, their range status and their worldbuff data.
---@return { name: string, inRange: boolean, sameInstance:boolean, distance: number, wbCount: integer, wbPoints:integer}[]
function PointDistributor.GetPlayerReadyList()
    local playerList = {} ---@type {name:string,inRange:boolean,distance:number,wbCount:integer,wbPoints:integer}[]
    for unit in Env.MakeGroupIterator() do
        local name = UnitName(unit)
        local inRange, distance, sameInstance = IsUnitInRange(unit)
        local wbCount, wbPoints = Env.Worldbuffs.GetWorldbuffPoints(name)
        table.insert(playerList, {
            name = Ambiguate(name, "short"),
            inRange = inRange,
            sameInstance = sameInstance,
            distance = distance,
            wbCount = wbCount,
            wbPoints = wbPoints,
        })
        LogDebug(name, "in range", tostring(inRange), distance, "wbs", wbCount)
    end
    return playerList
end

local function GetReadyPointReason(isInRange, worldBuffCount)
    if worldBuffCount > 0 then
        return ("Is present: %s, WBs: %d"):format(tostring(isInRange), worldBuffCount)
    end
    return ("Is present: %s"):format(tostring(isInRange))
end

---Award points based on whether players in group are in range and how many WBs they have.
---@param ignoreRangeCheck boolean If true then ignore failed range checks.
function PointDistributor.AwardReadyPointsToInRange(ignoreRangeCheck)
    local list = PointDistributor.GetPlayerReadyList()
    local listNotPresent = {} ---@type string[]
    local basePoints = Env.settings.pointDistrib.baseReadyPoints
    local inRangePoints = Env.settings.pointDistrib.inRangeReadyPoints
    for _, entry in ipairs(list) do
        if not Env.Database:GetPlayer(entry.name) then
            local classId = select(3, UnitClass(entry.name))
            Env.Database:AddPlayer(entry.name, classId, 0)
        end

        local points = basePoints + entry.wbPoints
        if entry.inRange or ignoreRangeCheck then
            points = points + inRangePoints
        end

        if points > 0 then
            local reason = GetReadyPointReason(entry.inRange, entry.wbCount)
            Env.Database:AddPointsToPlayer(entry.name, points, "READY", reason)
        else
            table.insert(listNotPresent, entry.name)
        end
    end
    Env:PrintSuccess(L["Added preperation sanity for %d players. Following players only got base sanity: %s"]:format(
    #list, table.concat(listNotPresent, ", ")))
end

--------------------------------------------------------------------------
--- Raid points
--------------------------------------------------------------------------

---Get player list for party or raid.
function PointDistributor.GetCurrentGroup()
    local playerList = {} ---@type {name:string, isOnline:boolean}[]
    for unit in Env.MakeGroupIterator() do
        local name = UnitName(unit)
        table.insert(playerList, { name = Ambiguate(name, "short"), isOnline = UnitIsConnected(unit) })
    end
    return playerList
end

---@param amount integer
---@param reasonType PointChangeType
---@param reason string
---@param includeOffline boolean
local function AwardToRaid(amount, reasonType, reason, includeOffline)
    local excludeList = {} ---@type string[]
    if amount < 1 then return 0, excludeList end
    local list = PointDistributor.GetCurrentGroup()
    LogDebug("Giving", amount, "points to everyone in raid.", reasonType, reason, "includeOffline:",
        tostring(includeOffline))
    for _, entry in ipairs(list) do
        if entry.isOnline or includeOffline then
            if not Env.Database:GetPlayer(entry.name) then
                local classId = select(3, UnitClass(entry.name))
                Env.Database:AddPlayer(entry.name, classId, 0)
            end
            Env.Database:AddPointsToPlayer(entry.name, amount, reasonType, reason)
        else
            table.insert(excludeList, entry.name)
        end
    end
    return #list, excludeList
end

---Give points to anyone in raid for raid completion.
---@param amount integer
---@param raidName string
---@param includeOffline boolean
function PointDistributor.AwardRaidCompletePoints(amount, raidName, includeOffline)
    local playerCount, noPointsList = AwardToRaid(amount, "RAID", raidName, includeOffline)
    local msg
    if #noPointsList > 0 then
        local str = L
        ["Added %d raid completion sanity to %d players in raid for: %s. Following players receive no sanity: %s"]
        msg = str:format(amount, playerCount, raidName, table.concat(noPointsList, ", "))
    else
        local str = L["Added %d raid completion sanity to %d players in raid for: %s."]
        msg = str:format(amount, playerCount, raidName)
    end
    Env:PrintSuccess(msg)
    SendRaidOrGroup(msg)
end
