---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")

local GetImagePath = Env.UI.GetImagePath

---@alias LootFrameListItem {itemId:integer}[]

---@class (exact) LootFrameController
---@field frame ButtonWindow|nil
---@field items LootFrameListItem
---@field st ST_ScrollingTable
local Controller = {
    items = {},
}

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local function CreateFrame()
    local ROW_HEIGHT = 30

    local function ShowItemTooltip(parent, link)
        GameTooltip:SetOwner(parent, "ANCHOR_MOUSE")
        GameTooltip:SetHyperlink(link)
    end

    ---@type ST_CellUpdateFunc
    local function CellUpdateIcon(rowFrame, frame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        local texture = data[realrow][column]
        local link = data[realrow][2]
        frame:SetNormalTexture(texture)
        frame:SetScript("OnEnter", function(f) ShowItemTooltip(f, link) end)
        frame:SetScript("OnLeave", function() GameTooltip_Hide() end)
    end

    ---@type ST_CellUpdateFunc
    local function CellUpdateRemoveButton(rowFrame, frame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        frame:SetNormalTexture(GetImagePath("bars_05.png"))
    end

    local frame = Env.UI.CreateButtonWindow(L["Add Loot to Session"], 111, 111, 0, true, Env.settings.UI.LootAddWindow)
    frame:AddLeftButton("Add", function() Controller:AddToSession() end)
    frame:AddRightButton("Cancel", function() Controller:HideAndClear() end)
    frame.onTopCloseClicked = function() Controller:HideAndClear() end

    local st = ScrollingTable:CreateST({
        { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateIcon },         -- Icon
        { name = "", width = 125, },                                              -- Name/ItemLink display
        { name = "", width = ROW_HEIGHT, DoCellUpdate = CellUpdateRemoveButton }, -- Remove
    }, 7, ROW_HEIGHT, nil, frame)

    st.head:SetHeight(0)
    st.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -2, 4)
    st:RegisterEvents({
        ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            if column == 3 then
                Controller:RemoveItem(data[realrow][column])
            end
            return false
        end,
    })
    frame:SetWidth(st.frame:GetWidth() + 6)
    frame:SetHeight(st.frame:GetHeight() + 44)

    Controller.frame = frame
    Controller.st = st
end

Env:OnAddonLoaded(function()
    CreateFrame()
end)

---------------------------------------------------------------------------
--- Controller Functions
---------------------------------------------------------------------------

function Controller:Show()
    self.frame:Show()
end

function Controller:HideAndClear()
    wipe(self.items)
    self:UpdateTable()
    self.frame:Hide()
end

function Controller:AddToSession()
    local hostSession = Env.Session.Host:GetSession()
    if not hostSession then
        local session, err = Env.Session.Host:Start("self")
        if not session or err then
            if err then Env:PrintError(err) end
            return
        end
        hostSession = session
    end
    for _, v in ipairs(self.items) do
        hostSession:ItemAdd(v.itemId)
    end
    self:HideAndClear()
end

---@param index integer
function Controller:RemoveItem(index)
    table.remove(self.items, index)
    self:UpdateTable()
    if #self.items == 0 then
        self:HideAndClear()
    end
end

function Controller:UpdateTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for k, v in ipairs(self.items) do
        local _, itemLink = GetItemInfo(v.itemId)
        local itemIcon = GetItemIcon(v.itemId)
        table.insert(dataTable, { itemIcon, itemLink, k })
    end
    self.st:SetData(dataTable, true)
end

---Add item to the window.
---@param itemId number
function Controller:AddItem(itemId)
    ---@type LootFrameListItem
    local n = { itemId = itemId }
    table.insert(self.items, n)
    Controller:UpdateTable()
end

function Controller:HaveItems()
    return #self.items > 0
end

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

---Split multiple connected itemlinks.
---@param str string
---@return string[]
local function ItemLinkSplit(str)
    local links = {}
    ---@type integer|nil, integer|nil
    local startPos, endPos = 1, nil
    while startPos do
        if str:sub(1, 2) == "|c" then
            startPos, endPos = str:find("|c.-|r", startPos)
        else
            startPos = nil
        end
        if startPos then
            table.insert(links, str:sub(startPos, endPos))
            startPos = startPos + 1
        end
    end
    return links
end

Env:RegisterSlashCommand("add", L["Add items to a session."], function(args)
    if not args[1] then
        -- TODO: all all bag items
    elseif tonumber(args[1]) and tonumber(args[1]) < 50 then
        -- TODO: add n bag items with the lowest trade timer
    else
        for _, arg in ipairs(args) do
            local links = ItemLinkSplit(arg)
            for _, v in pairs(links) do
                local id = Env.Item:GetIdFromLink(v)
                if id then
                    Controller:AddItem(id)
                end
            end
        end
    end
    if Controller:HaveItems() then
        Controller:Show()
    else
        Env:PrintWarn(L["No items added!"])
    end
end)
