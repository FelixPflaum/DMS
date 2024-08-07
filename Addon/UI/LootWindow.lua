---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local GetImagePath = Env.UI.GetImagePath
local ShowItemTooltip = Env.UI.ShowItemTooltip

---@class (exact) LootWindowController
local Controller = {}
Env.UI = Env.UI or {}
Env.UI.LootWindow = Controller

---@alias LootWindowListItem {itemId:integer}

local items = {} ---@type LootWindowListItem[]
local frame ---@type ButtonWindow
local st ---@type ST_ScrollingTable

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local ROW_HEIGHT = 30

local UpdateTable

local function ButtonScript_Close()
    wipe(items)
    UpdateTable()
    frame:Hide()
end

local function Script_AddToSession()
    local hostSession = Env.Session.Host:GetSession()
    if not hostSession then
        local session, err = Env.Session.Host:Start("self")
        if not session or err then
            if err then Env:PrintError(err) end
            return
        end
        hostSession = session
    end
    for _, v in ipairs(items) do
        hostSession:ItemAdd(v.itemId)
    end
    ButtonScript_Close()
end

---@type ST_CellUpdateFunc
local function Script_TableRemoveClicked(rowFrame, cellFrame, data, cols, row, realrow, column)
    if column == 3 then
        table.remove(items, realrow)
        UpdateTable()
        if #items == 0 then
            ButtonScript_Close()
        end
    end
    return false
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

---Display item icon and show tooltip on hover.
---@type ST_CellUpdateFunc
local function CellUpdateIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local texture = data[realrow][column]
    cellFrame:SetNormalTexture(texture)
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
    frame = Env.UI.CreateButtonWindow("DMSLootWindow", L["Add Loot to Session"], 111, 111, 0, true, Env.settings.UI.LootWindow)
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
--- Local Functions
---------------------------------------------------------------------------

---Update shown table content.
function UpdateTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for k, v in ipairs(items) do
        local _, itemLink = GetItemInfo(v.itemId)
        local itemIcon = GetItemIcon(v.itemId)
        table.insert(dataTable, { itemIcon, itemLink, k })
    end
    st:SetData(dataTable, true)
end

---------------------------------------------------------------------------
--- Controller Functions
---------------------------------------------------------------------------

---Show the window.
function Controller:Show()
    frame:Show()
end

---Add item to the window.
---@param itemId integer
function Controller:AddItem(itemId)
    ---@type LootWindowListItem
    local entry = { itemId = itemId }
    table.insert(items, entry)
    UpdateTable()
end

function Controller:HaveItems()
    return #items > 0
end
