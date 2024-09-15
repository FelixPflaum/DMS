---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local ColorByClassId = Env.UI.ColorByClassId
local VersionCheck = Env.VersionCheck

local frame ---@type ButtonWindow
local sTable ---@type ST_ScrollingTable

local TABLE_INDICES = {
    PLAYER_NAME = 1,
    VERSION_STRING = 2,
    VERSION_NUM = 3,
    IS_OLDER = 4,
}

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local function CloseWindow()
    frame:Hide()
    VersionCheck.Enable(false)
end

local function CheckGuild()
    frame.LeftButton:Disable()
    frame.RightButton:Disable()
    VersionCheck.SendRequest("GUILD")
end

local function CheckGroup()
    frame.LeftButton:Disable()
    frame.RightButton:Disable()
    VersionCheck.SendRequest("RAID")
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local ROW_HEIGHT = 14

---@type ST_CellUpdateFunc
local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    if not fShow then return end
    local name = data[realrow][column] ---@type string
    local _, _, classId = UnitClass(name)
    if classId then
        cellFrame.text:SetText(ColorByClassId(data[realrow][column], classId))
    else
        cellFrame.text:SetText(data[realrow][column])
    end
end

---@type ST_CellUpdateFunc
local function CellUpdateVersion(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local versionString = data[realrow][column] ---@type string
    local versionNum = data[realrow][TABLE_INDICES.VERSION_NUM] ---@type integer
    if versionNum == -1 then
        versionString = L["No response"]
        versionString = "|cFFCC4444" .. versionString
    elseif versionString == "" then
        versionString = L["..."]
        versionString = "|cFFAACC44" .. versionString
    else
        local isOlder = data[realrow][TABLE_INDICES.IS_OLDER] ---@type boolean
        if isOlder then
            versionString = "|cFFCC4444" .. versionString
        else
            versionString = "|cFF44CC44" .. versionString
        end
    end
    cellFrame.text:SetText(versionString)
end

---@type ST_CellUpdateFunc
local function CellUpdateNil(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    frame = Env.UI.CreateButtonWindow("DMSTradeWindow", L["Version Check"], 111, 111, 0, true, Env.settings.UI.TradeWindow, "RIGHT", -150, 0)
    frame:AddLeftButton(L["Group"], CheckGroup)
    frame:AddRightButton(L["Guild"], CheckGuild)
    frame.onTopCloseClicked = CloseWindow

    sTable = ScrollingTable:CreateST({
        [TABLE_INDICES.PLAYER_NAME] = { name = "", width = 85, DoCellUpdate = CellUpdateName },
        [TABLE_INDICES.VERSION_STRING] = { name = "", width = 75, DoCellUpdate = CellUpdateVersion },
        [TABLE_INDICES.VERSION_NUM] = { name = "", width = 0, sort = ScrollingTable.SORT_DSC, sortnext = TABLE_INDICES.PLAYER_NAME },
        [TABLE_INDICES.IS_OLDER] = { name = "", width = 0, DoCellUpdate = CellUpdateNil },
    }, 20, ROW_HEIGHT, nil, frame)

    sTable.head:SetHeight(0)
    sTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -2, 4)
    frame:SetWidth(sTable.frame:GetWidth() + 6)
    frame:SetHeight(sTable.frame:GetHeight() + 44)
end)

VersionCheck.OnAllResponded:RegisterCallback(function(isTimeout)
    frame.LeftButton:Enable()
    frame.RightButton:Enable()
end)

VersionCheck.OnResponsesUpdate:RegisterCallback(function(list)
    local _, myVerNum = VersionCheck.GetMyVersion()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for player, data in pairs(list) do
        local isOlder = data.versionNum < myVerNum
        local versNum = data.state == "timeout" and -1 or data.versionNum
        local rowData = { player, data.version, versNum, isOlder } ---@type any[]
        table.insert(dataTable, rowData)
    end
    sTable:SetData(dataTable, true)
end)

Env:RegisterSlashCommand("v", L["Open version check."], function()
    frame:Show()
    VersionCheck.Enable(true)
end)
