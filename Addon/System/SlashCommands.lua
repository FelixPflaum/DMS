---@type string
local addonName = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

local L = DMS:GetLocalization()
local AceConsole = LibStub("AceConsole-3.0")

---@type table<string, {callback:fun(args: string[]), description:string}>
local registeredCommands = {}

SLASH_DAMAGEDMINDSSANITY1 = "/dms"
SlashCmdList["DAMAGEDMINDSSANITY"] = function(arg)
    local args = { AceConsole:GetArgs(arg, 10, 1) }

    if #args > 0 and registeredCommands[args[1]] then
        local cmd = table.remove(args, 1)
        registeredCommands[cmd].callback(args)
        return
    end

    local cmdColor = "|cFFDDFFFF"
    local descColor = "|cFFDDDDDD"
    print(addonName .. " " .. L["commands"] .. ":")
    for command, v in pairs(registeredCommands) do
        print(cmdColor .. "  /" .. command .. "|r - " .. descColor .. v.description)
    end
end

---Register a slash command.
---@param command string The command to add.
---@param description string
---@param callback fun(args: string[]): nil The function to call when the cmommand is used.
function DMS:RegisterSlashCommand(command, description, callback)
    assert(registeredCommands[command] == nil, "Command with that name already exists!")
    registeredCommands[command] = {
        callback = callback,
        description = description,
    }
end
