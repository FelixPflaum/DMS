---@class AddonEnv
local DMS = select(2, ...)
local L = DMS:GetLocalization()

DMS.Session.Host = {}

local Net = DMS.Net
local Comm = DMS.Session.Comm

---@alias CommTarget "group"|"guild"|"self"

---@class (exact) LootCandidate
---@field name string
---@field classId integer
---@field isOffline boolean
---@field leftGroup boolean
---@field isReady boolean
---@field lastMessage integer

---@class (exact) LootSessionHostItemClient
---@field candidate LootCandidate
---@field status LootClientStatus
---@field response LootResponse|nil
---@field roll [integer,integer]|nil

---@class (exact) LootSessionHostItem
---@field distributionGUID string Unique id for that specific loot distribution.
---@field order integer For ordering items in the UI.
---@field parentGUID string|nil If this item is a duplicate this will be the guid of the main item, i.e. the one people respond to.
---@field duplicateGUIDs string[]|nil If duplicates of the item exist their guids will be in here.
---@field itemId integer
---@field veiled boolean
---@field startTime integer
---@field endTime integer
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
---@field timers table<string, {expires:number, exec:fun(sess:LootSessionHost)}>
local LootSessionHost = {}
---@diagnostic disable-next-line: inject-field
LootSessionHost.__index = LootSessionHost

---@param target CommTarget
local function NewLootSessionHost(target)
    ---@type LootSessionHost
    local session = {
        sessionGUID = DMS:MakeGUID(),
        target = target,
        responses = DMS.Session:CreateLootResponses(),
        candidates = {},
        isFinished = false,
        itemCount = 0,
        items = {},
        timers = {},
    }
    setmetatable(session, LootSessionHost)
    session:Setup()
    return session
end

---Send comm message to target channel.
---@param opcode OpCode
---@param data any
function LootSessionHost:Broadcast(opcode, data)
    if self.target == "self" then
        DMS:PrintDebug("Sending broadcast whisper", opcode)
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
            DMS:PrintError("Tried to broadcast to group but not in a group! Ending session.")
            self:Destroy()
        end
    elseif self.target == "guild" then
        channel = "GUILD"
    end

    DMS:PrintDebug("Sending broadcast", channel, opcode)
    Net:Send(Comm.PREFIX, channel, opcode, data)
end

function LootSessionHost:Setup()
    DMS:RegisterEvent("GROUP_ROSTER_UPDATE", self)
    DMS:RegisterEvent("GROUP_LEFT", self)

    DMS:PrintSuccess("Started a new host session for " .. self.target)
    DMS:PrintDebug("Session GUID", self.sessionGUID)
    self:Broadcast(Comm.OpCodes.HMSG_SESSION, Comm:Packet_MakeSessionHost(self))

    self:UpdateCandidateList()
    -- TODO: Update responses if player db changes (points)
end

function LootSessionHost:Destroy()
    if self.isFinished then
        return
    end

    self.isFinished = true

    DMS:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    DMS:UnregisterEvent("GROUP_LEFT", self)

    self:Broadcast(Comm.OpCodes.HMSG_SESSION_END, self.sessionGUID)
end

function LootSessionHost:GROUP_LEFT()
    if self.isFinished then return end
    if self.target == "group" then
        DMS:PrintError("Session host destroyed because you left the group!")
        self:Destroy()
    end
end

function LootSessionHost:GROUP_ROSTER_UPDATE()
    DMS:PrintDebug("LootSessionHost GROUP_ROSTER_UPDATE")
    self:UpdateCandidateList()
end

---Create list of loot candidates, i.e. list of all raid members at this point in time.
---Players that leave the party will be kept in the list if an existing list is provided.
function LootSessionHost:UpdateCandidateList()
    ---@type table<string, LootCandidate>
    local newList = {}
    local prefix = ""
    local changed = 0
    ---@type table<string, LootCandidate>
    local changedLootCandidates = {}

    if self.target == "group" then
        if IsInRaid() then
            prefix = "raid"
        elseif IsInGroup() then
            prefix = "party"
        else
            DMS:PrintError("Tried to update candidates but not in a group! Ending session.")
            self:Destroy()
        end
    elseif self.target == "guild" then
        prefix = "" -- Not supported, same as self test mode
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
            isReady = false,
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
                isReady = false,
                lastMessage = 0,
            }
        end
    end

    for oldName, oldEntry in pairs(self.candidates) do
        local newEntry = newList[oldName]

        if newEntry == nil then
            if not oldEntry.leftGroup then
                oldEntry.leftGroup = true
                changed = changed + 1
                changedLootCandidates[oldName] = oldEntry
            end
        else
            if oldEntry.leftGroup then
                oldEntry.leftGroup = false
                changed = changed + 1
                changedLootCandidates[oldName] = oldEntry
            end
            if oldEntry.isOffline ~= newEntry.isOffline then
                oldEntry.isOffline = newEntry.isOffline
                changed = changed + 1
                changedLootCandidates[oldName] = oldEntry
            end
        end
    end

    for newName, newEntry in pairs(newList) do
        if not self.candidates[newName] then
            self.candidates[newName] = newEntry
            changed = changed + 1
            changedLootCandidates[newName] = newEntry
        end
    end

    if changed > 0 then
        --- Add new member to open and non-awarded items
        for _, item in pairs(self.items) do
            if not item.awardedTo and not item.parentGUID then
                for name, candidate in pairs(self.candidates) do
                    if not item.responses[name] then
                        item.responses[name] = {
                            candidate = candidate,
                            status = DMS.Session.LootStatus.dataNotSent,
                        }
                    end
                end
            end
        end

        if DMS.settings.debug then
            print("Changed candidates:")
            for _, lc in pairs(changedLootCandidates) do
                print(" - ", lc.name)
            end
        end

        ---@type Packet_LootCandidate[]
        local lcPacketList = {}
        for _, lc in pairs(changedLootCandidates) do
            table.insert(lcPacketList, Comm:Packet_Candidate(lc))
        end
        self:Broadcast(Comm.OpCodes.HMSG_CANDIDATES_UPDATE, lcPacketList)
    end
end

------------------------------------------------------------------
--- API
------------------------------------------------------------------

---@type LootSessionHost|nil
local hostSession = nil

---Start a new host session.
---@param target CommTarget
---@return string|nil errorMessage
function DMS.Session.Host:Start(target)
    if hostSession and not hostSession.isFinished then
        return L["A host session is already running."]
    end
    if target == "group" then
        if not IsInRaid() and not IsInGroup() then
            return L["Host target group does not work outside of a group!"]
        end
    elseif target == "guild" then
        -- TODO
    elseif target ~= "self" then
        return L["Invalid host target! Valid values are: %s, %s and %s."]:format("group", "guild", "self")
    end
    DMS:PrintDebug("Starting host session with target: ", target)
    hostSession = NewLootSessionHost(target)
end

function DMS.Session.Host:GetSession()
    return hostSession
end

DMS:RegisterSlashCommand("host", L["Start a new loot session."], function(args)
    local target = args[1] or "group"
    local err = DMS.Session.Host:Start(target)
    if err then
        DMS:PrintError(err)
    end
end)

DMS:RegisterSlashCommand("end", L["End hosting a loot session."], function(args)
    if not hostSession then
        DMS:PrintWarn(L["No session is running."])
        return
    end
    DMS:PrintSuccess("Destroy host session...")
    hostSession:Destroy()
end)
