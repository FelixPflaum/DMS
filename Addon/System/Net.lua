---@class AddonEnv
local DMS = select(2, ...)

local LibDeflate = LibStub("LibDeflate")
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

DMS.Net = {}

---@alias AddonCommCallback fun(prefix:string, sender:string, opcode:OpCode, data:any)

---@type table<string, (AddonCommCallback|{obj:table, funcName:string})[]>
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
        DMS:PrintError("Could not decode message from " .. sender)
        return
    end

    ---@diagnostic disable-next-line: no-unknown
    local inflated = LibDeflate:DecompressDeflate(decoded)
    if not inflated then
        DMS:PrintError("Could not inflate message from " .. sender)
        return
    end

    ---@diagnostic disable-next-line: no-unknown
    local success, opcode, data = AceSerializer:Deserialize(inflated)
    if not success then
        DMS:PrintError("Could not deserialized message from " .. sender)
        return
    end

    for _, cb in ipairs(callbacks[prefix]) do
        if type(cb) == "function" then
            cb(prefix, sender, opcode, data)
        else
            cb.obj[cb.funcName](cb.obj, prefix, sender, opcode, data)
        end
    end
end

---@param prefix string
---@param callback AddonCommCallback
function DMS.Net:Register(prefix, callback)
    if not callbacks[prefix] then
        callbacks[prefix] = {}
        AceComm:RegisterComm(prefix, MessageReceived)
    end
    table.insert(callbacks[prefix], callback)
end

---@param prefix string
---@param object table
---@param funcName string
function DMS.Net:RegisterObj(prefix, object, funcName)
    if not callbacks[prefix] then
        callbacks[prefix] = {}
        AceComm:RegisterComm(prefix, MessageReceived)
    end
    table.insert(callbacks[prefix], { obj = object, funcName = funcName })
end

---@param prefix string
---@param object table
function DMS.Net:UnregisterObj(prefix, object)
    if not callbacks[prefix] then
        return
    end
    for k, v in ipairs(callbacks[prefix]) do
        if type(v) == "table" and v.obj == object then
            table.remove(callbacks[prefix], k)
        end
    end
end

---@param opcode OpCode
---@return string
local function MakeMsg(opcode, ...)
    ---@diagnostic disable-next-line: no-unknown
    local serialized = AceSerializer:Serialize(opcode, ...)
    ---@diagnostic disable-next-line: no-unknown
    local deflated = LibDeflate:CompressDeflate(serialized)
    ---@diagnostic disable-next-line: no-unknown
    return LibDeflate:EncodeForWoWAddonChannel(deflated)
end

---@param prefix string
---@param channel string
---@param opcode OpCode
function DMS.Net:Send(prefix, channel, opcode, ...)
    AceComm:SendCommMessage(prefix, MakeMsg(opcode, ...), channel)
end

---@param prefix string
---@param target string
---@param opcode OpCode
function DMS.Net:SendWhisper(prefix, target, opcode, ...)
    AceComm:SendCommMessage(prefix, MakeMsg(opcode, ...), "WHISPER", target)
end
