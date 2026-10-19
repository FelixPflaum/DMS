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

local function GetGuildInfoData()
    ---@class (exact) GuildInfoData
    ---@field allowedNames table<string,boolean>
    ---@field allowedRanks table<string,boolean>
    ---@field namePermissions table<string,number>
    ---@field rankPermissions table<string,number>
    local data = { ---@type GuildInfoData
        allowedNames = {},
        allowedRanks = {},
        namePermissions = {},
        rankPermissions = {},
    }
    local text = GetGuildInfoText()
    if text then
        -- Expected format: 
        -- DS>START=Name,R:Rank,Name2...;PERM=Name:123,R:Officer:123,...;<DS
        local matched = text:match("DS>(.*)<DS") ---@type string|nil
        if matched then
            for entry in string.gmatch(text, "(%a+=[^;]+);") do
                local sep = entry:find("=")
                local key = entry:sub(1, sep - 1)
                local val = entry:sub(sep + 1, #entry)
                if key == "START" then
                    for str in val:gmatch("([^,]+)") do
                        if str:sub(1, 2) == "R:" then
                            data.allowedRanks[str:sub(3)] = true
                        else
                            data.allowedNames[str] = true
                        end
                    end
                elseif key == "PERM" then
                    for str in val:gmatch("([^,]+)") do
                        local name, field = str:match("^(.*):(%d+)$")
                        if name and field then
                            local number = tonumber(field)
                            if not number then
                                Env:PrintError("Invalid guild setting PERM value " ..
                                str .. "! Permission field is not a number.")
                            else
                                if name:sub(1, 2) == "R:" then
                                    data.rankPermissions[name:sub(3)] = number
                                else
                                    data.namePermissions[name] = number
                                end
                            end
                        end
                    end
                else
                    Env:PrintWarn("Invalid guild setting key " .. key)
                end
            end
        end
    end
    Env:PrintDebug(data)
    return data
end

---Check if character is guild member and has permission from guild info.
---@param charName string
---@param perm "START"|"PERM"
---@param permBit integer?
function Guild:CheckPerm(charName, perm, permBit)
    if not self.memberCache[charName] then
        return false
    end
    local infoData = GetGuildInfoData()

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

    if perm == "PERM" then
        local infoEntry = infoData.namePermissions[charName]
        if not infoEntry then
            local guildRank = self.rankCache[self.memberCache[charName].rankIndex]
            if guildRank and infoData.rankPermissions[guildRank.name] then
                infoEntry = infoData.rankPermissions[guildRank.name]
            else
                return false
            end
        end
        return bit.band(infoEntry, permBit) ~= 0
    end

    error("Invalid perm type " .. perm)
end

Env:RegisterSlashCommand("testperm", "", function(args)
    ---@type string, string, string
    local name, perm, arg
    if Env.IS_FOREVER then
        name = args[1] .. " " .. args[2]
        perm = args[3]
        arg = args[4]
    else
        name = args[1]
        perm = args[2]
        arg = args[3]
    end
    print("testing perm", perm, "for", name, "with arg", tostring(arg))
    local infoData = GetGuildInfoData()
    Env.PrintTable(infoData, 0)
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
