---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local GetImagePath = Env.UI.GetImagePath
local ShowItemTooltip = Env.UI.ShowItemTooltip
local ColorByClassId = Env.UI.ColorByClassId
local Trade = Env.Trade

local frame ---@type ButtonWindow
local sTable ---@type ST_ScrollingTable

local TABLE_INDICES = {
    ICON = 1,
    ITEMLINK = 2,
    RECEIVER = 3,
    REMOVE_BTN = 4,
}

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local function CloseWindow()
    frame:Hide()
end

---@type ST_CellUpdateFunc
local function TableClicked(rowFrame, cellFrame, data, cols, row, realrow, column)
    local receiver = data[realrow][TABLE_INDICES.RECEIVER] ---@type string
    if column == TABLE_INDICES.REMOVE_BTN then
        local itemLink = data[realrow][TABLE_INDICES.ITEMLINK] ---@type string
        local itemId = Env.Item.GetIdFromLink(itemLink)
        if itemId then
            Trade:RemoveItem(itemId, receiver)
        end
    else
        Trade:InitiateTrade(receiver)
    end
    return false
end

local function UpdateRange()
    if frame:IsShown() then
        if #sTable.data > 0 then
            sTable:Refresh()
        end
        C_Timer.NewTimer(1, UpdateRange)
    end
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local ROW_HEIGHT = 24

---Display item icon and show tooltip on hover.
---@type ST_CellUpdateFunc
local function CellUpdateIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local texture = data[realrow][column]
    cellFrame:SetNormalTexture(texture or [[Interface/Icons/inv_misc_questionmark]])
    local link = data[realrow][2]
    cellFrame:SetScript("OnEnter", function(f) ShowItemTooltip(f, link) end)
    cellFrame:SetScript("OnLeave", GameTooltip_Hide)
end

---Display x icon.
---@type ST_CellUpdateFunc
local function CellUpdateRemoveButton(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    cellFrame:SetNormalTexture(GetImagePath("bars_05.png"))
end

local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end

    local name = data[realrow][column] ---@type string
    if not CheckInteractDistance(name, 2) then
        cellFrame.text:SetText("|cFFFF2222"..name.."|r")
        return
    end

    local _, _, classId = UnitClass(name)
    if classId then
        cellFrame.text:SetText(ColorByClassId(name, classId))
    else
        cellFrame.text:SetText(name)
    end
end

local function CreateFrame()
    frame = Env.UI.CreateButtonWindow("DMSTradeWindow", L["Trade Items"], 111, 111, 0, false, Env.settings.UI.TradeWindow, "RIGHT", -150, 0)
    frame.onTopCloseClicked = CloseWindow

    sTable = ScrollingTable:CreateST({
        [TABLE_INDICES.ICON] = { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateIcon },
        [TABLE_INDICES.ITEMLINK] = { name = "", width = 125, },
        [TABLE_INDICES.RECEIVER] = { name = "", width = 100, DoCellUpdate = CellUpdateName },
        [TABLE_INDICES.REMOVE_BTN] = { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateRemoveButton },
    }, 7, ROW_HEIGHT, nil, frame)

    sTable.head:SetHeight(0)
    sTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -2, 4)
    sTable:RegisterEvents({ OnClick = TableClicked })
    frame:SetWidth(sTable.frame:GetWidth() + 6)
    frame:SetHeight(sTable.frame:GetHeight() + 22)
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    CreateFrame()
end)

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady

---Update shown table content.
Trade.OnItemsChanged:RegisterCallback(function(items)
    if #items == 0 then
        frame:Hide()
        return
    end

    if not frame:IsShown() then
        frame:Show()
        frame:SetFrameLevel(1000)
        UpdateRange()
    end

    ---@type ST_DataMinimal[]
    local dataTable = {}
    for idx, entry in ipairs(items) do
        local rowData = { nil, entry.itemId, entry.receiver, idx } ---@type any[]
        DoWhenItemInfoReady(entry.itemId, function(_, itemLink, _, _, _, _, _, _, _, itemTexture)
            rowData[1] = itemTexture
            rowData[2] = itemLink
            sTable:Refresh()
        end)
        table.insert(dataTable, rowData)
    end
    sTable:SetData(dataTable, true)
end)

Env.UI:RegisterOnReset(function()
    frame:Reset()
end)

Env:RegisterSlashCommand("trade", L["Open trade window."], function(args)
    if #sTable.data == 0 then
        Env:PrintError(L["There are no items to trade."])
        return
    end
    frame:Show()
    UpdateRange()
end)
