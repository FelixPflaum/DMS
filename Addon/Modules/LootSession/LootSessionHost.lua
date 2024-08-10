---@class AddonEnv
local Env = select(2, ...)
local L = Env:GetLocalization()

local Comm2 = Env.Session.Comm2
local LootStatus = Env.Session.LootStatus

local RESPONSE_GRACE_PERIOD = 3 -- Extra time given where the host will still accept responsed after expiration. Will not be reflected in UI. Just to account for comm latency.

local function LogDebug(...)
    Env:PrintDebug("Host:", ...)
end

---Create a simple unique identifier.
local function MakeGUID()
    local g = time() .. "-" .. string.format("%08x", math.floor(math.random(0, 0x7FFFFFFF)))
    LogDebug("Creating GUID:", g)
    return g
end

---@alias CommTarget "group"|"self"

---@class (exact) LootCandidate
---@field name string
---@field classId integer
---@field isOffline boolean
---@field leftGroup boolean
---@field isResponding boolean
---@field lastMessage number GetTime()

---@class (exact) LootSessionHostItemClient
---@field candidate LootCandidate
---@field status LootClientStatus
---@field response LootResponse|nil
---@field roll integer|nil
---@field sanity integer|nil

---@class (exact) LootSessionHostItem
---@field distributionGUID string Unique id for that specific loot distribution.
---@field order integer For ordering items in the UI.
---@field parentGUID string|nil If this item is a duplicate this will be the guid of the main item, i.e. the one people respond to.
---@field childGUIDs string[]|nil If duplicates of the item exist their guids will be in here.
---@field itemId integer
---@field veiled boolean Details are not sent to clients until item is unveiled.
---@field startTime integer
---@field endTime integer
---@field status "waiting"|"timeout"|"child"
---@field roller UniqueRoller
---@field responses table<string, LootSessionHostItemClient>
---@field awardedTo string|nil

---@class (exact) LootSessionHost
---@field sessionGUID string
---@field target CommTarget
---@field responses LootResponses
---@field candidates table<string, LootCandidate>
---@field isRunning boolean
---@field itemCount integer
---@field items table<string, LootSessionHostItem>
---@field timers UniqueTimers
local LootSessionHost = {
    timers = Env:NewUniqueTimers(),
}

Env.Session.Host = LootSessionHost

---@param target CommTarget
local function InitHost(target)
    LootSessionHost.sessionGUID = MakeGUID()
    LootSessionHost.target = target
    LootSessionHost.responses = Env.Session:CreateLootResponses()
    LootSessionHost.candidates = {}
    LootSessionHost.isRunning = true
    LootSessionHost.itemCount = 0
    LootSessionHost.items = {}

    LootSessionHost:Setup()
end

local updateTimerKey = "mainUpdate"

function LootSessionHost:Setup()
    Env:RegisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:RegisterEvent("GROUP_LEFT", self)

    Env:PrintSuccess("Started a new host session for " .. self.target)
    LogDebug("Session GUID", self.sessionGUID)

    Comm2:HostSetCurrentTarget(self.target)
    Comm2.Send.HMSG_SESSION_START(self)

    self:UpdateCandidateList()

    self.timers:StartUnique(updateTimerKey, 10, "TimerUpdate", self)

    -- TODO: Update responses if player db changes (points)
end

function LootSessionHost:Destroy()
    if not self.isRunning then return end
    self.isRunning = false
    LootSessionHost.sessionGUID = ""
    LootSessionHost.timers:CancelAll()
    Env:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:UnregisterEvent("GROUP_LEFT", self)
    Comm2.Send.HMSG_SESSION_END()
end

function LootSessionHost:TimerUpdate()
    if not self.isRunning then return end
    LogDebug("TimerUpdate")
    local nowgt = GetTime()

    -- Update candidates
    -- TODO: offline and leftgroup, only send if changed
    -- TODO: this is completely stupid, need a group update and a candidate update function, here candidates should update themself
    -- split UpdateCandidateList
    ---@type table<string, LootCandidate>
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
---@param item LootSessionHostItem
---@param itemClient LootSessionHostItemClient
---@param response LootResponse
function LootSessionHost:SetItemResponse(item, itemClient, response)
    itemClient.response = response
    itemClient.roll = itemClient.roll or item.roller:GetRoll()
    itemClient.status = LootStatus.responded
    -- TODO: get sanity from DB
    itemClient.sanity = response.isPointsRoll and 999 or nil
    if not item.veiled then
        Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.distributionGUID, itemClient)
    end
