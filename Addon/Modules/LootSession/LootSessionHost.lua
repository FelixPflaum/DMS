---@class AddonEnv
local Env = select(2, ...)
local L = Env:GetLocalization()

local Comm = Env.SessionComm
local LootStatus = Env.Session.LootCandidateStatus

local RESPONSE_GRACE_PERIOD = 3 -- Extra time given where the host will still accept responsed after expiration. Will not be reflected in UI. Just to account for comm latency.

local function LogDebug(...)
    Env:PrintDebug("Host:", ...)
end

---Create a simple unique identifier.
local function MakeGuid()
    return time() .. "-" .. string.format("%08x", math.floor(math.random(0, 0x7FFFFFFF)))
end

------------------------------------------------------------------------------------
--- Data Structure Types
------------------------------------------------------------------------------------

---@alias CommTarget "group"|"self"

---@class (exact) SessionHost_Candidate
---@field name string
---@field classId integer
---@field leftGroup boolean
---@field isResponding boolean
---@field lastMessage number GetTime()

---@class (exact) SessionHost_ItemResponse
---@field candidate SessionHost_Candidate
---@field status LootCandidateStatus
---@field response LootResponse|nil
---@field roll integer|nil
---@field points integer|nil

---@class (exact) SessionHost_Item
---@field guid string Unique id for that specific loot distribution.
---@field order integer For ordering items in the UI.
---@field parentGuid string|nil If this item is a duplicate this will be the guid of the main item, i.e. the one people respond to.
---@field childGuids string[]|nil If duplicates of the item exist their guids will be in here.
---@field itemId integer
---@field veiled boolean Details are not sent to clients until item is unveiled.
---@field startTime integer
---@field endTime integer
---@field status "waiting"|"timeout"|"child"
---@field roller UniqueRoller
---@field responses table<string, SessionHost_ItemResponse>
---@field awardedTo string|nil

---@class (exact) SessionHost
---@field guid string
---@field isRunning boolean
local Host = {}
Env.SessionHost = Host

------------------------------------------------------------------------------------
--- Construction
------------------------------------------------------------------------------------

local UPDATE_TIMER_KEY = "mainUpdate"

local targetChannelType = "self" ---@type CommTarget
local timers = Env:NewUniqueTimers()
local items = {} ---@type table<string, SessionHost_Item>
local itemCount = 0
local candidates = {} ---@type table<string, SessionHost_Candidate>
local responses ---@type LootResponses

---@param target CommTarget
local function InitHost(target)
    Host.guid = MakeGuid()
    targetChannelType = target
    responses = Env.Session.CreateLootResponses()
    candidates = {}
    Host.isRunning = true
    itemCount = 0
    items = {}

    Env:RegisterEvent("GROUP_ROSTER_UPDATE", Host)
    Env:RegisterEvent("GROUP_LEFT", Host)

    Env:PrintSuccess("Started a new host session for " .. targetChannelType)
    LogDebug("Session GUID", Host.guid)

    Comm:HostSetCurrentTarget(targetChannelType)
    Comm.Send.HMSG_SESSION_START(Host.guid, responses.responses)

    Host:UpdateCandidateList()
    timers:StartUnique(UPDATE_TIMER_KEY, 10, "TimerUpdate", Host)

    -- TODO: Update responses if player db changes (points)
end

function Host:Destroy()
    if not self.isRunning then return end
    self.isRunning = false
    Host.guid = ""
    timers:CancelAll()
    Env:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:UnregisterEvent("GROUP_LEFT", self)
    Comm.Send.HMSG_SESSION_END()
end

---@private
function Host:TimerUpdate()
    if not self.isRunning then return end
    LogDebug("TimerUpdate")
    local nowgt = GetTime()

    ---@type table<string, SessionHost_Candidate>
    local changedLootCandidates = {}
    local haveCandidateChange = false
    for _, candidate in pairs(candidates) do
        local oldIsResponding = candidate.isResponding
        candidate.isResponding = candidate.lastMessage > nowgt - 25
        if oldIsResponding ~= candidate.isResponding then
            changedLootCandidates[candidate.name] = candidate
            haveCandidateChange = true
        end
    end

    if haveCandidateChange then
        Comm.Send.HMSG_CANDIDATE_UPDATE(changedLootCandidates)
    end

    -- Restart timer
    timers:StartUnique(UPDATE_TIMER_KEY, 10, "TimerUpdate", self)
end

---@private
function Host:GROUP_LEFT()
    if not self.isRunning then return end
    if targetChannelType == "group" then
        Env:PrintError("Session host destroyed because you left the group!")
        self:Destroy()
    end
end

------------------------------------------------------------------------------------
--- Candidates
------------------------------------------------------------------------------------

