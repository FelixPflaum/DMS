---@class AddonEnv
local DMS = select(2, ...)

local L = DMS:GetLocalization()
local DB = DMS.Database

DMS.Session = {}

----------------------------------------------------------------------------
--- Loot Status
--- This is static and the same for host and client. Only id needs to be communicated.
----------------------------------------------------------------------------

---@class (exact) LootClientStatus
---@field id integer
---@field displayString string
---@field color [number, number, number]

DMS.Session.LootStatus = {
    ---@type LootClientStatus
    dataNotSent = {
        id = 1,
        displayString = L["Loot data not yet sent"],
        color = { 1, 0.5, 0 },
    },
    ---@type LootClientStatus
    dataSent = {
        id = 2,
        displayString = L["Loot data sent, waiting for answer..."],
        color = { 1, 0.5, 0 },
    },
    ---@type LootClientStatus
    waitingForResponse = {
        id = 3,
        displayString = L["Waiting for response selection..."],
        color = { 1, 1, 0 },
    },
    ---@type LootClientStatus
    unknown = {
        id = 4,
        displayString = L["Unknown, offline or addon not installed"],
        color = { 0.5, 0.5, 0.5 },
    },
    ---@type LootClientStatus
    responseTimeout = {
        id = 5,
        displayString = L["Did not respond in time"],
        color = { 1, 0, 0 },
    },
    ---@type LootClientStatus
    responded = {
        id = 6,
        displayString = L["Response given"],
        color = { 0.5, 1, 0.5 },
    },
}

---Get status data by id.
---@param id integer
---@return LootClientStatus|nil Will return nothing if status doesn't exist.
function DMS.Session.LootStatus:GetById(id)
    for _, status in pairs(self) do
        if type(status) ~= "function" and status.id == id then
            return status
        end
    end
end

---Get display text and color info.
---@param id integer
---@return string statusText Will be "UNKNOWN STATUS" if status with id doesn't exist.
---@return [number, number, number] colorInfo The RGB color data.
function DMS.Session.LootStatus:GetDisplayFromId(id)
    for _, status in pairs(self) do
        if type(status) ~= "function" and status.id == id then
            return status.displayString, status.color
        end
    end
    return "UNKNOWN STATUS", { 1, 0, 0 }
end

----------------------------------------------------------------------------
--- Loot Responses
--- Host decides these. Static on a per session basis.
--- All data needs to be communicated on session init.
----------------------------------------------------------------------------

---@class (exact) LootResponse
---@field id integer
---@field displayString string
---@field color [number, number, number]
---@field isPointsRoll boolean|nil
---@field noButton boolean|nil

local RESPONSE_ID_AUTOPASS = 1
local RESPONSE_ID_PASS = 2
local REPSONSE_ID_FIRST_CUSTOM = 3

local defaultResponses = {
    ---@type LootResponse
    autopass = {
        id = RESPONSE_ID_AUTOPASS,
        displayString = L["Pass (Automatically passed)"],
        color = { 0.7, 0.7, 0.7 },
        noButton = true,
    },
    ---@type LootResponse
    pass = {
        id = RESPONSE_ID_PASS,
        displayString = L["Pass"],
        color = { 0.7, 0.7, 0.7 },
    },
}

