---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Net = Env.Net

local COMM_SESSION_PREFIX = "DMSS"
local COMM_VERSION = 3

---@enum Opcode
local OPCODES = {
    HMSG_SESSION_START = 1,
    HMSG_SESSION_END = 2,
    HMSG_CANDIDATE_UPDATE = 3,
    HMSG_ITEM_ANNOUNCE = 4,
    HMSG_ITEM_RESPONSE_UPDATE = 5,
    HMSG_CANDIDATE_STATUS_UPDATE = 6,
    HMSG_ITEM_ROLL_END = 7,
    HMSG_ITEM_AWARD_UPDATE = 8,
    HMSG_KEEPALIVE = 9,
    HMSG_SESSION_START_RESEND = 10,
    HMSG_ITEM_UPDATE = 11,

    MAX_HMSG = 99,

    CMSG_ATTENDANCE_CHECK = 100,
    CMSG_ITEM_RECEIVED = 101,
    CMSG_ITEM_RESPONSE = 102,
    CMSG_RESEND_START = 103,

    MAX_CMSG = 199,

    CBMSG_ITEM_CURRENTLY_EQUIPPED = 200,
}

---@type table<integer,string>
local OPCODE_NAMES = {}
for key, num in pairs(OPCODES) do OPCODE_NAMES[num] = key end

---@param opcode Opcode
local function LookupOpcodeName(opcode)
    return OPCODE_NAMES[opcode]
end

local messageHandler = {} ---@type table<Opcode,fun(data:any, sender:string)>
local messageFilter = {} ---@type table<Opcode,(fun(channel:string, sender:string, opcode:Opcode, data:any):boolean)|nil>
local batchTimers = Env:NewUniqueTimers()
local hostCommTarget = "group" ---@type CommTarget
local clientHostName = ""
local reconnectMsgBuffer = nil ---@type {src:string,buf:{channel:string, sender:string, opcode:Opcode, data:any}[]}|nil
local lastReceived = {} ---@type table<string,number> -- <sender, GetTime()>
local blockedVersionMismatch = {} ---@type table<string,boolean> -- <sender, hasDifferentVersion>

---@class (static) CommLogEntrySend
---@field timestamp integer
---@field type string
---@field opcode Opcode
---@field opcodeStr string
---@field data any
---@field sendSize integer

---@class (static) CommLogEntryReceive
---@field timestamp integer
---@field sender string
---@field opcode Opcode
---@field opcodeStr string
---@field data any
---@field recvSize integer

---@class (static) CommLog
---@field logtype "commlog"
---@field timestamp integer
---@field sendlog CommLogEntrySend[]
---@field receivelog CommLogEntryReceive[]

local commlog = nil ---@type CommLog|nil

---@param channel string
---@param sender string
---@param opcode Opcode
---@param data any
---@param recvSize integer
local function HandleMessage(channel, sender, opcode, data, recvSize)
    if not messageHandler[opcode] then
        Env:PrintError(L["Received unhandled opcode %s from %s"]:format(LookupOpcodeName(opcode), sender))
        return
    end
    Env:PrintDebug("Comm received:", LookupOpcodeName(opcode))
    Env:PrintVerbose(data)

    if commlog then
        local newEntry = { ---@type CommLogEntryReceive
            timestamp = time(),
            sender = sender,
            opcode = opcode,
            opcodeStr = LookupOpcodeName(opcode),
            data = data,
            recvSize = recvSize,
        }
        table.insert(commlog.receivelog, newEntry)
    end

    local now = GetTime()
    lastReceived[sender] = now
    for k, v in pairs(lastReceived) do
        if now - v > 600 then
            lastReceived[k] = nil
        end
    end

    -- Buffer all packets except the resend start packet.
    if opcode ~= OPCODES.HMSG_SESSION_START_RESEND and reconnectMsgBuffer and reconnectMsgBuffer.src == sender then
        Env:PrintDebug("Buffering msg from", sender, LookupOpcodeName(opcode))
        table.insert(reconnectMsgBuffer.buf, {
            channel = channel,
            sender = sender,
            opcode = opcode,
            data = data,
        })
        return
    end

    if messageFilter[opcode] and not messageFilter[opcode](channel, sender, opcode, data) then
        return
    end
    messageHandler[opcode](data, sender)
end
Net:Register(COMM_SESSION_PREFIX, HandleMessage)

---@class CommSender
local Sender = {}
---@class CommEvents
local Events = {}

---@class SessionComm
local Comm = {
    COMM_VERSION = COMM_VERSION,
    OPCODES = OPCODES,
    OPCODE_NAMES = OPCODE_NAMES,
    LookupOpcodeName = LookupOpcodeName,
    Events = Events,
    Send = Sender,
}

Env.SessionComm = Comm

---Set the target for host communication.
---@param target CommTarget
function Comm:HostSetCurrentTarget(target)
    hostCommTarget = target
end

---Set the hostname the client is listening to.
---@param name string?
function Comm:ClientSetAllowedHost(name)
    clientHostName = name or ""
    reconnectMsgBuffer = nil
end

---Get how many seconds ago the sender sent us the last message.
---@param senderName string
---@return number? secondsAgo How many seconds ago the last message was received, nil if no message received.
function Comm.GetLastReceivedAgo(senderName)
    if lastReceived[senderName] then
        return GetTime() - lastReceived[senderName]
    end
end

--------------------------------------------------------------------------
--- Host To Client
--------------------------------------------------------------------------

local lastHostBroadcastSent = 0 -- GetTime()

local function LogDebugHtC(...)
    Env:PrintDebug("Comm Host:", ...)
end

