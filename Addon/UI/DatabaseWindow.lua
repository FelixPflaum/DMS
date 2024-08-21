---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local ShowItemTooltip = Env.UI.ShowItemTooltip
local ColorByClassId = Env.UI.ColorByClassId
local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady

local frame ---@type DbWindow
local playerTable ---@type ST_ScrollingTable
local pointHistoryTable ---@type ST_ScrollingTable
local lootHistoryTable ---@type ST_ScrollingTable
local state = "none" ---@type "player"|"points"|"loot"|"none"

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local function ButtonScript_Close()
    frame:Hide()
end

---@param forceUpdate boolean?
local function Script_SwitchToPlayers(forceUpdate)
    if state == "player" and not forceUpdate then return end

    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in pairs(Env.Database.players) do
        local rowData = { v.classId, v.playerName, v.points } ---@type any[]
        table.insert(dataTable, rowData)
    end
    playerTable:SetData(dataTable, true)

    playerTable.frame:Show()
    pointHistoryTable.frame:Hide()
    lootHistoryTable.frame:Hide()

    state = "player"
    frame.buttonPlayers:Disable()
    frame.buttonPoints:Enable()
    frame.buttonLoot:Enable()
end

---@param forceUpdate boolean?
local function Script_SwitchToPoints(forceUpdate)
    if state == "points" and not forceUpdate then return end

    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.pointHistory) do
        local rowData = { v.timeStamp, v.playerName, v.change, v.newPoints, v.type, v.reason } ---@type any[]
        table.insert(dataTable, rowData)
    end
    pointHistoryTable:SetData(dataTable, true)

    playerTable.frame:Hide()
    pointHistoryTable.frame:Show()
    lootHistoryTable.frame:Hide()

    state = "points"
    frame.buttonPlayers:Enable()
    frame.buttonPoints:Disable()
    frame.buttonLoot:Enable()
end

---@param forceUpdate boolean?
local function Script_SwitchToLoot(forceUpdate)
    if state == "loot" and not forceUpdate then return end

    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.lootHistory) do
        local rowData = { v.timeStamp, v.playerName, v.itemId, v.response, v.reverted } ---@type any[]
        table.insert(dataTable, rowData)
    end
    lootHistoryTable:SetData(dataTable, true)

    playerTable.frame:Hide()
    pointHistoryTable.frame:Hide()
    lootHistoryTable.frame:Show()

    state = "loot"
    frame.buttonPlayers:Enable()
    frame.buttonPoints:Enable()
    frame.buttonLoot:Disable()
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local TOP_INSET = 50
local TABLE_ROW_HEIGHT = 18
local MIN_WIDTH = 300

---Display item icon and show tooltip on hover.
---@type ST_CellUpdateFunc
local function CellUpdateIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local classId = data[realrow][column]
    if classId then
        cellFrame:SetNormalTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
        local texCoords = CLASS_ICON_TCOORDS[select(2, GetClassInfo(classId))]
        cellFrame:GetNormalTexture():SetTexCoord(unpack(texCoords))
    end
end

---Update function for name cell.
---@type ST_CellUpdateFunc
local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local name = data[realrow][column] ---@type string
    local dbEntry = Env.Database:GetPlayer(name)
    if dbEntry then
        cellFrame.text:SetText(ColorByClassId(name, dbEntry.classId))
    else
        cellFrame.text:SetText(name)
    end
end

