---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local GetImagePath = Env.UI.GetImagePath
local ShowItemTooltip = Env.UI.ShowItemTooltip
local LootList = Env.SessionLootList

local frame ---@type ButtonWindow
local st ---@type ST_ScrollingTable

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local function ButtonScript_Close()
    frame:Hide()
    LootList:Clear()
end

local function Script_AddToSession()
    LootList:AddListToSession()
    ButtonScript_Close()
end

---@type ST_CellUpdateFunc
local function Script_TableRemoveClicked(rowFrame, cellFrame, data, cols, row, realrow, column)
    if column == 3 then
        LootList:Remove(realrow)
    end
    return false
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local ROW_HEIGHT = 30

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

local function CreateFrame()
    frame = Env.UI.CreateButtonWindow("DMSLootWindow", L["Add Loot to Session"], 111, 111, 0, true, Env.settings.UI.LootWindow,
        "RIGHT", -150, 0)
    frame:AddLeftButton("Add", Script_AddToSession)
    frame:AddRightButton("Cancel", ButtonScript_Close)
    frame.onTopCloseClicked = ButtonScript_Close

    st = ScrollingTable:CreateST({
        { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateIcon },         -- Icon
        { name = "", width = 125, },                                              -- Name/ItemLink display
        { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateRemoveButton }, -- Remove
    }, 7, ROW_HEIGHT, nil, frame)

    st.head:SetHeight(0)
    st.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -2, 4)
    st:RegisterEvents({ OnClick = Script_TableRemoveClicked })
    frame:SetWidth(st.frame:GetWidth() + 6)
    frame:SetHeight(st.frame:GetHeight() + 44)
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
LootList.OnListUpdate:RegisterCallback(function(items)
    if #items == 0 then return end

    frame:Show()
    frame:SetFrameLevel(750)

    ---@type ST_DataMinimal[]
    local dataTable = {}
    for k, itemId in ipairs(items) do
        local rowData = { nil, itemId, k } ---@type any[]
        DoWhenItemInfoReady(itemId, function(_, itemLink, _, _, _, _, _, _, _, itemTexture)
            rowData[1] = itemTexture
            rowData[2] = itemLink
            st:Refresh()
        end)
        table.insert(dataTable, rowData)
    end
    st:SetData(dataTable, true)
end)

Env.UI:RegisterOnReset(function()
    frame:Reset()
end)
