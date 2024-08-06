---@class AddonEnv
local Env = select(2, ...)
local L = Env:GetLocalization()

Env.Session.Host = {}

local Net = Env.Net
local Comm = Env.Session.Comm
local LootStatus = Env.Session.LootStatus

local function LogDebug(...)
    Env:PrintDebug("Host:", ...)
end

---Create a simple unique identifier.
local function MakeGUID()
    return time() .. "-" .. string.format("%08x", math.floor(math.random(0,0x7FFFFFFF)))
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
---@field duplicateGUIDs string[]|nil If duplicates of the item exist their guids will be in here.
---@field itemId integer
---@field veiled boolean Details are not sent to clients until item is unveiled.
---@field startTime integer
---@field endTime integer
---@field status "waiting"|"timeout"|"copy"
---@field roller UniqueRoller
---@field responses table<string, LootSessionHostItemClient>
---@field awardedTo string|nil

---@class (exact) LootSessionHost
---@field sessionGUID string
---@field target CommTarget
---@field responses LootResponses
---@field candidates table<string, LootCandidate>
---@field isFinished boolean
---@field itemCount integer
---@field items table<string, LootSessionHostItem>
---@field timers UniqueTimers
local LootSessionHost = {}
---@diagnostic disable-next-line: inject-field
LootSessionHost.__index = LootSessionHost

---@param target CommTarget
local function NewLootSessionHost(target)
    ---@type LootSessionHost
    local session = {
        sessionGUID = MakeGUID(),
        target = target,
        responses = Env.Session:CreateLootResponses(),
        candidates = {},
        isFinished = false,
        itemCount = 0,
        items = {},
        timers = Env:NewUniqueTimers(),
    }
    setmetatable(session, LootSessionHost)
    session:Setup()
    return session
end

local updateTimerKey = "mainUpdate"

function LootSessionHost:Setup()
    ---@class (exact) LSHostEndEvent
    ---@field RegisterCallback fun(self:LSHostEndEvent, cb:fun())
    ---@field Trigger fun(self:LSHostEndEvent)
    ---@diagnostic disable-next-line: inject-field
    self.OnSessionEnd = Env:NewEventEmitter()

    Env:RegisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:RegisterEvent("GROUP_LEFT", self)

    Env:PrintSuccess("Started a new host session for " .. self.target)
    LogDebug("Session GUID", self.sessionGUID)

    Net:RegisterObj(Comm.PREFIX, self, "OnMsgReceived")

    self:Broadcast(Comm.OpCodes.HMSG_SESSION, Comm:Packet_HtC_LootSession(self))
    self:UpdateCandidateList()

    self.timers:StartUnique(updateTimerKey, 10, "TimerUpdate", self)

    -- TODO: Update responses if player db changes (points)
end

function LootSessionHost:Destroy()
    if self.isFinished then return end
    self.isFinished = true
    Env:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    Env:UnregisterEvent("GROUP_LEFT", self)
    Net:UnregisterObj(Comm.PREFIX, self)
    self:Broadcast(Comm.OpCodes.HMSG_SESSION_END, self.sessionGUID)
    self.OnSessionEnd:Trigger()
end

function LootSessionHost:TimerUpdate()
    if self.isFinished then return end
    local nowgt = GetTime()

    -- Update candidates
    -- TODO: offline and leftgroup, only send if changed
    ---@type table<string, LootCandidate>
    local changedLootCandidates = {}
    for _, candidate in pairs(self.candidates) do
        local oldIsResponding = candidate.isResponding
        candidate.isResponding = candidate.lastMessage < nowgt - 25
        if oldIsResponding ~= candidate.isResponding then
            changedLootCandidates[candidate.name] = candidate
        end
    end

    local lcPacketList = Comm:Packet_LootCandidate_List(changedLootCandidates)
    self:Broadcast(Comm.OpCodes.HMSG_CANDIDATES_UPDATE, lcPacketList)

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
        self:Broadcast(Comm.OpCodes.HMSG_ITEM_RESPONSE_UPDATE,
            Comm:Packet_HtC_LootResponseUpdate(item.distributionGUID, itemClient))
    end