---Get GetTime() stamp of the last broadcast sent to clients. This is only available on the host.
function Comm.GetLastHostBroadcastSent()
    return lastHostBroadcastSent
end

---@param opcode Opcode
---@param data any
---@param isLowPriority boolean|nil
local function SendToClients(opcode, data, isLowPriority)
    lastHostBroadcastSent = GetTime()

    local priority = isLowPriority and "BULK" or "NORMAL"

    if hostCommTarget == "self" then
        LogDebugHtC("Sending whisper", LookupOpcodeName(opcode))
        Net:SendWhisper(COMM_SESSION_PREFIX, UnitName("player"), opcode, priority, data)
        return
    end

    local channel = ""
    if hostCommTarget == "group" then
        if IsInRaid() then
            channel = "RAID"
        elseif IsInGroup() then
            channel = "PARTY"
        else
            Env:PrintError("Tried to broadcast to group but not in a group!")
            return false
        end
    end

    LogDebugHtC("Sending broadcast", channel, LookupOpcodeName(opcode))
    local sendSize = Net:Send(COMM_SESSION_PREFIX, channel, opcode, priority, data)
    if commlog then
        local newEntry = { ---@type CommLogEntrySend
            timestamp = time(),
            type = "host_broadcast " .. priority,
            opcode = opcode,
            opcodeStr = LookupOpcodeName(opcode),
            data = data,
            sendSize = sendSize,
        }
        table.insert(commlog.sendlog, newEntry)
    end
end

---@param channel string
---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedOnClient(channel, sender, opcode, data)
    if opcode >= OPCODES.MAX_HMSG then
        return false
    end

    if blockedVersionMismatch[sender] then
        return false
    end

    -- Filter all but session start here if session is not from currently set host.
    if opcode ~= OPCODES.HMSG_SESSION_START and sender ~= clientHostName and sender ~= UnitName("player") then
        if clientHostName == "" then
            LogDebugHtC("Received", LookupOpcodeName(opcode), "from", sender, "while not having a host")
            if Env.Session.CanUnitStartSession(sender) then
                Env:PrintWarn(L["A loot session from %s is running, trying to reconnect..."]:format(sender))
                reconnectMsgBuffer = { src = sender, buf = {} }
                Comm.Send.CMSG_RESEND_START()
                HandleMessage(channel, sender, opcode, data, 0) -- Make it buffer this msg
                return false
            end
        end
        LogDebugHtC("Received", LookupOpcodeName(opcode), "from", sender, "who isn't the current host")
        return false
    end

    if channel ~= "WHISPER" and channel ~= "RAID" and channel ~= "PARTY" then
        return false
    end

    return true
end

-- HMSG_SESSION_START
do
    ---@class (exact) Packet_HMSG_SESSION_START
    ---@field guid string
    ---@field commVersion integer
    ---@field responses LootResponse[]
    ---@field pointsMinForRoll integer
    ---@field pointsMaxRange integer

    ---@param guid string
    ---@param responses LootResponse[]
    ---@param pointsMinRoll integer
    ---@param pointsMaxRange integer
    function Sender.HMSG_SESSION_START(guid, responses, pointsMinRoll, pointsMaxRange)
        local p = { ---@type Packet_HMSG_SESSION_START
            guid = guid,
            commVersion = COMM_VERSION,
            responses = responses,
            pointsMinForRoll = pointsMinRoll,
            pointsMaxRange = pointsMaxRange,
        }
        SendToClients(OPCODES.HMSG_SESSION_START, p)
    end

    ---This event will always fire regardless of who sends it!
    ---@class CommEvent_HMSG_SESSION_START
    ---@field RegisterCallback fun(self:CommEvent_HMSG_SESSION_START, cb:fun(data:Packet_HMSG_SESSION_START, responses:LootResponses, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_SESSION_START, data:Packet_HMSG_SESSION_START, responses:LootResponses, sender:string)
    Events.HMSG_SESSION_START = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_SESSION_START] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_SESSION_START] = function(data, sender)
        ---@cast data Packet_HMSG_SESSION_START
        if COMM_VERSION ~= data.commVersion then
            Env:PrintError(L["Received session from %s with API version %d"]:format(sender, data.commVersion))
            if COMM_VERSION < data.commVersion then
                Env:PrintError(L["Your addon version is outdated! Your API version: %d"]:format(COMM_VERSION))
            else
                Env:PrintError(L["Host's addon version is outdated! Your API version: %d"]:format(COMM_VERSION))
            end
            blockedVersionMismatch[sender] = true
            return
        end
        local rebuiltResponses = Env.Session.CreateLootClientResponsesFromComm(data.responses)
        Events.HMSG_SESSION_START:Trigger(data, rebuiltResponses, sender)
    end
end

-- HMSG_SESSION_END
do
    function Sender.HMSG_SESSION_END()
        SendToClients(OPCODES.HMSG_SESSION_END)
    end

    ---@class CommEvent_HMSG_SESSION_END
    ---@field RegisterCallback fun(self:CommEvent_HMSG_SESSION_END, cb:fun(sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_SESSION_END, sender:string)
    Events.HMSG_SESSION_END = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_SESSION_END] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_SESSION_END] = function(data, sender)
        Events.HMSG_SESSION_END:Trigger(sender)
    end
end

-- HMSG_CANDIDATE_UPDATE

---@param candidate SessionHost_Candidate
local function PackLootCandidateStatus(candidate)
    local status = 0
    if candidate.leftGroup then
        status = status + 0x2
    end
    if candidate.isResponding then
        status = status + 0x4
    end
    return status
end

