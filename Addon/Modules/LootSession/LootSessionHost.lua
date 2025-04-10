---@class AddonEnv
local Env = select(2, ...)
local L = Env:GetLocalization()

local Comm = Env.SessionComm
local LootStatus = Env.Session.LootCandidateStatus

local MAX_IMPORT_AGE = 86400 * 3;
local RESPONSE_GRACE_PERIOD = 2 -- Extra time given where the host will still accept responsed after expiration. Will not be reflected in UI. Just to account for comm latency.

local function LogDebug(...)
    Env:PrintDebug("Host:", ...)
end

local MakeGuid = Env.Database.GenerateHistGuid

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
---@field currentPoints integer Current point count. ONLY EVER update this from DB data!
---@field isFake? boolean Is fake test candidate.

---@class (exact) SessionHost_ItemResponse
---@field candidate SessionHost_Candidate
---@field status LootCandidateStatus
---@field response LootResponse|nil
---@field roll integer|nil

---@class (exact) SessionHost_ItemAwardData
---@field candidateName string The name of the player the item was awarded to.
---@field usedResponse LootResponse
---@field usedPoints integer?
---@field awardTime integer
---@field pointsSnapshot? table<string,integer> Snapshot of point count the award was based on.

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
---@field awarded SessionHost_ItemAwardData?
---@field markedGarbage boolean

---@class (exact) SessionHost
---@field guid string
---@field isRunning boolean
local Host = {}
Env.SessionHost = Host

------------------------------------------------------------------------------------
--- Construction
------------------------------------------------------------------------------------

local UPDATE_TIMER_KEY = "mainUpdate"
local UPDATE_TIME = Env.Session.HOST_UPDATE_TIME
local CLIENT_TIMEOUT_TIME = Env.Session.CLIENT_TIMEOUT_TIME
local RESEND_MIN_INTERVAL = 10
local RESEND_TIMER_KEY = "resendStart"

local targetChannelType = "self" ---@type CommTarget
local timers = Env:NewUniqueTimers()
local items = {} ---@type table<string, SessionHost_Item>
local itemCount = 0
local candidates = {} ---@type table<string, SessionHost_Candidate>
local responses ---@type LootResponses
local pointsMinForRoll = 0
local pointsMaxRange = 0
local lastStartResend = 0

---@param target CommTarget
local function InitHost(target)
    Host.guid = MakeGuid()
    targetChannelType = target
    responses = Env.Session.CreateLootResponses()
    candidates = {}
    Host.isRunning = true
    itemCount = 0
    items = {}
    pointsMinForRoll = Env.settings.lootSession.pointsMinForRoll
    pointsMaxRange = Env.settings.lootSession.pointsMaxRange

    Env:RegisterEvent("GROUP_ROSTER_UPDATE", Host)
    Env:RegisterEvent("GROUP_LEFT", Host)

    Env:PrintSuccess("Started a new host session for " .. targetChannelType)
    LogDebug("Session GUID", Host.guid)

    Comm:HostSetCurrentTarget(targetChannelType)
    Comm.Send.HMSG_SESSION_START(Host.guid, responses.responses, pointsMinForRoll, pointsMaxRange)

    Host:UpdateCandidateList()
    timers:StartUnique(UPDATE_TIMER_KEY, UPDATE_TIME, "TimerUpdate", Host)

    if Env.settings.testMode then
        Env:PrintError("TEST MODE: Generating fake candidate entries!")
        Env.Session.FillFakeCandidateList(candidates, 20)
        Comm.Send.HMSG_CANDIDATE_UPDATE(candidates)
    end
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

local function ResendStart()
    if not Host.isRunning then return end
    lastStartResend = GetTime()
    LogDebug("Resending start")
    Comm.Send.HMSG_SESSION_START_RESEND(Host.guid, responses.responses, pointsMinForRoll, pointsMaxRange, candidates, items)
end

