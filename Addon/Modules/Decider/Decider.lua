---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("Decider:", ...)
end

local L = Env:GetLocalization()

local SPIN_DURATION = 10

---@alias DeciderPlayerData {name:string, classId:integer}

---@class DecissionPacket
---@field title string
---@field data DeciderPlayerData[]
---@field resultPos integer

---@enum OpcodeDecider
local DECIDER_OPCODES = {
    SEND_DECISSION = 1,
}

local Net = Env.Net
local DECIDER_COMM_PREFIX = "DMSDecide"
local commHandler = {} ---@type table<OpcodeDecider,fun(sender:string, data:any)>
local decissionRunning = nil ---@type {title:string, winner:string}|nil

---Check if unit has permission to start a wheel.
---@param unitName string
---@return boolean
local function CanUnitDecide(unitName)
    if UnitIsGroupLeader(unitName, LE_PARTY_CATEGORY_HOME) then
        LogDebug("Unit is party leader and can start.")
        return true
    elseif UnitIsGroupAssistant(unitName, LE_PARTY_CATEGORY_HOME) then
        LogDebug("Unit is assist and can start.")
        return true
    else
        local guildPerms = Env.Guild:GetGuildInfoData()
        if guildPerms.allowedNames[unitName] then
            LogDebug("Sender has permission from guild info.")
            return true
        end
    end
    return false
end

---Send decission packet to group.
---@param title string
---@param data DeciderPlayerData[]
---@param resultPos integer
local function SendDecission(title, data, resultPos)
    LogDebug("Sending decission", title, #data, resultPos)
    ---@type DecissionPacket
    local pck = {
        title = title,
        data = data,
        resultPos = resultPos,
    }
    local channel = IsInRaid() and "RAID" or "PARTY"
    Net:Send(DECIDER_COMM_PREFIX, channel, DECIDER_OPCODES.SEND_DECISSION, "BULK", pck)
end

---Show the wheel UI and spin it.
---@param data {color:[number, number, number], text:string}[]
local function StartWheel(title, data, target, duration)
    Env.DeciderUI:Show()
    Env.DeciderUI:SetTitle(title)
    Env.DeciderUI:SetData(data)
    Env.DeciderUI:Spin(target, duration)

    decissionRunning = {
        title = title,
        winner = Env.UI.ColorStringFromArray(data[target].color, data[target].text),
    }

    C_Timer.After(duration, function()
        if not decissionRunning then
            return
        end
        Env:PrintSuccess(decissionRunning.title .. ": " .. decissionRunning.winner)
        C_Timer.After(4, function()
            decissionRunning = nil
        end)
    end)
end

commHandler[DECIDER_OPCODES.SEND_DECISSION] = function(sender, data)
    ---@cast data DecissionPacket
    LogDebug("got SEND_DECISSION", sender, data)

    if not CanUnitDecide(sender) then
        return Env:PrintWarn(L["%s tried to spin the wheel but has no permission to do so!"]:format(sender))
    end

    if decissionRunning and sender ~= UnitName("player") then
        return Env:PrintWarn(L["%s tried to spin the wheel but there's already one running!"]:format(sender))
    end

    local wheelData = {}
    for _, member in ipairs(data.data) do
        table.insert(wheelData, { color = Env.UI.GetClassColor(member.classId).color, text = member.name })
    end

    Env:PrintSuccess(L["Wheelspin from %s: %s"]:format(sender, data.title))
    StartWheel(data.title, wheelData, data.resultPos, SPIN_DURATION)
end

Env:OnAddonLoaded(function(...)
    Env.Net:Register(DECIDER_COMM_PREFIX, function(channel, sender, opcode, data)
        if channel ~= "RAID" and channel ~= "PARTY" then
            return
        end
        if commHandler[opcode] then
            commHandler[opcode](sender, data)
        else
            LogDebug("Unhandled opcode received:", opcode, sender)
        end
    end)
end)

--[[ Env:RegisterSlashCommand("decidetest", "", function(args)
    if decissionRunning then
        return Env:PrintError(L["Wheel is already spinning! Wait before starting a new one."])
    end

    local slices = tonumber(args[1])
    local tarPos = tonumber(args[2])
    local title = table.concat(args, " ", 3)

    if not tarPos or not slices then
        return Env:PrintError("not a number!")
    end

    local data = {}
    for i = 1, slices do
        local cls = Env.classList[math.random(1, #Env.classList)]
        table.insert(data, { color = Env.UI.GetClassColor(cls.id).color, text = "Test" .. i })
    end

    StartWheel(title, data, tarPos, SPIN_DURATION)
end) ]]

Env.Decider = {}

---Start a decision wheel if permissions are met and none is currently active.
---@param title string
---@param members DeciderPlayerData[]
function Env.Decider.Start(title, members)
    if not CanUnitDecide(UnitName("player")) then
        return Env:PrintError(L["You do not have permissions to start a session."])
    end

    if decissionRunning then
        return Env:PrintError(L["Wheel is already spinning! Wait before starting a new one."])
    end

    if #members < 2 then
        return Env:PrintError(L["Requires at least 2 entries!"])
    end

    local target = math.random(1, #members)
    SendDecission(title, members, target)
    decissionRunning = {
        title = title,
        winner = Env.UI.ColorByClassId(members[target].name, members[target].classId)
    }
end
