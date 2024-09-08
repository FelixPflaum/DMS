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
---@alias StateKey "player"|"points"|"loot"|"none"
local state = "none" ---@type StateKey
local tabs = {} ---@type table<StateKey, {frame:WoWFrame, button:WoWFrameButton}>

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

local function Script_Close()
    frame:Hide()
end

---@param name StateKey
local function ShowTab(name)
    local tab = tabs[name]
    if not tab then return end
    for k, v in pairs(tabs) do
        if k ~= name then
            v.button:Enable()
            v.frame:Hide()
        else
            v.button:Disable()
            v.frame:Show()
        end
    end
    state = name
end

---@param forceUpdate boolean?
local function SwitchToPlayers(forceUpdate)
    if state == "player" and not forceUpdate then return end
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in pairs(Env.Database.players) do
        local rowData = { v.classId, v.playerName, v.points } ---@type any[]
        table.insert(dataTable, rowData)
    end
    playerTable:SetData(dataTable, true)
    ShowTab("player")
end

---@param forceUpdate boolean?
local function SwitchToPoints(forceUpdate)
    if state == "points" and not forceUpdate then return end
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.pointHistory) do
        local rowData = { v.timeStamp, v.playerName, v.change, v.newPoints, v.type, v.reason } ---@type any[]
        table.insert(dataTable, rowData)
    end
    pointHistoryTable:SetData(dataTable, true)
    ShowTab("points")
end

---@param forceUpdate boolean?
local function SwitchToLoot(forceUpdate)
    if state == "loot" and not forceUpdate then return end
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.lootHistory) do
        local rowData = { v.timeStamp, v.playerName, v.itemId, v.itemId, v.response, v.reverted } ---@type any[]
        table.insert(dataTable, rowData)
    end
    lootHistoryTable:SetData(dataTable, true)
    ShowTab("loot")
end

---@param name string
---@param classId integer
local function Script_AddNewPlayerClicked(name, classId)
    if name:len() < 2 then return end
    name = name:sub(1, 1):upper() .. name:sub(2):lower()
    if Env.Database:GetPlayer(name) then
        Env:PrintError(L["Player with that name already exist in the database!"])
        return
    end
    Env.Database:AddPlayer(name, classId, 0)
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local TOP_INSET = 50
local TABLE_ROW_HEIGHT = 18
local MIN_WIDTH = 300

---Display class icon.
---@type ST_CellUpdateFunc
local function CellUpdateClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
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
        cellFrame:SetScript("OnEnter", function() ShowItemTooltip(cellFrame, itemLink) end)
        cellFrame:SetScript("OnLeave", GameTooltip_Hide)
    else
        cellFrame.text:SetText(tostring(itemId))
        DoWhenItemInfoReady(itemId, function(_, itemLink)
            cellFrame.text:SetText(itemLink)
            cellFrame:SetScript("OnEnter", function() ShowItemTooltip(cellFrame, itemLink) end)
            cellFrame:SetScript("OnLeave", GameTooltip_Hide)
        end)
    end
end

---Display item icon from itemId.
---@type ST_CellUpdateFunc
local function CellUpdateItemIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local itemId = data[realrow][column] ---@type integer
    DoWhenItemInfoReady(itemId, function(_, itemLink, _, _, _, _, _, _, _, itemTexture)
        cellFrame:SetNormalTexture(itemTexture or [[Interface/Icons/inv_misc_questionmark]])
        cellFrame:SetScript("OnEnter", function() ShowItemTooltip(cellFrame, itemLink) end)
        cellFrame:SetScript("OnLeave", GameTooltip_Hide)
    end)
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
                cellFrame:SetScript("OnEnter", function() ShowItemTooltip(cellFrame, itemLink) end)
                cellFrame:SetScript("OnLeave", GameTooltip_Hide)
            end)
            return
        end
    end
    cellFrame.text:SetText(changeReason)
end

