---@class AddonEnv
local Env = select(2, ...)
local L = Env:GetLocalization()

local Comm2 = Env.Session.Comm2
local LootStatus = Env.Session.LootCandidateStatus

local RESPONSE_GRACE_PERIOD = 3 -- Extra time given where the host will still accept responsed after expiration. Will not be reflected in UI. Just to account for comm latency.

local function LogDebug(...)
    Env:PrintDebug("Host:", ...)
end

---Create a simple unique identifier.
local function MakeGuid()
    return time() .. "-" .. string.format("%08x", math.floor(math.random(0, 0x7FFFFFFF)))
end

---@alias CommTarget "group"|"self"

---@class (exact) SessionHost_Candidate
---@field name string
---@field classId integer
---@field isOffline boolean
---@field leftGroup boolean
---@field isResponding boolean
---@field lastMessage number GetTime()

---@class (exact) SessionHost_ItemResponse
---@field candidate SessionHost_Candidate
---@field status LootCandidateStatus
---@field response LootResponse|nil
---@field roll integer|nil
---@field sanity integer|nil

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
---@field target CommTarget
---@field responses LootResponses
---@field candidates table<string, SessionHost_Candidate>
---@field isRunning boolean
---@field itemCount integer
---@field items table<string, SessionHost_Item>
---@field timers UniqueTimers
local Host = {
    timers = Env:NewUniqueTimers(),
}

Env.Session.Host = Host

---@param target CommTarget
local function InitHost(target)
    Host.guid = MakeGuid()
    Host.target = target
    Host.responses = Env.Session:CreateLootResponses()
    Host.candidates = {}
    Host.isRunning = true
    Host.itemCount = 0
    Host.items = {}

    Host:Setup()
end

local updateTimerKey = "mainUpdate"

function Host:Setup()
    Env:RegisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:RegisterEvent("GROUP_LEFT", self)

    Env:PrintSuccess("Started a new host session for " .. self.target)
    LogDebug("Session GUID", self.guid)

    Comm2:HostSetCurrentTarget(self.target)
    Comm2.Send.HMSG_SESSION_START(self)

    self:UpdateCandidateList()

    self.timers:StartUnique(updateTimerKey, 10, "TimerUpdate", self)

    -- TODO: Update responses if player db changes (points)
end

function Host:Destroy()
    if not self.isRunning then return end
    self.isRunning = false
    Host.guid = ""
    Host.timers:CancelAll()
    Env:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:UnregisterEvent("GROUP_LEFT", self)
    Comm2.Send.HMSG_SESSION_END()
end

function Host:TimerUpdate()
    if not self.isRunning then return end
    LogDebug("TimerUpdate")
    local nowgt = GetTime()

    -- Update candidates
    -- TODO: offline and leftgroup, only send if changed
    -- TODO: this is completely stupid, need a group update and a candidate update function, here candidates should update themself
    -- split UpdateCandidateList
    ---@type table<string, SessionHost_Candidate>
    local changedLootCandidates = {}
    local haveCandidateChange = false
    for _, candidate in pairs(self.candidates) do
        local oldIsResponding = candidate.isResponding
        candidate.isResponding = candidate.lastMessage - 25 < nowgt
        if oldIsResponding ~= candidate.isResponding then
            changedLootCandidates[candidate.name] = candidate
            haveCandidateChange = true
        end
    end

    if haveCandidateChange then
        Comm2.Send.HMSG_CANDIDATE_UPDATE(changedLootCandidates)
    end

    -- Restart timer
    self.timers:StartUnique(updateTimerKey, 10, "TimerUpdate", self)
end

---Set response, does NOT check if response was already set!
---@param item SessionHost_Item
---@param itemResponse SessionHost_ItemResponse
---@param response LootResponse
function Host:SetItemResponse(item, itemResponse, response)
    itemResponse.response = response
    itemResponse.roll = itemResponse.roll or item.roller:GetRoll()
    itemResponse.status = LootStatus.responded
    -- TODO: get sanity from DB
    itemResponse.sanity = response.isPointsRoll and 999 or nil
    if not item.veiled then
        Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
    end
end

Comm2.Events.CMSG_ATTENDANCE_CHECK:RegisterCallback(function(sender)
    local candidate = Host.candidates[sender]
    if not candidate then return end
    local update = not candidate.isResponding
    candidate.isResponding = true
    candidate.lastMessage = GetTime()
    if update then
        Comm2.Send.HMSG_CANDIDATE_UPDATE(candidate)
    end
end)

Comm2.Events.CMSG_ITEM_RECEIVED:RegisterCallback(function(sender, itemGuid)
    local candidate = Host.candidates[sender]
    if not candidate then return end
    local item = Host.items[itemGuid]
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
            Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
        end
    end
end)

Comm2.Events.CMSG_ITEM_RESPONSE:RegisterCallback(function(sender, itemGuid, responseId)
    local item = Host.items[itemGuid]
    if not item then
        Env:PrintError(sender .. " tried to respond to unknown item " .. itemGuid)
        return
    end
    if item.endTime < time() - RESPONSE_GRACE_PERIOD then
        Env:PrintError(sender .. " tried to respond to expired item " .. itemGuid)
        return
    end
    if item.parentGuid ~= nil then
        Env:PrintError(sender .. " tried to respond to child item " .. itemGuid)
        return
    end
    local itemResponse = item.responses[sender]
    if not itemResponse then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but candidate not known for that item")
        return
    end
    if itemResponse.response then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but already responded")
        return
    end
    local response = Host.responses:GetResponse(responseId)
    if not response then
        Env:PrintError(sender ..
            " tried to respond to item " .. itemGuid .. " but response id " .. responseId .. " invalid")
        return
    end
    Host:SetItemResponse(item, itemResponse, response)
end)

