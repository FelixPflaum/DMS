---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("VC:", ...)
end

local Net = Env.Net

local VersionCheck = {}
Env.VersionCheck = VersionCheck

---@enum OpcodeVersionCheck
local VC_OPCODES = {
    REQUEST_VERSION = 1,
    MY_VERSION = 2,
}
local VC_COMM_PREFIX = "DMSVerCheck"
local RESPONSE_TIMEOUT = 10
local VERSION = C_AddOns.GetAddOnMetadata(select(1, ...), "Version") or "999.0.0"

local isEnabled = false
local currentTimeoutTimer = nil ---@type TimerHandle?
---@alias ResponseData {state:"waiting"|"response"|"timeout", version:string, versionNum:integer}
local responseList = {} ---@type table<string,ResponseData>

---@class (exact) VersionCheckUpdateEvent
---@field RegisterCallback fun(self:VersionCheckUpdateEvent, cb:fun(list:table<string,ResponseData>))
---@field Trigger fun(self:VersionCheckUpdateEvent, list:table<string,ResponseData>)
VersionCheck.OnResponsesUpdate = Env:NewEventEmitter()

---@class (exact) VersionCheckTimeoutEvent
---@field RegisterCallback fun(self:VersionCheckTimeoutEvent, cb:fun(isTimeout:boolean))
---@field Trigger fun(self:VersionCheckTimeoutEvent, isTimeout:boolean)
VersionCheck.OnAllResponded = Env:NewEventEmitter()

local function FillFromGuild()
    local size = GetNumGuildMembers()
    local haveOnline = false
    if size == 0 then
        return false
    end
    LogDebug("fill guild")
    wipe(responseList)
    for i = 1, size do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            responseList[name] = {
                state = "waiting",
                version = "",
                versionNum = 0,
            }
            haveOnline = true
        end
    end
    return haveOnline
end

local function FillFromGroup()
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return false
    end
    LogDebug("fill group")
    wipe(responseList)
    for unit in Env.MakeGroupIterator() do
        local name = UnitName(unit)
        responseList[name] = {
            state = "waiting",
            version = "",
            versionNum = 0,
        }
    end
    return true
end

---@param channel "RAID"|"GUILD"
function VersionCheck.SendRequest(channel)
    local filled = false
    if channel == "GUILD" then
        filled = FillFromGuild()
    else
        filled = FillFromGroup()
    end

    if not filled then
        VersionCheck.OnAllResponded:Trigger(true)
        return
    end

    Net:Send(VC_COMM_PREFIX, channel, VC_OPCODES.REQUEST_VERSION, "NORMAL")

    if currentTimeoutTimer then
        currentTimeoutTimer:Cancel()
    end
    currentTimeoutTimer = C_Timer.NewTimer(RESPONSE_TIMEOUT, function(t)
        for _, v in pairs(responseList) do
            if v.state == "waiting" then
                v.state = "timeout"
            end
        end
        VersionCheck.OnAllResponded:Trigger(true)
        VersionCheck.OnResponsesUpdate:Trigger(responseList)
    end)

    VersionCheck.OnResponsesUpdate:Trigger(responseList)
end

---Pack version into one int. x.y.z will each use 10 bit, with z using the lowest order ones.
---@param ver string
---@return integer packed
local function PackVersion(ver)
    local ver1, ver2, ver3 = strsplit(".", ver)
    local ver1Num = tonumber(ver1) or 0 ---@cast ver1Num integer
    local ver2Num = tonumber(ver2) or 0 ---@cast ver2Num integer
    local ver3Num = tonumber(ver3) or 0 ---@cast ver3Num integer
    return bit.lshift(ver1Num, 20) + bit.lshift(ver2Num, 10) + ver3Num
end

---Get version as string and in packed format (x.y.z becomes 10b-10b-10b in an integer)
---@return string
---@return integer
function VersionCheck.GetMyVersion()
    return VERSION, PackVersion(VERSION)
end

Env:OnAddonLoaded(function(...)
    Env.Net:Register(VC_COMM_PREFIX, function(channel, sender, opcode, data)
        if opcode == VC_OPCODES.REQUEST_VERSION then
            if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "GUILD" then return end
            Net:SendWhisper(VC_COMM_PREFIX, sender, VC_OPCODES.MY_VERSION, "NORMAL", VERSION)
        elseif opcode == VC_OPCODES.MY_VERSION then
            if channel ~= "WHISPER" then return end
            if isEnabled and responseList[sender] then
                responseList[sender].state = "response"
                responseList[sender].version = data
                responseList[sender].versionNum = PackVersion(data)
                VersionCheck.OnResponsesUpdate:Trigger(responseList)

                local allResponded = true
                for _, v in pairs(responseList) do
                    if v.state ~= "response" then
                        allResponded = false
                        break
                    end
                end
                if allResponded then
                    VersionCheck.OnAllResponded:Trigger(false)
                end
            end
        else
            LogDebug("Unhandled opcode received:", opcode, sender)
        end
    end)
end)

---Enable or disable addon communication.
---@param enabled boolean Whether to enable or disable comm.
function VersionCheck.Enable(enabled)
    isEnabled = enabled
    LogDebug("enabled:", tostring(isEnabled))
    if not isEnabled then
        if currentTimeoutTimer then
            currentTimeoutTimer:Cancel()
        end
        responseList = {}
        VersionCheck.OnResponsesUpdate:Trigger(responseList)
        VersionCheck.OnAllResponded:Trigger(true)
    end
end