local function CreateDefaultResponseTable()
    ---@type LootResponse[]
    local responses = {}
    for _, defaultResponse in pairs(defaultResponses) do
        assert(not responses[defaultResponse.id], "Id collision!")
        responses[defaultResponse.id] = defaultResponse
    end
    assert(#responses == REPSONSE_ID_FIRST_CUSTOM - 1, "Default responses count not correct!")
    return responses
end

---@class (exact) LootResponses
---@field responses LootResponse[]
local LootResponses = {}
---@diagnostic disable-next-line: inject-field
LootResponses.__index = LootResponses

---Get response by id.
---@param id integer
---@return LootResponse|nil response Data for the response if id is valid.
function LootResponses:GetResponse(id)
    return self.responses[id]
end

---Get pass response.
function LootResponses:GetPass()
    return self.responses[RESPONSE_ID_PASS]
end

---Get autopass response.
function LootResponses:GetAutoPass()
    return self.responses[RESPONSE_ID_AUTOPASS]
end

---Create loot response data from current settings data.
function DMS.Session:CreateLootResponses()
    local lrc = setmetatable({ responses = CreateDefaultResponseTable() }, LootResponses)
    local numButtons = DMS.settings.lootSession.responses.buttonCount
    local buttons = DMS.settings.lootSession.responses.buttons
    local count = 0
    for i = 1, numButtons do
        local id = REPSONSE_ID_FIRST_CUSTOM + i - 1
        lrc.responses[id] = {
            id = id,
            displayString = buttons[i].response,
            color = buttons[i].color,
            isPontsRoll = buttons[i].pointRoll,
        }
        count = count + 1
    end
    assert(#lrc.responses == count + REPSONSE_ID_FIRST_CUSTOM - 1, "Did not create a correct array!")
    return lrc
end

---Get data for clients. Includes all custom response options.
function LootResponses:GetCommData()
    ---@type LootResponse[]
    local list = {}
    for i = REPSONSE_ID_FIRST_CUSTOM, #self.responses do
        table.insert(list, self.responses[i])
    end
    return list
end

---Create loot response data from received data.
---@param list LootResponse[]
function DMS.Session:CreateLootClientResponsesFromComm(list)
    local lrc = setmetatable({ responses = CreateDefaultResponseTable() }, LootResponses)
    for _, v in ipairs(list) do
        lrc.responses[v.id] = v
    end
    return lrc
end

----------------------------------------------------------------------------
--- Comm
----------------------------------------------------------------------------

---@enum OpCode
local opcodes = {
    HMSG_SESSION = 1,
    HMSG_SESSION_END = 2,
    HMSG_CANDIDATES_UPDATE = 3,

    MAX_HMSG = 99,
    CMSG_IM_HERE = 100
}

local Comm = {
    PREFIX = "DMSanity",
    VERSION = 1,
    OpCodes = opcodes,
}
DMS.Session.Comm = Comm

---@class (exact) Packet_LootCandidate
---@field n string
---@field c integer
---@field s integer

---@class (exact) Packet_LootSessionItemClient
---@field candidate string
---@field responseId integer
---@field statusId integer
---@field roll [integer,integer]|nil

---@class (exact) Packet_LootSessionItem
---@field guid string
---@field order integer
---@field itemId integer
---@field veiled boolean
---@field endTime integer
---@field responses Packet_LootSessionItemClient[]
---@field awardedTo string|nil

---@class (exact) Packet_LootSession
---@field guid string
---@field responses LootResponse[]
---@field commVersion integer

---@param host LootSessionHost
function Comm:Packet_MakeSessionHost(host)
    ---@type Packet_LootSession
    local sp = {
        guid = host.sessionGUID,
        commVersion = self.VERSION,
        responses = host.responses:GetCommData(),
    }
    return sp
end

---@param candidate LootCandidate
function Comm:Packet_Candidate(candidate)
    ---@type Packet_LootCandidate
    local data = {
        n = candidate.name,
        c = candidate.classId,
        s = 0
    }
    if candidate.isOffline then
        data.s = data.s + 0x1
    end
    if candidate.leftGroup then
        data.s = data.s + 0x2
    end
    if candidate.isResponding then
        data.s = data.s + 0x4
    end
    return data
end

---@param data Packet_LootCandidate
function Comm:Packet_ReadCandidate(data)
    ---@type LootCandidate
    local lc = {
        name = data.n,
        classId = data.c,
        isOffline = bit.band(data.s, 0x1) > 0,
        leftGroup = bit.band(data.s, 0x2) > 0,
        isResponding = bit.band(data.s, 0x4) > 0,
        lastMessage = 0,
    }
    return lc
end