Comm.Events.CMSG_RESEND_START:RegisterCallback(function(sender)
    if not Host.isRunning then return end
    Env:PrintWarn(L["%s is reconnecting to session."]:format(sender))
    local now = GetTime()
    local timeSinceLastResend = now - lastStartResend
    if not timers:HasTimer(RESEND_TIMER_KEY) and timeSinceLastResend > RESEND_MIN_INTERVAL then
        ResendStart()
    else
        timers:StartUnique(RESEND_TIMER_KEY, RESEND_MIN_INTERVAL - timeSinceLastResend, ResendStart, nil, true)
    end
    for _, sessionItem in pairs(items) do
        if sessionItem.status == "waiting" and
            sessionItem.responses[sender] and
            sessionItem.responses[sender].status.id == LootStatus.unknown.id then
            sessionItem.responses[sender].status = LootStatus.sent
            Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(sessionItem.guid, sessionItem.responses[sender])
        end
    end
end)

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
        candidate.isResponding = candidate.lastMessage > nowgt - CLIENT_TIMEOUT_TIME
        if oldIsResponding ~= candidate.isResponding then
            changedLootCandidates[candidate.name] = candidate
            haveCandidateChange = true
        end
    end

    if haveCandidateChange then
        Comm.Send.HMSG_CANDIDATE_STATUS_UPDATE(changedLootCandidates)
    end

    local lastBoradcastTime = Comm.GetLastHostBroadcastSent()
    if nowgt - lastBoradcastTime >= UPDATE_TIME - 0.5 then
        Comm.Send.HMSG_KEEPALIVE()
    end

    -- Restart timer
    timers:StartUnique(UPDATE_TIMER_KEY, UPDATE_TIME, "TimerUpdate", self)
end

---@private
function Host:GROUP_LEFT()
    if not self.isRunning then return end
    if targetChannelType == "group" then
        Env:PrintError("Session host destroyed because you left the group!")
        self:Destroy()
    end
end

---Send message to target channel of host session.
---Will be raid, party or whisper to self.
---@param message string
function Host:SendMessageToTargetChannel(message)
    local channel = "WHISPER"
    if targetChannelType == "group" then
        if IsInRaid() then
            channel = "RAID"
        elseif IsInGroup() then
            channel = "PARTY"
        else
            Env:PrintError(L["Can't send message! Session target is group but you are not in any group!"])
            return
        end
    end
    if channel == "WHISPER" then
        SendChatMessage(message, channel, nil, select(1, UnitName("player")))
    else
        SendChatMessage(message, channel)
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
        local dbEntry = Env.Database:GetPlayer(myName)
        newList[myName] = {
            name = myName,
            classId = select(3, UnitClass("player")),
            leftGroup = false,
            isResponding = false,
            lastMessage = 0,
            currentPoints = dbEntry and dbEntry.points or 0,
        }
    end

    local numMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name then
            local dbEntry = Env.Database:GetPlayer(name)
            newList[name] = {
                name = name,
                classId = select(3, UnitClass(unit)),
                leftGroup = false,
                isResponding = false,
                lastMessage = 0,
                currentPoints = dbEntry and dbEntry.points or 0,
            }
        end
    end

    for oldName, oldEntry in pairs(candidates) do
        local newEntry = newList[oldName]

        if newEntry == nil and not oldEntry.isFake then
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
            for _, sessionItem in pairs(items) do
                if sessionItem.status == "waiting" then
                    sessionItem.responses[newName] = {
                        candidate = newEntry,
                        status = LootStatus.unknown,
                    }
                    Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(sessionItem.guid, sessionItem.responses[newName])
                end
            end
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
    timers:StartUnique(tkey, 1, "UpdateCandidateList", self)
end

Comm.Events.CMSG_ATTENDANCE_CHECK:RegisterCallback(function(sender)
    if not Host.isRunning then return end
    local candidate = candidates[sender]
    if not candidate then return end
    local update = not candidate.isResponding
    candidate.isResponding = true
    candidate.lastMessage = GetTime()
    if update then
        Comm.Send.HMSG_CANDIDATE_STATUS_UPDATE(candidate)
    end
end)

