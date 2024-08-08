---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Net = Env.Net
local Comm = Env.Session.Comm
local LootStatus = Env.Session.LootStatus

local function LogDebug(...)
    Env:PrintDebug("Client:", ...)
end

------------------------------------------------------------------------------------
--- Data Structure Types
------------------------------------------------------------------------------------

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
---@field startTime integer
---@field endTime integer
---@field responseSent boolean
---@field isChild boolean|nil
---@field responses table<string, LootSessionItemClient>
---@field awardedTo string|nil

---@class (exact) LootSessionClient
---@field sessionGUID string
---@field hostName string
---@field responses LootResponses|nil
---@field candidates table<string, LootCandidate>
---@field isRunning boolean
---@field keepaliveTimer TimerHandle|nil
---@field items table<string, LootSessionClientItem>
local LootSessionClient = {}

Env.Session.Client = LootSessionClient

------------------------------------------------------------------------------------
--- Construction
------------------------------------------------------------------------------------

---@class (exact) LootSessionClientStartEvent
---@field RegisterCallback fun(self:LootSessionClientStartEvent, cb:fun())
---@field Trigger fun(self:LootSessionClientStartEvent)
---@diagnostic disable-next-line: inject-field
LootSessionClient.OnStart = Env:NewEventEmitter()

---@class (exact) LSClientEndEvent
---@field RegisterCallback fun(self:LSClientEndEvent, cb:fun())
---@field Trigger fun(self:LSClientEndEvent)
---@diagnostic disable-next-line: inject-field
LootSessionClient.OnEnd = Env:NewEventEmitter()

---@class (exact) LSClientCandidateUpdateEvent
---@field RegisterCallback fun(self:LSClientCandidateUpdateEvent, cb:fun())
---@field Trigger fun(self:LSClientCandidateUpdateEvent)
---@diagnostic disable-next-line: inject-field
LootSessionClient.OnCandidateUpdate = Env:NewEventEmitter()

---@class (exact) LSClientItemUpdateEvent
---@field RegisterCallback fun(self:LSClientItemUpdateEvent, cb:fun(item:LootSessionClientItem))
---@field Trigger fun(self:LSClientItemUpdateEvent, item:LootSessionClientItem)
---@diagnostic disable-next-line: inject-field
LootSessionClient.OnItemUpdate = Env:NewEventEmitter()

---Reset and initialize client session.
---@param hostName string
---@param guid string
---@param responses LootResponses
local function InitClient(hostName, guid, responses)
    LootSessionClient.sessionGUID = guid
    LootSessionClient.hostName = hostName
    LootSessionClient.responses = responses
    LootSessionClient.candidates = {}
    LootSessionClient.isRunning = true
    LootSessionClient.keepaliveTimer = nil
    LootSessionClient.items = {}

    Net:RegisterObj(Comm.PREFIX, LootSessionClient, "HandleEvent_OnHostMessageReceived")

    LootSessionClient.keepaliveTimer = C_Timer.NewTicker(20, function(t)
        LootSessionClient:SendToHost(Comm.OpCodes.CMSG_IM_HERE)
    end)
    LootSessionClient:SendToHost(Comm.OpCodes.CMSG_IM_HERE)

    LootSessionClient.OnStart:Trigger()
end

local function EndSession()
    if not LootSessionClient.isRunning then
        return
    end
    if LootSessionClient.keepaliveTimer then
        LootSessionClient.keepaliveTimer:Cancel()
        LootSessionClient.keepaliveTimer = nil
    end
    LootSessionClient.isRunning = false
    Net:UnregisterObj(Comm.PREFIX, LootSessionClient)
    LootSessionClient.OnEnd:Trigger()
end

------------------------------------------------------------------------------------
--- Host Communiction
------------------------------------------------------------------------------------

---Send message to host.
---@param opcode OpCode
---@param data any
function LootSessionClient:SendToHost(opcode, data)
    LogDebug("Sending to host", opcode)
    Net:SendWhisper(Comm.PREFIX, self.hostName, opcode, data)
end

