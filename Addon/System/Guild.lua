---@class AddonEnv
local Env = select(2, ...)

---@param n string
local function GetClassIdFromName(n)
    for _, v in ipairs(Env.classList) do
        if v[1] == n then
            return v[2]
        end
    end
    return 1 -- fall back to warrior
end

local function TriggerRosterUpdate()
    Env:PrintDebug("Trigger GUILD_ROSTER_UPDATE")
    if GuildRoster then
        GuildRoster()
    else
        C_GuildInfo.GuildRoster()
    end
    --C_Timer.After(600, function()
    --    TriggerRosterUpdate()
    --end)
end

Env:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    TriggerRosterUpdate()
end)

local Guild = {
    rankCache = {}, ---@type {id:integer, name:string}[]
    memberCache = {}, ---@type table<integer, {name:string, classId:integer}[]>
}
Env.Guild = Guild

---@class (exact) GuildRosterDataEvent
---@field RegisterCallback fun(self:GuildRosterDataEvent, cb:fun())
---@field Trigger fun(self:GuildRosterDataEvent)
---@diagnostic disable-next-line: inject-field
Guild.OnRosterDataUpdate = Env:NewEventEmitter()

Env:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    local memberCount = GetNumGuildMembers()
    wipe(Guild.rankCache)
    wipe(Guild.memberCache)
    for i = 1, memberCount do
        local name, rankName, rankIndex, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
        if not Guild.rankCache[rankIndex] then
            Guild.rankCache[rankIndex] = { id = rankIndex, name = rankName }
            Guild.memberCache[rankIndex] = {}
        end
        table.insert(Guild.memberCache[rankIndex], { name = Ambiguate(name, "short"), classId = GetClassIdFromName(class) })
    end
    Guild.OnRosterDataUpdate:Trigger()
end)

function Guild:GetGuildInfoData()
    ---@class GuildInfoData
    ---@field allowedNames table<string,boolean>
    local data = { ---@type GuildInfoData
        allowedNames = {},
    }
    local text = GetGuildInfoText()
    if text then
        local matched = text:match("DMS:::.*:::") ---@type string|nil
        if matched then
            local matchStart = matched:match("START=([^:]+)::") ---@type string|nil
            if matchStart then
                for str in matchStart:gmatch("([^,]+)") do
                    data.allowedNames[str] = true
                end
            end
        end
    end
    Env:PrintDebug(data)
    return data
end

local catNameList = { "Socks", "Elvis", "Phoebe", "Twiggy", "Milo", "Tigger", "Tucker", "Frankie", "Precious", "Bandit", "Sasha",
    "Simba", "Boomer", "Oprah", "Madonna", "Oscar", "Snickers", "Fred", "Angel", "Pumpkin", "Bailey", "Scooter", "Boots", "Murphy",
    "Marley", "Jake", "Lily", "Sox", "Leo", "Luna", "Mittens", "Lola", "BatMan", "Coco", "Rocky", "Pepper", "Houdini", "Princess",
    "Jasmine", "Samantha" }

---Get random name, class combos from guild or a backup list of cat names.
---@return fun():string,string,integer generatorFunction Returns name, classFile, classId on call.
function Guild:GetRandomGuildNameGenerator()
    local numMembers = GetNumGuildMembers()
    local picker = Env:NewUniqueRoller(numMembers)
    local backupPicker = Env:NewUniqueRoller(#catNameList)
    return function()
        if picker:Remaining() > 0 then
            local pick = picker:GetRoll()
            local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(pick)
            if name then
                name = Ambiguate(name, "short")
                return name, classFile, GetClassIdFromName(classFile)
            end
        end
        local classPick = Env.classList[math.random(#Env.classList)]
        return catNameList[backupPicker:GetRoll()], classPick.file, classPick.id
    end
end