------------------------------------------------------------------------------------
--- Item Responses
------------------------------------------------------------------------------------

Comm.Events.CMSG_ITEM_RECEIVED:RegisterCallback(function(sender, itemGuid)
    if not Host.isRunning then return end
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
    if itemResponse.status == LootStatus.sent or itemResponse.status == LootStatus.unknown then
        itemResponse.status = LootStatus.waitingForResponse
        if not item.veiled then
            Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
        end
    end
end)

---Set response, does NOT do any checks, it will simply change the response!
---@param item SessionHost_Item
---@param itemResponse SessionHost_ItemResponse
---@param response LootResponse
---@param doInstant boolean? Do not batch response change comm message.
local function SetItemResponse(item, itemResponse, response, doInstant)
    itemResponse.response = response
    if not itemResponse.roll and itemResponse.response.id >= Env.Session.REPSONSE_ID_FIRST_CUSTOM then
        itemResponse.roll = item.roller:GetRoll()
    end
    itemResponse.status = LootStatus.responded
    if not item.veiled then
        Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse, doInstant)
    end

    local allResponded = true
    for _, itemResponseItr in pairs(item.responses) do
        if not itemResponseItr.response and not (
                itemResponseItr.status.id == LootStatus.unknown.id or
                itemResponseItr.status.id == LootStatus.responseTimeout.id
            ) then
            allResponded = false
            break
        end
    end
    if allResponded then
        Host:ItemStopRoll(item.guid)
    end
end

---Manually set response of a player for a given item.
---@param itemGuid string
---@param candidateName string
---@param responseId integer
---@param doInstant boolean? Do not batch response change comm message.
---@return string? error If arguments are not valid will return an error message.
function Host:SetItemResponse(itemGuid, candidateName, responseId, doInstant)
    local item = items[itemGuid]
    local response = responses:GetResponse(responseId)
    local itemResponse = item.responses[candidateName]
    if not item then return L["Invalid item guid!"] end
    if not response then return L["Invalid response id!"] end
    if not itemResponse then return L["Invalid candidate name!"] end
    if item.awarded then return L["Can't change response after item was awarded!"] end
    SetItemResponse(item, itemResponse, response, doInstant)
end

Comm.Events.CMSG_ITEM_RESPONSE:RegisterCallback(function(sender, itemGuid, responseId)
    if not Host.isRunning then return end
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
    SetItemResponse(item, itemResponse, response)
end)

------------------------------------------------------------------
--- Award Item
------------------------------------------------------------------

---@param item SessionHost_Item
local function MakePointsSnapshot(item)
    ---@type table<string,integer>
    local ss = {}
    for _, v in pairs(item.responses) do
        ss[v.candidate.name] = v.candidate.currentPoints
    end
    return ss
end

---Mark item as garbage.
---@param itemGuid string
---@return string? error
function Host:TrashItem(itemGuid)
    local item = items[itemGuid]
    if not item then return L["Invalid item guid!"] end
    if item.awarded then return end
    -- if item.endTime > time() then return L["Item is still being rolled for, not everyone responded!"] end
    self:DoForEachRelatedItem(item, true, function(relatedItem, isThis)
        if not relatedItem.markedGarbage then
            relatedItem.markedGarbage = true;
            Comm.Send.HMSG_ITEM_UPDATE(relatedItem)
        end
    end)
    UnveilNextItem();
end