---@param prefix string
---@param sender string
---@param opcode OpCode
---@param data any
function LootSessionClient:HandleEvent_OnHostMessageReceived(prefix, sender, opcode, data)
    if opcode > Comm.OpCodes.MAX_HMSG then return end
    if self.hostName ~= sender then return end

    if opcode == Comm.OpCodes.HMSG_CANDIDATES_UPDATE then
        ---@cast data Packet_LootCandidate|Packet_LootCandidate[]
        LogDebug("Recieved msg", sender, "HMSG_CANDIDATES_UPDATE")
        Env:PrintVerbose(data)
        if data.c then
            self:HandleMessage_LootCandidate({ data })
        else
            self:HandleMessage_LootCandidate(data)
        end
    elseif opcode == Comm.OpCodes.HMSG_ITEM_ANNOUNCE then
        ---@cast data Packet_HtC_LootSessionItem
        LogDebug("Recieved msg", sender, "HMSG_ITEM_ANNOUNCE")
        Env:PrintVerbose(data)
        self:HandleMessage_LootSessionItem(data)
    elseif opcode == Comm.OpCodes.HMSG_ITEM_RESPONSE_UPDATE then
        ---@cast data Packet_HtC_LootResponseUpdate
        LogDebug("Recieved msg", sender, "HMSG_ITEM_RESPONSE_UPDATE")
        Env:PrintVerbose(data)
        self:HandleMessage_LootResponseUpdate(data)
    else
        LogDebug("Recieved unknown msg", opcode)
        Env:PrintVerbose(data)
    end

    --TODO: CMSG_ITEM_RESPONSE = 102,
    --Spawn roll window/list if items are announced initially and endtime < now
    --Send response from there via this client session
end

------------------------------------------------------------------------------------
--- Candidate List
------------------------------------------------------------------------------------

---@param list Packet_LootCandidate[]
function LootSessionClient:HandleMessage_LootCandidate(list)
    Env:PrintVerbose(list)
    for _, pc in ipairs(list) do
        local candidate = Comm:Packet_Read_LootCandidate(pc)
        self.candidates[candidate.name] = candidate
    end
    self.OnCandidateUpdate:Trigger()
end

------------------------------------------------------------------
--- Items
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
function LootSessionClient:HandleMessage_LootResponseUpdate(data)
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
function LootSessionClient:HandleMessage_LootSessionItem(data)
    ---@type LootSessionClientItem
    local pitem = {
        guid = data.guid,
        order = data.order,
        itemId = data.itemId,
        veiled = data.veiled,
        startTime = data.startTime,
        endTime = data.endTime,
        responses = {},
        responseSent = false,
        isChild = data.isChild,
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

    LogDebug("item updated HandleMessage_LootSessionItem", pitem.guid)
    self.OnItemUpdate:Trigger(pitem)
end

---Send reponse for an item roll.
---@param itemGuid string
---@param responseId integer
function LootSessionClient:RespondToItem(itemGuid, responseId)
    local item = self.items[itemGuid]
    if not item then
        Env:PrintError(L["Tried to respond to item %s but distribution with that GUID doesn't exist!"]:format(itemGuid))
        return
    elseif not self.responses:GetResponse(responseId) then
        Env:PrintError(L["Tried to respond with response Id %d but response doesn't exist!"]:format(responseId))
        return
    elseif item.isChild then
        Env:PrintError(L["Tried to respond to child item distribution %s!"]:format(itemGuid))
        return
    elseif item.endTime < time() then
        Env:PrintError(L["Item %s already expired, did not send response!"]:format(itemGuid))
        return
    end

    ---@type Packet_CtH_LootClientResponse
    local p = {
        itemGuid = itemGuid,
        responseId = responseId,
    }
    self:SendToHost(Comm.OpCodes.CMSG_ITEM_RESPONSE, p)
    item.responseSent = true
    self.OnItemUpdate:Trigger(item)
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

Env.Net:Register(Comm.PREFIX, function(prefix, sender, opcode, data)
    if opcode == Comm.OpCodes.HMSG_SESSION then
        if LootSessionClient.isRunning then
            LogDebug("Received HMSG_SESSION from", sender, "but already have a session.")
            return
        end
        LogDebug("HMSG_SESSION")
        Env:PrintVerbose(data)

        ---@type Packet_HtC_LootSession
        data = data
        if Comm.VERSION ~= data.commVersion then
            Env:PrintError(L["Received session from %s with API version %d"]:format(sender, data.commVersion))
            if Comm.VERSION < data.commVersion then
                Env:PrintError(L["Your addon version is outdated! Your API version: %d"]:format(Comm.VERSION))
            else
                Env:PrintError(L["Host's addon version is outdated! Your API version: %d"]:format(Comm.VERSION))
            end
            return
        end
        InitClient(sender, data.guid, Env.Session:CreateLootClientResponsesFromComm(data.responses))
    elseif opcode == Comm.OpCodes.HMSG_SESSION_END then
        LogDebug("Recieved msg", sender, "HMSG_SESSION_END")
        if LootSessionClient.hostName == sender then
            EndSession()
        end
    end
end)