end

Comm2.Events.CMSG_ATTENDANCE_CHECK:RegisterCallback(function(sender)
    local candidate = LootSessionHost.candidates[sender]
    if not candidate then return end
    local update = not candidate.isResponding
    candidate.isResponding = true
    candidate.lastMessage = GetTime()
    if update then
        Comm2.Send.HMSG_CANDIDATE_UPDATE(candidate)
    end
end)

Comm2.Events.CMSG_ITEM_RECEIVED:RegisterCallback(function(sender, itemGuid)
    local candidate = LootSessionHost.candidates[sender]
    if not candidate then return end
    local item = LootSessionHost.items[itemGuid]
    if not item then
        Env:PrintError(sender .. " tried to respond to unknown item " .. itemGuid)
        return
    end
    local itemClient = item.responses[sender]
    if not itemClient then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but candidate client not known!")
        return
    end
    if itemClient.status == LootStatus.sent then
        itemClient.status = LootStatus.waitingForResponse
        if not item.veiled then
            Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(item.distributionGUID, itemClient)
        end
    end
end)

Comm2.Events.CMSG_ITEM_RESPONSE:RegisterCallback(function(sender, itemGuid, responseId)
    local item = LootSessionHost.items[itemGuid]
    if not item then
        Env:PrintError(sender .. " tried to respond to unknown item " .. itemGuid)
        return
    end
    if item.endTime < time() - RESPONSE_GRACE_PERIOD then
        Env:PrintError(sender .. " tried to respond to expired item " .. itemGuid)
        return
    end
    if item.parentGUID ~= nil then
        Env:PrintError(sender .. " tried to respond to child item " .. itemGuid)
        return
    end
    local itemClient = item.responses[sender]
    if not itemClient then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but candidate not known for that item")
        return
    end
    if itemClient.response then
        Env:PrintError(sender .. " tried to respond to item " .. itemGuid .. " but already responded")
        return
    end
    local response = LootSessionHost.responses:GetResponse(responseId)
    if not response then
        Env:PrintError(sender ..
            " tried to respond to item " .. itemGuid .. " but response id " .. responseId .. " invalid")
        return
    end
    LootSessionHost:SetItemResponse(item, itemClient, response)
end)

function LootSessionHost:GROUP_LEFT()
    if not self.isRunning then return end
    if self.target == "group" then
        Env:PrintError("Session host destroyed because you left the group!")
        self:Destroy()
    end
end

function LootSessionHost:GROUP_ROSTER_UPDATE()
    LogDebug("LootSessionHost GROUP_ROSTER_UPDATE")
    local tkey = "groupupdate"
    if self.timers:HasTimer(tkey) then return end
    LogDebug("Start UpdateCandidateList timer")
    self.timers:StartUnique(tkey, 5, "UpdateCandidateList", self)
end

---Create list of loot candidates, i.e. list of all raid members at this point in time.
---Players that leave the party will be kept in the list if an existing list is provided.
function LootSessionHost:UpdateCandidateList()
    ---@type table<string, LootCandidate>
    local newList = {}
    local prefix = ""
    local changed = false
    ---@type table<string, LootCandidate>
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
function LootSessionHost:UnveilNextItem()
    ---@type LootSessionHostItem[]
    local orderedItem = {}

    for _, sessionItem in pairs(self.items) do
        table.insert(orderedItem, sessionItem)
    end

    table.sort(orderedItem, function(a, b)
        return a.order < b.order
    end)

    for _, sessionItem in ipairs(orderedItem) do
        if not sessionItem.veiled then
            if not sessionItem.awardedTo then
                LogDebug("Last unveiled item not yet awarded, not unveiling another.")
                return
            end
        else
            LogDebug("Unveil item: ", sessionItem.distributionGUID, sessionItem.itemId)
            sessionItem.veiled = false
            Comm2.Send.HMSG_ITEM_UNVEIL(sessionItem.distributionGUID)
            if sessionItem.childGUIDs then
                for _, childGUID in ipairs(sessionItem.childGUIDs) do
                    local childItem = self.items[childGUID]
                    if childItem.veiled then
                        LogDebug("Unveil child item because parent was unveiled", childGUID)
                        childItem.veiled = false
                        Comm2.Send.HMSG_ITEM_UNVEIL(childItem.distributionGUID)
                    end
                end
            end

            if not sessionItem.awardedTo then
                LogDebug("Unveiled item is the next to be awarded, not unveiling more.")
                return
            end
        end
    end