---Award item to a candidate.
---@param itemGuid string
---@param candidateName string
---@return string? error If arguments are not valid will return an error message.
---@return LootResponse? responseUsed The response used to award item for. Can be different from chosen response if e.g. points were too low on a point roll.
---@return integer? pointsUsed The points used if awarded for a point roll.
---@return string? pointUsageReason Reason for using points if points were used.
function Host:AwardItem(itemGuid, candidateName)
    local item = items[itemGuid]
    local itemResponse = item.responses[candidateName]
    local chosenResponse = itemResponse.response

    if not item then return L["Invalid item guid!"] end
    if not itemResponse then return L["Invalid candidate name!"] end
    if not chosenResponse or chosenResponse.id < Env.Session.REPSONSE_ID_FIRST_CUSTOM then
        return L["Candidate has no response set or passed!"]
    end
    if item.awarded then return L["Item already awarded to %s!"]:format(item.awarded.candidateName) end

    self:ItemStopRoll(itemGuid)

    local responseUsed = chosenResponse
    local pointsUsed ---@type integer?
    local pointUsageReason ---@type string?
    local pointSnapshop ---@type table<string, integer>?

    if chosenResponse.isPointsRoll then
        local candidate = itemResponse.candidate
        local doesCount, useResponse, useReason = Env.PointLogic.DoesRollCountAsPointRoll(candidate.currentPoints, chosenResponse, responses.responses, pointsMinForRoll)
        if doesCount then
            pointSnapshop = MakePointsSnapshot(item)
            local pointsToRemove, reason = Env.PointLogic.ShouldDeductPoints(item, itemResponse, candidate.currentPoints)
            if pointsToRemove then
                if reason == "contested" then
                    pointUsageReason = L["Contested item won with sanity."]
                elseif reason == "uncontested" then
                    pointUsageReason = L["Uncontested item won with sanity."]
                end
                pointsUsed = pointsToRemove
                candidate.currentPoints = candidate.currentPoints - pointsUsed
                if not candidate.isFake and pointsUsed > 0 then
                    if not Env.Database:GetPlayer(candidate.name) then
                        Env.Database:AddPlayer(candidate.name, candidate.classId, candidate.currentPoints + pointsUsed)
                    end
                    Env.Database:UpdatePlayerPoints(candidate.name, candidate.currentPoints, "ITEM_AWARD", item.guid)
                end
                Comm.Send.HMSG_CANDIDATE_UPDATE(candidate)
            end
        else
            responseUsed = useResponse
            Env:PrintDebug("Awarding for", useResponse.displayString, "because", useReason)
        end
    end

    item.awarded = {
        candidateName = candidateName,
        usedResponse = responseUsed,
        usedPoints = pointsUsed,
        awardTime = time(),
        pointsSnapshot = pointSnapshop,
    }

    if not itemResponse.candidate.isFake then
        Env.Database:RemoveLootHistoryEntry(item.guid)
        if not Env.Database:GetPlayer(candidateName) then
            Env.Database:AddPlayer(candidateName, itemResponse.candidate.classId, 0)
        end
        Env.Database:AddLootHistoryEntry(item.guid, candidateName, item.itemId, responseUsed)
    end
    Comm.Send.HMSG_ITEM_AWARD_UPDATE(itemGuid, candidateName, responseUsed.id, item.awarded.pointsSnapshot)

    Env.Trade:AddItem(item.itemId, item.awarded.candidateName)
    UnveilNextItem()

    return nil, responseUsed, pointsUsed, pointUsageReason
end