end

---@param prefix string
---@param sender string
---@param opcode OpCode
---@param data any
function LootSessionHost:OnMsgReceived(prefix, sender, opcode, data)
    if opcode < Comm.OpCodes.MAX_HMSG then return end

    LogDebug("Received client msg", sender, opcode)
    local candidate = self.candidates[sender]
    if not candidate then return end

    if opcode == Comm.OpCodes.CMSG_IM_HERE then
        local update = not candidate.isResponding
        candidate.isResponding = true
        candidate.lastMessage = GetTime()
        if update then
            self:Broadcast(Comm.OpCodes.HMSG_CANDIDATES_UPDATE, Comm:Packet_LootCandidate(candidate))
        end
    elseif opcode == Comm.OpCodes.CMSG_ITEM_RESPONSE then
        ---@cast data Packet_CtH_LootClientResponse
        local item = self.items[data.itemGuid]
        if not item then
            Env:PrintError(sender .. " tried to respond to unknown item " .. data.itemGuid)
            return
        end
        local itemClient = item.responses[sender]
        if not itemClient then
            Env:PrintError(sender .. " tried to respond to item " .. data.itemGuid .. " but candidate not known for that item")
            return
        end
        if itemClient.response then
            Env:PrintError(sender .. " tried to respond to item " .. data.itemGuid .. " but already responded")
            return
        end
        local response = self.responses:GetResponse(data.responseId)
        if not response then
            Env:PrintError(sender ..
                " tried to respond to item " .. data.itemGuid .. " but response id " .. data.responseId .. " invalid")
            return
        end
        self:SetItemResponse(item, itemClient, response)
    elseif opcode == Comm.OpCodes.CMSG_ITEM_ACK then
        ---@cast data string
        local item = self.items[data]
        if not item then
            Env:PrintError(sender .. " tried to respond to unknown item " .. data)
            return
        end
        local itemClient = item.responses[sender]
        if not itemClient then
            Env:PrintError(sender .. " tried to respond to item " .. data .. " but candidate client not known!")
            return
        end

        if itemClient.status == LootStatus.sent then
            itemClient.status = LootStatus.waitingForResponse
            if not item.veiled then
                self:Broadcast(Comm.OpCodes.HMSG_ITEM_RESPONSE_UPDATE,
                    Comm:Packet_HtC_LootResponseUpdate(item.distributionGUID, itemClient))
            end
        end
    end
end

---Send comm message to target channel.
---@param opcode OpCode
---@param data any
function LootSessionHost:Broadcast(opcode, data)
    if self.target == "self" then
        LogDebug("Sending broadcast whisper", opcode)
        Net:SendWhisper(Comm.PREFIX, UnitName("player"), opcode, data)
        return
    end

    local channel = ""
    if self.target == "group" then
        if IsInRaid() then
            channel = "RAID"
        elseif IsInGroup() then
            channel = "PARTY"
        else
            Env:PrintError("Tried to broadcast to group but not in a group! Ending session.")
            self:Destroy()
        end
    end

    LogDebug("Sending broadcast", channel, opcode)
    Net:Send(Comm.PREFIX, channel, opcode, data)
end

