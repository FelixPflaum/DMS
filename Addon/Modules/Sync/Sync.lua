---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("Sync:", ...)
end

local Net = Env.Net

local Sync = {}
Env.Sync = Sync

---@alias SyncDataType "settings"

---@enum OpcodeSync
local SYNC_OPCODES = {
    PROBE_RECEIVER = 1,
    PROBE_RECEIVED = 2,
    PROBE_RESPONSE = 3,
    SEND_SESSION_SETTINGS = 4,
}
local SYNC_COMM_PREFIX = "DMSSync"

local commHandler = {} ---@type table<OpcodeSync,fun(sender:string, data:any)>
local isEnabled = false

--------------------------------------------------------------------------------------------------------------------
--- Sending side
--------------------------------------------------------------------------------------------------------------------

local PROBE_TIMEOUT = 5
local RESPONSE_TIMEOUT = 10

---@alias SendState "probing"|"waiting"|"sending"|"failed"
local initiatedSyncs = {} ---@type table<string,{type:SyncDataType,state:SendState,timer:TimerHandle}>

---@class (exact) SendProgressEventEmitter
---@field RegisterCallback fun(self:SendProgressEventEmitter, cb:fun(target:string, state:SendState, sent:number, total:number))
---@field Trigger fun(self:SendProgressEventEmitter, target:string, state:SendState, sent:number, total:number)
Sync.OnSendProgress = Env:NewEventEmitter()

local function FailProbe(target)
    initiatedSyncs[target] = nil
    Sync.OnSendProgress:Trigger(target, "failed", 0, 0)
end

---Send probe packet to target.
---@param target string The name of the player to probe for receiver readiness.
---@param dataType SyncDataType
local function SendProbe(target, dataType)
    if initiatedSyncs[target] then
        return false
    end
    LogDebug("Sending probe to", target, dataType)
    Net:SendWhisper(SYNC_COMM_PREFIX, target, SYNC_OPCODES.PROBE_RECEIVER, dataType)
    local th = C_Timer.NewTimer(PROBE_TIMEOUT, function(t)
        FailProbe(target)
        LogDebug("probe timed out", target, dataType)
    end)
    initiatedSyncs[target] = {
        type = dataType,
        state = "probing",
        timer = th,
    }
    Sync.OnSendProgress:Trigger(target, "probing", 0, 0)
end

---@param target string
---@param sent number
---@param total number
local function SendProgress(target, sent, total)
    if initiatedSyncs[target] then
        if sent == total then
            initiatedSyncs[target] = nil
        end
    end
    Sync.OnSendProgress:Trigger(target, "sending", sent, total)
end

local function SendSettings(target)
    LogDebug("sending settings to", target)
    Sync.OnSendProgress:Trigger(target, "sending", 0, 0)
    Net:SendWhisperWithProgress(SYNC_COMM_PREFIX, target, SYNC_OPCODES.SEND_SESSION_SETTINGS, SendProgress, target, Env.settings.lootSession)
end

commHandler[SYNC_OPCODES.PROBE_RECEIVED] = function(sender, data)
    ---@cast data SyncDataType
    LogDebug("got PROBE_RECEIVED", sender, data)
    if initiatedSyncs[sender] then
        if initiatedSyncs[sender].timer then
            initiatedSyncs[sender].timer:Cancel()
            initiatedSyncs[sender].timer = nil
        end
        LogDebug("have entry, set state to waiting", sender, data)
        initiatedSyncs[sender].state = "waiting"
        initiatedSyncs[sender].timer = C_Timer.NewTimer(RESPONSE_TIMEOUT, function(t) FailProbe(sender) end)
        Sync.OnSendProgress:Trigger(sender, "waiting", 0, 0)
    end
end

commHandler[SYNC_OPCODES.PROBE_RESPONSE] = function(sender, data)
    ---@cast data boolean
    LogDebug("got PROBE_RESPONSE", sender, tostring(data))
    if initiatedSyncs[sender] then
        if initiatedSyncs[sender].timer then
            initiatedSyncs[sender].timer:Cancel()
            initiatedSyncs[sender].timer = nil
        end
        if data then
            initiatedSyncs[sender].state = "sending"
            if initiatedSyncs[sender].type == "settings" then
                SendSettings(sender)
            end
        else
            initiatedSyncs[sender] = nil
        end
    end
end

--------------------------------------------------------------------------------------------------------------------
--- Receiving side
--------------------------------------------------------------------------------------------------------------------

commHandler[SYNC_OPCODES.PROBE_RECEIVER] = function(sender, data)
    LogDebug("doing fake placeholder accept")
    Net:SendWhisper(SYNC_COMM_PREFIX, sender, SYNC_OPCODES.PROBE_RECEIVED, data)
    C_Timer.NewTimer(4, function(t)
        Net:SendWhisper(SYNC_COMM_PREFIX, sender, SYNC_OPCODES.PROBE_RESPONSE, true)
    end)
end

commHandler[SYNC_OPCODES.SEND_SESSION_SETTINGS] = function(sender, data)
    print("got data")
    -- TODO: Update settings
end

Env:OnAddonLoaded(function(...)
    Env.Net:Register(SYNC_COMM_PREFIX, function(prefix, sender, opcode, data)
        if not isEnabled then
            return
        end
        if commHandler[opcode] then
            commHandler[opcode](sender, data)
        else
            LogDebug("Unhanled opcode received:", opcode, sender)
        end
    end)
end)

---Enable or disable sync addon communication.
---@param enabled boolean Whether to enable or disable sync.
function Sync.EnableSync(enabled)
    isEnabled = enabled
    LogDebug("Sync enabled:", tostring(isEnabled))
    if not isEnabled then
        for _, v in pairs(initiatedSyncs) do
            if v.timer then
                v.timer:Cancel()
            end
        end
        initiatedSyncs = {}
    end
end

---Initiate syncing with target.
---@param target string
---@param dataType SyncDataType
function Sync.Initiate(target, dataType)
    return SendProbe(target, dataType)
end

Env:RegisterSlashCommand("st", "", function(args)
    Sync.EnableSync(true)
    SendProbe(UnitName("player"), "settings")
end)
