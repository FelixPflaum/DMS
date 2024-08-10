---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Comm2 = Env.Session.Comm2
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
---@field parentGUID string|nil
---@field childGUIDs string[]|nil
---@field responses table<string, LootSessionItemClient>
---@field awardedTo string|nil

---@class (exact) LootSessionClient
---@field sessionGUID string
---@field hostName string
---@field responses LootResponses|nil
---@field candidates table<string, LootCandidate>
---@field isRunning boolean
---@field items table<string, LootSessionClientItem>
local LootSessionClient = {}

local timers = Env:NewUniqueTimers()

Env.Session.Client = LootSessionClient

---@type table<Opcode, fun(data:any, sender:string)>
Env.Session.ClientCommHandlers = {}

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

local function KeepAlive()
    if not LootSessionClient.isRunning then return end
    Comm2.Send.CMSG_ATTENDANCE_CHECK()
    timers:StartUnique("keepaliveTimer", 20, KeepAlive)
end

---Reset and initialize client session.
---@param hostName string
---@param guid string
---@param responses LootResponses
function LootSessionClient:Init(hostName, guid, responses)
    LootSessionClient.sessionGUID = guid
    LootSessionClient.hostName = hostName
    LootSessionClient.responses = responses
    LootSessionClient.candidates = {}
    LootSessionClient.isRunning = true
    LootSessionClient.items = {}
    Comm2:ClientSetAllowedHost(hostName)
    KeepAlive()
    LootSessionClient.OnStart:Trigger()
end

local function EndSession()
    if not LootSessionClient.isRunning then
        return
    end
    timers:CancelAll()
    LootSessionClient.isRunning = false
    Comm2:ClientSetAllowedHost("_nohost_")
    LootSessionClient.OnEnd:Trigger()
end

------------------------------------------------------------------------------------
--- Host Communiction
------------------------------------------------------------------------------------

Comm2.Events.HMSG_CANDIDATE_UPDATE:RegisterCallback(function(lcs, sender)
    LootSessionClient:HandleMessage_LootCandidate(lcs)
end)

Comm2.Events.HMSG_ITEM_ANNOUNCE:RegisterCallback(function(data, sender)
    LootSessionClient:HandleMessage_LootSessionItem(data)
end)

Comm2.Events.HMSG_ITEM_ANNOUNCE_ChildItem:RegisterCallback(function(data, sender)
    LootSessionClient:HandleMessage_LootSessionItemChild(data)
end)

Comm2.Events.HMSG_ITEM_RESPONSE_UPDATE:RegisterCallback(function(itemGuid, data, sender)
    LootSessionClient:HandleMessage_LootResponseUpdate(itemGuid, data)
end)

Comm2.Events.HMSG_ITEM_ROLL_END:RegisterCallback(function(itemGuid, sender)
    local item = LootSessionClient.items[itemGuid]
    if not item then return end
    LootSessionClient.OnItemUpdate:Trigger(item)
end)

Comm2.Events.HMSG_ITEM_UNVEIL:RegisterCallback(function(itemGuid, sender)
    local item = LootSessionClient.items[itemGuid]
    if not item then return end
    item.veiled = false
    LootSessionClient.OnItemUpdate:Trigger(item)
end)

------------------------------------------------------------------------------------
--- Candidate List
------------------------------------------------------------------------------------

---@param list LootCandidate[]
function LootSessionClient:HandleMessage_LootCandidate(list)
    LogDebug("Got candidate update list")
    Env:PrintVerbose(list)
    for _, lc in ipairs(list) do
        self.candidates[lc.name] = lc
    end
    self.OnCandidateUpdate:Trigger()
end

------------------------------------------------------------------
--- Items
------------------------------------------------------------------

---@param data PackedSessionItemClient
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

---@param itemGuid string
---@param data PackedSessionItemClient[]
function LootSessionClient:HandleMessage_LootResponseUpdate(itemGuid, data)
    local item = self.items[itemGuid]
    if not item then
        LogDebug("got item response update for unknown item", itemGuid)
    end
    for _, packedClient in ipairs(data) do
        local itemCLient = self:Parse_Packet_LootSessionItemClient(packedClient)
        if not itemCLient then
            return
        end
        item.responses[itemCLient.candidate.name] = itemCLient
    end

    LogDebug("item updated OnPacket_LootResponseUpdate", itemGuid)
    self.OnItemUpdate:Trigger(item)

    if item.childGUIDs and #item.childGUIDs > 0 then
        for _, childGUID in ipairs(item.childGUIDs) do
            local childItem = self.items[childGUID]
            if childItem then
                self.OnItemUpdate:Trigger(childItem)
            end
        end
    end
end

---@param data Packet_HMSG_ITEM_ANNOUNCE
function LootSessionClient:HandleMessage_LootSessionItem(data)
    if self.items[data.guid] then
        LogDebug("Got item announce but already have item!", data.guid)
        return
    end

    ---@type LootSessionClientItem
    local newItem = {
        guid = data.guid,
        order = data.order,
        itemId = data.itemId,
        veiled = data.veiled,
        startTime = data.startTime,
        endTime = data.endTime,
        responses = {},
        responseSent = false,
    }

    self.items[data.guid] = newItem
    Comm2.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Item added", newItem.guid)
    self.OnItemUpdate:Trigger(newItem)
end

---@param data Packet_HMSG_ITEM_ANNOUNCE_ChildItem
function LootSessionClient:HandleMessage_LootSessionItemChild(data)
    if self.items[data.guid] then
        LogDebug("Got item announce but already have item!", data.guid)
        return
    end

    local parentIitem = self.items[data.parentGUID]

    if not parentIitem then
        Env:PrintError(L["Got child item %s but data for parent %s doesn't exit!"]:format(data.guid, data.parentGUID))
        return
    end

    ---@type LootSessionClientItem
    local newItem = {
        guid = data.guid,
        order = data.order,
        itemId = parentIitem.itemId,
        veiled = parentIitem.veiled,
        startTime = parentIitem.startTime,
        endTime = parentIitem.endTime,
        responses = parentIitem.responses,
        responseSent = false,
        parentGUID = parentIitem.guid,
    }

    parentIitem.childGUIDs = parentIitem.childGUIDs or {}
    table.insert(parentIitem.childGUIDs, newItem.guid)

    self.items[data.guid] = newItem
    Comm2.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Child item added", newItem.guid, "parent", newItem.parentGUID)
    self.OnItemUpdate:Trigger(newItem)
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
    elseif item.parentGUID then
        Env:PrintError(L["Tried to respond to child item distribution %s!"]:format(itemGuid))
        return
    elseif item.endTime < time() then
        Env:PrintError(L["Item %s already expired, did not send response!"]:format(itemGuid))
        return
    end
    Comm2.Send.CMSG_ITEM_RESPONSE(itemGuid, responseId)
    item.responseSent = true
    self.OnItemUpdate:Trigger(item)
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

Comm2.Events.HMSG_SESSION_START:RegisterCallback(function(sessionGUID, responses, sender)
    if LootSessionClient.isRunning then
        LogDebug("Received HMSG_SESSION_START from", sender, "but already have a session.")
        return
    end
    LootSessionClient:Init(sender, sessionGUID, responses)
end)

Comm2.Events.HMSG_SESSION_END:RegisterCallback(function(sender)
    LogDebug("Recieved HMSG_SESSION_END from", sender)
    if LootSessionClient.hostName == sender then
        EndSession()
    end
end)