end

function LootSessionHost:ItemStopRoll(guid)
    local lootItem = self.items[guid]
    if not lootItem then return end
    LogDebug("ItemStopRoll", guid, lootItem.itemId)
    if lootItem.status == "waiting" then
        lootItem.status = "timeout"
        for _, itemClient in pairs(lootItem.responses) do
            if not itemClient.response and itemClient.status ~= LootStatus.unknown then
                itemClient.status = LootStatus.responseTimeout
                if not lootItem.veiled then
                    Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(lootItem.distributionGUID, itemClient)
                end
            end
        end
        Comm2.Send.HMSG_ITEM_ROLL_END(lootItem.distributionGUID)
    end
end

---@param itemId integer
---@return boolean itemAdded
---@return string|nil errorMessage
function LootSessionHost:ItemAdd(itemId)
    if not self.isRunning then
        return false, "session was already finished"
    end

    ---@type LootSessionHostItem|nil
    local parentItem = nil
    for _, existingItem in pairs(self.items) do
        if existingItem.itemId == itemId then
            local parentGuid = existingItem.parentGUID
            if parentGuid then
                parentItem = self.items[parentGuid]
                break
            end
            parentItem = existingItem
        end
    end

    ---@type LootSessionHostItem
    local lootItem

    if parentItem then
        parentItem.childGUIDs = parentItem.childGUIDs or {}

        lootItem = {
            distributionGUID = MakeGUID(),
            order = parentItem.order + #parentItem.childGUIDs + 1,
            itemId = itemId,
            veiled = parentItem.veiled,
            startTime = parentItem.startTime,
            endTime = parentItem.endTime,
            status = "child",
            responses = parentItem.responses,
            roller = parentItem.roller,
            parentGUID = parentItem.distributionGUID,
        }

        table.insert(parentItem.childGUIDs, lootItem.distributionGUID)
    else
        ---@type table<string, LootSessionHostItemClient>
        local candidateResponseList = {}
        for name, candidate in pairs(self.candidates) do
            candidateResponseList[name] = {
                candidate = candidate,
                status = LootStatus.sent,
            }
        end

        lootItem = {
            distributionGUID = MakeGUID(),
            order = self.itemCount * 100,
            itemId = itemId,
            veiled = true,
            startTime = time(),
            endTime = time() + Env.settings.lootSession.timeout,
            status = "waiting",
            responses = candidateResponseList,
            roller = Env:NewUniqueRoller(),
        }

        self.timers:StartUnique(lootItem.distributionGUID, Env.settings.lootSession.timeout, "ItemStopRoll", self)
    end

    LogDebug("ItemAdd", itemId, "have parent ", parentItem ~= nil, "guid:", lootItem.distributionGUID)

    self.itemCount = self.itemCount + 1
    self.items[lootItem.distributionGUID] = lootItem
    self:UnveilNextItem()

    Comm2.Send.HMSG_ITEM_ANNOUNCE(lootItem)

    self.timers:StartUnique(lootItem.distributionGUID .. "ackcheck", 6, function(key)
        LogDebug("ItemAdd ackcheck", itemId, "guid:", lootItem.distributionGUID)
        for _, itemClient in pairs(lootItem.responses) do
            if itemClient.status == LootStatus.sent then
                itemClient.status = LootStatus.unknown
                if not lootItem.veiled then
                    Comm2.Send.HMSG_ITEM_RESPONSE_UPDATE(lootItem.distributionGUID, itemClient)
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
---@return LootSessionHost|nil
---@return string|nil errorMessage
function LootSessionHost:Start(target)
    if LootSessionHost.isRunning then
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

    return LootSessionHost
end

Env:RegisterSlashCommand("end", L["End hosting a loot session."], function(args)
    if not LootSessionHost.isRunning then
        Env:PrintWarn(L["No session is running."])
        return
    end
    Env:PrintSuccess("Destroy host session...")
    LootSessionHost:Destroy()
end)
