---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local Comm = Env.SessionComm
local LootStatus = Env.Session.LootCandidateStatus
local ShouldAutopass = Env.Session.ShouldAutopass

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
---@field currentPoints integer

---@class (exact) SessionClient_ItemResponse
---@field candidate SessionClient_Candidate
---@field response LootResponse|nil
---@field status LootCandidateStatus
---@field roll integer|nil
---@field currentItem integer[]? ItemIds [item1[,item2]] for currently equipped items. Item2 is used for rings and trinkets.

---@class (exact) SessionClient_ItemAwardData
---@field candidateName string The name of the player the item was awarded to.
---@field usedResponse LootResponse
---@field pointsSnapshot? table<string,integer> Snapshot of point count the award was based on.

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
---@field awarded SessionClient_ItemAwardData?
---@field isGarbage boolean

---@class (exact) SessionClient
---@field guid string
---@field hostName string The name of the hosting player.
---@field responses LootResponses|nil
---@field pointsMinForRoll integer
---@field pointsMaxRange integer
---@field candidates table<string, SessionClient_Candidate>
---@field isRunning boolean
---@field items table<string, SessionClient_Item>
local Client = {}
Env.SessionClient = Client

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
---@field RegisterCallback fun(self:LSClientItemUpdateEvent, cb:fun(item:SessionClient_Item, isAwardEvent:boolean))
---@field Trigger fun(self:LSClientItemUpdateEvent, item:SessionClient_Item, isAwardEvent:boolean)
---@diagnostic disable-next-line: inject-field
Client.OnItemUpdate = Env:NewEventEmitter()

------------------------------------------------------------------------------------
--- Construction
------------------------------------------------------------------------------------

local KEEP_ALIVE_INTERVAL = Env.Session.CLIENT_KEEPALIVE_TIME
local HOST_MAX_MSG_INTERVAL = Env.Session.HOST_TIMEOUT_TIME

local timers = Env:NewUniqueTimers()

local function KeepAlive()
    if not Client.isRunning then return end
    Comm.Send.CMSG_ATTENDANCE_CHECK()
    timers:StartUnique("keepaliveTimer", KEEP_ALIVE_INTERVAL, KeepAlive)
end

---Reset and initialize client session.
---@param hostName string
---@param guid string
---@param responses LootResponses
function InitClient(hostName, guid, responses, pointsMinForRoll, pointsMaxRange)
    Client.guid = guid
    Client.hostName = hostName
    Client.responses = responses
    Client.candidates = {}
    Client.isRunning = true
    Client.pointsMinForRoll = pointsMinForRoll
    Client.pointsMaxRange = pointsMaxRange
    Client.items = {}
    Comm:ClientSetAllowedHost(hostName)
    KeepAlive()
    Client:CheckHostAlive()
    Env:RegisterEvent("UNIT_CONNECTION", Client)
    Env:RegisterEvent("GROUP_LEFT", Client)
    Client.OnStart:Trigger()
end

local function EndSession()
    if not Client.isRunning then return end
    timers:CancelAll()
    Client.isRunning = false
    Comm:ClientSetAllowedHost()
    Env:UnregisterEvent("UNIT_CONNECTION", Client)
    Env:UnregisterEvent("GROUP_LEFT", Client)
    Client.OnEnd:Trigger()
end

function Client:CheckHostAlive()
    if not Client.isRunning then return end
    local lastHostMessageAge = Comm.GetLastReceivedAgo(Client.hostName)
    if lastHostMessageAge > HOST_MAX_MSG_INTERVAL then
        Env:PrintWarn(L["Host %s did not send any messages for %d seconds. Ending session."]:format(Client.hostName, HOST_MAX_MSG_INTERVAL))
        EndSession()
        return
    end
    timers:StartUnique("CheckHostAliveTimer", 2, "CheckHostAlive", self)
end

---@private
function Client:GROUP_LEFT()
    if not self.isRunning then return end
    Env:PrintError(L["Session ended because you left the group!"])
    EndSession()
end

