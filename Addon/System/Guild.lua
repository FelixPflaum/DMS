---@class AddonEnv
local Env = select(2, ...)

---@param fileName string
local function GetClassIdFromName(fileName)
    for _, v in ipairs(Env.classList) do
        if v.file == fileName then
            return v.id
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
    memberCache = {}, ---@type table<string, {name:string, classId:integer, rankIndex:integer}>
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
        -- TODO: Aparently name can be nil, or rather data isn't actually available at this point? Can't reproduce though.
        if name then
            if not Guild.rankCache[rankIndex] then
                Guild.rankCache[rankIndex] = { id = rankIndex, name = rankName }
            end
            local nameShort = Ambiguate(name, "short")
            Guild.memberCache[nameShort] = {
                name = nameShort,
                classId = GetClassIdFromName(class),
                rankIndex = rankIndex
            }
        end
    end
    Guild.OnRosterDataUpdate:Trigger()
end)

function Guild:GetGuildInfoData()
    ---@class (exact) GuildInfoData
    ---@field allowedNames table<string,boolean>
    ---@field allowedRanks table<string,boolean>
    ---@field druid table<string,number>
    local data = { ---@type GuildInfoData
        allowedNames = {},
        allowedRanks = {},
        druid = {},
    }
    local text = GetGuildInfoText()
    if text then
        local matched = text:match("DMS:::.*:::") ---@type string|nil
        if matched then
            local matchStart = matched:match("START=([^:]+)::") ---@type string|nil
            if matchStart then
                for str in matchStart:gmatch("([^,]+)") do
                    local rankMatch = str:match("R%-(.*)")
                    if rankMatch then
                        data.allowedRanks[rankMatch] = true
                    else
                        data.allowedNames[str] = true
                    end
                end
            end

            local matchDruid = matched:match("DRUID=([^:]-)::") ---@type string|nil
            if matchDruid then
                for str in matchDruid:gmatch("([^,]+)") do
                    local name, field = str:match("([^-]+)%-(%d+)")
                    if name and field then
                        data.druid[name] = tonumber(field)
                    end
                end
            end
        end
    end
    Env:PrintDebug(data)
    return data
end

---Check if character is guild member and has permission from guild info.
---@param charName string
---@param perm "START"|"DRUID"
---@param arg number
function Guild:CheckPerm(charName, perm, arg)
    if not self.memberCache[charName] then
        return false
    end
    local infoData = self:GetGuildInfoData()

    if perm == "START" then
        if infoData.allowedNames[charName] then
            return true
        end
        local guildRank = self.rankCache[self.memberCache[charName].rankIndex]
        if guildRank and infoData.allowedRanks[guildRank.name] then
            return true
        end
        return false
    end

    if perm == "DRUID" then
        local infoEntry = infoData.druid[charName]
        if not infoEntry then
            return false
        end
        return bit.band(infoEntry, arg) ~= 0
    end

    error("Invalid perm type "..perm)
end

Env:RegisterSlashCommand("testperm", "", function(args)
    local name = args[1]
    local perm = args[2]
    local arg = args[3]
    print(Guild:CheckPerm(name, perm, arg and tonumber(arg) or 0))
end)

local catNameList = { "Socks", "Elvis", "Phoebe", "Twiggy", "Milo", "Tigger", "Tucker", "Frankie", "Precious", "Bandit",
    "Sasha", "Simba", "Boomer", "Oprah", "Madonna", "Oscar", "Snickers", "Fred", "Angel", "Pumpkin", "Bailey", "Scooter",
    "Boots", "Murphy", "Marley", "Jake", "Lily", "Sox", "Leo", "Luna", "Mittens", "Lola", "BatMan", "Coco", "Rocky",
    "Pepper", "Houdini", "Princess", "Jasmine", "Samantha" }

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
