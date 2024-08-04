---@type string
local addonName = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")
local LibDialog = LibStub("LibDialog-1.1")
local L = DMS:GetLocalization()

---@class SessionWindowController
---@field frame SessionWindow
---@field client LootSessionClient|nil
---@field host LootSessionHost|nil
local Controller = {}

---Get path to an image file of the addon.
---@param imgName string The name of the image.
local function GetImagePath(imgName)
    return [[Interface\AddOns\]] .. addonName .. [[\UI\img\]] .. imgName
end

---------------------------------------------------------------------------
--- Status Headers
---------------------------------------------------------------------------

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

    parent.ClientsStatusLabel = parent:CreateFontString(nil, "OVERLAY", fontLabel)
    parent.ClientsStatusLabel:SetPoint("TOPRIGHT", parent.ClientsStatus, "TOPLEFT", -10, 0)
    parent.ClientsStatusLabel:SetText(L["Players ready:"])
end

---@param text string
function Controller:SetHostName(text)
    self.frame.HostName:SetText(text)
end

---@param text string
function Controller:SetSessionStatus(text)
    self.frame.SessionStatus:SetText(text)
end

---@param candidates table<string, LootCandidate>
function Controller:SetConnected(candidates)
    local count = 0
    local ready = 0
    for _, v in pairs(candidates) do
        DMS:PrintDebug(v)
        count = count + 1
        if v.isResponding then
            ready = ready + 1
        else

        end
    end
    self.frame.ClientsStatus:SetText(ready .. "/" .. count)
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
    frame:RegisterConfig(DMS.settings.UI.SessionWindow) ---@diagnostic disable-line: undefined-field
    frame:SetScale(DMS.settings.UI.SessionWindow.scale or 1.0)
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
    if self.host then
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
        DMS:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
    end
end

---@param clientSession LootSessionClient
function Controller:SetClient(clientSession)
    self:SetHostName(clientSession.hostName)
    self:SetSessionStatus(L["Running"])

    self.client = clientSession

    clientSession.OnSessionEnd:RegisterCallback(function()
        self:SetSessionStatus(L["Ended"])
        if not self.frame:IsShown() then
            self:Hide()
        end
    end)

    clientSession.OnCandidateUpdate:RegisterCallback(function()
        self:SetConnected(clientSession.candidates)
    end)
end

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

DMS.Session.Client.OnClientStart:RegisterCallback(function(session)
    if Controller.client then
        DMS:PrintDebug("Got new session start but client for UI already set!")
        return
    end

    Controller:Show()
    local hostSession = DMS.Session.Host:GetSession()
    if hostSession and hostSession.sessionGUID == session.sessionGUID then
        Controller.host = hostSession
    end
    Controller:SetClient(session)
end)

DMS:RegisterSlashCommand("open", L["Opens session window if a session is running."], function(args)
    if not Controller.client or Controller.client.isFinished then
        DMS:PrintError(L["No session is running!"])
        return
    end
    Controller:Show()
end)