Comm.Events.HMSG_SESSION_START:RegisterCallback(function(data, responses, sender)
    if Client.isRunning and Client.hostName ~= sender then
        local lastMsgAgeCurrentHost = Comm.GetLastReceivedAgo(Client.hostName)
        if not lastMsgAgeCurrentHost or lastMsgAgeCurrentHost > HOST_MAX_MSG_INTERVAL then
            Env:PrintWarn(L["New session start from %s and current host %s stopped sending data, starting new session."]:format(sender, Client.hostName))
        else
            LogDebug("Received HMSG_SESSION_START from", sender, "but already have a session from", Client.hostName)
            return
        end
    end

    if sender ~= UnitName("player") and not Env.Session.CanUnitStartSession(sender) then
        LogDebug("Received HMSG_SESSION_START from", sender, "but sender has no permission to start a session")
        return
    end

    if Client.isRunning then
        EndSession()
    end

    InitClient(sender, data.guid, responses, data.pointsMinForRoll, data.pointsMaxRange)
end)

Comm.Events.HMSG_SESSION_END:RegisterCallback(function(sender)
    EndSession()
end)

Comm.Events.HMSG_ITEM_ROLL_END:RegisterCallback(function(itemGuid, sender)
    local item = Client.items[itemGuid]
    if not item then return end
    local now = time()
    if item.endTime > now then
        Client:DoForEachRelatedItem(item, true, function(relatedItem)
            relatedItem.endTime = now
        end)
        LogDebug("Item", itemGuid, "dist was closed before default timeout, ran for", item.endTime - item.startTime)
    end
    Client.OnItemUpdate:Trigger(item, false)
end)

Comm.Events.HMSG_ITEM_UPDATE:RegisterCallback(function(data, sender)
    local item = Client.items[data.guid]
    if not item then return end
    if item.veiled and not data.isVeiled then
        for _, response in pairs(item.responses) do
            if response.status.id == LootStatus.veiled.id then
                response.status = LootStatus.unveiled
            end
        end
    end
    item.veiled = data.isVeiled
    item.isGarbage = data.isGarbage
    LogDebug("item update", tostring(item.veiled), tostring(item.isGarbage))
    Client.OnItemUpdate:Trigger(item, false)
end)

------------------------------------------------------------------------------------
--- Candidate List
------------------------------------------------------------------------------------

Comm.Events.HMSG_CANDIDATE_UPDATE:RegisterCallback(function(lcs, sender)
    Env:PrintVerbose(lcs)
    for _, lc in ipairs(lcs) do
        if not Client.candidates[lc.name] then
            Client.candidates[lc.name] = {
                name = lc.name,
                classId = lc.classId,
                leftGroup = lc.leftGroup,
                isResponding = lc.isResponding,
                isOffline = not UnitIsConnected(lc.name),
                currentPoints = lc.currentPoints,
            }
        else
            local candidate = Client.candidates[lc.name]
            candidate.leftGroup = lc.leftGroup
            candidate.isResponding = lc.isResponding
            candidate.isOffline = not UnitIsConnected(lc.name)
            candidate.currentPoints = lc.currentPoints
        end
    end
    Client.OnCandidateUpdate:Trigger()
end)

Comm.Events.HMSG_CANDIDATE_STATUS_UPDATE:RegisterCallback(function(lcs, sender)
    Env:PrintVerbose(lcs)
    for _, lc in ipairs(lcs) do
        local candidate = Client.candidates[lc.name]
        if not candidate then
            Env:PrintError("Got HMSG_CANDIDATE_STATUS_UPDATE for unknown candidate " .. lc.name)
            return
        end
        candidate.leftGroup = lc.leftGroup
        candidate.isResponding = lc.isResponding
        candidate.isOffline = not UnitIsConnected(lc.name)
    end
    Client.OnCandidateUpdate:Trigger()
end)

