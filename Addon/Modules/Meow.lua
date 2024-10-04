---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

-- TODO: deactivate this lol

---@param n string
function GetPath(n)
    return [[Interface\AddOns\]] .. addonName .. [[\Media\]] .. n
end

local meows = { "Meow.mp3", "Meow2.mp3" }

Env:RegisterEvent("CHAT_MSG_TEXT_EMOTE", function(text, sender)
    ---@cast text string
    ---@cast sender string
    if text:find("meow") then
        local _, class = UnitClass(sender)
        if class == "DRUID" then
            local catform = GetSpellInfo(768)
            local aura = AuraUtil.FindAuraByName(catform, sender)
            if aura then
                PlaySoundFile(GetPath(meows[math.random(#meows)]), "Master")
            end
        end
    end
end)
