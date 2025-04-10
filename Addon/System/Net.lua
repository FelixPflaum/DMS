---@class AddonEnv
local Env = select(2, ...)

local LibDeflate = LibStub("LibDeflate")
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

---Provides functions for serialized and compressed addon communication.
local Net = {}
Env.Net = Net

---@alias AddonCommCallback fun(channel:string, sender:string, opcode:integer, data:any, recvSize: integer)

---@type table<string, (AddonCommCallback|{object:table, funcName:string})[]>
local callbacks = {}

---@param prefix string
---@param text string
---@param channel string
---@param sender string
local function MessageReceived(prefix, text, channel, sender)
    if not callbacks[prefix] or #callbacks[prefix] == 0 then
        return
    end

    ---@diagnostic disable-next-line: no-unknown
    local decoded = LibDeflate:DecodeForWoWAddonChannel(text)
    if not decoded then
        Env:PrintError("Could not decode message from " .. sender)
        return
    end

    ---@diagnostic disable-next-line: no-unknown
    local inflated = LibDeflate:DecompressDeflate(decoded)
    if not inflated then
        Env:PrintError("Could not inflate message from " .. sender)
        return
    end

    ---@diagnostic disable-next-line: no-unknown
    local success, opcode, data = AceSerializer:Deserialize(inflated)
    if not success then
        Env:PrintError("Could not deserialized message from " .. sender)
        return
    end

    for _, cb in ipairs(callbacks[prefix]) do
        if type(cb) == "function" then
            cb(channel, sender, opcode, data, text:len())
        else
            cb.object[cb.funcName](cb.object, channel, sender, opcode, data, text:len())
        end
    end
end

---@param prefix string
---@param callback AddonCommCallback
function Net:Register(prefix, callback)
    if not callbacks[prefix] then
        callbacks[prefix] = {}
        AceComm:RegisterComm(prefix, MessageReceived)
    end
    table.insert(callbacks[prefix], callback)
end

---@param prefix string
---@param object table
---@param funcName string
function Net:RegisterObj(prefix, object, funcName)
    if object[funcName] == nil or type(object[funcName]) ~= "function" then
        error(string.format("object.%s is not a function!", funcName))
    end
    if not callbacks[prefix] then
        callbacks[prefix] = {}
        AceComm:RegisterComm(prefix, MessageReceived)
    end
    table.insert(callbacks[prefix], { object = object, funcName = funcName })
end

---@param prefix string
---@param object table
function Net:UnregisterObj(prefix, object)
    if not callbacks[prefix] then
        return
    end
    for i = #callbacks[prefix], 1, -1 do
        local entry = callbacks[prefix][i]
        if type(entry) == "table" and entry.object == object then
            table.remove(callbacks[prefix], i)
        end
    end
end

---@type {sentAt:number, size:integer}[]
local cpsTracker = {}
local cpsTrackerLen = 100
local cpsTrackerLastPos = 1
for i = 1, cpsTrackerLen do
    cpsTracker[i] = { sentAt = 0, size = 0 }
end

---@param offset integer
local function GetCpsTrackerPos(offset)
    assert(math.abs(offset) < cpsTrackerLen, "Offset must be within dimensions of array.")
    local pos = cpsTrackerLastPos + offset
    if pos < 1 then
        pos = pos + cpsTrackerLen
    elseif pos > cpsTrackerLen then
        pos = pos - cpsTrackerLen
    end
    return pos
end

---@param msg string
local function TrackCPS(msg)
    if not DMS_Settings or DMS_Settings.logLevel == 1 then
        return
    end

    local size = msg:len()

    cpsTrackerLastPos = GetCpsTrackerPos(1)
    cpsTracker[cpsTrackerLastPos].sentAt = GetTime()
    cpsTracker[cpsTrackerLastPos].size = size

    local now = GetTime()
    local cps1s = 0.0 -- chars per second
    local cps2s = 0.0
    local cps5s = 0.0
    local ps1s = 0 -- packets per second
    local ps2s = 0
    local ps5s = 0

    local offset = 1
    while true do
        offset = offset - 1
        if offset == -cpsTrackerLen then
            break
        end
        local i = GetCpsTrackerPos(offset)
        local v = cpsTracker[i]
        local delta = now - v.sentAt

        if delta > 5 then
            break
        end

        cps5s = cps5s + v.size / 5
        ps5s = ps5s + 1
        if delta <= 2 then
            cps2s = cps2s + v.size / 2
            ps2s = ps2s + 1
            if delta <= 1 then
                cps1s = cps1s + v.size
                ps1s = ps1s + 1
            end
        end
    end

    local warnlimit1s = 1500
    local warnlimit2s = 1000
    local warnlimit5s = 600
    if cps1s > warnlimit1s then
        Env:PrintWarn("CPS last second over " .. warnlimit1s .. "! CPS: " .. cps1s)
    end
    if cps2s > warnlimit2s then
        Env:PrintWarn("CPS last 2 seconds over " .. warnlimit2s .. "! CPS: " .. cps2s)
    end
    if cps5s > warnlimit5s then
        Env:PrintWarn("CPS last 5 seconds over " .. warnlimit5s .. "! CPS: " .. cps5s)
    end

    Env:PrintDebug("Net: Sending with size", size, "PS/CPS 1s:", ps1s, "/", cps1s, "2s:", ps2s, "/", cps2s, "5s:", "/", ps5s, cps5s)
end

---@param opcode integer
---@return string
local function MakeMsg(opcode, ...)
    ---@diagnostic disable-next-line: no-unknown
    local serialized = AceSerializer:Serialize(opcode, ...)
    ---@diagnostic disable-next-line: no-unknown
    local deflated = LibDeflate:CompressDeflate(serialized)
    ---@diagnostic disable-next-line: no-unknown
    return LibDeflate:EncodeForWoWAddonChannel(deflated)
end

---@alias CTLPrio "BULK"|"NORMAL"|"ALERT"

---Send message to a channel.
---@param prefix string
---@param channel string
---@param opcode integer
---@param prio CTLPrio
function Net:Send(prefix, channel, opcode, prio, ...)
    local msg = MakeMsg(opcode, ...)
    TrackCPS(msg)
    AceComm:SendCommMessage(prefix, msg, channel, nil, prio)
    return msg:len()
end

---Send message in whisper channel.
---@param prefix string
---@param target string
---@param opcode integer
---@param prio CTLPrio
function Net:SendWhisper(prefix, target, opcode, prio, ...)
    local msg = MakeMsg(opcode, ...)
    TrackCPS(msg)
    AceComm:SendCommMessage(prefix, msg, "WHISPER", target, prio)
    return msg:len()
end

---Send message in whisper channel.
---@param prefix string
---@param target string
---@param opcode integer
---@param prio CTLPrio
---@param callbackFn fun(callbackArg:string, sent:number, textlen:number)
---@param callbackArg string
function Net:SendWhisperWithProgress(prefix, target, opcode, prio, callbackFn, callbackArg, ...)
    local msg = MakeMsg(opcode, ...)
    TrackCPS(msg)
    AceComm:SendCommMessage(prefix, msg, "WHISPER", target, prio, callbackFn, callbackArg)
    return msg:len()
end