---@param candidate {leftGroup:boolean, isResponding:boolean}
---@param status integer
local function UnpackLootCandidateStatus(candidate, status)
    candidate.leftGroup = bit.band(status, 0x2) > 0
    candidate.isResponding = bit.band(status, 0x4) > 0
end

---@param candidate SessionHost_Candidate
local function PackLootCandidate(candidate)
    local data = { ---@type PackedLootCandidate
        n = candidate.name,
        c = candidate.classId,
        s = PackLootCandidateStatus(candidate),
        cp = candidate.currentPoints,
    }
    return data
end

do
    ---@class (exact) PackedLootCandidate
    ---@field n string
    ---@field c integer
    ---@field s integer
    ---@field cp integer

    ---@class (exact) Packet_HMSG_CANDIDATE_UPDATE
    ---@field name string
    ---@field classId integer
    ---@field leftGroup boolean
    ---@field isResponding boolean
    ---@field currentPoints integer

    ---@param candidates table<string,SessionHost_Candidate>|SessionHost_Candidate
    function Sender.HMSG_CANDIDATE_UPDATE(candidates)
        ---@type PackedLootCandidate[]
        local lcPackList = {}
        if candidates.name then
            table.insert(lcPackList, PackLootCandidate(candidates))
        else
            for _, lc in pairs(candidates) do
                table.insert(lcPackList, PackLootCandidate(lc))
            end
        end
        SendToClients(OPCODES.HMSG_CANDIDATE_UPDATE, lcPackList)
    end

    ---@class CommEvent_HMSG_CANDIDATE_UPDATE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_CANDIDATE_UPDATE, cb:fun(lcs:Packet_HMSG_CANDIDATE_UPDATE[], sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_CANDIDATE_UPDATE, lcs:Packet_HMSG_CANDIDATE_UPDATE[], sender:string)
    Events.HMSG_CANDIDATE_UPDATE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_CANDIDATE_UPDATE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_CANDIDATE_UPDATE] = function(data, sender)
        ---@cast data PackedLootCandidate[]
        local lcs = {} ---@type Packet_HMSG_CANDIDATE_UPDATE[]
        for _, packedLc in ipairs(data) do
            ---@type Packet_HMSG_CANDIDATE_UPDATE
            local lc = {
                name = packedLc.n,
                classId = packedLc.c,
                leftGroup = false,
                isResponding = false,
                currentPoints = packedLc.cp,
            }
            UnpackLootCandidateStatus(lc, packedLc.s)
            table.insert(lcs, lc)
        end
        Events.HMSG_CANDIDATE_UPDATE:Trigger(lcs, sender)
    end
end

-- HMSG_CANDIDATE_STATUS_UPDATE

do
    ---@class (exact) PackedLootCandidateStatus
    ---@field n string
    ---@field s integer

    ---@class (exact) Packet_HMSG_CANDIDATE_STATUS_UPDATE
    ---@field name string
    ---@field leftGroup boolean
    ---@field isResponding boolean

    local queued = {} ---@type PackedLootCandidateStatus[]

    ---@param candidate SessionHost_Candidate
    local function PackLootCandidateStatusUpdate(candidate)
        local data = { ---@type PackedLootCandidateStatus
            n = candidate.name,
            s = PackLootCandidateStatus(candidate),
        }
        return data
    end

    local function SendQueued()
        local packet = {} ---@type PackedLootCandidateStatus[]
        for _, v in ipairs(queued) do
            table.insert(packet, v)
        end
        wipe(queued)
        LogDebugHtC("Sending batched HMSG_CANDIDATE_STATUS_UPDATE, entries:", #packet)
        SendToClients(OPCODES.HMSG_CANDIDATE_STATUS_UPDATE, packet, true)
    end

    ---@param candidates table<string,SessionHost_Candidate>|SessionHost_Candidate
    function Sender.HMSG_CANDIDATE_STATUS_UPDATE(candidates)
        ---@type PackedLootCandidateStatus[]
        local lcPackList = {}
        if candidates.name then
            table.insert(lcPackList, PackLootCandidateStatusUpdate(candidates))
        else
            for _, lc in pairs(candidates) do
                table.insert(lcPackList, PackLootCandidateStatusUpdate(lc))
            end
        end
        for _, v in ipairs(lcPackList) do
            table.insert(queued, v)
        end
        batchTimers:StartUnique("HMSG_CANDIDATE_STATUS_UPDATE", 3, SendQueued, nil, true)
    end

    ---@class CommEvent_HMSG_CANDIDATE_STATUS_UPDATE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_CANDIDATE_STATUS_UPDATE, cb:fun(lcs:Packet_HMSG_CANDIDATE_STATUS_UPDATE[], sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_CANDIDATE_STATUS_UPDATE, lcs:Packet_HMSG_CANDIDATE_STATUS_UPDATE[], sender:string)
    Events.HMSG_CANDIDATE_STATUS_UPDATE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_CANDIDATE_STATUS_UPDATE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_CANDIDATE_STATUS_UPDATE] = function(data, sender)
        ---@cast data PackedLootCandidateStatus[]
        local lcs = {} ---@type Packet_HMSG_CANDIDATE_STATUS_UPDATE[]
        for _, packedLc in ipairs(data) do
            ---@type Packet_HMSG_CANDIDATE_STATUS_UPDATE
            local lc = {
                name = packedLc.n,
                leftGroup = false,
                isResponding = false,
            }
            UnpackLootCandidateStatus(lc, packedLc.s)
            table.insert(lcs, lc)
        end
        Events.HMSG_CANDIDATE_STATUS_UPDATE:Trigger(lcs, sender)
    end
end

