---@class AddonEnv
local DMS = select(2, ...)

local L = DMS:GetLocalization()
local Net = DMS.Net
local Comm = DMS.Session.Comm
local LootStatus = DMS.Session.LootStatus

local function LogDebug(...)
    DMS:PrintDebug("Client:", ...)
end

---@class (exact) LootSessionItemClient
---@field candidate LootCandidate
---@field response LootResponse|nil
---@field status LootClientStatus
---@field roll integer|nil
---@field sanity integer|nil

---@class (exact) LootSessionClientItem
---@field guid string
---@field order integer
---@field itemId integer
---@field veiled boolean
---@field endTime integer
---@field responses table<string, LootSessionItemClient>
---@field awardedTo string|nil

---@class (exact) LootSessionClient
---@field sessionGUID string
---@field hostName string
---@field responses LootResponses
---@field candidates table<string, LootCandidate>
---@field isFinished boolean
---@field keepaliveTimer TimerHandle|nil
---@field items table<string, LootSessionClientItem>
local LootSessionClient = {}
---@diagnostic disable-next-line: inject-field
LootSessionClient.__index = LootSessionClient

---@param hostName string
---@param guid string
---@param responses LootResponses
---@return LootSessionClient
local function NewLootSessionClient(hostName, guid, responses)
    ---@type LootSessionClient
    local clientSession = {
        sessionGUID = guid,
        hostName = hostName,
        responses = responses,
        candidates = {},
        isFinished = false,
        items = {},
    }
    setmetatable(clientSession, LootSessionClient)
    clientSession:Setup()
    return clientSession
end

function LootSessionClient:Setup()
    ---@class (exact) LSClientEndEvent
    ---@field RegisterCallback fun(self:LSClientEndEvent, cb:fun())
    ---@field Trigger fun(self:LSClientEndEvent)
    ---@diagnostic disable-next-line: inject-field
    self.OnSessionEnd = DMS:NewEventEmitter()

    ---@class (exact) LSClientCandidateUpdateEvent
    ---@field RegisterCallback fun(self:LSClientCandidateUpdateEvent, cb:fun())
    ---@field Trigger fun(self:LSClientCandidateUpdateEvent)
    ---@diagnostic disable-next-line: inject-field
    self.OnCandidateUpdate = DMS:NewEventEmitter()

    ---@class (exact) LSClientItemUpdateEvent
    ---@field RegisterCallback fun(self:LSClientItemUpdateEvent, cb:fun(item:LootSessionClientItem))
    ---@field Trigger fun(self:LSClientItemUpdateEvent, item:LootSessionClientItem)
    ---@diagnostic disable-next-line: inject-field
    self.OnItemUpdate = DMS:NewEventEmitter()

    Net:RegisterObj(Comm.PREFIX, self, "OnMsgReceived")

    local s = self
    self.keepaliveTimer = C_Timer.NewTicker(20, function(t)
        s:SendToHost(Comm.OpCodes.CMSG_IM_HERE)
    end)
    self:SendToHost(Comm.OpCodes.CMSG_IM_HERE)
end

function LootSessionClient:SendToHost(opcode, data)
    LogDebug("Sending to host", opcode)
    Net:SendWhisper(Comm.PREFIX, self.hostName, opcode, data)
end

function LootSessionClient:End()
    if self.isFinished then
        return
    end
    if self.keepaliveTimer then
        self.keepaliveTimer:Cancel()
    end
    self.isFinished = true
    self.OnSessionEnd:Trigger()
    Net:UnregisterObj(Comm.PREFIX, self)
end

---@param prefix string
---@param sender string
---@param opcode OpCode
---@param data any
function LootSessionClient:OnMsgReceived(prefix, sender, opcode, data)
    if opcode > Comm.OpCodes.MAX_HMSG then return end
    if self.hostName ~= sender then return end

    if opcode == Comm.OpCodes.HMSG_CANDIDATES_UPDATE then
        ---@cast data Packet_LootCandidate|Packet_LootCandidate[]
        LogDebug("Recieved msg", sender, "HMSG_CANDIDATES_UPDATE")
        DMS:PrintDebug(data)
        if data.c then
            self:OnPacket_LootCandidate({ data })
        else
            self:OnPacket_LootCandidate(data)
        end
    elseif opcode == Comm.OpCodes.HMSG_ITEM_ANNOUNCE then
        ---@cast data Packet_HtC_LootSessionItem
        LogDebug("Recieved msg", sender, "HMSG_ITEM_ANNOUNCE")
        DMS:PrintDebug(data)
        self:OnPacket_LootSessionItem(data)
    elseif opcode == Comm.OpCodes.HMSG_ITEM_RESPONSE_UPDATE then
        ---@cast data Packet_HtC_LootResponseUpdate
        LogDebug("Recieved msg", sender, "HMSG_ITEM_RESPONSE_UPDATE")
        DMS:PrintDebug(data)
        self:OnPacket_LootResponseUpdate(data)
    else
        LogDebug("Recieved unknown msg", opcode)
        DMS:PrintDebug(data)
    end

    --CMSG_ITEM_RESPONSE = 102,
end