---@private
---@param unit string
---@param isConnected boolean
function Client:UNIT_CONNECTION(unit, isConnected)
    local name = UnitName(unit)

    if name == Client.hostName and not isConnected then
        Env:PrintWarn(L["Host %s went offline, ending session."]:format(Client.hostName))
        EndSession()
        return
    end

    local candidate = Client.candidates[name]
    LogDebug("UNIT_CONNECTION", name, isConnected, "have candidate", candidate ~= nil)
    if candidate and candidate.isOffline == isConnected then
        candidate.isOffline = not isConnected
        Client.OnCandidateUpdate:Trigger()
    end
end

------------------------------------------------------------------
--- Items
------------------------------------------------------------------

---@param item SessionClient_Item
---@param data PackedSessionItemClient
local function UpdateResponseFromPacket(item, data)
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
        local entry = item.responses[candidate.name]
        if entry then
            entry.response = response
            entry.status = status
            entry.roll = data.roll
        else
            item.responses[candidate.name] = {
                name = data.candidate,
                candidate = candidate,
                response = response,
                status = status,
                roll = data.roll,
            }
        end
    end
end

Comm.Events.HMSG_ITEM_RESPONSE_UPDATE:RegisterCallback(function(itemGuid, data, sender)
    local item = Client.items[itemGuid]
    if not item then
        LogDebug("got item response update for unknown item", itemGuid)
        return
    end
    for _, packedClient in ipairs(data) do
        UpdateResponseFromPacket(item, packedClient)
    end
    LogDebug("item updated HMSG_ITEM_RESPONSE_UPDATE", itemGuid)
    Client.OnItemUpdate:Trigger(item, false)
    if item.childGuids and #item.childGuids > 0 then
        for _, childGuid in ipairs(item.childGuids) do
            local childItem = Client.items[childGuid]
            if childItem then
                Client.OnItemUpdate:Trigger(childItem, false)
            end
        end
    end
end)

-- itemGuid -> candidateName -> [link1[, link2]]
local gearReceivedBuffer = {} ---@type table<string, table<string, integer[]>>

Comm.Events.CBMSG_ITEM_CURRENTLY_EQUIPPED:RegisterCallback(function(sender, data)
    if not Client.isRunning then return end
    local item = Client.items[data.itemGuid]
    if item then
        local itemResponse = item.responses[sender]
        if not itemResponse then
            LogDebug("Tried to add currently equipped items but candidate doesn't exist.", item.guid, sender)
            return
        end
        itemResponse.currentItem = data.currentItems
        LogDebug("Added current items for candidate.", item.guid, sender, unpack(data.currentItems))
        Client.OnItemUpdate:Trigger(item, false)
        return
    end
    LogDebug("Adding current items to buffer because we did not yet get item data.", data.itemGuid, sender)
    gearReceivedBuffer[data.itemGuid] = gearReceivedBuffer[data.itemGuid] or {}
    gearReceivedBuffer[data.itemGuid][sender] = data.currentItems
end)

Comm.Events.HMSG_ITEM_ANNOUNCE:RegisterCallback(function(data, sender)
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
        isGarbage = false,
    }

    local gearBuffer = gearReceivedBuffer[newItem.guid]
    gearReceivedBuffer[newItem.guid] = nil
    for k, v in pairs(Client.candidates) do
        newItem.responses[k] = {
            candidate = v,
            status = LootStatus.veiled,
        }
        if gearBuffer and gearBuffer[v.name] then
            newItem.responses[k].currentItem = gearBuffer[v.name]
        end
    end

    Client.items[data.guid] = newItem
    Comm.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Item added", newItem.guid)

    Env.Item.DoWhenItemInfoReady(newItem.itemId, function(_, itemLink, _, _, _, _, _, _, itemEquipLoc, _, _, classId, subclassId)
        -- If item is known this will be synchronous and not even show it at all.
        -- TODO: Delay adding/showing item if it needs to be loaded?
        -- Item should be cached at this point though, because client should have seen it drop.
        if ShouldAutopass(itemLink, classId, subclassId) then
            Client:RespondToItem(newItem.guid, Client.responses:GetAutoPass().id)
        end
        Client.OnItemUpdate:Trigger(newItem, false)

        local current1, current2 = Env.Item.GetCurrentlyEquippedItem(itemEquipLoc)
        local current1Id = current1 and Env.Item.GetIdFromLink(current1) or nil
        local current2Id = current2 and Env.Item.GetIdFromLink(current2) or nil
        Comm.Send.CBMSG_ITEM_CURRENTLY_EQUIPPED(newItem.guid, { current1Id, current2Id })
        LogDebug("Gear sent", newItem.guid, current1, current2)
    end)