-- HMSG_ITEM_ANNOUNCE

---@param item SessionHost_Item
local function MakeItemAnnouncePacket(item)
    local pitem ---@type Packet_HMSG_ITEM_ANNOUNCE|Packet_HMSG_ITEM_ANNOUNCE_ChildItem
    if not item.parentGuid then
        pitem = { ---@type Packet_HMSG_ITEM_ANNOUNCE
            guid = item.guid,
            order = item.order,
            itemId = item.itemId,
            veiled = item.veiled,
            startTime = item.startTime,
            endTime = item.endTime,
        }
    else
        pitem = { ---@type Packet_HMSG_ITEM_ANNOUNCE_ChildItem
            guid = item.guid,
            parentGuid = item.parentGuid,
            order = item.order,
        }
    end
    return pitem
end

do
    ---@class (exact) Packet_HMSG_ITEM_ANNOUNCE
    ---@field guid string
    ---@field order integer
    ---@field itemId integer
    ---@field veiled boolean
    ---@field startTime integer
    ---@field endTime integer

    ---@class (exact) Packet_HMSG_ITEM_ANNOUNCE_ChildItem
    ---@field guid string
    ---@field parentGuid string
    ---@field order integer

    ---@alias HMSG_ITEM_ANNOUNCE_PacketFormat (Packet_HMSG_ITEM_ANNOUNCE|Packet_HMSG_ITEM_ANNOUNCE_ChildItem)[]

    local queued = {} ---@type SessionHost_Item[]

    local function SendQueued()
        local packet = {} ---@type HMSG_ITEM_ANNOUNCE_PacketFormat
        local itemCount = 0
        for _, item in pairs(queued) do
            table.insert(packet, MakeItemAnnouncePacket(item))
            itemCount = itemCount + 1
        end
        wipe(queued)
        LogDebugHtC("Sending batched HMSG_ITEM_ANNOUNCE, items:", itemCount)
        SendToClients(OPCODES.HMSG_ITEM_ANNOUNCE, packet)
    end

    ---@param item SessionHost_Item
    function Sender.HMSG_ITEM_ANNOUNCE(item)
        table.insert(queued, item)
        -- Batch window can be short, it's just to batch multiple items added at the same time.
        batchTimers:StartUnique("HMSG_ITEM_ANNOUNCE", 0.1, SendQueued, nil, true)
    end

    ---@class CommEvent_HMSG_ITEM_ANNOUNCE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_ANNOUNCE, cb:fun(data:Packet_HMSG_ITEM_ANNOUNCE, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_ANNOUNCE, data:Packet_HMSG_ITEM_ANNOUNCE, sender:string)
    Events.HMSG_ITEM_ANNOUNCE = Env:NewEventEmitter()

    ---@class CommEvent_HMSG_ITEM_ANNOUNCE_ChildItem
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_ANNOUNCE_ChildItem, cb:fun(data:Packet_HMSG_ITEM_ANNOUNCE_ChildItem, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_ANNOUNCE_ChildItem, data:Packet_HMSG_ITEM_ANNOUNCE_ChildItem, sender:string)
    Events.HMSG_ITEM_ANNOUNCE_ChildItem = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_ANNOUNCE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_ANNOUNCE] = function(data, sender)
        ---@cast data HMSG_ITEM_ANNOUNCE_PacketFormat
        for _, individual in ipairs(data) do
            if individual.parentGuid then
                ---@cast individual Packet_HMSG_ITEM_ANNOUNCE_ChildItem
                Events.HMSG_ITEM_ANNOUNCE_ChildItem:Trigger(individual, sender)
            else
                ---@cast individual Packet_HMSG_ITEM_ANNOUNCE
                Events.HMSG_ITEM_ANNOUNCE:Trigger(individual, sender)
            end
        end
    end
end

-- HMSG_SESSION_START_RESEND
do
    ---@class Packet_HMSG_SESSION_START_RESEND
    ---@field startPck Packet_HMSG_SESSION_START
    ---@field candidates PackedLootCandidate[]
    ---@field items (Packet_HMSG_ITEM_ANNOUNCE|Packet_HMSG_ITEM_ANNOUNCE_ChildItem)[]

    ---@param guid string
    ---@param responses LootResponse[]
    ---@param pointsMinRoll integer
    ---@param pointsMaxRange integer
    ---@param candidates table<string,SessionHost_Candidate>
    ---@param items table<string, SessionHost_Item>
    function Sender.HMSG_SESSION_START_RESEND(guid, responses, pointsMinRoll, pointsMaxRange, candidates, items)
        local p = { ---@type Packet_HMSG_SESSION_START_RESEND
            startPck = {
                guid = guid,
                commVersion = COMM_VERSION,
                responses = responses,
                pointsMinForRoll = pointsMinRoll,
                pointsMaxRange = pointsMaxRange,
            },
            candidates = {},
            items = {},
        }
        for _, v in pairs(candidates) do
            table.insert(p.candidates, PackLootCandidate(v))
        end
        for _, v in pairs(items) do
            table.insert(p.items, MakeItemAnnouncePacket(v))
        end
        SendToClients(OPCODES.HMSG_SESSION_START_RESEND, p)
    end

    messageFilter[OPCODES.HMSG_SESSION_START_RESEND] = function(channel, sender, opcode, data)
        if not reconnectMsgBuffer or reconnectMsgBuffer.src ~= sender then
            return false
        end
        if channel ~= "RAID" and channel ~= "PARTY" then
            return false
        end
        return true
    end
    messageHandler[OPCODES.HMSG_SESSION_START_RESEND] = function(data, sender)
        ---@cast data Packet_HMSG_SESSION_START_RESEND
        if not reconnectMsgBuffer then return end

        local channel = "RAID" -- TODO: placeholder
        local msgbuf = reconnectMsgBuffer
        reconnectMsgBuffer = nil

        HandleMessage(channel, sender, OPCODES.HMSG_SESSION_START, data.startPck, 0)
        HandleMessage(channel, sender, OPCODES.HMSG_CANDIDATE_UPDATE, data.candidates, 0)

        HandleMessage(channel, sender, OPCODES.HMSG_ITEM_ANNOUNCE, data.items, 0)

        for _, buffered in ipairs(msgbuf.buf) do
            HandleMessage(buffered.channel, buffered.sender, buffered.opcode, buffered.data, 0)
        end
    end