function Host:GROUP_LEFT()
    if not self.isRunning then return end
    if self.target == "group" then
        Env:PrintError("Session host destroyed because you left the group!")
        self:Destroy()
    end
end

function Host:GROUP_ROSTER_UPDATE()
    LogDebug("LootSessionHost GROUP_ROSTER_UPDATE")
    local tkey = "groupupdate"
    if self.timers:HasTimer(tkey) then return end
    LogDebug("Start UpdateCandidateList timer")
    self.timers:StartUnique(tkey, 5, "UpdateCandidateList", self)
end

---Create list of loot candidates, i.e. list of all raid members at this point in time.
---Players that leave the party will be kept in the list if an existing list is provided.
function Host:UpdateCandidateList()
    ---@type table<string, SessionHost_Candidate>
    local newList = {}
    local prefix = ""
    local changed = false
    ---@type table<string, SessionHost_Candidate>
    local changedLootCandidates = {}

    if self.target == "group" then
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

    if prefix == "" then
        local myName = UnitName("player")
        newList[myName] = {
            name = myName,
            classId = select(3, UnitClass("player")),
            isOffline = false,
            leftGroup = false,
            isResponding = false,
            lastMessage = 0,
        }
    else
        local numMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
        for i = 1, numMembers do
            local unit = prefix .. i
            local name = UnitName(unit)
            newList[name] = {
                name = name,
                classId = select(3, UnitClass(unit)),
                isOffline = UnitIsConnected(unit),
                leftGroup = false,
                isResponding = false,
                lastMessage = 0,
            }
        end
    end

    for oldName, oldEntry in pairs(self.candidates) do
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
            if oldEntry.isOffline ~= newEntry.isOffline then
                oldEntry.isOffline = newEntry.isOffline
                changed = true
                changedLootCandidates[oldName] = oldEntry
            end
        end
    end

    for newName, newEntry in pairs(newList) do
        if not self.candidates[newName] then
            self.candidates[newName] = newEntry
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
        Comm2.Send.HMSG_CANDIDATE_UPDATE(changedLootCandidates)
    end
end

------------------------------------------------------------------
--- Add Item
------------------------------------------------------------------

---Sets next item after the last awarded item to be unveiled.
function Host:UnveilNextItem()
    ---@type SessionHost_Item[]
    local orderedItem = {}

    for _, item in pairs(self.items) do
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
            Comm2.Send.HMSG_ITEM_UNVEIL(item.guid)
            if item.childGuids then
                for _, childGuid in ipairs(item.childGuids) do
                    local childItem = self.items[childGuid]
                    if childItem.veiled then
                        LogDebug("Unveil child item because parent was unveiled", childGuid)
                        childItem.veiled = false
                        Comm2.Send.HMSG_ITEM_UNVEIL(childItem.guid)
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

function Host:ItemStopRoll(guid)
    local item = self.items[guid]
    if not item then return end
    LogDebug("ItemStopRoll", guid, item.itemId)
    if item.status == "waiting" then
        item.status = "timeout"
        for _, itemResponse in pairs(item.responses) do
            if not itemResponse.response and itemResponse.status ~= LootStatus.unknown then
                itemResponse.status = LootStatus.responseTimeout
                if not item.veiled then
                    Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
                end
            end
        end
        Comm2.Send.HMSG_ITEM_ROLL_END(item.guid)
    end
end

---@param itemId integer
---@return boolean itemAdded
---@return string|nil errorMessage
function Host:ItemAdd(itemId)
    if not self.isRunning then
        return false, "session was already finished"
    end

    ---@type SessionHost_Item|nil
    local parentItem = nil
    for _, existingItem in pairs(self.items) do
        if existingItem.itemId == itemId then
            local parentGuid = existingItem.parentGuid
            if parentGuid then
                parentItem = self.items[parentGuid]
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
        for name, candidate in pairs(self.candidates) do
            candidateResponseList[name] = {
                candidate = candidate,
                status = LootStatus.sent,
            }
        end

        item = {
            guid = MakeGuid(),
            order = self.itemCount * 100,
            itemId = itemId,
            veiled = true,
            startTime = time(),
            endTime = time() + Env.settings.lootSession.timeout,
            status = "waiting",
            responses = candidateResponseList,
            roller = Env:NewUniqueRoller(),
        }

        self.timers:StartUnique(item.guid, Env.settings.lootSession.timeout, "ItemStopRoll", self)
    end

    LogDebug("ItemAdd", itemId, "have parent ", parentItem ~= nil, "guid:", item.guid)

    self.itemCount = self.itemCount + 1
    self.items[item.guid] = item
    self:UnveilNextItem()

    Comm2.Send.HMSG_ITEM_ANNOUNCE(item)

    self.timers:StartUnique(item.guid .. "ackcheck", 6, function(key)
        LogDebug("ItemAdd ackcheck", itemId, "guid:", item.guid)
        for _, itemResponse in pairs(item.responses) do
            if itemResponse.status == LootStatus.sent then
                itemResponse.status = LootStatus.unknown
                if not item.veiled then
                    Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemResponse)
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
