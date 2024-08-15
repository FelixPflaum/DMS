---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function CreateOptionTable()
    local maxResponseButtons = 8

    local optionTable = {
        type = "group",
        get = function(info)
            return Env.settings[info[#info]]
        end,
        set = function(info, val)
            ---@diagnostic disable-next-line: no-unknown
            Env.settings[info[#info]] = val
        end,
        args = {
            generalGroup = {
                order = 100,
                type = "group",
                name = L["General"],
                args = {
                    autoOpenOnStart = {
                        order = 1,
                        name = L["Automatically open"],
                        desc = L["Open the session window automatically when a session starts, or ask with a dialog box."],
                        type = "select",
                        width = 0.75,
                        values = {
                            ["yes"] = L["Yes"],
                            ["no"] = L["No"],
                            ["ask"] = L["Always ask"],
                        }
                    },
                    autoSwitchToNextItem = {
                        order = 2,
                        name = L["Automatically switch to next"],
                        desc = L["Automatically switch to next unawarded item if the currently selected one is awarded."],
                        width = 1.5,
                        type = "toggle",
                    },
                }
            },
            hostGroup = {
                order = 200,
                type = "group",
                name = L["Host Settings"],
                get = function(info)
                    return Env.settings.lootSession[info[#info]]
                end,
                set = function(info, val)
                    ---@diagnostic disable-next-line: no-unknown
                    Env.settings.lootSession[info[#info]] = val
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
                    maxRangeForPointRoll = {
                        order = 2,
                        name = L["Max sanity roll range"],
                        desc = L
                        ["Which range to consider for sanity behind the highest sanity value when ordering results with roll values."],
                        type = "range",
                        width = "full",
                        min = 1,
                        max = 100,
                        step = 1,
                    },
                    headerResponses = {
                        order = 10,
                        type = "header",
                        name = L["Responses"]
                    },
                    descCound = {
                        order = 11,
                        type = "description",
                        name = L["Configure the available responses if you are the host. A pass button is always shown."]
                    },
                    responseCount = {
                        order = 12,
                        name = L["Number of Buttons"],
                        desc = L["How many buttons to show as options."],
                        type = "range",
                        width = "full",
                        min = 0,
                        max = maxResponseButtons,
                        step = 1,
                    },
                }
            },
            debugGroup = {
                order = -1,
                type = "group",
                name = "Debug",
                args = {
                    logLevel = {
                        order = 1,
                        type = "select",
                        name = L["Debug Log Level"],
                        values = {
                            [1] = L["Off"],
                            [2] = L["Debug"],
                            [3] = L["Verbose Data"],
                        }
                    },
                    testMode = {
                        order = 2,
                        type = "toggle",
                        name = L["Test mode"],
                    }
                }
            },
        }
    }

    local responseArgs = optionTable.args.hostGroup.args
    local orderLast = 100
    local perRow = 5

    for i = 1, maxResponseButtons do
        if not Env.settings.lootSession.responseButtons[i] then
            Env.settings.lootSession.responseButtons[i] = {
                response = "Button" .. i,
                color = { 1, 1, 1 },
            }
        end

        responseArgs["button" .. i] = {
            order = orderLast - i * perRow + 1,
            name = L["Button %d"]:format(i),
            desc = L["Set the response for button %d."]:format(i),
            type = "input",
            width = 0.85,
            get = function() return Env.settings.lootSession.responseButtons[i].response end,
            set = function(info, value)
                if value == "" then return end
                Env.settings.lootSession.responseButtons[i].response = tostring(value)
            end,
            hidden = function() return Env.settings.lootSession.responseCount < i end,
        }
        responseArgs["color" .. i] = {
            order = orderLast - i * perRow + 2,
            name = "", -- L["Color"],
            desc = L["Color used for response."],
            width = 0.25,
            type = "color",
            get = function() return unpack(Env.settings.lootSession.responseButtons[i].color) end,
            set = function(info, r, g, b, a) Env.settings.lootSession.responseButtons[i].color = { r, g, b } end,
            hidden = function() return Env.settings.lootSession.responseCount < i end,
        }
        responseArgs["isNeed" .. i] = {
            order = orderLast - i * perRow + 3,
            type = "toggle",
            name = L["Need Roll"],
            desc = L["Whether this response counts as a need roll for sanity point deduction."],
            width = 0.6,
            get = function() return Env.settings.lootSession.responseButtons[i].isNeed end,
            set = function(info, val)
                Env.settings.lootSession.responseButtons[i].isNeed = val
            end,
            hidden = function() return Env.settings.lootSession.responseCount < i end,
        }
        responseArgs["sanity" .. i] = {
            order = orderLast - i * perRow + 4,
            type = "toggle",
            name = L["Sanity Roll"],
            desc = L["Whether this response uses sanity."],
            width = 0.6,
            get = function() return Env.settings.lootSession.responseButtons[i].pointRoll end,
            set = function(info, val)
                if val then
                    for _, v in pairs(Env.settings.lootSession.responseButtons) do
                        v.pointRoll = false
                    end
                end
                Env.settings.lootSession.responseButtons[i].pointRoll = val
            end,
            hidden = function() return Env.settings.lootSession.responseCount < i end,
        }
        responseArgs["up" .. i] = {
            order = orderLast - i * perRow + 5,
            name = "",
            type = "execute",
            width = 0.1,
            image = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up",
            disabled = function(info)
                return i == Env.settings.lootSession.responseCount
            end,
            func = function()
                local tempResponse = Env.settings.lootSession.responseButtons[i]
                Env.settings.lootSession.responseButtons[i] = Env.settings.lootSession.responseButtons[i + 1]
                Env.settings.lootSession.responseButtons[i + 1] = tempResponse
            end,
            hidden = function()
                return Env.settings.lootSession.responseCount < i
            end,
        }
        responseArgs["down" .. i] = {
            order = orderLast - i * perRow + 6,
            name = "",
            type = "execute",
            width = 0.1,
            image = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
            disabled = function()
                return i == 1
            end,
            func = function()
                local tempResponse = Env.settings.lootSession.responseButtons[i]
                Env.settings.lootSession.responseButtons[i] = Env.settings.lootSession.responseButtons[i - 1]
                Env.settings.lootSession.responseButtons[i - 1] = tempResponse
            end,
            hidden = function()
                return Env.settings.lootSession.responseCount < i
            end,
        }
    end

    return optionTable
end

--- Setup SV tables, check settings and setup settings menu
Env:OnAddonLoaded(function()
    AceConfigRegistry:RegisterOptionsTable(addonName, CreateOptionTable())
    AceConfigDialog:AddToBlizOptions(addonName, addonName)
end)

Env:RegisterSlashCommand("config", L["Opens the config window."], function()
    InterfaceOptionsFrame_OpenToCategory(addonName)
    InterfaceOptionsFrame_OpenToCategory(addonName)
end)