end

-- HMSG_ITEM_RESPONSE_UPDATE
do
    ---@class (exact) PackedSessionItemClient
    ---@field candidate string
    ---@field statusId integer
    ---@field responseId? integer
    ---@field roll? integer

    ---@alias Packet_HMSG_ITEM_RESPONSE_UPDATE table<string,PackedSessionItemClient[]>

    ---@type table<string,table<string,PackedSessionItemClient>>
    local nextSend = {}

    local function SendResponseUpdateBatch()
        local packet = {} ---@type Packet_HMSG_ITEM_RESPONSE_UPDATE
        local itemCount = 0
        local respCount = 0
        for itemGuid, candidateData in pairs(nextSend) do
            packet[itemGuid] = {}
            itemCount = itemCount + 1
            for _, packedClientData in pairs(candidateData) do
                respCount = respCount + 1
                table.insert(packet[itemGuid], packedClientData)
            end
        end
        wipe(nextSend)
        LogDebugHtC("Sending batched HMSG_ITEM_RESPONSE_UPDATE, items:", itemCount, "responses:", respCount)
        SendToClients(OPCODES.HMSG_ITEM_RESPONSE_UPDATE, packet)
    end

    ---@param itemGuid string
    ---@param clientData SessionHost_ItemResponse
    ---@param doNotBatch? boolean Do not batch and send immediately.
    function Sender.HMSG_ITEM_RESPONSE_UPDATE(itemGuid, clientData, doNotBatch)
        local packedClient = { ---@type PackedSessionItemClient
            candidate = clientData.candidate.name,
            statusId = clientData.status.id,
        }
        if clientData.response then packedClient.responseId = clientData.response.id end
        if clientData.roll then packedClient.roll = clientData.roll end

        if doNotBatch then
            ---@type Packet_HMSG_ITEM_RESPONSE_UPDATE
            local singelTab = { [itemGuid] = { packedClient } }
            SendToClients(OPCODES.HMSG_ITEM_RESPONSE_UPDATE, singelTab)
            return
        end

        nextSend[itemGuid] = nextSend[itemGuid] or {}
        nextSend[itemGuid][clientData.candidate.name] = packedClient

        batchTimers:StartUnique("HMSG_ITEM_RESPONSE_UPDATE", 2, SendResponseUpdateBatch, nil, true)
    end

    ---@param item SessionHost_Item
    ---@param sendNow? boolean Immediately send list? Default behavior is waiting for the batch timer.
    function Sender.HMSG_ITEM_RESPONSE_UPDATE_SendList(item, sendNow)
        for _, itemClient in pairs(item.responses) do
            Sender.HMSG_ITEM_RESPONSE_UPDATE(item.guid, itemClient)
        end
        if sendNow then
            batchTimers:Cancel("HMSG_ITEM_RESPONSE_UPDATE")
            SendResponseUpdateBatch()
        end
    end

    ---@class CommEvent_HMSG_ITEM_RESPONSE_UPDATE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_RESPONSE_UPDATE, cb:fun(itemGuid:string, data: PackedSessionItemClient[], sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_RESPONSE_UPDATE, itemGuid:string, data: PackedSessionItemClient[], sender:string)
    Events.HMSG_ITEM_RESPONSE_UPDATE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_RESPONSE_UPDATE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_RESPONSE_UPDATE] = function(data, sender)
        ---@cast data Packet_HMSG_ITEM_RESPONSE_UPDATE
        for itemGuid, pic in pairs(data) do
            Events.HMSG_ITEM_RESPONSE_UPDATE:Trigger(itemGuid, pic, sender)
        end
    end
end

-- HMSG_ITEM_UPDATE
do
    ---@class (exact) Packet_HMSG_ITEM_UPDATE
    ---@field guid string
    ---@field isVeiled boolean
    ---@field isGarbage boolean

    ---@type table<string,Packet_HMSG_ITEM_UPDATE>
    local nextSend = {}

    local function SendUpdateBatch()
        local packet = {} ---@type Packet_HMSG_ITEM_UPDATE[]
        for _, pck in pairs(nextSend) do
            table.insert(packet, pck)
        end
        wipe(nextSend)
        LogDebugHtC("Sending batched HMSG_ITEM_UPDATE, items:", #packet)
        SendToClients(OPCODES.HMSG_ITEM_UPDATE, packet)
    end

    ---@param item SessionHost_Item
    ---@param doNotBatch? boolean Do not batch and send immediately.
    function Sender.HMSG_ITEM_UPDATE(item, doNotBatch)
        local pck = { ---@type Packet_HMSG_ITEM_UPDATE
            guid = item.guid,
            isVeiled = item.veiled,
            isGarbage = item.markedGarbage
        }
        if doNotBatch then
            ---@type Packet_HMSG_ITEM_UPDATE[]
            local singel = { pck }
            SendToClients(OPCODES.HMSG_ITEM_UPDATE, singel)
            return
        end

        nextSend[item.guid] = pck
        batchTimers:StartUnique("HMSG_ITEM_UPDATE", 0.2, SendUpdateBatch, nil, true)
    end

    ---@class CommEvent_HMSG_ITEM_UPDATE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_UPDATE, cb:fun(data:Packet_HMSG_ITEM_UPDATE, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_UPDATE, data:Packet_HMSG_ITEM_UPDATE, sender:string)
    Events.HMSG_ITEM_UPDATE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_UPDATE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_UPDATE] = function(data, sender)
        ---@cast data Packet_HMSG_ITEM_UPDATE[]
        for _, pck in pairs(data) do
            Events.HMSG_ITEM_UPDATE:Trigger(pck, sender)
        end
    end
