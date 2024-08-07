---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")
local LibDialog = LibStub("LibDialog-1.1")
local L = Env:GetLocalization()

local GetImagePath = Env.UI.GetImagePath
local GetClassColor = Env.UI.GetClassColor

---@class (exact) SessionWindowController
local Controller = {}

local frame ---@type SessionWindow
local itemIcons = {} ---@type IconButon[]
local Host = Env.Session.Host
local Client = Env.Session.Client

local function IsHosting()
    return Client.sessionGUID == Host.sessionGUID and Host.isRunning
end

---------------------------------------------------------------------------
--- Status Headers
---------------------------------------------------------------------------

-- Frame Script Handlers

---@param anchorFrame WoWFrame
local function ShowCandidateTooltip(anchorFrame)
    local tooltipText = ""
    local grey = "FF555555"
    for _, v in pairs(Client.candidates) do
        local nameStr = v.name
        if v.leftGroup then
            nameStr = "|c" .. grey .. nameStr .. " (" .. L["Left group"] .. ")"
        elseif v.isOffline then
            nameStr = "|c" .. grey .. nameStr .. " (" .. L["Offline"] .. ")"
        elseif not v.isResponding then
            nameStr = "|c" .. grey .. nameStr .. " (" .. L["Not responding"] .. ")"
        else
            nameStr = "|c" .. GetClassColor(v.classId).argbstr .. nameStr
        end
        tooltipText = tooltipText .. nameStr .. "\n"
    end
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(tooltipText)
end

-- Create Frames

local function CreateStatusHeaders()
    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    frame.HostNameLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.HostNameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 65, -6)
    frame.HostNameLabel:SetText(L["Host:"])

    frame.HostName = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.HostName:SetPoint("TOPLEFT", frame.HostNameLabel, "TOPRIGHT", 10, 0)
    frame.HostName:SetText("---")

    frame.SessionStatus = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.SessionStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -6)
    frame.SessionStatus:SetText("---")

    frame.SessionStatusLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.SessionStatusLabel:SetPoint("TOPRIGHT", frame.SessionStatus, "TOPLEFT", -10, 0)
    frame.SessionStatusLabel:SetText(L["Status:"])

    frame.ClientsStatus = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.ClientsStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -37)
    frame.ClientsStatus:SetText("---")
    frame.ClientsStatus:SetScript("OnEnter", ShowCandidateTooltip)
    frame.ClientsStatus:SetScript("OnLeave", GameTooltip_Hide)

    frame.ClientsStatusLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.ClientsStatusLabel:SetPoint("TOPRIGHT", frame.ClientsStatus, "TOPLEFT", -10, 0)
    frame.ClientsStatusLabel:SetText(L["Players ready:"])
    frame.ClientsStatusLabel:SetScript("OnEnter", function() ShowCandidateTooltip(frame.ClientsStatus) end)
    frame.ClientsStatusLabel:SetScript("OnLeave", GameTooltip_Hide)
end

-- Event Hooks

Client.OnStart:RegisterCallback(function()
    frame.HostName:SetText(Client.hostName)
    frame.SessionStatus:SetText("|cFF44FF44" .. L["Running"])
end)

Client.OnEnd:RegisterCallback(function()
    frame.SessionStatus:SetText("|cFFFFFF44" .. L["Ended"])
end)

Client.OnCandidateUpdate:RegisterCallback(function()
    local count = 0
    local ready = 0
    for _, candidate in pairs(Client.candidates) do
        count = count + 1
        if candidate.isResponding and not candidate.isOffline and not candidate.leftGroup then
            ready = ready + 1
        end
    end
    local text = ready .. "/" .. count
    if ready < count then
        text = "|cFFFFFF44" .. text
    end
    frame.ClientsStatus:SetText(text)
end)

---------------------------------------------------------------------------
--- Item List
---------------------------------------------------------------------------

-- Frame Script Handlers

