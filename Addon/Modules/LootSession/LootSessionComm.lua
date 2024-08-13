---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Net = Env.Net

local COMM_SESSION_PREFIX = "DMSS"
local COMM_VERSION = 1

---@enum Opcode
local OPCODES = {
    HMSG_SESSION_START = 1,
    HMSG_SESSION_END = 2,
    HMSG_CANDIDATE_UPDATE = 3,
    HMSG_ITEM_ANNOUNCE = 4,
    HMSG_ITEM_RESPONSE_UPDATE = 5,
    HMSG_ITEM_UNVEIL = 6,
    HMSG_ITEM_ROLL_END = 7,
    HMSG_ITEM_AWARD_UPDATE = 8,

    MAX_HMSG = 99,

    CMSG_ATTENDANCE_CHECK = 100,
    CMSG_ITEM_RECEIVED = 101,
    CMSG_ITEM_RESPONSE = 102,

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
local messageFilter = {} ---@type table<Opcode,fun(sender:string, opcode:Opcode, data:any)|nil>
local batchTimers = Env:NewUniqueTimers()
local hostCommTarget = "group" ---@type CommTarget
local clientHostName = ""

Net:Register(COMM_SESSION_PREFIX, function(prefix, sender, opcode, data)
    if not messageHandler[opcode] then
        Env:PrintError(L["Received unhandled opcode %s from %s"]:format(LookupOpcodeName(opcode), sender))
        return
    end
    Env:PrintDebug("Comm received:", LookupOpcodeName(opcode))
    Env:PrintVerbose(data)

    -- Stop all but session start opcodes here if session is no from sending host
    if opcode ~= OPCODES.HMSG_SESSION_START and opcode < OPCODES.MAX_HMSG and sender ~= clientHostName then
        Env:PrintDebug("Received", LookupOpcodeName(opcode), "from", sender, "who isn't the current host")
        return
    end

    if messageFilter[opcode] and not messageFilter[opcode](sender, opcode, data) then
        return
    end
    messageHandler[opcode](data, sender)
end)

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
---@param name string
function Comm:ClientSetAllowedHost(name)
    clientHostName = name
end

--------------------------------------------------------------------------
--- Host To Client
--------------------------------------------------------------------------

local function LogDebugHtC(...)
    Env:PrintDebug("Comm Host:", ...)
end

---@param opcode Opcode
---@param data any
local function SendToClients(opcode, data)
    if hostCommTarget == "self" then
        LogDebugHtC("Sending whisper", LookupOpcodeName(opcode))
        Net:SendWhisper(COMM_SESSION_PREFIX, UnitName("player"), opcode, data)
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
    Net:Send(COMM_SESSION_PREFIX, channel, opcode, data)
end

---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedOnClient(sender, opcode, data)
    if opcode >= OPCODES.MAX_HMSG then
        return false
    end
    -- Filter all but session start here if session is not from currently set host.
    if opcode ~= OPCODES.HMSG_SESSION_START and sender ~= clientHostName then
        Env:PrintDebug("Received", LookupOpcodeName(opcode), "from", sender, "who isn't the current host")
        return false
    end
    return true
end

-- HMSG_SESSION_START
do
    ---@class (exact) Packet_HMSG_SESSION_START
    ---@field guid string
    ---@field responses LootResponse[]
    ---@field commVersion integer

    ---@param guid string
    ---@param responses LootResponse[]
    function Sender.HMSG_SESSION_START(guid, responses)
        local p = { ---@type Packet_HMSG_SESSION_START
            guid = guid,
            responses = responses,
            commVersion = COMM_VERSION,
        }
        SendToClients(OPCODES.HMSG_SESSION_START, p)
    end

    ---This event will always fire regardless of who sends it!
    ---@class CommEvent_HMSG_SESSION_START
    ---@field RegisterCallback fun(self:CommEvent_HMSG_SESSION_START, cb:fun(guid:string, responses:LootResponses, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_SESSION_START, guid:string, responses:LootResponses, sender:string)
    Events.HMSG_SESSION_START = Env:NewEventEmitter()

    messageHandler[OPCODES.HMSG_SESSION_START] = function(data, sender)
        ---@cast data Packet_HMSG_SESSION_START
        if COMM_VERSION ~= data.commVersion then
            Env:PrintError(L["Received session from %s with API version %d"]:format(sender, data.commVersion))
            if COMM_VERSION < data.commVersion then
                Env:PrintError(L["Your addon version is outdated! Your API version: %d"]:format(COMM_VERSION))
            else
                Env:PrintError(L["Host's addon version is outdated! Your API version: %d"]:format(COMM_VERSION))
            end
            return
        end
        local rebuiltResponses = Env.Session.CreateLootClientResponsesFromComm(data.responses)
        Events.HMSG_SESSION_START:Trigger(data.guid, rebuiltResponses, sender)
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

    ---@param candidate SessionHost_Candidate
    local function PackLootCandidate(candidate)
        local data = { ---@type PackedLootCandidate
            n = candidate.name,
            c = candidate.classId,
            s = 0,
            cp = candidate.currentPoints,
        }
        if candidate.leftGroup then
            data.s = data.s + 0x2
        end
        if candidate.isResponding then
            data.s = data.s + 0x4
        end
        return data
    end

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
                leftGroup = bit.band(packedLc.s, 0x2) > 0,
                isResponding = bit.band(packedLc.s, 0x4) > 0,
                currentPoints = packedLc.cp,
            }
            table.insert(lcs, lc)
        end
        Events.HMSG_CANDIDATE_UPDATE:Trigger(lcs, sender)
    end
end

-- HMSG_ITEM_ANNOUNCE
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

    ---@param item SessionHost_Item
    function Sender.HMSG_ITEM_ANNOUNCE(item)
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
        SendToClients(OPCODES.HMSG_ITEM_ANNOUNCE, pitem)
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
        if data.parentGuid then
            ---@cast data Packet_HMSG_ITEM_ANNOUNCE_ChildItem
            Events.HMSG_ITEM_ANNOUNCE_ChildItem:Trigger(data, sender)
        else
            ---@cast data Packet_HMSG_ITEM_ANNOUNCE
            Events.HMSG_ITEM_ANNOUNCE:Trigger(data, sender)
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

        batchTimers:StartUnique("HMSG_ITEM_RESPONSE_UPDATE", 1, SendResponseUpdateBatch, nil, true)
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

-- HMSG_ITEM_UNVEIL
do
    ---@type table<string,boolean>
    local nextSend = {}

    local function SendUpdateBatch()
        local packet = {} ---@type string[]
        for itemGuid in pairs(nextSend) do
            table.insert(packet, itemGuid)
        end
        wipe(nextSend)
        LogDebugHtC("Sending batched HMSG_ITEM_UNVEIL, items:", #packet)
        SendToClients(OPCODES.HMSG_ITEM_UNVEIL, packet)
    end

    ---@param itemGuid string
    ---@param doNotBatch? boolean Do not batch and send immediately.
    function Sender.HMSG_ITEM_UNVEIL(itemGuid, doNotBatch)
        if doNotBatch then
            ---@type string[]
            local singel = { itemGuid }
            SendToClients(OPCODES.HMSG_ITEM_UNVEIL, singel)
            return
        end

        nextSend[itemGuid] = true
        batchTimers:StartUnique("HMSG_ITEM_UNVEIL", 0.2, SendUpdateBatch, nil, true)
    end

    ---@class CommEvent_HMSG_ITEM_UNVEIL
    ---@field RegisterCallback fun(self:CommEvent_HMSG_ITEM_UNVEIL, cb:fun(itemGuid:string, sender:string))
    ---@field Trigger fun(self:CommEvent_HMSG_ITEM_UNVEIL, itemGuid:string, sender:string)
    Events.HMSG_ITEM_UNVEIL = Env:NewEventEmitter()

    messageFilter[OPCODES.HMSG_ITEM_UNVEIL] = FilterReceivedOnClient
    messageHandler[OPCODES.HMSG_ITEM_UNVEIL] = function(data, sender)
        ---@cast data string[]
        for _, itemGuid in pairs(data) do
            Events.HMSG_ITEM_UNVEIL:Trigger(itemGuid, sender)
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
        batchTimers:StartUnique("HMSG_ITEM_ROLL_END", 0.2, SendUpdateBatch, nil, true)
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
    ---@field pointSnapshot? table<string,integer>

    ---@param itemGuid string
    ---@param candidateName? string
    ---@param pointSnapshot? table<string,integer>
    function Sender.HMSG_ITEM_AWARD_UPDATE(itemGuid, candidateName, pointSnapshot)
        local packet = { ---@type Packet_HMSG_ITEM_AWARD_UPDATE
            itemGuid = itemGuid,
            candidateName = candidateName,
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

--------------------------------------------------------------------------
--- Client To Host
--------------------------------------------------------------------------

local function LogDebugCtH(...)
    Env:PrintDebug("Comm Client:", ...)
end

---Send message to host.
---@param opcode Opcode
---@param data any
function SendToHost(opcode, data)
    LogDebugCtH("Sending to host", opcode)
    Net:SendWhisper(COMM_SESSION_PREFIX, clientHostName, opcode, data)
end

---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedOnHost(sender, opcode, data)
    if opcode < OPCODES.MAX_HMSG then
        return false
    end
    return true
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
    ---@param itemGuid string
    function Sender.CMSG_ITEM_RECEIVED(itemGuid)
        SendToHost(OPCODES.CMSG_ITEM_RECEIVED, itemGuid)
    end

    ---@class CommEvent_CMSG_ITEM_RECEIVED
    ---@field RegisterCallback fun(self:CommEvent_CMSG_ITEM_RECEIVED, cb:fun(sender:string, itemGuid:string))
    ---@field Trigger fun(self:CommEvent_CMSG_ITEM_RECEIVED, sender:string, itemGuid:string)
    Events.CMSG_ITEM_RECEIVED = Env:NewEventEmitter()

    messageFilter[OPCODES.CMSG_ITEM_RECEIVED] = FilterReceivedOnHost
    messageHandler[OPCODES.CMSG_ITEM_RECEIVED] = function(data, sender)
        Events.CMSG_ITEM_RECEIVED:Trigger(sender, data)
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
        Net:SendWhisper(COMM_SESSION_PREFIX, UnitName("player"), opcode, data)
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
    Net:Send(COMM_SESSION_PREFIX, channel, opcode, data)
end

---@param sender string
---@param opcode Opcode
---@param data any
local function FilterReceivedClientBroadcast(sender, opcode, data)
    if opcode < OPCODES.MAX_CMSG then
        return false
    end
    return true
end

-- CBMSG_ITEM_CURRENTLY_EQUIPPED
do
    ---@class (exact) Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED
    ---@field itemGuid string
    ---@field currentItems string[] [item1[, item2]]

    ---@param itemGuid string
    ---@param currentItems string[] [item1[, item2]]
    function Sender.CBMSG_ITEM_CURRENTLY_EQUIPPED(itemGuid, currentItems)
        local packet = { ---@type Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED
            itemGuid = itemGuid,
            currentItems = currentItems,
        }
        SendClientToAll(OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED, packet)
    end

    ---@class CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED
    ---@field RegisterCallback fun(self:CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED, cb:fun(sender:string, data:Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED))
    ---@field Trigger fun(self:CommEvent_CBMSG_ITEM_CURRENTLY_EQUIPPED, sender:string, data:Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED)
    Events.CBMSG_ITEM_CURRENTLY_EQUIPPED = Env:NewEventEmitter()

    messageFilter[OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED] = FilterReceivedClientBroadcast
    messageHandler[OPCODES.CBMSG_ITEM_CURRENTLY_EQUIPPED] = function(data, sender)
        ---@cast data Packet_CBMSG_ITEM_CURRENTLY_EQUIPPED
        Events.CBMSG_ITEM_CURRENTLY_EQUIPPED:Trigger(sender, data)
    end
end