---Revoke awarded item from a candidate.
---@param itemGuid string
---@param candidateName string
---@return string? error If arguments are not valid will return an error message.
---@return integer? pointsReturned
function Host:RevokeAwardItem(itemGuid, candidateName)
    local item = items[itemGuid]
    local itemResponse = item.responses[candidateName]
    if not item then return L["Invalid item guid!"] end
    if not itemResponse then return L["Invalid candidate name!"] end
    if not item.awarded or item.awarded.candidateName ~= candidateName then
        return L["Item isn't awarded to %s!"]:format(item.awarded.candidateName)
    end

    local pointsReturned ---@type integer?

    if item.awarded.usedResponse.isPointsRoll then
        -- Check if candidate was awarded another item using points after this. Fail if so, it would fuck up points.
        -- Host should manually go back the chain and revert awards if needed.
        for _, otherItem in pairs(items) do
            if otherItem.awarded and otherItem.awarded.awardTime > item.awarded.awardTime
                and otherItem.awarded.candidateName == candidateName
                and otherItem.awarded.usedResponse.isPointsRoll then
                local itemLink = select(2, C_Item.GetItemInfo(otherItem.itemId))
                return L
                    ["Candidate was awarded another item (%s) using sanity after this! Manually revoke awards in order if needed."]
                    :format(itemLink)
            end
        end

        local candidate = itemResponse.candidate
        pointsReturned = item.awarded.usedPoints or 0
        candidate.currentPoints = candidate.currentPoints + pointsReturned
        if not candidate.isFake and pointsReturned > 0 then
            if not Env.Database:GetPlayer(candidate.name) then
                Env.Database:AddPlayer(candidate.name, candidate.classId, candidate.currentPoints - pointsReturned)
            end
            Env.Database:UpdatePlayerPoints(candidate.name, candidate.currentPoints, "ITEM_AWARD_REVERTED", item.guid)
        end
        Comm.Send.HMSG_CANDIDATE_UPDATE(candidate)
    end

    item.awarded = nil
    if not itemResponse.candidate.isFake then
        Env.Database:RemoveLootHistoryEntry(item.guid)
    end
    Comm.Send.HMSG_ITEM_AWARD_UPDATE(itemGuid)

    Env.Trade:RemoveItem(item.itemId, candidateName)

    return nil, pointsReturned
end

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
            if not item.awarded and not item.markedGarbage then
                LogDebug("Last unveiled item not yet awarded, not unveiling another.")
                return
            end
        else
            LogDebug("Unveil item: ", item.guid, item.itemId)
            item.veiled = false
            Comm.Send.HMSG_ITEM_UPDATE(item)

            if not item.parentGuid then
                for _, v in pairs(item.responses) do
                    Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, v)
                end
                if item.childGuids then
                    for _, childGuid in ipairs(item.childGuids) do
                        local childItem = items[childGuid]
                        if childItem.veiled then
                            LogDebug("Unveil child item because parent was unveiled", childGuid)
                            childItem.veiled = false
                            Comm.Send.HMSG_ITEM_UPDATE(childItem)
                        end
                    end
                end
            end

            if not item.awarded and not item.markedGarbage then
                LogDebug("Unveiled item is the next to be awarded, not unveiling more.")
                return
            end
        end
    end
end

---Set item status to timed out, disallowing any further responses.
---@param guid string
---@param sendInstant boolean|nil Do not batch with other roll end packets and send immediately.
---@return SessionHost_Item? stoppedItem The item that was stopped if guid was valid.
function Host:ItemStopRoll(guid, sendInstant)
    local item = items[guid]
    if not item then return end
    LogDebug("ItemStopRoll", guid, item.itemId)
    if item.status == "waiting" then
        item.status = "timeout"
        local now = time()
        if item.endTime > now then
            self:DoForEachRelatedItem(item, true, function(relatedItem, isThis)
                LogDebug("Set end time for item", relatedItem.guid, now)
                relatedItem.endTime = now
            end)
        end
        for _, itemResponse in pairs(item.responses) do
            if not itemResponse.response and itemResponse.status ~= LootStatus.unknown then
                itemResponse.status = LootStatus.responseTimeout
                if not item.veiled then
                    Comm.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
                end
            end
        end
        Comm.Send.HMSG_ITEM_ROLL_END(item.guid, sendInstant)
    end
    return item
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
            markedGarbage = parentItem.markedGarbage,
        }

        table.insert(parentItem.childGuids, item.guid)
    else
        item = {
            guid = MakeGuid(),
            order = itemCount * 100,
            itemId = itemId,
            veiled = true,
            startTime = time(),
            endTime = time() + Env.settings.lootSession.timeout,
            status = "waiting",
            responses = {},
            roller = Env:NewUniqueRoller(),
            markedGarbage = false,
        }

        for name, candidate in pairs(candidates) do
            item.responses[name] = {
                candidate = candidate,
                status = LootStatus.sent,
            }
            if candidate.isFake and Env.settings.testMode then
                local shouldAck, shouldRespond, responseDelay, response = Env.Session.GetTestResponse(responses.responses)
                Env:PrintError("TEST MODE: Generating fake response for " .. name)
                print("Ack", tostring(shouldAck), "Resp", tostring(shouldRespond), "Delay", responseDelay, response.displayString)
                if shouldAck then
                    C_Timer.NewTimer(1, function (t)
                        Comm:FakeSendToHost(candidate.name, function ()
                            Comm.Send.CMSG_ITEM_RECEIVED(item.guid, true)
                        end)
                    end)
                    if shouldRespond then
                        C_Timer.NewTimer(responseDelay, function (t)
                            Comm:FakeSendToHost(candidate.name, function ()
                                Comm.Send.CMSG_ITEM_RESPONSE(item.guid, response.id)
                            end)
                        end)
                    end
                end
            end
        end

        timers:StartUnique(item.guid, Env.settings.lootSession.timeout + RESPONSE_GRACE_PERIOD, "ItemStopRoll", self)
    end

    LogDebug("ItemAdd", itemId, "have parent ", parentItem ~= nil, "guid:", item.guid)

    itemCount = itemCount + 1
    items[item.guid] = item

    Comm.Send.HMSG_ITEM_ANNOUNCE(item)

    if parentItem then
        if not parentItem.veiled then
            Comm.Send.HMSG_ITEM_UPDATE(item)
        end
    else
        UnveilNextItem()
    end

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

