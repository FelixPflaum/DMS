---@type string
local addonName = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

local L = DMS:GetLocalization()
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function CreateOptionTable()
    local maxResponseButtons = 8

    local optionTable = {
        type = "group",
        get = function(info)
            return DMS.settings[info[#info]]
        end,
        set = function(info, val)
            ---@diagnostic disable-next-line: no-unknown
            DMS.settings[info[#info]] = val
        end,
        args = {
            responseGroup = {
                order = 100,
                type = "group",
                name = L["Loot Responses"],
                get = function(info)
                    return DMS.settings.lootSession.responses[info[#info]]
                end,
                set = function(info, val)
                    ---@diagnostic disable-next-line: no-unknown
                    DMS.settings.lootSession.responses[info[#info]] = val
                end,
                args = {
                    desc = {
                        order = 1,
                        type = "description",
                        name = L["Configure the available responses if you are the host. A pass button is always shown."]
                    },
                    buttonCount = {
                        order = 2,
                        name = L["Number of buttons"],
                        desc = L["How many buttons to show as options."],
                        type = "range",
                        width = "full",
                        min = 0,
                        max = maxResponseButtons,
                        step = 1,
                    },
                }
            },
            sessionGroup = {
                order = 200,
                type = "group",
                name = L["Loot Session"],
                get = function(info)
                    return DMS.settings.lootSession[info[#info]]
                end,
                set = function(info, val)
                    ---@diagnostic disable-next-line: no-unknown
                    DMS.settings.lootSession[info[#info]] = val
                end,
                args = {
                    timeout = {
                        order = 1,
                        name = L["Roll Timeout"],
                        desc = L["How many seconds do player have for selecting a response."],
                        type = "range",
                        width = "full",
                        min = 10,
                        max = 300,
                        step = 1,
                    },
                }
            },

            debugGroup = {
                order = -1,
                type = "group",
                name = "Debug",
                args = {
                    debug = {
                        order = 1,
                        type = "toggle",
                        name = "Debug"
                    },
                }
            },
        }
    }

    local responseArgs = optionTable.args.responseGroup.args
    local orderLast = 100
    local perRow = 5

    for i = 1, maxResponseButtons do
        if not DMS.settings.lootSession.responses.buttons[i] then
            DMS.settings.lootSession.responses.buttons[i] = {
                response = "Button" .. i,
                color = { 1, 1, 1 },
            }
        end

        responseArgs["button" .. i] = {
            order = orderLast - i * perRow + 1,
            name = L["Button %d"]:format(i),
            desc = L["Set the response for button %d."]:format(i),
            type = "input",
            get = function() return DMS.settings.lootSession.responses.buttons[i].response end,
            set = function(info, value)
                if value == "" then return end
                DMS.settings.lootSession.responses.buttons[i].response = tostring(value)
            end,
            hidden = function() return DMS.settings.lootSession.responses.buttonCount < i end,
        }
        responseArgs["color" .. i] = {
            order = orderLast - i * perRow + 2,
            name = L["Color"],
            desc = L["Color used for response."],
            width = 0.4,
            type = "color",
            get = function() return unpack(DMS.settings.lootSession.responses.buttons[i].color) end,
            set = function(info, r, g, b, a) DMS.settings.lootSession.responses.buttons[i].color = { r, g, b } end,
            hidden = function() return DMS.settings.lootSession.responses.buttonCount < i end,
        }
        responseArgs["sanity" .. i] = {
            order = orderLast - i * perRow + 3,
            type = "toggle",
            name = L["Sanity Roll"],
            desc = L["Whether this response uses sanity."],
            width = 0.7,
            get = function() return DMS.settings.lootSession.responses.buttons[i].pointRoll end,
            set = function(info, val) DMS.settings.lootSession.responses.buttons[i].pointRoll = val end,
            hidden = function() return DMS.settings.lootSession.responses.buttonCount < i end,
        }
        responseArgs["up" .. i] = {
            order = orderLast - i * perRow + 4,
            name = "",
            type = "execute",
            width = 0.1,
            image = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up",
            disabled = function(info)
                return i == DMS.settings.lootSession.responses.buttonCount
            end,
            func = function()
                local tempResponse = DMS.settings.lootSession.responses.buttons[i]
                DMS.settings.lootSession.responses.buttons[i] = DMS.settings.lootSession.responses.buttons[i + 1]
                DMS.settings.lootSession.responses.buttons[i + 1] = tempResponse
            end,
            hidden = function()
                return DMS.settings.lootSession.responses.buttonCount < i
            end,
        }
        responseArgs["down" .. i] = {
            order = orderLast - i * perRow + 5,
            name = "",
            type = "execute",
            width = 0.1,
            image = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
            disabled = function()
                return i == 1
            end,
            func = function()
                local tempResponse = DMS.settings.lootSession.responses.buttons[i]
                DMS.settings.lootSession.responses.buttons[i] = DMS.settings.lootSession.responses.buttons[i - 1]
                DMS.settings.lootSession.responses.buttons[i - 1] = tempResponse
            end,
            hidden = function()
                return DMS.settings.lootSession.responses.buttonCount < i
            end,
        }
    end

    return optionTable
end

--- Setup SV tables, check settings and setup settings menu
DMS:OnAddonLoaded(function()
    AceConfigRegistry:RegisterOptionsTable(addonName, CreateOptionTable())
    AceConfigDialog:AddToBlizOptions(addonName, addonName)
end)

DMS:RegisterSlashCommand("config", L["Opens the config window."], function()
    InterfaceOptionsFrame_OpenToCategory(addonName)
    InterfaceOptionsFrame_OpenToCategory(addonName)
end)
