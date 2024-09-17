---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local LibDialog = LibStub("LibDialog-1.1")
local ColorByClassId = Env.UI.ColorByClassId
local AceGUI = LibStub("AceGUI-3.0")

---------------------------------------------------------------------------
--- Main Window Setup
---------------------------------------------------------------------------

local TOP_INSET = 30
local TABLE_ROW_HEIGHT = 18
local TABLE_ROWS = 10
local CONTENT_PADDING = 12
local NON_CONTENT_WIDTH = 8 + CONTENT_PADDING * 2
local NON_CONTENT_HEIGHT = 28 + CONTENT_PADDING * 2

---@alias DistUITab "none"|"ready"|"raid"|"custom"

local mainWindow ---@type DbWindow
local currentTab = "none" ---@type DistUITab
local tabs = {} ---@type table<DistUITab, {frame:WoWFrame, button:WoWFrameButton, updateFunc:fun(isShown:boolean)}>
local lastTabButton = nil ---@type WoWFrameButton?

local function Script_Close()
    mainWindow:Hide()
end

---Switch shown tab.
---@param tabId DistUITab
local function SwitchTab(tabId)
    local tab = tabs[tabId]
    if not tab then return end
    currentTab = tabId
    for k, v in pairs(tabs) do
        if k ~= tabId then
            v.button:Enable()
            v.frame:Hide()
            v.updateFunc(false)
        else
            v.button:Disable()
            v.frame:Show()
            tab.updateFunc(true)
        end
    end
end

---Add tab to window.
---@param tabId DistUITab
---@param contentFrame WoWFrame
---@param buttonText string
---@param updateFunc fun(isShown:boolean)
local function AddTab(tabId, contentFrame, buttonText, updateFunc)
    local btn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
    btn:SetText(buttonText)
    btn:SetWidth(btn:GetTextWidth() + 15)
    if lastTabButton then
        btn:SetPoint("LEFT", lastTabButton, "RIGHT", 5, 0)
    else
        btn:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, -27)
    end
    btn:SetScript("OnClick", function() SwitchTab(tabId) end)
    lastTabButton = btn

    tabs[tabId] = {
        frame = contentFrame,
        button = btn,
        updateFunc = updateFunc
    }

    contentFrame:SetPoint("TOPLEFT", mainWindow.Inset, "TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING)
    contentFrame:Hide()

    local newWidth = contentFrame:GetWidth() + NON_CONTENT_WIDTH
    if mainWindow:GetWidth() < newWidth then
        mainWindow:SetWidth(newWidth)
    end
    local newHeight = contentFrame:GetHeight() + NON_CONTENT_HEIGHT + TOP_INSET
    if mainWindow:GetHeight() < newHeight then
        mainWindow:SetHeight(newHeight)
    end
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    ---@class DbWindow : ButtonWindow
    mainWindow = Env.UI.CreateButtonWindow("DMSDistWindow", L["Sanity Distribution"], 450, 200, TOP_INSET, false, Env.settings.UI.DistWindow)
    mainWindow.onTopCloseClicked = Script_Close
    mainWindow:SetFrameStrata("HIGH")
end)

Env.UI:RegisterOnReset(function()
    mainWindow:Reset()
end)

---------------------------------------------------------------------------
--- Preperation sanity tab
---------------------------------------------------------------------------

local nearbyTable ---@type ST_ScrollingTable
local nearbyInfoText ---@type FontString

local NEARBY_PLAYER_TABLE_INDICES = {
    NAME = 1,
    DISTANCE = 2,
    IN_RANGE = 3,
    WORLDBUFFS = 4,
}

-- Dialog for confirming award of prep sanity to nearby raid members.
local confirmReadyAwardDialog = {
    text = L["Really award sanity to all players in range?"],
    on_cancel = function(self, data, arg) end,
    buttons = {
        {
            text = L["Accept"],
            on_click = function(self, arg)
                Env.PointDistributor.AwardReadyPointsToInRange()
            end
        },
        {
            text = L["Cancel"],
            on_click = function(self, arg) end
        },
    },
}