---Display readable datetime from unix timestamp.
---@type ST_CellUpdateFunc
local function CellUpdateTimeStamp(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local timeStamp = data[realrow][column] ---@type integer
    cellFrame.text:SetText(date("%Y-%m-%d %H:%M:%S", timeStamp))
end

---Display a red "yes" if revert state is true.
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

---@param parent WoWFrame
local function CreateAddPlayerForm(parent)
    local addForm = CreateFrame("Frame", nil, parent)

    local heading = addForm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetText(L["Add Player"])
    heading:SetPoint("TOPLEFT", 0, 0)

    local labelName = addForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelName:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -15)
    labelName:SetText(L["Name"])

    local nameBox = CreateFrame("EditBox", nil, addForm, "InputBoxTemplate")
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject(ChatFontNormal)
    nameBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    nameBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    nameBox:SetTextInsets(0, 0, 3, 3)
    nameBox:SetMaxLetters(12)
    nameBox:SetPoint("LEFT", labelName, "RIGHT", -labelName:GetWidth() + 60, 0)
    nameBox:SetHeight(19)
    nameBox:SetWidth(120)

    local labelClass = addForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelClass:SetPoint("TOPLEFT", labelName, "BOTTOMLEFT", 0, -20)
    labelClass:SetText(L["Class"])

    local selectedClass = 1
    local dropdown = CreateFrame("Frame", nil, addForm, "UIDropDownMenuTemplate") ---@cast dropdown UIDropDownMenu
    dropdown:SetPoint("LEFT", labelClass, "RIGHT", -labelClass:GetWidth() + 36, 4)
    dropdown:SetSize(60, 19)

    ---@param classId integer
    local function SelectClassClick(btn, classId)
        selectedClass = classId
        local className = GetClassInfo(classId)
        dropdown.Text:SetText(ColorByClassId(className, classId))
    end
    SelectClassClick(nil, 1)

    local dropdownMenuClass = MSA_DropDownMenu_Create("DMSDatabaseDropdownMenu", UIParent)
    local ddinfo = { text = "text not set" } ---@type MSA_InfoTable
    local function FillContextMenu()
        for i = 1, 99 do
            local className, _, classId = GetClassInfo(i)
            -- When calling GetClassInfo() it will return the next valid class on invalid classIds,
            -- or nil if classId is higher then the highest valid class Id.
            if classId == i then
                wipe(ddinfo)
                ddinfo.text = ColorByClassId(className, classId)
                ddinfo.isNotRadio = true
                ddinfo.checked = classId == selectedClass
                ddinfo.func = SelectClassClick
                ddinfo.arg1 = classId
                MSA_DropDownMenu_AddButton(ddinfo, 1)
            elseif not className then
                break
            end
        end
    end
    MSA_DropDownMenu_Initialize(dropdownMenuClass, FillContextMenu, "")
    dropdown.Button:SetScript("OnClick", function()
        MSA_DropDownMenu_SetAnchor(dropdownMenuClass, 0, 0, "TOPRIGHT", dropdown.Button, "BOTTOMRIGHT")
        MSA_ToggleDropDownMenu(1, nil, dropdownMenuClass)
    end)

    local buttonAddPlayer = CreateFrame("Button", nil, addForm, "UIPanelButtonTemplate")
    buttonAddPlayer:SetText(L["Add"])
    buttonAddPlayer:SetWidth(buttonAddPlayer:GetTextWidth() + 30)
    buttonAddPlayer:SetPoint("TOPLEFT", labelClass, "BOTTOMLEFT", 0, -13)
    buttonAddPlayer:SetScript("OnClick", function()
        EditBox_ClearFocus(nameBox)
        Script_AddNewPlayerClicked(nameBox:GetText(), selectedClass)
    end)

    -- TODO: add all players for rank

    addForm:SetHeight(105)
    addForm:SetWidth(100)
    addForm:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 10, 10)
end

local function CreateWindow()
    ---@class DbWindow : ButtonWindow
    frame = Env.UI.CreateButtonWindow("DMSDatabaseWindow", L["Database"], 111, 111, TOP_INSET, false, Env.settings.UI.DatabaseWindow)
    frame.onTopCloseClicked = Script_Close

    local buttonPlayers = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonPlayers:SetText(L["Players"])
    buttonPlayers:SetWidth(buttonPlayers:GetTextWidth() + 15)
    buttonPlayers:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -30)
    buttonPlayers:SetScript("OnClick", SwitchToPlayers)
    frame.buttonPlayers = buttonPlayers

    local buttonPoints = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonPoints:SetText(L["Sanity History"])
    buttonPoints:SetWidth(buttonPoints:GetTextWidth() + 15)
    buttonPoints:SetPoint("LEFT", buttonPlayers, "RIGHT", 5, 0)
    buttonPoints:SetScript("OnClick", SwitchToPoints)
    frame.buttonPoints = buttonPoints

    local buttonLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buttonLoot:SetText(L["Loot History"])
    buttonLoot:SetWidth(buttonLoot:GetTextWidth() + 15)
    buttonLoot:SetPoint("LEFT", buttonPoints, "RIGHT", 5, 0)
    buttonLoot:SetScript("OnClick", SwitchToLoot)
    frame.buttonLoot = buttonLoot

    playerTable = ScrollingTable:CreateST({
        { name = "",          width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateClassIcon }, -- Icon
        { name = L["Name"],   width = 90,               DoCellUpdate = CellUpdateName },
        { name = L["Sanity"], width = 50 },
    }, 20, TABLE_ROW_HEIGHT, nil, frame)
    playerTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -playerTable.head:GetHeight() - 4)
    playerTable.frame:Hide()

    CreateAddPlayerForm(playerTable.frame)
    tabs.player = { frame = playerTable.frame, button = buttonPlayers }

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
    tabs.points = { frame = pointHistoryTable.frame, button = buttonPoints }

    lootHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],     width = 125,              DoCellUpdate = CellUpdateTimeStamp },
        { name = L["Player"],   width = 90,               DoCellUpdate = CellUpdateName },
        { name = "",            width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateItemIcon },
        { name = L["Item"],     width = 150,              DoCellUpdate = CellUpdateItemId },
        { name = L["Response"], width = 100,              DoCellUpdate = CellUpdateLootResponse },
        { name = L["Reverted"], width = 60,               DoCellUpdate = CellUpdateReverted },
    }, 20, TABLE_ROW_HEIGHT, nil, frame)
    lootHistoryTable.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -lootHistoryTable.head:GetHeight() - 4)
    lootHistoryTable.frame:Hide()
    tabs.loot = { frame = lootHistoryTable.frame, button = buttonLoot }

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
        SwitchToPlayers(true)
    end
end)

Env.Database.OnPlayerPointHistoryUpdate:RegisterCallback(function(playerName)
    if state == "points" then
        SwitchToPoints(true)
    end
end)

Env.Database.OnLootHistoryEntryChanged:RegisterCallback(function(entryGuid)
    if state == "loot" then
        SwitchToLoot(true)
    end
end)

Env:RegisterSlashCommand("db", L["Show database window."], function(args)
    if state == "none" then
        SwitchToPlayers()
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
        if not Env.Database:GetPlayer(name) then
            return Env:PrintError("Player does not exist in DB!")
        end
        points = math.floor(points)
        Env.Database:UpdatePlayerPoints(name, points, "CUSTOM", "test command")
    end
end)

Env:RegisterSlashCommand("dbc", "", function(args)
    Env:PrintWarn("Clearing DB!")
    wipe(Env.Database.players)
    wipe(Env.Database.lootHistory)
    wipe(Env.Database.pointHistory)
end)
