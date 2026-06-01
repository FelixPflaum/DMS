---@class AddonEnv
local Env = select(2, ...)

-- Now this is really stupid, but imagine the possibilities!

local Guild = Env.Guild
-- TODO: move to guild?
local PERMISSION = 64

Env.Net:Register("DMSTTS", function(channel, sender, opcode, data, recvSize)
    local senderHasPerm = Guild:CheckPerm(sender, "DRUID", PERMISSION)

    Env:PrintDebug("Received DMSTTS", sender, opcode, data, tostring(senderHasPerm))

    if not senderHasPerm then
        return
    end

    -- This is the pre DF version in era/anniversary as of now.
    -- VoiceID: voice 0 should be locale default
    -- Text
    -- Destination: 1 = local playback
    -- Speed: 0 = default
    -- Volume
    C_VoiceChat.SpeakText(0, data, 1, 0, 100)
end)

Env:RegisterSlashCommand("tts", "", function(args)
    if #args < 2 then
        Env:PrintError("Not enough arguments.")
        return
    end

    local target = args[1]
    local text = table.concat(args, " ", 2)
    Env.Net:SendWhisper("DMSTTS", target, 1, "NORMAL", text)
end)