end)

Comm.Events.HMSG_ITEM_ANNOUNCE_ChildItem:RegisterCallback(function(data, sender)
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
        isGarbage = false,
    }

    parentIitem.childGuids = parentIitem.childGuids or {}
    table.insert(parentIitem.childGuids, newItem.guid)

    Client.items[data.guid] = newItem
    Comm.Send.CMSG_ITEM_RECEIVED(newItem.guid)
    LogDebug("Child item added", newItem.guid, "parent", newItem.parentGuid)
    Client.OnItemUpdate:Trigger(newItem, false)
end)

---Send reponse for an item roll.
---@param itemGuid string
---@param responseId integer
function Client:RespondToItem(itemGuid, responseId)
    local item = self.items[itemGuid]
    local response = self.responses:GetResponse(responseId)
    if not item then
        Env:PrintError(L["Tried to respond to item %s but distribution with that GUID doesn't exist!"]:format(itemGuid))
        return
    elseif not response then
        Env:PrintError(L["Tried to respond with response Id %d but response doesn't exist!"]:format(responseId))
        return
    elseif item.parentGuid then
        Env:PrintError(L["Tried to respond to child item distribution %s!"]:format(itemGuid))
        return
    elseif item.endTime < time() then
        Env:PrintError(L["Item %s already expired, did not send response!"]:format(itemGuid))
        return
    end
    Comm.Send.CMSG_ITEM_RESPONSE(itemGuid, responseId)
    item.responseSent = true
    local myName = UnitName("player")
    if item.responses[myName] then
        item.responses[myName].response = response
    end
    self.OnItemUpdate:Trigger(item, false)
end

Comm.Events.HMSG_ITEM_AWARD_UPDATE:RegisterCallback(function(data, sender)
    local item = Client.items[data.itemGuid]
    if not item then
        LogDebug("got HMSG_ITEM_AWARD_UPDATE for unknown item", data.itemGuid)
        return
    end
    if data.candidateName then
        local response = Client.responses:GetResponse(data.responseId)
        if not response then
            LogDebug("got HMSG_ITEM_AWARD_UPDATE for unknown response", data.responseId)
            return
        end
        item.awarded = {
            candidateName = data.candidateName,
            pointsSnapshot = data.pointSnapshot,
            usedResponse = response,
        }
    else
        item.awarded = nil
    end
    LogDebug("item awarded updated", data.itemGuid, data.candidateName)
    Client.OnItemUpdate:Trigger(item, data.candidateName ~= nil)
end)

---@return integer
function Client:GetItemCount()
    local count = 0
    for _ in pairs(self.items) do
        count = count + 1
    end
    return count
end

---Run func for each realted item, i.e. children or parent and other children of the parent.
---@param item SessionClient_Item
---@param includeThis boolean Run function for the argument item too.
---@param func fun(relatedItem:SessionClient_Item, isThis:boolean):boolean? Return true to break out after this callback.
function Client:DoForEachRelatedItem(item, includeThis, func)
    local childGuids = item.childGuids
    if item.parentGuid then
        local pitem = self.items[item.parentGuid] ---@type SessionClient_Item?
        if pitem then
            if func(pitem, false) then return end
            childGuids = pitem.childGuids
        end
    elseif includeThis then
        if func(item, true) then return end
    end
    if childGuids then
        for _, childGuid in ipairs(childGuids) do
            local isThis = childGuid == item.guid
            if not isThis or includeThis then
                local citem = self.items[childGuid]
                if citem then
                    if func(citem, isThis) then return end
                end
            end
        end
    end
end
