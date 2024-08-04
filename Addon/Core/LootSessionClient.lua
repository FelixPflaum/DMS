---@class AddonEnv
local DMS = select(2, ...)

local L = DMS:GetLocalization()
local Net = DMS.Net
local Comm = DMS.Session.Comm

---@class (exact) LootSessionClient
---@field sessionGUID string
---@field hostName string
---@field responses LootResponses
---@field candidates table<string, LootCandidate>
---@field isFinished boolean
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

    Net:RegisterObj(Comm.PREFIX, self, "OnMsgReceived")
end

function LootSessionClient:End()
    if not self.isFinished then
        self.OnSessionEnd:Trigger()
        Net:UnregisterObj(Comm.PREFIX, self)
    end
    self.isFinished = true
end

---@param list Packet_LootCandidate[]
function LootSessionClient:UpdateCandidates(list)
    for _, pc in ipairs(list) do
        local candidate = Comm:Packet_ReadCandidate(pc)
        if self.candidates[candidate.name] then
            -- TODO: update item data?
        else
            self.candidates[candidate.name] = candidate
        end
    end
    self.OnCandidateUpdate:Trigger()
end

---@param prefix string
---@param sender string
---@param opcode OpCode
---@param data any
function LootSessionClient:OnMsgReceived(prefix, sender, opcode, data)
    if opcode == Comm.OpCodes.HMSG_CANDIDATES_UPDATE then
        ---@cast data Packet_LootCandidate[]
        DMS:PrintDebug("Recieved msg", sender, "HMSG_CANDIDATES_UPDATE")
        DMS:PrintDebug(data)
        self:UpdateCandidates(data)
    else
        DMS:PrintDebug("Recieved msg", opcode)
        DMS:PrintDebug(data)
    end
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
            DMS:PrintDebug("Received HMSG_SESSION from", sender, "but already have a session.")
            return
        end
        DMS:PrintDebug(data)

        ---@type Packet_LootSession
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
        DMS:PrintDebug("Recieved msg", sender, "HMSG_SESSION_END")
        if clientSession and clientSession.hostName == sender then
            clientSession:End()
            clientSession = nil
        end
    else
        DMS:PrintDebug("Recieved msg", opcode)
        DMS:PrintDebug(data)
    end
end)