---Update function for showing item link from item id.
---@type ST_CellUpdateFunc
local function CellUpdateItemId(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local itemId = data[realrow][column] ---@type integer
    local _, itemLink = C_Item.GetItemInfo(itemId)
    if itemLink then
        cellFrame.text:SetText(itemLink)
        cellFrame:SetScript("OnEnter", function() Env.UI.ShowItemTooltip(cellFrame, itemLink) end)
        cellFrame:SetScript("OnLeave", GameTooltip_Hide)
    else
        cellFrame.text:SetText(tostring(itemId))
        DoWhenItemInfoReady(itemId, function(_, itemLink)
            cellFrame.text:SetText(itemLink)
            cellFrame:SetScript("OnEnter", function() Env.UI.ShowItemTooltip(cellFrame, itemLink) end)
            cellFrame:SetScript("OnLeave", GameTooltip_Hide)
        end)
    end
end

---Update function for point change reason cells.
---@type ST_CellUpdateFunc
local function CellUpdatePointChangeReason(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local changeType = data[realrow][column - 1] ---@type PointChangeType
    local changeReason = data[realrow][column] ---@type string
    if changeType == "ITEM_AWARD" or changeType == "ITEM_AWARD_REVERTED" then
        local lootEntry = Env.Database:GetLootHistoryEntry(changeReason)
        if lootEntry then
            cellFrame.text:SetText(tostring(lootEntry.itemId))
            DoWhenItemInfoReady(lootEntry.itemId, function(_, itemLink)
                cellFrame.text:SetText(itemLink)
                cellFrame:SetScript("OnEnter", function() Env.UI.ShowItemTooltip(cellFrame, itemLink) end)
                cellFrame:SetScript("OnLeave", GameTooltip_Hide)
            end)
            return
        end
    end
    cellFrame.text:SetText(changeReason)
end

---Display readable datetime.
---@type ST_CellUpdateFunc
local function CellUpdateTimeStamp(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local timeStamp = data[realrow][column] ---@type integer
    cellFrame.text:SetText(date("%Y-%m-%d %H:%M:%S", timeStamp))
end

---Prepends a + for positive numbers and colors green or red.
---@type ST_CellUpdateFunc
local function CellUpdateReverted(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local reverted = data[realrow][column] ---@type boolean
    if reverted then
        cellFrame.text:SetText("|cFFFF8888" .. L["Yes"] .. "|r")
    else
        cellFrame.text:SetText("")
    end
end

---Displays formatted response string from DB.
---@type ST_CellUpdateFunc
local function CellUpdateLootResponse(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local response = data[realrow][column] ---@type string {id,rgb_hexcolor}displayString
    local _, hexColor, displayString = Env.Database.FormatResponseStringForUI(response)
    cellFrame.text:SetText(("|cFF%s%s|r"):format(hexColor, displayString))
end

---Prepends a + for positive numbers and colors green or red.
---@type ST_CellUpdateFunc
local function CellUpdatePointChangeValue(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local change = data[realrow][column] ---@type integer
    local changeStr = tostring(change)
    if change > 0 then
        changeStr = "|cFF88FF88+" .. changeStr .. "|r"
    else
        changeStr = "|cFFFF8888" .. changeStr .. "|r"
    end
    cellFrame.text:SetText(changeStr)
end

local function CreateWindow()
    ---@class DbWindow : ButtonWindow
    frame = Env.UI.CreateButtonWindow("DMSDatabaseWindow", L["Database"], 111, 111, TOP_INSET, false, Env.settings.UI.DatabaseWindow)
    frame.onTopCloseClicked = ButtonScript_Close

    local buttonPlayers = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonPlayers:SetText(L["Players"])
    buttonPlayers:SetWidth(buttonPlayers:GetTextWidth() + 15)
    buttonPlayers:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -30)
    buttonPlayers:SetScript("OnClick", Script_SwitchToPlayers)
    frame.buttonPlayers = buttonPlayers

    local buttonPoints = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonPoints:SetText(L["Sanity History"])
    buttonPoints:SetWidth(buttonPoints:GetTextWidth() + 15)
    buttonPoints:SetPoint("LEFT", buttonPlayers, "RIGHT", 5, 0)
    buttonPoints:SetScript("OnClick", Script_SwitchToPoints)
    frame.buttonPoints = buttonPoints

    local buttonLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonLoot:SetText(L["Loot History"])
    buttonLoot:SetWidth(buttonLoot:GetTextWidth() + 15)
    buttonLoot:SetPoint("LEFT", buttonPoints, "RIGHT", 5, 0)
    buttonLoot:SetScript("OnClick", Script_SwitchToLoot)
    frame.buttonLoot = buttonLoot

    playerTable = ScrollingTable:CreateST({
        { name = "",          width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateIcon }, -- Icon
        { name = L["Name"],   width = 90,               DoCellUpdate = CellUpdateName },
        { name = L["Sanity"], width = 50 },
    }, 20, TABLE_ROW_HEIGHT, nil, frame)
    playerTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -playerTable.head:GetHeight() - 4)
    playerTable.frame:Hide()

    pointHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],   width = 125, DoCellUpdate = CellUpdateTimeStamp },
        { name = L["Name"],   width = 90,  DoCellUpdate = CellUpdateName },
        { name = L["Change"], width = 40,  DoCellUpdate = CellUpdatePointChangeValue },
        { name = L["New"],    width = 40 },
        { name = L["Type"],   width = 150 },
        { name = L["Reason"], width = 175, DoCellUpdate = CellUpdatePointChangeReason },
    }, 20, TABLE_ROW_HEIGHT, nil, frame)
    pointHistoryTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -pointHistoryTable.head:GetHeight() - 4)
    pointHistoryTable.frame:Hide()

    lootHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],     width = 125, DoCellUpdate = CellUpdateTimeStamp },
        { name = L["Player"],   width = 90,  DoCellUpdate = CellUpdateName },
        { name = L["Item"],     width = 150, DoCellUpdate = CellUpdateItemId },
        { name = L["Response"], width = 100, DoCellUpdate = CellUpdateLootResponse },
        { name = L["Reverted"], width = 60,  DoCellUpdate = CellUpdateReverted },
    }, 20, TABLE_ROW_HEIGHT, nil, frame)
    lootHistoryTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -lootHistoryTable.head:GetHeight() - 4)
    lootHistoryTable.frame:Hide()

    local maxTabWidth = math.max(playerTable.frame:GetWidth(), pointHistoryTable.frame:GetWidth(), lootHistoryTable.frame:GetWidth())
    frame:SetWidth(math.max(MIN_WIDTH, maxTabWidth + 6))
    frame:SetHeight(playerTable.frame:GetHeight() + 32 + playerTable.head:GetHeight() + TOP_INSET)
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    CreateWindow()
end)

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

Env.Database.OnPlayerChanged:RegisterCallback(function(playerName)
    if state == "player" then
        Script_SwitchToPlayers(true)
    end
end)

Env.Database.OnPlayerPointHistoryUpdate:RegisterCallback(function(playerName)
    if state == "points" then
        Script_SwitchToPoints(true)
    end
end)

Env.Database.OnLootHistoryEntryChanged:RegisterCallback(function(entryGuid)
    if state == "loot" then
        Script_SwitchToLoot(true)
    end
end)

Env:RegisterSlashCommand("db", L["Show database window."], function(args)
    if state == "none" then
        Script_SwitchToPlayers()
    end
    frame:Show()
end)

Env.UI:RegisterOnReset(function()
    frame:Reset()
end)

Env:RegisterSlashCommand("dbpa", "", function(args)
    local name = args[1]
    local points = tonumber(args[2])
    if name and points then
        points = math.floor(points)
        Env.Database:AddPlayer(name, 1, points)
        Env.Database:AddPlayerPointHistory(name, points, points, "CUSTOM", "test")
    end
end)

Env:RegisterSlashCommand("dbc", "", function(args)
    Env:PrintWarn("Clearing DB!")
    wipe(Env.Database.players)
    wipe(Env.Database.lootHistory)
    wipe(Env.Database.pointHistory)
end)