---@param guid string
local function Script_SelectItem(guid)
    --TODO: item selection
    print("Clicked item", guid)
end

-- Create Frames

local MAX_ICONS_PER_COLUMN = 9
local SELECT_ICON_SIZE = 40
local ICON_SLECT_OFFSET_X = -10

---@param index integer
local function GetOrCreateItemSelectIcon(index)
    if itemIcons[index] then
        return itemIcons[index]
    end

    local newBtn = Env.UI.CreateIconButton(frame, SELECT_ICON_SIZE)
    itemIcons[index] = newBtn

    if index == 1 then
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", ICON_SLECT_OFFSET_X, 0)
    elseif math.fmod(index - 1, MAX_ICONS_PER_COLUMN) == 0 then
        local column = math.ceil(index / MAX_ICONS_PER_COLUMN)
        local columnOffset = ICON_SLECT_OFFSET_X - (SELECT_ICON_SIZE + 5) * (column - 1)
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnOffset, 0)
    else
        newBtn:SetPoint("TOP", itemIcons[index - 1], "BOTTOM", 0, -2)
    end

    return newBtn
end

local function UpdateItemSelect()
    ---@type LootSessionClientItem[]
    local ordered = {}
    for _, item in pairs(Client.items) do
        table.insert(ordered, item)
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    for k, item in ipairs(ordered) do
        local btn = GetOrCreateItemSelectIcon(k)
        btn:SetBorderColor("grey")
        btn:SetItemData(item.itemId, item.guid)
        btn:SetOnClick(Script_SelectItem)
        btn:Show()
    end

    for i = #ordered + 1, #itemIcons do
        itemIcons[i]:Hide()
    end
end

-- Event Hooks

Client.OnItemUpdate:RegisterCallback(function(item)
    UpdateItemSelect()
end)

Client.OnStart:RegisterCallback(function()
    UpdateItemSelect()
end)

---------------------------------------------------------------------------
--- Main Window
---------------------------------------------------------------------------

local WIDTH = 600
local HEIGHT = 400

local function CreateWindow()
    ---@class SessionWindow : ButtonFrameTemplate
    frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetWidth(WIDTH)
    frame:SetHeight(HEIGHT)
    frame:SetClampedToScreen(true)
    ButtonFrameTemplate_HideButtonBar(frame)
    LibWindow:Embed(frame)
    frame:RegisterConfig(Env.settings.UI.SessionWindow) ---@diagnostic disable-line: undefined-field
    frame:SetScale(Env.settings.UI.SessionWindow.scale or 1.0)
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    frame:EnableMouse(true)
    frame:MakeDraggable() ---@diagnostic disable-line: undefined-field
    frame:SetScript("OnMouseWheel", function(f, d) if IsControlKeyDown() then LibWindow.OnMouseWheel(f, d) end end)
    frame.TitleText:SetText(addonName)
    frame.portrait:SetTexture(GetImagePath("logo.png"))
    frame.CloseButton:SetScript("OnClick", function() Controller:CloseClicked() end)

    CreateStatusHeaders()
end

Env:OnAddonLoaded(function()
    CreateWindow()
end)

function Controller:CloseClicked()
    if IsHosting() then
        LibDialog:Spawn({
            text = "Do you want to abort the loot session?",
            on_cancel = function(self, data, reason) end,
            buttons = {
                {
                    text = "Abort",
                    on_click = function()
                        Host:Destroy()
                        frame:Hide()
                    end,
                },
                {
                    text = "Minimize",
                    on_click = function()
                        frame:Hide()
                    end,
                },
            },
        })
        return
    end
    frame:Hide()
    if Client.isRunning then
        Env:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
    end
end

Client.OnStart:RegisterCallback(function()
    frame:Show()
end)

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

Env:RegisterSlashCommand("open", L["Opens session window if a session is running."], function(args)
    if not Client.isRunning then
        Env:PrintError(L["No session is running!"])
        return
    end
    frame:Show()
end)
