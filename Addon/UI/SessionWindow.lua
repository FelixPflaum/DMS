---@type string
local addonName = select(1, ...)
---@class AddonEnv
local DMS = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")
local LibDialog = LibStub("LibDialog-1.1")
local L = DMS:GetLocalization()

DMS.UI = DMS.UI or {}
DMS.UI.SessionWindow = {}

---@type LootSessionClient|nil
local currentClientSession = nil
---@type LootSessionHost|nil
local currentHostSession = nil

---------------------------------------------------------------------------
--- Events
---------------------------------------------------------------------------

---@alias SessionWindowEvent
---| "ITEM_SELECTED"
---| "AWARD_CLICKED"
---| "AWARD_REVERT_CLICKED"
---| "DISENCHANT_CLICKED"
---| "CLOSE_CLICKED"

---@type table<SessionWindowEvent, fun(event:SessionWindowEvent, ...)[]>
local callbacks = {}

---@param event SessionWindowEvent
---@param callback fun(event:SessionWindowEvent, ...)
function DMS.UI.SessionWindow:RegisterEvent(event, callback)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], callback)
end

---@param event SessionWindowEvent
local function FireEvent(event, ...)
    if callbacks[event] then
        for _, cb in ipairs(callbacks[event]) do
            cb(...)
        end
    end
end

---------------------------------------------------------------------------
--- Events
---------------------------------------------------------------------------

---Get path to an image file of the addon.
---@param imgName string The name of the image.
local function GetImagePath(imgName)
    return [[Interface\AddOns\]] .. addonName .. [[\UI\img\]] .. imgName
end

local WIDTH = 600

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetWidth(WIDTH)
    frame:SetHeight(400)
    frame:SetClampedToScreen(true)

    ButtonFrameTemplate_HideButtonBar(frame)

    LibWindow:Embed(frame)
    frame:RegisterConfig(DMS.settings.UI.SessionWindow)
    frame:SetScale(DMS.settings.UI.SessionWindow.scale or 1.0)
    frame:RestorePosition()
    frame:EnableMouse(true)
    frame:MakeDraggable()
    frame:SetScript("OnMouseWheel", function(f, delta)
        if IsControlKeyDown() then
            LibWindow.OnMouseWheel(f, delta)
        end
    end)

    frame.TitleText:SetText(addonName)
    frame.portrait:SetTexture(GetImagePath("logo.png"))

    frame.CloseButton:SetScript("OnClick", function()
        if currentSession and currentSession:IsHost() then
            LibDialog:Spawn({
                text = "Do you want to abort the loot session?",
                on_cancel = function(self, data, reason) end,
                buttons = {
                    {
                        text = "Abort",
                        on_click = function(self, mouseButton, down)
                            print("You clicked a button 1.")
                            FireEvent("CLOSE_CLICKED")
                        end,
                    },
                    {
                        text = "Minimize",
                        on_click = function(self, mouseButton, down)
                            print("You clicked a button 2.")
                            DMS.UI.SessionWindow:Hide()
                        end,
                    },
                },
            })
            return
        end
        DMS.UI.SessionWindow:Hide()
    end)

    return frame
end

local function CreateStatusHeader(frame)
    local fontLabel = "GameFontNormalMed2"
    local fontValue = fontLabel

    frame.labelHost = frame:CreateFontString(nil, "OVERLAY", fontLabel);
    frame.labelHost:SetPoint("TOPLEFT", 65, -35);
    frame.labelHost:SetText("Host:");

    frame.hostName = frame:CreateFontString(nil, "OVERLAY", fontValue);
    frame.hostName:SetPoint("TOPLEFT", frame.labelHost, "TOPRIGHT", 10, 0);
    frame.hostName:SetText("---");

    frame.labelStatus = frame:CreateFontString(nil, "OVERLAY", fontLabel);
    frame.labelStatus:SetPoint("TOPLEFT", frame.labelHost, "TOPRIGHT", 100, 0);
    frame.labelStatus:SetText("Status:");

    frame.statusString = frame:CreateFontString(nil, "OVERLAY", fontValue);
    frame.statusString:SetPoint("TOPLEFT", frame.labelStatus, "TOPRIGHT", 10, 0);
    frame.statusString:SetText("---");

    frame.labelConnected = frame:CreateFontString(nil, "OVERLAY", fontLabel);
    frame.labelConnected:SetPoint("TOPLEFT", frame.labelStatus, "TOPRIGHT", 100, 0);
    frame.labelConnected:SetText("Connected:");

    frame.connectedPlayers = frame:CreateFontString(nil, "OVERLAY", fontValue);
    frame.connectedPlayers:SetPoint("TOPLEFT", frame.labelConnected, "TOPRIGHT", 10, 0);
    frame.connectedPlayers:SetText("---");
end

---Create the session window frame.
local function CreateWindow()
    local frame = CreateMainFrame()
    CreateStatusHeader(frame)
    return frame
end

local window = nil

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

function DMS.UI.SessionWindow:Show()
    if not window then
        window = CreateWindow()
    end
    window:Show()
end

function DMS.UI.SessionWindow:Hide()
    if not window then
        return
    end
    if currentClientSession and currentClientSession.isFinished then
        currentClientSession = nil
    end
    if currentHostSession and currentHostSession.isFinished then
        currentHostSession = nil
    end
    window:Hide()
end

---Set session info for header.
---@param host string Name of the player that started the session.
---@param connected string How many players are responding.
---@param status string A status string shown in the header.
local function SetSessionInfo(host, connected, status)
    if not window then
        window = CreateWindow()
    end
    window.hostName:SetText(host)
    window.statusString:SetText(status)
    window.connectedPlayers:SetText(connected)
end

---@param client LootSessionClient
local function HookupClient(client)
    if not window or not currentClientSession then
        return
    end

    client.OnSessionEnd:RegisterCallback(function()
        SetSessionInfo(currentClientSession.hostName, "0", L["Ended"])
    end)

    client.OnCandidateUpdate:RegisterCallback(function()
        local numCandidates = 0
        for _ in pairs(client.candidates) do
            numCandidates = numCandidates + 1
        end
        SetSessionInfo(currentClientSession.hostName, numCandidates, L["Running"])
    end)
end

DMS.Session.Client.OnClientStart:RegisterCallback(function(session)
    DMS.UI.SessionWindow:Show()
    SetSessionInfo(session.hostName, "0", session.isFinished and L["Ended"] or L["Running"])
    currentClientSession = session
    local hostSession = DMS.Session.Host:GetSession()
    if hostSession and hostSession.sessionGUID == session.sessionGUID then
        currentHostSession = hostSession
    end
    HookupClient(currentClientSession)
end)
