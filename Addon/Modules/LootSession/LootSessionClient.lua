---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Comm2 = Env.Session.Comm2
local LootStatus = Env.Session.LootCandidateStatus

local function LogDebug(...)
    Env:PrintDebug("Client:", ...)
end

------------------------------------------------------------------------------------
--- Data Structure Types
------------------------------------------------------------------------------------

---@class (exact) SessionClient_Candidate
---@field name string
---@field classId integer
---@field isOffline boolean
---@field leftGroup boolean
---@field isResponding boolean

---@class (exact) SessionClient_ItemResponse
---@field candidate SessionClient_Candidate
---@field response LootResponse|nil
---@field status LootCandidateStatus
---@field roll integer|nil
---@field sanity integer|nil

---@class (exact) SessionClient_Item
---@field guid string
---@field order integer The order/position of the item. 
---@field itemId integer The game's item Id.
---@field veiled boolean Whether this item's responses are shown to the client.
---@field startTime integer time() stamp of when the roll started.
---@field endTime integer time() stamp of when the roll ends.
---@field responseSent boolean To keep track of whether an response was sent, purely clientside.
---@field parentGuid string|nil
---@field childGuids string[]|nil
---@field responses table<string, SessionClient_ItemResponse>
---@field awardedTo string|nil

---@class (exact) SessionClient
---@field guid string
---@field hostName string The name of the hosting player.
---@field responses LootResponses|nil
---@field candidates table<string, SessionClient_Candidate>
---@field isRunning boolean
---@field items table<string, SessionClient_Item>
local Client = {}
Env.Session.Client = Client

------------------------------------------------------------------------------------
--- Events
------------------------------------------------------------------------------------

---@class (exact) LootSessionClientStartEvent
---@field RegisterCallback fun(self:LootSessionClientStartEvent, cb:fun())
---@field Trigger fun(self:LootSessionClientStartEvent)
---@diagnostic disable-next-line: inject-field
Client.OnStart = Env:NewEventEmitter()

---@class (exact) LSClientEndEvent
---@field RegisterCallback fun(self:LSClientEndEvent, cb:fun())
---@field Trigger fun(self:LSClientEndEvent)
---@diagnostic disable-next-line: inject-field
Client.OnEnd = Env:NewEventEmitter()

---@class (exact) LSClientCandidateUpdateEvent
---@field RegisterCallback fun(self:LSClientCandidateUpdateEvent, cb:fun())
---@field Trigger fun(self:LSClientCandidateUpdateEvent)
---@diagnostic disable-next-line: inject-field
Client.OnCandidateUpdate = Env:NewEventEmitter()

---@class (exact) LSClientItemUpdateEvent
---@field RegisterCallback fun(self:LSClientItemUpdateEvent, cb:fun(item:SessionClient_Item))
---@field Trigger fun(self:LSClientItemUpdateEvent, item:SessionClient_Item)
---@diagnostic disable-next-line: inject-field
Client.OnItemUpdate = Env:NewEventEmitter()

------------------------------------------------------------------------------------
--- Construction
------------------------------------------------------------------------------------

local timers = Env:NewUniqueTimers()

local function KeepAlive()
    if not Client.isRunning then return end
    Comm2.Send.CMSG_ATTENDANCE_CHECK()
    timers:StartUnique("keepaliveTimer", 20, KeepAlive)
end

---Reset and initialize client session.
---@param hostName string
---@param guid string
---@param responses LootResponses
function InitClient(hostName, guid, responses)
    Client.guid = guid
    Client.hostName = hostName
    Client.responses = responses
    Client.candidates = {}
    Client.isRunning = true
    Client.items = {}
    Comm2:ClientSetAllowedHost(hostName)
    KeepAlive()
    Client.OnStart:Trigger()
end

local function EndSession()
    if not Client.isRunning then return end
    timers:CancelAll()
    Client.isRunning = false
    Comm2:ClientSetAllowedHost("_nohost_")
    Client.OnEnd:Trigger()
end

Comm2.Events.HMSG_SESSION_START:RegisterCallback(function(guid, responses, sender)
    if Client.isRunning and Client.hostName ~= sender then
        LogDebug("Received HMSG_SESSION_START from", sender, "but already have a session from", Client.hostName)
        return
    end
    InitClient(sender, guid, responses)
end)

