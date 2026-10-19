---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

---@param n string
local function GetPath(n)
    return [[Interface\AddOns\]] .. addonName .. [[\Media\]] .. n
end

local UnitNameForever = Env.UnitNameForever

local Guild = Env.Guild

local meows = { "Meow.mp3", "Meow2.mp3" }
local hiss = { "Hiss.mp3" }
local purrs = { "Purr.mp3" }
local roars = { "Bear.mp3" }

local CAT_ID = 768
local BEAR_ID = 9634
local MEOW_PERM = 1
local HISS_PERM = 2
local PURR_PERM = 4
local ROAR_PERM = 8

local function GetUnitIdFromFullName(fullName)
    if UnitNameForever("player") == fullName then
        return "player"
    end

    local unit = IsInRaid() and "raid" or "party"
    local numGroupMembers = GetNumGroupMembers()
    local numMembers = unit == "party" and numGroupMembers - 1 or numGroupMembers

    local unitId
    for i = 1, numMembers do
        unitId = unit .. i
        if UnitNameForever(unitId) == fullName then
            return unitId
        end
    end
end

local function CanEmote(sender, perm, formId)
    local _, class = UnitClass(sender)
    if class == "DRUID" and Guild:CheckPerm(sender, "PERM", perm) then
        local unitId = GetUnitIdFromFullName(sender)
        if unitId then
            local aura = C_UnitAuras.GetUnitAuraBySpellID(unitId, formId)
            if aura then
                return true
            end
        end
    end
    return false
end

Env:RegisterEvent("CHAT_MSG_TEXT_EMOTE", function(...)
    -- TODO: Something here doesn't work in combat ("failed because of addon")
    if Env.IS_FOREVER and InCombatLockdown() then
        return
    end

    local text = select(1, ...)
    local senderGuid = select(12, ...)
    -- Forever fix. Source name is some random garbage if emote is done by player.
    local sender = (UnitGUID("player") == senderGuid) and UnitNameForever("player") or select(2, ...)

    ---@cast text string
    ---@cast sender string
    if text:find("meow") or text:find("miau") then
        if CanEmote(sender, MEOW_PERM, CAT_ID) then
            PlaySoundFile(GetPath(meows[math.random(#meows)]), "Master")
        end
        return
    end

    if text:find("hiss") or text:find("fauch") then
        if CanEmote(sender, HISS_PERM, CAT_ID) then
            PlaySoundFile(GetPath(hiss[math.random(#hiss)]), "Master")
        end
        return
    end

    if text:find("purr") or text:find("schnurr") then
        if CanEmote(sender, PURR_PERM, CAT_ID) then
            PlaySoundFile(GetPath(purrs[math.random(#purrs)]), "Master")
        end
        return
    end

    if text:find("roar") or text:find("brüllt") then
        if CanEmote(sender, ROAR_PERM, BEAR_ID) then
            PlaySoundFile(GetPath(roars[math.random(#roars)]), "Master")
        end
        return
    end
end)
