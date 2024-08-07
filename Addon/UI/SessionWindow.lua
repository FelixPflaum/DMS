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
---@field frame SessionWindow
---@field itemIcons IconButon[]
---@field client LootSessionClient|nil
---@field host LootSessionHost|nil
local Controller = {
    itemIcons = {},
}

---------------------------------------------------------------------------
--- Status Headers
---------------------------------------------------------------------------

local function ShowCandidateTooltip(f)
    if Controller.client == nil then return end
    local tooltipText = ""
    local grey = "FF555555"
    for _, v in pairs(Controller.client.candidates) do
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
    GameTooltip:SetOwner(f, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(tooltipText)
end

---@param parent SessionWindow
local function CreateStatusHeaders(parent)
    ---@class SessionWindow
    parent = parent

    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    parent.HostNameLabel = parent:CreateFontString(nil, "OVERLAY", fontLabel)
    parent.HostNameLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 65, -6)
    parent.HostNameLabel:SetText(L["Host:"])

    parent.HostName = parent:CreateFontString(nil, "OVERLAY", fontValue)
    parent.HostName:SetPoint("TOPLEFT", parent.HostNameLabel, "TOPRIGHT", 10, 0)
    parent.HostName:SetText("---")

    parent.SessionStatus = parent:CreateFontString(nil, "OVERLAY", fontValue)
    parent.SessionStatus:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -35, -6)
    parent.SessionStatus:SetText("---")

    parent.SessionStatusLabel = parent:CreateFontString(nil, "OVERLAY", fontLabel)
    parent.SessionStatusLabel:SetPoint("TOPRIGHT", parent.SessionStatus, "TOPLEFT", -10, 0)
    parent.SessionStatusLabel:SetText(L["Status:"])

    parent.ClientsStatus = parent:CreateFontString(nil, "OVERLAY", fontValue)
    parent.ClientsStatus:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -37)
    parent.ClientsStatus:SetText("---")
    parent.ClientsStatus:SetScript("OnEnter", function(f) ShowCandidateTooltip(f) end)
    parent.ClientsStatus:SetScript("OnLeave", function() GameTooltip_Hide() end)

    parent.ClientsStatusLabel = parent:CreateFontString(nil, "OVERLAY", fontLabel)
    parent.ClientsStatusLabel:SetPoint("TOPRIGHT", parent.ClientsStatus, "TOPLEFT", -10, 0)
    parent.ClientsStatusLabel:SetText(L["Players ready:"])
    parent.ClientsStatusLabel:SetScript("OnEnter", function(f) ShowCandidateTooltip(f) end)
    parent.ClientsStatusLabel:SetScript("OnLeave", function() GameTooltip_Hide() end)
end

---@param text string
function Controller:SetHostName(text)
    self.frame.HostName:SetText(text)
end

---@param text string
---@param color "green"|"yellow"|"red"|nil
function Controller:SetSessionStatus(text, color)
    if color then
        if color == "red" then
            text = "|cFFRR4444" .. text
        elseif color == "yellow" then
            text = "|cFFFFFF44" .. text
        elseif color == "green" then
            text = "|cFF44FF44" .. text
        end
    end
    self.frame.SessionStatus:SetText(text)
end

---@param candidates table<string, LootCandidate>
function Controller:SetCandidateList(candidates)
    local count = 0
    local ready = 0
    for _, v in pairs(candidates) do
        count = count + 1
        if v.isResponding then
            ready = ready + 1
        else

        end
    end
    local text = ready .. "/" .. count
    if ready < count then
        text = "|cFFFFFF44" .. text
    end
    self.frame.ClientsStatus:SetText(text)
end

---------------------------------------------------------------------------
--- Item List
---
--- TODO
--- Columns, start top left outside of main frame.
---
--- ItemFrame
---     CheckMark
---     SelectedBorder
---     IconTexture
---
---
---
---------------------------------------------------------------------------

function Controller:UpdateItemSelect()
    ---@type LootSessionClientItem[]
    local ordered = {}
    for _, item in pairs(Controller.client.items) do
        table.insert(ordered, item)
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    for k, item in ipairs(ordered) do
        if not self.itemIcons[k] then
            local newBtn = Env.UI.CreateIconButton(Controller.frame)
            if k == 1 then
                newBtn:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -10, 0)
            else
                newBtn:SetPoint("TOP", self.itemIcons[k - 1], "BOTTOM", 0, -2)
            end
            self.itemIcons[k] = newBtn
        end
        local btn = self.itemIcons[k]
        btn:SetBorderColor("grey")
        btn:SetItemData(item.itemId, item.guid)
        btn:SetOnClick(function(guid) 
            --TODO: item selection
            print("Clicked item", guid) 
        end)
        btn:Show()
    end

    for i = #ordered + 1, #self.itemIcons do
        self.itemIcons[i]:Hide()
    end
end

---------------------------------------------------------------------------
--- Main Window
---------------------------------------------------------------------------

local WIDTH = 600
local HEIGHT = 400

local function CreateWindow()
    ---@class SessionWindow : ButtonFrameTemplate
    local frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
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

    CreateStatusHeaders(frame)

    return frame
end

function Controller:Show()
    if not self.frame then
        self.frame = CreateWindow()
    end
    self.frame:Show()
end

function Controller:Hide()
    if self.client and self.client.isFinished then
        self.client = nil
    end
    if self.host and self.host.isFinished then
        self.host = nil
    end
    self.frame:Hide()
end

function Controller:CloseClicked()
    if self.host and not self.host.isFinished then
        LibDialog:Spawn({
            text = "Do you want to abort the loot session?",
            on_cancel = function(self, data, reason) end,
            buttons = {
                {
                    text = "Abort",
                    on_click = function()
                        Controller.host:Destroy()
                        Controller.host = nil
                        Controller:Hide()
                    end,
                },
                {
                    text = "Minimize",
                    on_click = function()
                        Controller:Hide()
                    end,
                },
            },
        })
        return
    end
    self:Hide()
    if self.client and not self.client.isFinished then
        Env:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
    end
end

---@param clientSession LootSessionClient
function Controller:SetClient(clientSession)
    self.client = clientSession

    self:SetHostName(self.client.hostName)
    self:SetSessionStatus(L["Running"], "green")
    self:UpdateItemSelect()

    self.client.OnSessionEnd:RegisterCallback(function()
        self:SetSessionStatus(L["Ended"], "yellow")
        if not self.frame:IsShown() then
            self:Hide()
        end
    end)

    self.client.OnCandidateUpdate:RegisterCallback(function()
        self:SetCandidateList(clientSession.candidates)
    end)

    self.client.OnItemUpdate:RegisterCallback(function(item)
        self:UpdateItemSelect()
    end)
end

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

Env.Session.Client.OnClientStart:RegisterCallback(function(session)
    if Controller.client then
        Env:PrintDebug("Got new session start but client for UI already set!")
        return
    end

    Controller:Show()
    local hostSession = Env.Session.Host:GetSession()
    if hostSession and hostSession.sessionGUID == session.sessionGUID then
        Controller.host = hostSession
    end
    Controller:SetClient(session)
end)

Env:RegisterSlashCommand("open", L["Opens session window if a session is running."], function(args)
    if not Controller.client or Controller.client.isFinished then
        Env:PrintError(L["No session is running!"])
        return
    end
    Controller:Show()
end)