end

-- HMSG_ITEM_ROLL_END
do
    ---@type table<string,boolean>
    local nextSend = {}

    local function SendUpdateBatch()
        local packet = {} ---@type string[]
        for itemGuid in pairs(nextSend) do
            table.insert(packet, itemGuid)
        end
        wipe(nextSend)
        LogDebugHtC("Sending batched HMSG_ITEM_ROLL_END, items:", #packet)
        SendToClients(OPCODES.HMSG_ITEM_ROLL_END, packet)
    end

    ---@param itemGuid string
    ---@param doNotBatch? boolean Do not batch and send immediately.
    function Sender.HMSG_ITEM_ROLL_END(itemGuid, doNotBatch)
        if doNotBatch then
            ---@type string[]
            local singel = { itemGuid }
            SendToClients(OPCODES.HMSG_ITEM_ROLL_END, singel)
            return
        end

        nextSend[itemGuid] = true
        batchTimers:StartUnique("HMSG_ITEM_ROLL_END", 2, SendUpdateBatch, nil, true)
    end

    ---@class CommEvent_HMSG_ITEM_ROLL_END
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_ROLL_END, cb:fun(itemGuid:string, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_ROLL_END, itemGuid:string, sender:string)
    Events.HMSG_ITEM_ROLL_END = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_ROLL_END] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_ROLL_END] = function(data, sender)
        ---@cast data string[]
        for _, itemGuid in pairs(data) do
            Events.HMSG_ITEM_ROLL_END:Trigger(itemGuid, sender)
        end
    end
end

-- HMSG_ITEM_AWARD_UPDATE
do
    ---@class (exact) Packet_HMSG_ITEM_AWARD_UPDATE
    ---@field itemGuid string
    ---@field candidateName? string
    ---@field responseId? integer
    ---@field pointSnapshot? table<string,integer>

    ---@param itemGuid string
    ---@param candidateName? string
    ---@param responseId? integer
    ---@param pointSnapshot? table<string,integer>
    function Sender.HMSG_ITEM_AWARD_UPDATE(itemGuid, candidateName, responseId, pointSnapshot)
        local packet = { ---@type Packet_HMSG_ITEM_AWARD_UPDATE
            itemGuid = itemGuid,
            candidateName = candidateName,
            responseId = responseId,
            pointSnapshot = pointSnapshot,
        }
        SendToClients(OPCODES.HMSG_ITEM_AWARD_UPDATE, packet)
    end

    ---@class CommEvent_HMSG_ITEM_AWARD_UPDATE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_AWARD_UPDATE, cb:fun(data:Packet_HMSG_ITEM_AWARD_UPDATE, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_AWARD_UPDATE, data:Packet_HMSG_ITEM_AWARD_UPDATE, sender:string)
    Events.HMSG_ITEM_AWARD_UPDATE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_AWARD_UPDATE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_AWARD_UPDATE] = function(data, sender)
        ---@cast data Packet_HMSG_ITEM_AWARD_UPDATE
        Events.HMSG_ITEM_AWARD_UPDATE:Trigger(data, sender)
    end
end

-- HMSG_KEEPALIVE
-- This is basically just to update the last received time for clients if no other comm happens.
do
    function Sender.HMSG_KEEPALIVE()
        SendToClients(OPCODES.HMSG_KEEPALIVE)
    end

    ---@class CommEvent_HMSG_KEEPALIVE
    ---@field RegisterCallback fun(self:CommEvent_HMSG_KEEPALIVE, cb:fun(sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_KEEPALIVE, sender:string)
    Events.HMSG_KEEPALIVE = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_KEEPALIVE] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_KEEPALIVE] = function(data, sender)
        Events.HMSG_KEEPALIVE:Trigger(sender)
    end
end

--------------------------------------------------------------------------
--- Client To Host
--------------------------------------------------------------------------

local function LogDebugCtH(...)
    Env:PrintDebug("Comm Client:", ...)
end

local doFakeSend = false ---@type string|false

---Send message to host.
---@param opcode Opcode
---@param data any
function SendToHost(opcode, data)
    if doFakeSend ~= false then
        local sender = doFakeSend
        local delay = 0.5 + math.random()
        LogDebugCtH("FAKE Sending to host", opcode, ", Delay: ", delay)
        C_Timer.NewTimer(delay, function(t)
            HandleMessage("WHISPER", sender, opcode, data, 0)
        end)
        return
    end
    LogDebugCtH("Sending to host", opcode)
    local sendSize = Net:SendWhisper(COMM_SESSION_PREFIX, clientHostName, opcode, "NORMAL", data)
    if commlog then
        local newEntry = { ---@type CommLogEntrySend
            timestamp = time(),
            type = "whisper_host",
            opcode = opcode,
            opcodeStr = LookupOpcodeName(opcode),
            data = data,
            sendSize = sendSize,
        }
        table.insert(commlog.sendlog, newEntry)
    end