---@type ST_CellUpdateFunc
local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local name = data[realrow][column] ---@type string
    local _, _, classId = UnitClass(name)
    if classId then
        cellFrame.text:SetText(ColorByClassId(name, classId))
    else
        cellFrame.text:SetText(name)
    end
end

---@type ST_CellUpdateFunc
local function CellUpdateDistance(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local distance = data[realrow][column] ---@type number
    local inRange = data[realrow][NEARBY_PLAYER_TABLE_INDICES.IN_RANGE] ---@type integer
    if inRange == 1 then
        cellFrame.text:SetText(("|cFF33AA33%.0f|r"):format(distance))
    else
        cellFrame.text:SetText(("|cFFAA3333%.0f|r"):format(distance))
    end
end

local nearbyUpdateTimer = nil ---@type TimerHandle?

---Update nearby player table and status for prep tab.
local function UpdateNearbyPlayerTable()
    Env:PrintDebug("UpdateNearbyTable")
    ---@type ST_DataMinimal[]
    local dataTable = {}
    local list = Env.PointDistributor.GetPlayerReadyList()
    local inRangeCount = 0
    for _, entry in ipairs(list) do
        local rowData = { entry.name, entry.distance, entry.inRange and 1 or 0, tostring(entry.wbCount) } ---@type any[]
        table.insert(dataTable, rowData)
        if entry.inRange then
            inRangeCount = inRangeCount + 1
        end
    end
    nearbyTable:SetData(dataTable, true)
    nearbyInfoText:SetText(L["%d / %d in range (%d y) for sanity."]:format(inRangeCount, #list, Env.settings.pointDistrib.inRangeReadyMaxDistance))
    nearbyUpdateTimer = C_Timer.NewTimer(2, UpdateNearbyPlayerTable)
end

---Update function for prep tab.
---@param isShown boolean
local function UpdateNearbyTab(isShown)
    Env:PrintDebug("UpdateNearbyTab", isShown)
    if isShown then
        UpdateNearbyPlayerTable()
        Env:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateNearbyPlayerTable)
        if not nearbyUpdateTimer then
            nearbyUpdateTimer = C_Timer.NewTimer(2, UpdateNearbyPlayerTable)
        end
    else
        Env:UnregisterEvent("GROUP_ROSTER_UPDATE", UpdateNearbyPlayerTable)
        if nearbyUpdateTimer then
            nearbyUpdateTimer:Cancel()
            nearbyUpdateTimer = nil
        end
    end
end

-- Create prep sanity award tab.
Env:OnAddonLoaded(function()
    local tabFrame = CreateFrame("Frame", nil, mainWindow)
    tabFrame:SetSize(420, TABLE_ROWS * TABLE_ROW_HEIGHT + 30)

    nearbyTable = ScrollingTable:CreateST({
        [NEARBY_PLAYER_TABLE_INDICES.NAME] = { name = L["Name"], width = 90, DoCellUpdate = CellUpdateName, defaultsort = ScrollingTable.SORT_ASC },
        [NEARBY_PLAYER_TABLE_INDICES.DISTANCE] = { name = L["Distance"], width = 60, DoCellUpdate = CellUpdateDistance, defaultsort = ScrollingTable.SORT_DSC },
        [NEARBY_PLAYER_TABLE_INDICES.IN_RANGE] = { name = "-", width = 1, sort = ScrollingTable.SORT_DSC, sortnext = NEARBY_PLAYER_TABLE_INDICES.NAME },
        [NEARBY_PLAYER_TABLE_INDICES.WORLDBUFFS] = { name = L["Buffs"], width = 40 },
    }, TABLE_ROWS, TABLE_ROW_HEIGHT, nil, tabFrame)
    nearbyTable.frame:SetPoint("TOPRIGHT", 0, -nearbyTable.head:GetHeight() - 4)

    local heading = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetText(L["Award Preperation Sanity"])
    heading:SetPoint("TOPLEFT", 0, 0)

    nearbyInfoText = tabFrame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    nearbyInfoText:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -15)
    nearbyInfoText:SetText("------------------------------------")

    local buttonAward = CreateFrame("Button", nil, tabFrame, "UIPanelButtonTemplate")
    buttonAward:SetText(L["Award Sanity"])
    buttonAward:SetWidth(buttonAward:GetTextWidth() + 30)
    buttonAward:SetPoint("TOPLEFT", nearbyInfoText, "BOTTOMLEFT", 0, -10)
    buttonAward:SetScript("OnClick", function()
        if not LibDialog:ActiveDialog(confirmReadyAwardDialog) then
            LibDialog:Spawn(confirmReadyAwardDialog)
        end
    end)

    AddTab("ready", tabFrame, L["Preperation"], UpdateNearbyTab)
end)

---------------------------------------------------------------------------
--- Raid points
---------------------------------------------------------------------------

local groupListTable ---@type ST_ScrollingTable
local completionRaidInput ---@type EditBox
local completionPointInput ---@type EditBox
local completionInfoText ---@type FontString

-- Dialog for confirming award of prep sanity to nearby raid members.
local confirmRaidPointAward = {
    text = "-", -- To init height.
    on_cancel = function(self, data, arg) end,
    buttons = {
        {
            text = L["Accept"],
            ---@param arg {points:integer, raidName:string, includeOffline:boolean}
            on_click = function(self, arg)
                Env.PointDistributor.AwardRaidCompletePoints(arg.points, arg.raidName, arg.includeOffline)
            end
        },
        {
            text = L["Cancel"],
            on_click = function(self, arg) end
        },
    },
}

---Update raid list for completion tab.
local function UpdateRaidPlayerTable()
    Env:PrintDebug("UpdateRaidPlayerTable")
    ---@type ST_DataMinimal[]
    local dataTable = {}
    local list = Env.PointDistributor.GetCurrentGroup()
    local online = 0
    for _, entry in ipairs(list) do
        local rowData = { entry.name, entry.isOnline and 1 or 0 } ---@type any[]
        table.insert(dataTable, rowData)
        if entry.isOnline then
            online = online + 1
        end
    end
    groupListTable:SetData(dataTable, true)
    completionInfoText:SetText(L["%d / %d group members will receive sanity."]:format(online, #list))
end

---Update function for completion tab.
---@param isShown boolean
local function UpdateRaidTab(isShown)
    Env:PrintDebug("UpdateRaidTab", isShown)
    if isShown then
        UpdateRaidPlayerTable()
        Env:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateRaidPlayerTable)
        completionPointInput:SetText(tostring(Env.settings.pointDistrib.raidCompleteDefaultPoints))
        completionRaidInput:SetText(GetInstanceInfo())
    else
        Env:UnregisterEvent("GROUP_ROSTER_UPDATE", UpdateRaidPlayerTable)
    end
end

---@type ST_CellUpdateFunc
local function CellUpdateStatus(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local online = data[realrow][column] ---@type integer
    if online == 1 then
        cellFrame.text:SetText("")
    else
        cellFrame.text:SetText("|cFFAA3333"..L["Offline"].."|r")
    end
end

-- Create raid completion award tab.
Env:OnAddonLoaded(function()
    local tabFrame = CreateFrame("Frame", nil, mainWindow)
    tabFrame:SetSize(420, TABLE_ROWS * TABLE_ROW_HEIGHT + 30)

    groupListTable = ScrollingTable:CreateST({
        { name = L["Name"], width = 90, DoCellUpdate = CellUpdateName, sort = ScrollingTable.SORT_ASC },
        { name = L["Status"], width = 70, DoCellUpdate = CellUpdateStatus, defaultsort = ScrollingTable.SORT_DSC },
    }, TABLE_ROWS, TABLE_ROW_HEIGHT, nil, tabFrame)
    groupListTable.frame:SetPoint("TOPRIGHT", 0, -nearbyTable.head:GetHeight() - 4)

    local heading = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetText(L["Award Raid Completion Sanity"])
    heading:SetPoint("TOPLEFT", 0, 0)

    local labelRaid = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelRaid:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -15)
    labelRaid:SetText(L["Raid"])

    completionRaidInput = CreateFrame("EditBox", nil, tabFrame, "InputBoxTemplate")
    completionRaidInput:SetAutoFocus(false)
    completionRaidInput:SetFontObject(ChatFontNormal)
    completionRaidInput:SetScript("OnEscapePressed", EditBox_ClearFocus)
    completionRaidInput:SetScript("OnEnterPressed", EditBox_ClearFocus)
    completionRaidInput:SetTextInsets(0, 0, 3, 3)
    completionRaidInput:SetMaxLetters(20)
    completionRaidInput:SetPoint("LEFT", labelRaid, "RIGHT", -labelRaid:GetWidth() + 60, 0)
    completionRaidInput:SetHeight(19)
    completionRaidInput:SetWidth(150)

    local labelPoints = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelPoints:SetPoint("TOPLEFT", labelRaid, "BOTTOMLEFT", 0, -15)
    labelPoints:SetText(L["Sanity"])

    completionPointInput = CreateFrame("EditBox", nil, tabFrame, "InputBoxTemplate")
    completionPointInput:SetAutoFocus(false)
    completionPointInput:SetFontObject(ChatFontNormal)
    completionPointInput:SetScript("OnEscapePressed", EditBox_ClearFocus)
    completionPointInput:SetScript("OnEnterPressed", EditBox_ClearFocus)
    completionPointInput:SetTextInsets(0, 0, 3, 3)
    completionPointInput:SetMaxLetters(4)
    completionPointInput:SetPoint("LEFT", labelPoints, "RIGHT", -labelPoints:GetWidth() + 60, 0)
    completionPointInput:SetHeight(19)
    completionPointInput:SetWidth(50)

    local offlineCheckbox = AceGUI:Create("CheckBox") ---@type any
    offlineCheckbox.frame:SetParent(tabFrame)
    offlineCheckbox.parent = tabFrame
    offlineCheckbox.frame:Show()
    offlineCheckbox.text:SetText(L["Include Offline"])
    offlineCheckbox:SetValue(true)
    offlineCheckbox:SetPoint("TOPLEFT", labelPoints, "BOTTOMLEFT", 0, -15)
    offlineCheckbox:SetWidth(150)

    completionInfoText = tabFrame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    completionInfoText:SetPoint("TOPLEFT", offlineCheckbox.frame, "BOTTOMLEFT", 0, -15)
    completionInfoText:SetText("------------------------------------")

    local buttonAward = CreateFrame("Button", nil, tabFrame, "UIPanelButtonTemplate")
    buttonAward:SetText(L["Award Sanity"])
    buttonAward:SetWidth(buttonAward:GetTextWidth() + 30)
    buttonAward:SetPoint("TOPLEFT", completionInfoText, "BOTTOMLEFT", 0, -10)
    buttonAward:SetScript("OnClick", function()
        EditBox_ClearFocus(completionPointInput)
        EditBox_ClearFocus(completionPointInput)
        local raid = completionRaidInput:GetText()
        local includeOffline = offlineCheckbox:GetValue() ---@type boolean
        local pointStr = completionPointInput:GetText()
        local pointNum = tonumber(pointStr)
        if not pointNum or not raid or raid == "" then return end
        pointNum = math.floor(pointNum)
        if pointNum <= 0 then return end
        if not LibDialog:ActiveDialog(confirmRaidPointAward) then
            LibDialog:Dismiss(confirmRaidPointAward)
        end
        local dialog = LibDialog:Spawn(confirmRaidPointAward, { points = pointNum, raidName = raid, includeOffline = includeOffline }) ---@type any
        dialog.text:SetText(L["Really award %d sanity to raid?"]:format(pointNum))
    end)

    AddTab("raid", tabFrame, L["Raid Completion"], UpdateRaidTab)
end)

---------------------------------------------------------------------------
--- Slash command
---------------------------------------------------------------------------

Env:RegisterSlashCommand("dist", L["Show sanity distribution window."], function(args)
    if currentTab == "none" then
        SwitchTab("ready")
    else
        SwitchTab(currentTab)
    end
    mainWindow:Show()
end)