---@param list Packet_LootCandidate[]
function LootSessionClient:OnPacket_LootCandidate(list)
    for _, pc in ipairs(list) do
        local candidate = Comm:Packet_Read_LootCandidate(pc)
        self.candidates[candidate.name] = candidate
    end
    self.OnCandidateUpdate:Trigger()
end

------------------------------------------------------------------
--- Item Updates
------------------------------------------------------------------

---@param data Packet_HtC_LootSessionItemClient
function LootSessionClient:Parse_Packet_LootSessionItemClient(data)
    local candidate = self.candidates[data.candidate]
    local response = data.responseId and self.responses:GetResponse(data.responseId)
    local status = LootStatus:GetById(data.statusId)
    if not candidate then
        LogDebug("got item client update for unknown candidate", data.candidate)
        return
    elseif not response and data.responseId then
        LogDebug("got item client update with unknown response id", data.responseId)
        return
    elseif not status then
        LogDebug("got item client update with unknown status id", data.statusId)
        return
    else
        ---@type LootSessionItemClient
        local lsic = {
            name = data.candidate,
            candidate = candidate,
            response = response,
            status = status,
            roll = data.roll,
            sanity = data.sanity,
        }
        return lsic
    end
end

---@param data Packet_HtC_LootResponseUpdate
function LootSessionClient:OnPacket_LootResponseUpdate(data)
    local item = self.items[data.itemGuid]
    if not item then
        LogDebug("got item response update for unknown item", data.itemGuid)
    end
    local itemCLient = self:Parse_Packet_LootSessionItemClient(data.client)
    if not itemCLient then
        return
    end
    item.responses[itemCLient.candidate.name] = itemCLient
    LogDebug("item updated OnPacket_LootResponseUpdate", data.itemGuid)
    self.OnItemUpdate:Trigger(item)
end

---@param data Packet_HtC_LootSessionItem
function LootSessionClient:OnPacket_LootSessionItem(data)
    ---@type LootSessionClientItem
    local pitem = {
        guid = data.guid,
        order = data.order,
        itemId = data.itemId,
        veiled = data.veiled,
        endTime = data.endTime,
        responses = {},
    }

    if not self.items[pitem.guid] then
        LogDebug("item ack", pitem.guid)
        self:SendToHost(Comm.OpCodes.CMSG_ITEM_ACK, pitem.guid)
    end

    self.items[pitem.guid] = pitem

    if data.responses then
        ---@type table<string, LootSessionItemClient>
        local respList = {}
        for _, lootItemClientPacket in ipairs(data.responses) do
            local lsic = self:Parse_Packet_LootSessionItemClient(lootItemClientPacket)
            if lsic then
                respList[lootItemClientPacket.candidate] = lsic
            end
        end
        pitem.responses = respList
    end

    LogDebug("item updated OnPacket_LootSessionItem", pitem.guid)
    self.OnItemUpdate:Trigger(pitem)
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

DMS.Session.Client = {}

---@type LootSessionClient|nil
local clientSession = nil

---@class (exact) LootSessionClientStartEvent
---@field RegisterCallback fun(self:LootSessionClientStartEvent, cb:fun(client:LootSessionClient))
---@field Trigger fun(self:LootSessionClientStartEvent, client:LootSessionClient)
DMS.Session.Client.OnClientStart = DMS:NewEventEmitter()

DMS.Net:Register(DMS.Session.Comm.PREFIX, function(prefix, sender, opcode, data)
    if opcode == Comm.OpCodes.HMSG_SESSION then
        if clientSession then
            LogDebug("Received HMSG_SESSION from", sender, "but already have a session.")
            return
        end
        LogDebug("HMSG_SESSION")
        DMS:PrintDebug(data)

        ---@type Packet_HtC_LootSession
        data = data
        if Comm.VERSION ~= data.commVersion then
            DMS:PrintError(L["Received session from %s with API version %d"]:format(sender, data.commVersion))
            if Comm.VERSION < data.commVersion then
                DMS:PrintError(L["Your addon version is outdated! Your API version: %d"]:format(Comm.VERSION))
            else
                DMS:PrintError(L["Host's addon version is outdated! Your API version: %d"]:format(Comm.VERSION))
            end
            return
        end
        clientSession = NewLootSessionClient(sender, data.guid, DMS.Session:CreateLootClientResponsesFromComm(data.responses))
        DMS.Session.Client.OnClientStart:Trigger(clientSession)
    elseif opcode == Comm.OpCodes.HMSG_SESSION_END then
        LogDebug("Recieved msg", sender, "HMSG_SESSION_END")
        if clientSession and clientSession.hostName == sender then
            clientSession:End()
            clientSession = nil
        end
    end
end)

DMS:RegisterSlashCommand("rtest", "respiond to item test", function(args)
    print("respond to", args[1], "with", args[2])
    ---@type Packet_CtH_LootClientResponse
    local p = {
        itemGuid = args[1],
        responseId = tonumber(args[2]),
    }
    Net:SendWhisper(Comm.PREFIX, clientSession.hostName, Comm.OpCodes.CMSG_ITEM_RESPONSE, p)
end)