end

---@param channel string
---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedOnHost(channel, sender, opcode, data)
    if opcode < OPCODES.MAX_HMSG then
        return false
    end
    if channel ~= "WHISPER" and channel ~= "RAID" and channel ~= "PARTY" then
        return false
    end
    return true
end

---For debugging: Fake send to host by directly calling the local message handler after a delay.
---@param sender string The sender name to use.
---@param action fun() A function that uses a Comm.Sender.CMSG_ function.
function Comm:FakeSendToHost(sender, action)
    doFakeSend = sender
    action()
    doFakeSend = false
end

-- CMSG_ATTENDANCE_CHECK
do
    function Sender.CMSG_ATTENDANCE_CHECK()
        SendToHost(OPCODES.CMSG_ATTENDANCE_CHECK)
    end

    ---@class CommEvent_CMSG_ATTENDANCE_CHECK
    ---@field RegisterCallback fun(self:CommEvent_CMSG_ATTENDANCE_CHECK, cb:fun(sender:string))
    ---@field Trigger fun(self:CommEvent_CMSG_ATTENDANCE_CHECK, sender:string)
    Events.CMSG_ATTENDANCE_CHECK = Env:NewEventEmitter()

    messageFilter[OPCODES.CMSG_ATTENDANCE_CHECK] = FilterReceivedOnHost
    messageHandler[OPCODES.CMSG_ATTENDANCE_CHECK] = function(data, sender)
        Events.CMSG_ATTENDANCE_CHECK:Trigger(sender)
    end
end

