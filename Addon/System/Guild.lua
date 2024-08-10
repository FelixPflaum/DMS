---@class AddonEnv
local Env = select(2, ...)

local function TriggerRosterUpdate()
    if GuildRoster then
        GuildRoster()
    else
        C_GuildInfo.GuildRoster()
    end
end

Env:OnAddonLoaded(function()
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
