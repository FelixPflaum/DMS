---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
local LibDialog = LibStub("LibDialog-1.1")

---------------------------------------------------------------------------
--- Main Window Setup
---------------------------------------------------------------------------

local syncWindow ---@type SyncWindow

local function CloseWindow()
    syncWindow:Hide()
    Env.Sync.EnableSync(false)
end

local function SettingsInit()
    local target = syncWindow.NameInput:GetText()
    if target and target ~= "" then
        syncWindow.SendSettingsButton:Disable()
        syncWindow.SendDataButton:Disable()
        Env.Sync.Initiate(target, "settings")
    end
end

local function Reset()
    syncWindow.SendSettingsButton:Enable()
    syncWindow.SendDataButton:Enable()
    syncWindow.InfoText:SetText("")
    syncWindow.ProgressText:SetText("")
end

Env.Sync.OnSendProgress:RegisterCallback(function(target, state, sent, total)
    if syncWindow:IsShown() then
        if state == "probing" then
            Reset()
            syncWindow.InfoText:SetText(L["Trying to send to %s..."]:format(target))
        elseif state == "waiting" then
            syncWindow.InfoText:SetText(L["Waiting for %s to accept..."]:format(target))
        elseif state == "sending" then
            if sent < total then
                syncWindow.InfoText:SetText(L["Sending to %s..."]:format(target))
            else
                syncWindow.InfoText:SetText(L["Done!"])
            end
            syncWindow.ProgressText:SetText(L["%dB / %dB (%.1f%%)"]:format(sent, total, (sent / total) * 100))
        elseif state == "failed" then
            Reset()
            syncWindow.InfoText:SetText(L["Sending to %s failed!"]:format(target))
        end
    end
end)

local confirmReceiveDialog = {
    show_while_dead = true,
    text = "-", -- So height is initialized
    on_cancel = function(self, data, source)
        Env.Sync.RespondToProbe(source, false)
    end,
    buttons = {
        {
            text = L["Accept"],
            on_click = function(self, source)
                Env.Sync.RespondToProbe(source, true)
                syncWindow.InfoText:SetText(L["Waiting for data..."])
            end
        },
        {
            text = L["Cancel"],
            on_click = function(self, source)
                Env.Sync.RespondToProbe(source, false)
            end
        },
    },
}

---@param dataType SyncDataType
local function GetDataTypeString(dataType)
    return dataType == "settings" and L["settings"] or "?"
end

Env.Sync.OnProbe:RegisterCallback(function(source, dataType)
    if syncWindow:IsShown() then
        if LibDialog:ActiveDialog(confirmReceiveDialog) then
            LibDialog:Dismiss(confirmReceiveDialog)
        end
        local dialog = LibDialog:Spawn(confirmReceiveDialog, source) ---@type any
        dialog.text:SetText(L["%s wants to send you %s data."]:format(source, GetDataTypeString(dataType)))
    end
end)

Env.Sync.OnReceived:RegisterCallback(function(source, dataType)
    if syncWindow:IsShown() then
        syncWindow.InfoText:SetText(L["Received %s data successfully."]:format(GetDataTypeString(dataType)))
        syncWindow.ProgressText:SetText("")
    end
end)

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    ---@class SyncWindow : ButtonWindow
    syncWindow = Env.UI.CreateButtonWindow("DMSSyncWindow", L["DMS Sync"], 300, 150, 0, false, Env.settings.UI.SyncWindow)
    syncWindow.onTopCloseClicked = CloseWindow
    syncWindow:SetFrameStrata("DIALOG")

    local nameBox = CreateFrame("EditBox", nil, syncWindow, "InputBoxTemplate")
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject(ChatFontNormal)
    nameBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    nameBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    nameBox:SetTextInsets(0, 0, 3, 3)
    nameBox:SetMaxLetters(12)
    nameBox:SetPoint("TOP", syncWindow.Inset, "TOP", 0, -7)
    nameBox:SetHeight(24)
    nameBox:SetWidth(120)
    syncWindow.NameInput = nameBox

    local labelName = syncWindow.Inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelName:SetJustifyH("CENTER")
    labelName:SetPoint("RIGHT", nameBox, "LEFT", -10, 0)
    labelName:SetText(L["Target"])

    local buttonSettings = CreateFrame("Button", nil, syncWindow.Inset, "UIPanelButtonTemplate")
    buttonSettings:SetText(L["Send Settings"])
    buttonSettings:SetWidth(120)
    buttonSettings:SetHeight(27)
    buttonSettings:SetPoint("TOP", nameBox, "BOTTOM", -65, -5)
    buttonSettings:SetScript("OnClick", SettingsInit)
    syncWindow.SendSettingsButton = buttonSettings

    local buttonData = CreateFrame("Button", nil, syncWindow.Inset, "UIPanelButtonTemplate")
    buttonData:SetText(L["Send Data"])
    buttonData:SetWidth(120)
    buttonData:SetHeight(27)
    buttonData:SetPoint("TOP", nameBox, "BOTTOM", 65, -5)
    --buttonData:SetScript("OnClick", SettingsInit)
    syncWindow.SendDataButton = buttonData

    local infoText = syncWindow.Inset:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    infoText:SetJustifyH("CENTER")
    infoText:SetPoint("TOP", nameBox, "TOP", 0, -65)
    syncWindow.InfoText = infoText

    local progressText = syncWindow.Inset:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    progressText:SetJustifyH("CENTER")
    progressText:SetPoint("TOP", infoText, "BOTTOM", 0, -10)
    syncWindow.ProgressText = progressText
end)

local origSIF = SetItemRef
---@param link string
---@param text string
---@param button any
---@param chatFrame any
SetItemRef = function(link, text, button, chatFrame)
    if syncWindow.NameInput:HasFocus() then
        local namelink = link:sub(8)
        local name, lineID, chatType, chatTarget = strsplit(":", namelink)
        if (name and (name:len() > 0)) then
            name = Ambiguate(name, "short")
            syncWindow.NameInput:SetText(name)
            return
        end
    end
    origSIF(link, text, button, chatFrame)
end

Env.UI:RegisterOnReset(function()
    syncWindow:Reset()
end)

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

Env:RegisterSlashCommand("sync", L["Share settings or database with others."], function(args)
    Reset()
    syncWindow:Show()
    Env.Sync.EnableSync(true)
end)