-- CMSG_ITEM_RECEIVED
do
    local queued = {} ---@type string[] -- The item guids to send.

    local function SendQueued()
        LogDebugCtH("Sending batched CMSG_ITEM_RECEIVED, items:", #queued)
        SendToHost(OPCODES.CMSG_ITEM_RECEIVED, queued)
        wipe(queued)
    end

    ---@param itemGuid string
    ---@param doNotBatch boolean?
    function Sender.CMSG_ITEM_RECEIVED(itemGuid, doNotBatch)
        if doNotBatch then
            SendToHost(OPCODES.CMSG_ITEM_RECEIVED, { itemGuid })
            return
        end
        table.insert(queued, itemGuid)
        -- Similar to HMSG_ITEM_ANNOUNCE, this is for multiple items received at once.
        batchTimers:StartUnique("CMSG_ITEM_RECEIVED", 0.1, SendQueued, nil, true)
    end

    ---@class CommEvent_CMSG_ITEM_RECEIVED
    ---@field RegisterCallback fun(self:CommEvent_CMSG_ITEM_RECEIVED, cb:fun(sender:string, itemGuid:string))
    ---@field Trigger fun(self:CommEvent_CMSG_ITEM_RECEIVED, sender:string, itemGuid:string)
    Events.CMSG_ITEM_RECEIVED = Env:NewEventEmitter()

    messageFilter[OPCODES.CMSG_ITEM_RECEIVED] = FilterReceivedOnHost
    messageHandler[OPCODES.CMSG_ITEM_RECEIVED] = function(data, sender)
        ---@cast data string[]
        for _, itemGuid in ipairs(data) do
            Events.CMSG_ITEM_RECEIVED:Trigger(sender, itemGuid)
        end
    end
end

-- CMSG_ITEM_RESPONSE
do
    ---@class (exact) Packet_CMSG_ITEM_RESPONSE
    ---@field itemGuid string
    ---@field responseId integer

    ---@param itemGuid string
    ---@param responseId integer
    function Sender.CMSG_ITEM_RESPONSE(itemGuid, responseId)
        local p = { ---@type Packet_CMSG_ITEM_RESPONSE
            itemGuid = itemGuid,
            responseId = responseId,
        }
        SendToHost(OPCODES.CMSG_ITEM_RESPONSE, p)
    end

    ---@class CommEvent_CMSG_ITEM_RESPONSE
    ---@field RegisterCallback fun(self:CommEvent_CMSG_ITEM_RESPONSE, cb:fun(sender:string, itemGuid:string, responseId:integer))
    ---@field Trigger fun(self:CommEvent_CMSG_ITEM_RESPONSE, sender:string, itemGuid:string, responseId:integer)
    Events.CMSG_ITEM_RESPONSE = Env:NewEventEmitter()

    messageFilter[OPCODES.CMSG_ITEM_RESPONSE] = FilterReceivedOnHost
    messageHandler[OPCODES.CMSG_ITEM_RESPONSE] = function(data, sender)
        ---@cast data Packet_CMSG_ITEM_RESPONSE
        Events.CMSG_ITEM_RESPONSE:Trigger(sender, data.itemGuid, data.responseId)
    end
end

--------------------------------------------------------------------------
--- Client To All
--------------------------------------------------------------------------

local function LogDebugCtA(...)
    Env:PrintDebug("Comm Client:", ...)
end

---Send message to host.
---@param opcode Opcode
---@param data any
function SendClientToAll(opcode, data)
    if hostCommTarget and hostCommTarget == "self" then
        LogDebugCtA("Sending client broadcast to self", LookupOpcodeName(opcode))
        Net:SendWhisper(COMM_SESSION_PREFIX, UnitName("player"), opcode, "BULK", data)
        return
    end
    local channel = ""
    if IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    else
        Env:PrintError("Tried to broadcast to group but not in a group!")
        return false
    end
    LogDebugCtA("Sending client broadcast", channel, LookupOpcodeName(opcode))
    local sendSize = Net:Send(COMM_SESSION_PREFIX, channel, opcode, "BULK", data)
    if commlog then
        local newEntry = { ---@type CommLogEntrySend
            timestamp = time(),
            type = "client_broadcast",
            opcode = opcode,
            opcodeStr = LookupOpcodeName(opcode),
            data = data,
            sendSize = sendSize,
        }
        table.insert(commlog.sendlog, newEntry)
    end
end

---@param channel string
---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedClientBroadcast(channel, sender, opcode, data)
    if opcode < OPCODES.MAX_CMSG then
        return false
    end
    if channel ~= "WHISPER" and channel ~= "RAID" and channel ~= "PARTY" then
        return false
    end
    return true
end

-- CBMSG_ITEM_CURRENTLY_EQUIPPED
do
    ---@class (exact) Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED
    ---@field itemGuid string
    ---@field currentItems integer[] [item1[, item2]]

    local queued = {} ---@type Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED[]

    local function SendQueued()
        LogDebugCtH("Sending batched CBMSG_ITEM_CURRENTLY_EQUIPPED, items:", #queued)
        SendClientToAll(OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED, queued)
        wipe(queued)
    end

    ---@param itemGuid string
    ---@param currentItems integer[] [item1[, item2]]
    function Sender.CBMSG_ITEM_CURRENTLY_EQUIPPED(itemGuid, currentItems)
        local packet = { ---@type Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED
            itemGuid = itemGuid,
            currentItems = currentItems,
        }
        table.insert(queued, packet)
        -- Similar to HMSG_ITEM_ANNOUNCE, this is for multiple items received at once.
        -- Delay sending equipped items to not clog up addon channel with this when many items are posted at once.
        -- TODO: Should be able to send more info after all, just make sure it happens after most data was already sent.
        batchTimers:StartUnique("CBMSG_ITEM_CURRENTLY_EQUIPPED", 5, SendQueued, nil, true)
    end

    ---@class CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED
    ---@field RegisterCallback fun(self:CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED, cb:fun(sender:string, data:Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED))
    ---@field Trigger fun(self:CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED, sender:string, data:Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED)
    Events.CBMSG_ITEM_CURRENTLY_EQUIPPED = Env:NewEventEmitter()

    messageFilter[OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED] = FilterReceivedClientBroadcast
    messageHandler[OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED] = function(data, sender)
        ---@cast data Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED[]
        for _, individual in ipairs(data) do
            Events.CBMSG_ITEM_CURRENTLY_EQUIPPED:Trigger(sender, individual)
        end
    end
end

-- CMSG_RESEND_START
do
    function Sender.CMSG_RESEND_START()
        SendClientToAll(OPCODES.CMSG_RESEND_START)
    end

    ---@class CommEvent_CMSG_RESEND_START
    ---@field RegisterCallback fun(self:CommEvent_CMSG_RESEND_START, cb:fun(sender:string))
    ---@field Trigger fun(self:CommEvent_CMSG_RESEND_START, sender:string)
    Events.CMSG_RESEND_START = Env:NewEventEmitter()

    messageFilter[OPCODES.CMSG_RESEND_START] = function(channel, sender, opcode, data)
        if IsInRaid() then
            if channel ~= "RAID" then
                return false
            end
        elseif IsInGroup() then
            if channel ~= "PARTY" then
                return false
            end
        else
            return false
        end
        return true
    end
    messageHandler[OPCODES.CMSG_RESEND_START] = function(data, sender)
        Events.CMSG_RESEND_START:Trigger(sender)
    end
end

--------------------------------------------------------------------------
--- Debug log commands
--------------------------------------------------------------------------

Env:RegisterSlashCommand("commlogstart", "", function(args)
    if not DMS_Logs then
        DMS_Logs = {}
    end
    commlog = {
        logtype = "commlog",
        timestamp = time(),
        receivelog = {},
        sendlog = {}
    }
    table.insert(DMS_Logs, commlog)
    Env:PrintSuccess("Comm log enabled.")
end)

Env:RegisterSlashCommand("commlogend", "", function(args)
    commlog = nil
    Env:PrintSuccess("Comm log disabled.")
end)

Env:RegisterSlashCommand("commlogclear", "", function(args)
    commlog = nil
    if DMS_Logs then
        DMS_Logs = {}
    end
    Env:PrintSuccess("Comm logs cleared.")
end)

Env:RegisterSlashCommand("commloglist", "", function(args)
    if not DMS_Logs then
        Env:PrintError("No comm logs exist!")
        return
    end

    Env:PrintSuccess("Comm logs:")
    for k, v in ipairs(DMS_Logs) do
        print(k .. ": " .. v.timestamp)
    end
end)

Env:RegisterSlashCommand("commlogshow", "", function(args)
    if not DMS_Logs then
        Env:PrintError("No comm logs exist!")
        return
    end

    local num = tonumber(args[1])
    if not num or not DMS_Logs or not DMS_Logs[num] then
        print("Log doesn't exist!")
        return
    end

    local log = DMS_Logs[num] ---@type CommLog

    Env:PrintSuccess("Comm log #" .. num)
    local startTime = log.timestamp
    Env:PrintSuccess("--- RECV log: ---")
    for _, v in ipairs(log.receivelog) do
        print(string.format("T+%ds: %s > %s (%d)", v.timestamp - startTime, v.sender, v.opcodeStr, v.recvSize))
    end
    Env:PrintSuccess("--- SEND log: ---")
    for _, v in ipairs(log.sendlog) do
        print(string.format("T+%ds: %s > %s (%d)", v.timestamp - startTime, v.type, v.opcodeStr, v.sendSize))
    end
end)