---Create list of loot candidates, i.e. list of all raid members at this point in time.
---Players that leave the party will be kept in the list if an existing list is provided.
function Host:UpdateCandidateList()
    ---@type table<string, SessionHost_Candidate>
    local newList = {}
    local prefix = ""
    local changed = false
    ---@type table<string, SessionHost_Candidate>
    local changedLootCandidates = {}

    if targetChannelType == "group" then
        if IsInRaid() then
            prefix = "raid"
        elseif IsInGroup() then
            prefix = "party"
        else
            Env:PrintError("Tried to update candidates but not in a group! Ending session.")
            self:Destroy()
        end
    else
        prefix = ""
    end

    if prefix == "" or prefix == "party" then
        local myName = UnitName("player")
        newList[myName] = {
            name = myName,
            classId = select(3, UnitClass("player")),
            leftGroup = false,
            isResponding = false,
            lastMessage = 0,
        }
    end

    local numMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name then
            newList[name] = {
                name = name,
                classId = select(3, UnitClass(unit)),
                leftGroup = false,
                isResponding = false,
                lastMessage = 0,
            }
        end
    end

    for oldName, oldEntry in pairs(candidates) do
        local newEntry = newList[oldName]

        if newEntry == nil then
            if not oldEntry.leftGroup then
                oldEntry.leftGroup = true
                changed = true
                changedLootCandidates[oldName] = oldEntry
            end
        else
            if oldEntry.leftGroup then
                oldEntry.leftGroup = false
                changed = true
                changedLootCandidates[oldName] = oldEntry
            end
        end
    end

    for newName, newEntry in pairs(newList) do
        if not candidates[newName] then
            candidates[newName] = newEntry
            changed = true
            changedLootCandidates[newName] = newEntry
        end
    end

    if changed then
        if Env.settings.logLevel > 1 then
            LogDebug("Changed candidates:")
            for _, lc in pairs(changedLootCandidates) do
                LogDebug(" - ", lc.name)
            end
        end
        Comm.Send.HMSG_CANDIDATE_UPDATE(changedLootCandidates)
    end
end

---@private
function Host:GROUP_ROSTER_UPDATE()
    LogDebug("GROUP_ROSTER_UPDATE")
    local tkey = "groupupdate"
    if timers:HasTimer(tkey) then return end
    LogDebug("Start UpdateCandidateList timer")
    timers:StartUnique(tkey, 5, "UpdateCandidateList", self)
end

Comm.Events.CMSG_ATTENDANCE_CHECK:RegisterCallback(function(sender)
    local candidate = candidates[sender]
    if not candidate then return end
    local update = not candidate.isResponding
    candidate.isResponding = true
    candidate.lastMessage = GetTime()
    if update then
        Comm.Send.HMSG_CANDIDATE_UPDATE(candidate)
    end
end)

------------------------------------------------------------------------------------
--- Item Responses
------------------------------------------------------------------------------------

Comm.Events.CMSG_ITEM_RECEIVED:RegisterCallback(function(sender, itemGuid)
    local candidate = candidates[sender]
    if not candidate then return end
    local item = items[itemGuid]
    if not item then
        Env:PrintError(sender .. " tried to respond to unknown item " .. itemGuid)
        return
    end
    local itemResponse = item.responses[sender]
    if not itemResponse then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but candidate client not known!")
        return
    end
    if itemResponse.status == LootStatus.sent then
        itemResponse.status = LootStatus.waitingForResponse
        if not item.veiled then
            Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
        end
    end
end)

---Set response, does NOT check if response was already set!
---@param item SessionHost_Item
---@param itemResponse SessionHost_ItemResponse
---@param response LootResponse
function Host:SetItemResponse(item, itemResponse, response)
    itemResponse.response = response
    itemResponse.roll = itemResponse.roll or item.roller:GetRoll()
    itemResponse.status = LootStatus.responded
    -- TODO: get points from DB
    itemResponse.points = response.isPointsRoll and 999 or nil
    if not item.veiled then
        Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
    end
end

Comm.Events.CMSG_ITEM_RESPONSE:RegisterCallback(function(sender, itemGuid, responseId)
    local item = items[itemGuid]
    if not item then
        Env:PrintError(sender .. " tried to respond to unknown item " .. itemGuid)
        return
    elseif item.status ~= "waiting" then
        Env:PrintError(sender .. " tried to respond to expired item " .. itemGuid)
        return
    elseif item.parentGuid ~= nil then
        Env:PrintError(sender .. " tried to respond to child item " .. itemGuid)
        return
    end
    local itemResponse = item.responses[sender]
    if not itemResponse then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but candidate not known for that item")
        return
    elseif itemResponse.response then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but already responded")
        return
    end
    local response = responses:GetResponse(responseId)
    if not response then
        Env:PrintError(sender ..
            " tried to respond to item " .. itemGuid .. " but response id " .. responseId .. " invalid")
        return
    end
    Host:SetItemResponse(item, itemResponse, response)
end)

------------------------------------------------------------------
--- Add Item
------------------------------------------------------------------

