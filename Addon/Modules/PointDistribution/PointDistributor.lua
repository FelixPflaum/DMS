---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

local function LogDebug(...)
    Env:PrintDebug("PointDistrib:", ...)
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
local function IsUnitInRange(unit)
    local maxDist = Env.settings.pointDistrib.inRangeReadyMaxDistance
    if not IsInInstance() and maxDist > 40 then
        local myX, myY, _, myMapID = UnitPosition("player")
        local x, y, _, mapID = UnitPosition(unit)
        if myMapID == mapID then
            local dist = GetDistance(myX, myY, x, y)
            return dist <= maxDist, dist
        end
    elseif not InCombatLockdown() and CheckInteractDistance(unit, 4) then
        return true, 28
    elseif UnitInRange(unit) then -- 40y
        return true, 40
    end
    return false, 9999
end



local PointDistributor = {}
Env.PointDistributor = PointDistributor

---Get list of players, their range status and their worldbuff data.
---@return { name: string, inRange: boolean, distance: number, wbCount: integer, wbPoints:integer}[]
function PointDistributor.GetPlayerReadyList()
    local playerList = {} ---@type {name:string,inRange:boolean,distance:number,wbCount:integer,wbPoints:integer}[]
    for unit in Env.MakeGroupIterator() do
        local name = UnitName(unit)
        local inRange, distance = IsUnitInRange(unit)
        local wbCount, wbPoints = Env.Worldbuffs.GetWorldbuffPoints(name)
        table.insert(playerList, {
            name = Ambiguate(name, "short"),
            inRange = inRange,
            distance = distance,
            wbCount = wbCount,
            wbPoints = wbPoints,
        })
        LogDebug(name, "in range", tostring(inRange), distance, "wbs", wbCount)
    end
    return playerList
end

---Award points based on whether players in group are in range and how many WBs they have.
function PointDistributor.AwardReadyPointsToInRange()
    local list = PointDistributor.GetPlayerReadyList()
    local listNoSanity = {} ---@type string[]
    local inRangePoints = Env.settings.pointDistrib.inRangeReadyPoints
    for _, entry in ipairs(list) do
        if not Env.Database:GetPlayer(entry.name) then
            local classId = select(3, UnitClass(entry.name))
            Env.Database:AddPlayer(entry.name, classId, 0)
        end
        local reason = ("InRange: %s, WBs: %d"):format(tostring(entry.inRange), entry.wbCount)
        local points = entry.inRange and inRangePoints or 0
        points = points + entry.wbPoints
        if points > 0 then
            Env.Database:AddPointsToPlayer(entry.name, points, "READY", reason)
        else
            table.insert(listNoSanity, entry.name)
        end
    end
    Env:PrintSuccess(L["Added preperation sanity for %d players. Following players received 0 sanity: %s"]:format(#list, table.concat(listNoSanity, ", ")))
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
    LogDebug("Giving", amount, "points to everyone in raid.", reasonType, reason, "includeOffline:", tostring(includeOffline))
    for _, entry in ipairs(list) do
        if entry.isOnline or includeOffline then
            if not Env.Database:GetPlayer(entry.name) then
                local classId = select(3, UnitClass(entry.name))
                Env.Database:AddPlayer(entry.name, classId, 0)
            else
                table.insert(excludeList, entry.name)
            end
            Env.Database:AddPointsToPlayer(entry.name, amount, reasonType, reason)
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
    Env:PrintSuccess(L["Added %d raid completion sanity to %d players in raid for: %s. Following players receivec no sanity: %s"]:format(amount, playerCount, raidName, table.concat(noPointsList, ", ")))
end

---Give points to anyone in raid for other reasons.
---@param amount integer
---@param reason string
---@param includeOffline boolean
function PointDistributor.AwardPointsToGroup(amount, reason, includeOffline)
    local playerCount, noPointsList = AwardToRaid(amount, "CUSTOM", reason, includeOffline)
    Env:PrintSuccess(L["Added %d sanity to %d players in raid for reason: %s. Following players receivec no sanity: %s"]:format(amount, playerCount, reason, table.concat(noPointsList, ", ")))
end
