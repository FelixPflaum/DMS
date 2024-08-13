---@class AddonEnv
local Env = select(2, ...)

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

function Env:GetGuildInfoData()
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

local classNameAndId = {
    { "DRUID",   11 },
    { "HUNTER",  3 },
    { "MAGE",    8 },
    { "PALADIN", 2 },
    { "PRIEST",  5 },
    { "ROGUE",   4 },
    { "SHAMAN",  7 },
    { "WARLOCK", 9 },
    { "WARRIOR", 1 },
}
---@param n string
local function GetClassIdFromName(n)
    for _, v in ipairs(classNameAndId) do
        if v[1] == n then
            return v[2]
        end
    end
    return 1 -- fall back to warrior
end

---Get random name, class combos from guild or a backup list of cat names.
---@return fun():string,string,integer generatorFunction Returns name, classFile, classId on call.
function Env:GetRandomGuildNameGenerator()
    local numMembers = GetNumGuildMembers()
    local picker = Env:NewUniqueRoller(numMembers)
    local backupPicker = Env:NewUniqueRoller(#catNameList)
    return function()
        local pick = picker:GetRoll()
        local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(pick)
        if name then
            name = Ambiguate(name, "short")
            return name, classFile, GetClassIdFromName(classFile)
        end
        local classPick = classNameAndId[math.random(#classNameAndId)]
        return catNameList[backupPicker:GetRoll()], classPick[1], classPick[2]
    end
end