Comm2.Events.HMSG_SESSION_END:RegisterCallback(function(sender)
    EndSession()
end)

Comm2.Events.HMSG_ITEM_ROLL_END:RegisterCallback(function(itemGuid, sender)
    local item = Client.items[itemGuid]
    if not item then return end
    Client.OnItemUpdate:Trigger(item)
end)

Comm2.Events.HMSG_ITEM_UNVEIL:RegisterCallback(function(itemGuid, sender)
    local item = Client.items[itemGuid]
    if not item then return end
    item.veiled = false
    Client.OnItemUpdate:Trigger(item)
end)

------------------------------------------------------------------------------------
--- Candidate List
------------------------------------------------------------------------------------

Comm2.Events.HMSG_CANDIDATE_UPDATE:RegisterCallback(function(lcs, sender)
    Env:PrintVerbose(lcs)
    for _, lc in ipairs(lcs) do
        Client.candidates[lc.name] = lc
    end
    Client.OnCandidateUpdate:Trigger()
end)

------------------------------------------------------------------
--- Items
------------------------------------------------------------------

---@param data PackedSessionItemClient
local function GetClientFromPackedClient(data)
    local candidate = Client.candidates[data.candidate]
    local response = data.responseId and Client.responses:GetResponse(data.responseId)
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
        ---@type SessionClient_ItemResponse
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

Comm2.Events.HMSG_ITEM_RESPONSE_UPDATE:RegisterCallback(function(itemGuid, data, sender)
    local item = Client.items[itemGuid]
    if not item then
        LogDebug("got item response update for unknown item", itemGuid)
    end
    for _, packedClient in ipairs(data) do
        local itemCLient = GetClientFromPackedClient(packedClient)
        if not itemCLient then
            return
        end
        item.responses[itemCLient.candidate.name] = itemCLient
    end

    LogDebug("item updated OnPacket_LootResponseUpdate", itemGuid)
    Client.OnItemUpdate:Trigger(item)

    if item.childGuids and #item.childGuids > 0 then
        for _, childGuid in ipairs(item.childGuids) do
            local childItem = Client.items[childGuid]
            if childItem then
                Client.OnItemUpdate:Trigger(childItem)
            end
        end
    end
end)

Comm2.Events.HMSG_ITEM_ANNOUNCE:RegisterCallback(function(data, sender)
    if Client.items[data.guid] then
        LogDebug("Got item announce but already have item!", data.guid)
        return
    end

    ---@type SessionClient_Item
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

    Client.items[data.guid] = newItem
    Comm2.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Item added", newItem.guid)
    Client.OnItemUpdate:Trigger(newItem)
end)


Comm2.Events.HMSG_ITEM_ANNOUNCE_ChildItem:RegisterCallback(function(data, sender)
    if Client.items[data.guid] then
        LogDebug("Got item announce but already have item!", data.guid)
        return
    end

    local parentIitem = Client.items[data.parentGuid]

    if not parentIitem then
        Env:PrintError(L["Got child item %s but data for parent %s doesn't exit!"]:format(data.guid, data.parentGuid))
        return
    end

    ---@type SessionClient_Item
    local newItem = {
        guid = data.guid,
        order = data.order,
        itemId = parentIitem.itemId,
        veiled = parentIitem.veiled,
        startTime = parentIitem.startTime,
        endTime = parentIitem.endTime,
        responses = parentIitem.responses,
        responseSent = false,
        parentGuid = parentIitem.guid,
    }

    parentIitem.childGuids = parentIitem.childGuids or {}
    table.insert(parentIitem.childGuids, newItem.guid)

    Client.items[data.guid] = newItem
    Comm2.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Child item added", newItem.guid, "parent", newItem.parentGuid)
    Client.OnItemUpdate:Trigger(newItem)
end)

---Send reponse for an item roll.
---@param itemGuid string
---@param responseId integer
function Client:RespondToItem(itemGuid, responseId)
    local item = self.items[itemGuid]
    if not item then
        Env:PrintError(L["Tried to respond to item %s but distribution with that GUID doesn't exist!"]:format(itemGuid))
        return
    elseif not self.responses:GetResponse(responseId) then
        Env:PrintError(L["Tried to respond with response Id %d but response doesn't exist!"]:format(responseId))
        return
    elseif item.parentGuid then
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
