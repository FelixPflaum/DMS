---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function CreateOptionTable()
    local MAX_RESPONSE_BUTTONS = 8
    local ORDER_LAST_RESPONSE_BUTTON = 100

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
                    headerResponses = {
                        order = 3,
                        type = "header",
                        name = L["More Info Panel"]
                    },
                    descCound = {
                        order = 4,
                        type = "description",
                        name = L["Panel that shows the recent loot history of players in loot session window on mouseover."]
                    },
                    moreInfoEnabled = {
                        order = 5,
                        name = L["Enable"],
                        width = 0.5,
                        type = "toggle",
                    },
                    moreInfoItemCount = {
                        order = 6,
                        name = L["Item Count"],
                        desc = L["How many recent items to list."],
                        type = "range",
                        width = 1,
                        min = 1,
                        max = 20,
                        step = 1,
                    },
                    moreInfoTimeframe = {
                        order = 7,
                        name = L["Timeframe Days"],
                        desc = L["How far back in time to look for the recent loot history."],
                        type = "range",
                        width = 1,
                        min = 1,
                        max = 365,
                        step = 1,
                        get = function(info)
                            return math.floor(Env.settings[info[#info]] / 86400) -- Convert to days.
                        end,
                        set = function(info, val)
                            ---@diagnostic disable-next-line: no-unknown
                            Env.settings[info[#info]] = val * 86400 -- Convert to seconds.
                        end,
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
                        desc = L["How many seconds do players have for selecting a response."],
                        type = "range",
                        width = "full",
                        min = 10,
                        max = 300,
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
                        max = MAX_RESPONSE_BUTTONS,
                        step = 1,
                    },
                    pointsHeader = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 1,
                        type = "header",
                        name = L["Sanity Settings"]
                    },
                    pointsDesc = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 2,
                        type = "description",
                        name = L["Configure settings for how sanity is handled and used."]
                    },
                    pointsMaxRange = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 3,
                        name = L["Max sanity roll range"],
                        desc = L
                            ["Which range to consider for sanity behind the highest sanity value when ordering results with roll values. 100 = disabled"],
                        type = "range",
                        width = "full",
                        min = 1,
                        max = 100,
                        step = 1,
                    },
                    pointsMinForRoll = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 4,
                        name = L["Min sanity for roll"],
                        desc = L
                            ["How much sanity is needed to use a sanity button and for a sanity roll to count as a sanity roll."],
                        type = "range",
                        width = "full",
                        min = 1,
                        max = 100,
                        step = 1,
                    },
                    descSanityRemoveCompetetion = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 5,
                        type = "description",
                        name = L
                            ["How much sanity to remove if a sanity roll is won with competition, i.e. another sanity or need roll exists."]
                    },
                    pointsRemoveIfCompetitionFlat = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 6,
                        name = L["Flat Value"],
                        desc = L["Flat value to remove."],
                        type = "range",
                        width = 1,
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function(info)
                            return Env.settings.lootSession.pointsRemoveIfCompetition.flat
                        end,
                        set = function(info, val)
                            Env.settings.lootSession.pointsRemoveIfCompetition.flat = val
                        end,
                    },
                    pointsRemoveIfCompetitionPct = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 7,
                        name = L["Percent"],
                        desc = L["Percentage to remove."],
                        type = "range",
                        width = 1,
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function(info)
                            return Env.settings.lootSession.pointsRemoveIfCompetition.pct
                        end,
                        set = function(info, val)
                            Env.settings.lootSession.pointsRemoveIfCompetition.pct = val
                        end,
                    },
                    descSanityRemoveUncontested = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 8,
                        type = "description",
                        name = L
                            ["How much sanity to remove if a sanity roll is won without competition, i.e. it was the only sanity roll and no need roll exists."]
                    },
                    pointsRemoveUncontestedFlat = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 9,
                        name = L["Flat Value"],
                        desc = L["Flat value to remove."],
                        type = "range",
                        width = 1,
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function(info)
                            return Env.settings.lootSession.pointsRemoveIfSoloRoll.flat
                        end,
                        set = function(info, val)
                            Env.settings.lootSession.pointsRemoveIfSoloRoll.flat = val
                        end,
                    },
                    pointsRemoveUncontestedPct = {
                        order = ORDER_LAST_RESPONSE_BUTTON + 10,
                        name = L["Percent"],
                        desc = L["Percentage to remove."],
                        type = "range",
                        width = 1,
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function(info)
                            return Env.settings.lootSession.pointsRemoveIfSoloRoll.pct
                        end,
                        set = function(info, val)
                            Env.settings.lootSession.pointsRemoveIfSoloRoll.pct = val
                        end,
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
                        desc = L["Create test player entries when hosting a session."]
                    }
                }
            },
        }
    }

    local responseArgs = optionTable.args.hostGroup.args
    local perRow = 6

    for i = 1, MAX_RESPONSE_BUTTONS do
        if not Env.settings.lootSession.responseButtons[i] then
            Env.settings.lootSession.responseButtons[i] = {
                response = "Button" .. i,
                color = { 1, 1, 1 },
            }
        end

        responseArgs["button" .. i] = {
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 1,
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
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 2,
            name = "", -- L["Color"],
            desc = L["Color used for response."],
            width = 0.25,
            type = "color",
            get = function() return unpack(Env.settings.lootSession.responseButtons[i].color) end,
            set = function(info, r, g, b, a) Env.settings.lootSession.responseButtons[i].color = { r, g, b } end,
            hidden = function() return Env.settings.lootSession.responseCount < i end,
        }
        responseArgs["isNeed" .. i] = {
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 3,
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
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 4,
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
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 5,
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
            order = ORDER_LAST_RESPONSE_BUTTON - i * perRow + 6,
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