---Run func for each realted item, i.e. children or parent and other children of the parent.
---@param item SessionHost_Item
---@param includeThis boolean Run function for the argument item too.
---@param func fun(relatedItem:SessionHost_Item, isThis:boolean):boolean? Return true to break out after this callback.
function Host:DoForEachRelatedItem(item, includeThis, func)
    local childGuids = item.childGuids
    if item.parentGuid then
        local pitem = items[item.parentGuid] ---@type SessionHost_Item?
        if pitem then
            if func(pitem, false) then return end
            childGuids = pitem.childGuids
        end
    elseif includeThis then
        if func(item, true) then return end
    end
    if childGuids then
        for _, childGuid in ipairs(childGuids) do
            local isThis = childGuid == item.guid
            if not isThis or includeThis then
                local citem = items[childGuid]
                if citem then
                    if func(citem, isThis) then return end
                end
            end
        end
    end
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

local LibDialog = LibStub("LibDialog-1.1")

local confirmDialog = {
    show_while_dead = true,
    text = "IMPORT IS OLD\n!\n!",
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Start"],
            on_click = function(self, target)
                InitHost(target)
            end
        },
        {
            text = L["Abort"],
            on_click = function() end
        },
    },
}

---Start a new host session.
---@param target CommTarget
---@return SessionHost|nil
---@return string|nil errorMessage
function Host:Start(target)
    if Host.isRunning then
        return nil, L["A host session is already running."]
    end

    if Env.SessionClient.isRunning then
        return nil, L["A client session is already running."]
    end

    if target == "group" then
        if not IsInRaid() and not IsInGroup() then
            return nil, L["Host target group does not work outside of a group!"]
        end
        if not Env.Session.CanUnitStartSession(UnitName("player")) then
            return nil, L["You do not have permissions to start a session."]
        end
    elseif target ~= "self" then
        return nil, L["Invalid host target! Valid values are: %s and %s."]:format("group", "self")
    end

    local lastImportAge = Env.Database:TimeSinceLastImport()
    if lastImportAge > MAX_IMPORT_AGE then
        if not LibDialog:ActiveDialog(confirmDialog) then
            local dialog = LibDialog:Spawn(confirmDialog, target) ---@type any
            dialog.text:SetText(L["Last data import is %s old!\n\nAre you sure you want to start the session?"]:format(Env.ToShortTimeUnit(lastImportAge)));
        end
        return
    end

    LogDebug("Starting host session with target: ", target)
    InitHost(target)

    return Host
end

Env:RegisterSlashCommand("end", "", function(args)
    if not Host.isRunning then
        Env:PrintWarn(L["No session is running."])
        return
    end
    Env:PrintSuccess("Destroy host session...")
    Host:Destroy()
end)
