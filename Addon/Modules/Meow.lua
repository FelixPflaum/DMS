---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

---@param n string
local function GetPath(n)
    return [[Interface\AddOns\]] .. addonName .. [[\Media\]] .. n
end

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

local function CanEmote(sender, perm, formId)
    local _, class = UnitClass(sender)
    if class == "DRUID" and Guild:CheckPerm(sender, "DRUID", perm) then
        local formName = GetSpellInfo(formId)
        local aura = AuraUtil.FindAuraByName(formName, sender)
        if aura then
            return true
        end
    end
    return false
end

Env:RegisterEvent("CHAT_MSG_TEXT_EMOTE", function(text, sender)
    ---@cast text string
    ---@cast sender string
    ---@
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