function LootSessionHost:GROUP_LEFT()
    if self.isFinished then return end
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
        if Env.settings.debug then
            LogDebug("Changed candidates:")
            for _, lc in pairs(changedLootCandidates) do
                LogDebug(" - ", lc.name)
            end
        end

        local lcPacketList = Comm:Packet_LootCandidate_List(changedLootCandidates)
        self:Broadcast(Comm.OpCodes.HMSG_CANDIDATES_UPDATE, lcPacketList)
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
        if not sessionItem.awardedTo then
            if sessionItem.veiled then
                LogDebug("Unveil item because it's the next to be awarded: ", sessionItem.distributionGUID, sessionItem.itemId)
                sessionItem.veiled = false
                self:Broadcast(Comm.OpCodes.HMSG_ITEM_ANNOUNCE, Comm:Packet_HtC_LootSessionItem(sessionItem))
            end
            return
        elseif sessionItem.veiled then
            LogDebug("Unveil item because already awarded: ", sessionItem.distributionGUID, sessionItem.itemId)
            sessionItem.veiled = false
            self:Broadcast(Comm.OpCodes.HMSG_ITEM_ANNOUNCE, Comm:Packet_HtC_LootSessionItem(sessionItem))
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
            if not itemClient.response and not itemClient.status == LootStatus.unknown then
                itemClient.status = LootStatus.responseTimeout
            end
        end
        if not lootItem.veiled then
            self:Broadcast(Comm.OpCodes.HMSG_ITEM_ANNOUNCE, Comm:Packet_HtC_LootSessionItem(lootItem))
        end
    end
end

---@param itemId integer
---@return boolean itemAdded
---@return string|nil errorMessage
function LootSessionHost:ItemAdd(itemId)
    if self.isFinished then
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
        parentItem.duplicateGUIDs = parentItem.duplicateGUIDs or {}

        lootItem = {
            distributionGUID = MakeGUID(),
            order = parentItem.order + #parentItem.duplicateGUIDs + 1,
            itemId = itemId,
            veiled = parentItem.veiled,
            startTime = parentItem.startTime,
            endTime = parentItem.endTime,
            status = "copy",
            responses = parentItem.responses,
            roller = parentItem.roller,
            parentGUID = parentItem.distributionGUID,
        }

        table.insert(parentItem.duplicateGUIDs, lootItem.distributionGUID)
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

    self:Broadcast(Comm.OpCodes.HMSG_ITEM_ANNOUNCE, Comm:Packet_HtC_LootSessionItem(lootItem))

    self.timers:StartUnique(lootItem.distributionGUID .. "ackcheck", 10, function(key)
        LogDebug("ItemAdd ackcheck", itemId, "guid:", lootItem.distributionGUID)
        for _, itemClient in pairs(lootItem.responses) do
            if not itemClient.response then
                itemClient.status = LootStatus.unknown
            end
        end
        if not lootItem.veiled then
            self:Broadcast(Comm.OpCodes.HMSG_ITEM_ANNOUNCE, Comm:Packet_HtC_LootSessionItem(lootItem))
        end
    end)

    return true
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

---@type LootSessionHost|nil
local hostSession = nil

---Start a new host session.
---@param target CommTarget
---@return string|nil errorMessage
function Env.Session.Host:Start(target)
    if hostSession and not hostSession.isFinished then
        return L["A host session is already running."]
    end
    if target == "group" then
        if not IsInRaid() and not IsInGroup() then
            return L["Host target group does not work outside of a group!"]
        end
    elseif target ~= "self" then
        return L["Invalid host target! Valid values are: %s and %s."]:format("group", "self")
    end
    LogDebug("Starting host session with target: ", target)
    hostSession = NewLootSessionHost(target)

    hostSession.OnSessionEnd:RegisterCallback(function()
        hostSession = nil
    end)
end

function Env.Session.Host:GetSession()
    return hostSession
end

Env:RegisterSlashCommand("host", L["Start a new loot session."], function(args)
    local target = args[1] or "group"
    local err = Env.Session.Host:Start(target)
    if err then
        Env:PrintError(err)
    end
end)

Env:RegisterSlashCommand("end", L["End hosting a loot session."], function(args)
    if not hostSession then
        Env:PrintWarn(L["No session is running."])
        return
    end
    Env:PrintSuccess("Destroy host session...")
    hostSession:Destroy()
end)

Env:RegisterSlashCommand("add", L["Add items to a session."], function(args)
    if not hostSession then
        Env:PrintWarn(L["No session is running."])
        return
    end
    for _, itemLink in ipairs(args) do
        local id = Env.Item:GetIdFromLink(itemLink)
        print(itemLink, id)
        if id then
            hostSession:ItemAdd(id)
        end
    end
end)