---Unveil next item after the last awarded item.
function UnveilNextItem()
    ---@type SessionHost_Item[]
    local orderedItem = {}

    for _, item in pairs(items) do
        table.insert(orderedItem, item)
    end

    table.sort(orderedItem, function(a, b)
        return a.order < b.order
    end)

    for _, item in ipairs(orderedItem) do
        if not item.veiled then
            if not item.awardedTo then
                LogDebug("Last unveiled item not yet awarded, not unveiling another.")
                return
            end
        else
            LogDebug("Unveil item: ", item.guid, item.itemId)
            item.veiled = false
            Comm.Send.HMSG_ITEM_UNVEIL(item.guid)
            if item.childGuids then
                for _, childGuid in ipairs(item.childGuids) do
                    local childItem = items[childGuid]
                    if childItem.veiled then
                        LogDebug("Unveil child item because parent was unveiled", childGuid)
                        childItem.veiled = false
                        Comm.Send.HMSG_ITEM_UNVEIL(childItem.guid)
                    end
                end
            end

            if not item.awardedTo then
                LogDebug("Unveiled item is the next to be awarded, not unveiling more.")
                return
            end
        end
    end
end

---Set item status to timed out, disallowing any further responses.
---@param guid string
function Host:ItemStopRoll(guid)
    local item = items[guid]
    if not item then return end
    LogDebug("ItemStopRoll", guid, item.itemId)
    if item.status == "waiting" then
        item.status = "timeout"
        for _, itemResponse in pairs(item.responses) do
            if not itemResponse.response and itemResponse.status ~= LootStatus.unknown then
                itemResponse.status = LootStatus.responseTimeout
                if not item.veiled then
                    Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
                end
            end
        end
        Comm.Send.HMSG_ITEM_ROLL_END(item.guid)
    end
end

---Add item to the session.
---@param itemId integer
---@return boolean itemAdded
---@return string|nil errorMessage
function Host:ItemAdd(itemId)
    if not self.isRunning then
        return false, "session was already finished"
    end

    ---@type SessionHost_Item|nil
    local parentItem = nil
    for _, existingItem in pairs(items) do
        if existingItem.itemId == itemId then
            local parentGuid = existingItem.parentGuid
            if parentGuid then
                parentItem = items[parentGuid]
                break
            end
            parentItem = existingItem
        end
    end

    ---@type SessionHost_Item
    local item

    if parentItem then
        parentItem.childGuids = parentItem.childGuids or {}

        item = {
            guid = MakeGuid(),
            order = parentItem.order + #parentItem.childGuids + 1,
            itemId = itemId,
            veiled = parentItem.veiled,
            startTime = parentItem.startTime,
            endTime = parentItem.endTime,
            status = "child",
            responses = parentItem.responses,
            roller = parentItem.roller,
            parentGuid = parentItem.guid,
        }

        table.insert(parentItem.childGuids, item.guid)
    else
        ---@type table<string, SessionHost_ItemResponse>
        local candidateResponseList = {}
        for name, candidate in pairs(candidates) do
            candidateResponseList[name] = {
                candidate = candidate,
                status = LootStatus.sent,
            }
        end

        item = {
            guid = MakeGuid(),
            order = itemCount * 100,
            itemId = itemId,
            veiled = true,
            startTime = time(),
            endTime = time() + Env.settings.lootSession.timeout,
            status = "waiting",
            responses = candidateResponseList,
            roller = Env:NewUniqueRoller(),
        }

        timers:StartUnique(item.guid, Env.settings.lootSession.timeout + RESPONSE_GRACE_PERIOD, "ItemStopRoll", self)
    end

    LogDebug("ItemAdd", itemId, "have parent ", parentItem ~= nil, "guid:", item.guid)

    itemCount = itemCount + 1
    items[item.guid] = item
    UnveilNextItem()

    Comm.Send.HMSG_ITEM_ANNOUNCE(item)

    timers:StartUnique(item.guid .. "ackcheck", 6, function(key)
        LogDebug("ItemAdd ackcheck", itemId, "guid:", item.guid)
        for _, itemResponse in pairs(item.responses) do
            if itemResponse.status == LootStatus.sent then
                itemResponse.status = LootStatus.unknown
                if not item.veiled then
                    Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
                end
            end
        end
    end)

    return true
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

---Start a new host session.
---@param target CommTarget
---@return SessionHost|nil
---@return string|nil errorMessage
function Host:Start(target)
    if Host.isRunning then
        return nil, L["A host session is already running."]
    end

    if not Env.Session.CanUnitStartSession(UnitName("player")) then
        return nil, L["You do not have permissions to start a session."]
    end

    if target == "group" then
        if not IsInRaid() and not IsInGroup() then
            return nil, L["Host target group does not work outside of a group!"]
        end
    elseif target ~= "self" then
        return nil, L["Invalid host target! Valid values are: %s and %s."]:format("group", "self")
    end

    LogDebug("Starting host session with target: ", target)
    InitHost(target)

    return Host
end

Env:RegisterSlashCommand("end", L["End hosting a loot session."], function(args)
    if not Host.isRunning then
        Env:PrintWarn(L["No session is running."])
        return
    end
    Env:PrintSuccess("Destroy host session...")
    Host:Destroy()
end)
