---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local LibDialog = LibStub("LibDialog-1.1")
local ShowItemTooltip = Env.UI.ShowItemTooltip
local ColorByClassId = Env.UI.ColorByClassId
local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady

---------------------------------------------------------------------------
--- Main Window Setup
---------------------------------------------------------------------------

local TOP_INSET = 50
local TABLE_ROW_HEIGHT = 18
local NON_CONTENT_WIDTH = 8
local NON_CONTENT_HEIGHT = 28

---@alias StateKey "player"|"points"|"loot"|"none"

local mainWindow ---@type DbWindow
local state = "none" ---@type StateKey
local tabs = {} ---@type table<StateKey, {frame:WoWFrame, button:WoWFrameButton, updateFunc:fun()}>

local lastTabButton = nil ---@type WoWFrameButton?

local function Script_Close()
    mainWindow:Hide()
end

---Switch shown tab.
---@param tabId StateKey
local function SwitchTab(tabId)
    local tab = tabs[tabId]
    if not tab then return end
    for k, v in pairs(tabs) do
        if k ~= tabId then
            v.button:Enable()
            v.frame:Hide()
        else
            v.button:Disable()
            v.frame:Show()
        end
    end
    state = tabId
    tab.updateFunc()
end

---Add tab to DB window.
---@param tabId StateKey
---@param contentFrame WoWFrame
---@param buttonText string
---@param updateFunc fun()
---@param extraYOffset number?
local function AddTab(tabId, contentFrame, buttonText, updateFunc, extraYOffset)
    local btn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
    btn:SetText(buttonText)
    btn:SetWidth(btn:GetTextWidth() + 15)
    if lastTabButton then
        btn:SetPoint("LEFT", lastTabButton, "RIGHT", 5, 0)
    else
        btn:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 13, -30)
    end
    btn:SetScript("OnClick", function() SwitchTab(tabId) end)
    lastTabButton = btn

    tabs[tabId] = {
        frame = contentFrame,
        button = btn,
        updateFunc = updateFunc
    }

    extraYOffset = extraYOffset or 0
    contentFrame:SetPoint("TOPLEFT", mainWindow.Inset, "TOPLEFT", -1, extraYOffset)
    contentFrame:Hide()

    local newWidth = contentFrame:GetWidth() + NON_CONTENT_WIDTH
    if mainWindow:GetWidth() < newWidth then
        mainWindow:SetWidth(newWidth)
    end
    local newHeight = contentFrame:GetHeight() + NON_CONTENT_HEIGHT + TOP_INSET - extraYOffset
    if mainWindow:GetHeight() < newHeight then
        mainWindow:SetHeight(newHeight)
    end
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    ---@class DbWindow : ButtonWindow
    mainWindow = Env.UI.CreateButtonWindow("DMSDatabaseWindow", L["Database"], 111, 111, TOP_INSET, false, Env.settings.UI.DatabaseWindow)
    mainWindow.onTopCloseClicked = Script_Close
    mainWindow:SetSize(300, 200)
    mainWindow:SetFrameStrata("HIGH")
end)

Env.UI:RegisterOnReset(function()
    mainWindow:Reset()
end)

---------------------------------------------------------------------------
--- Player DB tab
---------------------------------------------------------------------------

local playerTable ---@type ST_ScrollingTable
local playerEditFrame ---@type PlayerEditFrame

local PLAYER_TABLE_IDICES = {
    ICON = 1,
    NAME = 2,
    SANITY = 3,
}

---@param name string
---@param classId integer
local function AddNewPlayer(name, classId)
    if name:len() < 2 then return end
    name = name:sub(1, 1):upper() .. name:sub(2):lower()
    if Env.Database:GetPlayer(name) then
        Env:PrintError(L["Player with that name already exist in the database!"])
        return
    end
    Env.Database:AddPlayer(name, classId, 0)
end

---@param rankIndex integer
local function AddPlayersFromRankIndex(rankIndex)
    local members = Env.Guild.memberCache[rankIndex]
    if not members then return end
    local addCount = 0
    for _, memberData in ipairs(members) do
        if not Env.Database:GetPlayer(memberData.name) then
            Env.Database:AddPlayer(memberData.name, memberData.classId, 0)
            addCount = addCount + 1
        end
    end
    Env:PrintSuccess(L["Added %d new players from guild rank %s."]:format(addCount, Env.Guild.rankCache[rankIndex].name))
end

---@param name string
---@param change string
---@param reason string
local function PlayerPointChangeClick(name, change, reason)
    local changeNum = tonumber(change)
    local entry = Env.Database:GetPlayer(name)
    if not changeNum then
        return Env:PrintError(L["Invalid input for sanity change value! Must be a number."])
    elseif not entry then
        return Env:PrintError("Player does not exist in DB!")
    end
    changeNum = math.floor(changeNum)
    Env.Database:UpdatePlayerPoints(name, entry.points + changeNum, "CUSTOM", reason)
    Env:PrintSuccess(L["Changed sanity of %s by %d to %d."]:format(name, changeNum, Env.Database:GetPlayer(name).points))
end

local confirmDeleteDialogData = {
    text = L["Really delete player data?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Confirm"],
            on_click = function(self, data)
                if type(data) == "string" then
                    local playerName = data
                    Env.Database:RemovePlayerLootHistory(playerName)
                    Env.Database:RemovePlayerPointHistory(playerName)
                    Env.Database:RemovePlayer(playerName)
                end
            end
        },
        { text = L["Cancel"], on_click = function() end },
    },
}

---@param parent WoWFrame
local function CreateAddPlayerForm(parent)
    local addForm = CreateFrame("Frame", nil, parent)
    do
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

        local classDropdown = Env.UI.CreateMSADropdown("DMSDatabaseDropdownAddPlayerClass", addForm)
        classDropdown:SetPoint("LEFT", labelClass, "RIGHT", -labelClass:GetWidth() + 36, 4)
        classDropdown:SetSize(60, 19)
        local entries = {} ---@type { displayText: string, value: any }[]
        for i = 1, 99 do
            local className, _, classId = GetClassInfo(i)
            -- When calling GetClassInfo() it will return the next valid class on invalid classIds,
            -- or nil if classId is higher then the highest valid class Id.
            if classId == i then
                table.insert(entries, { displayText = ColorByClassId(className, classId), value = classId })
            elseif not className then
                break
            end
        end
        classDropdown:SetEntries(entries)

        local buttonAddPlayer = CreateFrame("Button", nil, addForm, "UIPanelButtonTemplate")
        buttonAddPlayer:SetText(L["Add"])
        buttonAddPlayer:SetWidth(buttonAddPlayer:GetTextWidth() + 30)
        buttonAddPlayer:SetPoint("TOPLEFT", labelClass, "BOTTOMLEFT", 0, -13)
        buttonAddPlayer:SetScript("OnClick", function()
            EditBox_ClearFocus(nameBox)
            AddNewPlayer(nameBox:GetText(), classDropdown.selectedValue)
        end)

        addForm:SetHeight(111)
        addForm:SetWidth(nameBox:GetWidth() + 60)
        addForm:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 10, 10)
    end

    local addAllRankForm = CreateFrame("Frame", nil, parent)
    do
        local heading = addAllRankForm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetText(L["Add Guild Rank"])
        heading:SetPoint("TOPLEFT", 0, 0)

        local labelRank = addAllRankForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelRank:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -15)
        labelRank:SetText(L["Rank"])

        local rankDropdown = Env.UI.CreateMSADropdown("DMSDatabaseDropdownAddPlayerClass", addAllRankForm, function(entries)
            local ranks = Env.Guild.rankCache
            for rankIndex = 0, #ranks do
                if ranks[rankIndex] then
                    table.insert(entries, { displayText = ranks[rankIndex].name, value = rankIndex })
                end
            end
        end)
        rankDropdown:SetPoint("LEFT", labelRank, "RIGHT", -labelRank:GetWidth() + 36, 4)
        rankDropdown:SetSize(60, 19)
        rankDropdown:SetSelected(-1, "???")

        local buttonAddRankPlayers = CreateFrame("Button", nil, addAllRankForm, "UIPanelButtonTemplate")
        buttonAddRankPlayers:SetText(L["Add All Missing"])
        buttonAddRankPlayers:SetWidth(buttonAddRankPlayers:GetTextWidth() + 30)
        buttonAddRankPlayers:SetPoint("TOPLEFT", labelRank, "BOTTOMLEFT", 0, -13)
        buttonAddRankPlayers:SetScript("OnClick", function()
            MSA_CloseDropDownMenus()
            AddPlayersFromRankIndex(rankDropdown.selectedValue)
        end)

        addAllRankForm:SetHeight(77)
        addAllRankForm:SetWidth(100)
        addAllRankForm:SetPoint("TOPLEFT", addForm, "TOPRIGHT", 30, 0)
    end
end

---@param parent WoWFrame
local function CreatePlayerEditForm(parent)
    assert(playerEditFrame == nil, "playerEditFrame already created!")

    ---@class PlayerEditFrame : WoWFrame
    local peframe = CreateFrame("Frame", nil, parent)

    local heading = peframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetText("NO PLAYER SELECTED")
    heading:SetPoint("TOPLEFT", 0, 0)

    local labelClass = peframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelClass:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -15)
    labelClass:SetText(L["Class"])

    local currentPlayerName = nil ---@type string|nil

    local editClassDropdown = Env.UI.CreateMSADropdown("DMSDatabaseDropdownEditPlayerClass", peframe, nil, function(value)
        if not currentPlayerName then return end
        Env.Database:UpdatePlayerEntry(currentPlayerName, value)
    end)
    editClassDropdown:SetPoint("LEFT", labelClass, "RIGHT", -labelClass:GetWidth() + 36, 4)
    editClassDropdown:SetSize(60, 19)
    local entries = {} ---@type { displayText: string, value: any }[]
    for i = 1, 99 do
        local className, _, classId = GetClassInfo(i)
        -- When calling GetClassInfo() it will return the next valid class on invalid classIds,
        -- or nil if classId is higher then the highest valid class Id.
        if classId == i then
            table.insert(entries, { displayText = ColorByClassId(className, classId), value = classId })
        elseif not className then
            break
        end
    end
    editClassDropdown:SetEntries(entries)

    local pointHeading = peframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointHeading:SetText(L["Add Or Remove Sanity"])
    pointHeading:SetPoint("TOPLEFT", labelClass, "BOTTOMLEFT", 0, -25)

    local labelPointAdd = peframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelPointAdd:SetPoint("TOPLEFT", pointHeading, "BOTTOMLEFT", 0, -10)
    labelPointAdd:SetText(L["Change"])

    local pointChangeInput = CreateFrame("EditBox", nil, peframe, "InputBoxTemplate")
    pointChangeInput:SetAutoFocus(false)
    pointChangeInput:SetFontObject(ChatFontNormal)
    pointChangeInput:SetScript("OnEscapePressed", EditBox_ClearFocus)
    pointChangeInput:SetScript("OnEnterPressed", EditBox_ClearFocus)
    pointChangeInput:SetTextInsets(0, 0, 3, 3)
    pointChangeInput:SetMaxLetters(4)
    pointChangeInput:SetPoint("LEFT", labelPointAdd, "RIGHT", -labelPointAdd:GetWidth() + 60, 0)
    pointChangeInput:SetHeight(19)
    pointChangeInput:SetWidth(50)

    local labelPointReason = peframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelPointReason:SetPoint("TOPLEFT", labelPointAdd, "BOTTOMLEFT", 0, -10)
    labelPointReason:SetText(L["Reason"])

    local pointChangeReason = CreateFrame("EditBox", nil, peframe, "InputBoxTemplate")
    pointChangeReason:SetAutoFocus(false)
    pointChangeReason:SetFontObject(ChatFontNormal)
    pointChangeReason:SetScript("OnEscapePressed", EditBox_ClearFocus)
    pointChangeReason:SetScript("OnEnterPressed", EditBox_ClearFocus)
    pointChangeReason:SetTextInsets(0, 0, 3, 3)
    pointChangeReason:SetMaxLetters(50)
    pointChangeReason:SetPoint("LEFT", labelPointReason, "RIGHT", -labelPointReason:GetWidth() + 60, 0)
    pointChangeReason:SetHeight(19)
    pointChangeReason:SetWidth(300)

    local buttonAddPointChange = CreateFrame("Button", nil, peframe, "UIPanelButtonTemplate")
    buttonAddPointChange:SetText(L["Add"])
    buttonAddPointChange:SetWidth(buttonAddPointChange:GetTextWidth() + 30)
    buttonAddPointChange:SetPoint("TOPLEFT", labelPointReason, "BOTTOMLEFT", 0, -10)
    buttonAddPointChange:SetScript("OnClick", function()
        if not currentPlayerName then return end
        EditBox_ClearFocus(pointChangeInput)
        EditBox_ClearFocus(pointChangeReason)
        PlayerPointChangeClick(currentPlayerName, pointChangeInput:GetText(), pointChangeReason:GetText())
        pointChangeInput:SetText("")
    end)

    local buttonDelete = CreateFrame("Button", nil, peframe, "UIPanelButtonTemplate")
    buttonDelete:SetText(L["Delete Player"])
    buttonDelete:SetWidth(buttonDelete:GetTextWidth() + 30)
    buttonDelete:SetPoint("TOPLEFT", buttonAddPointChange, "BOTTOMLEFT", 0, -20)
    buttonDelete:SetScript("OnClick", function()
        if currentPlayerName then
            if LibDialog:ActiveDialog(confirmDeleteDialogData) then
                LibDialog:Dismiss(confirmDeleteDialogData)
            end
            LibDialog:Spawn(confirmDeleteDialogData, currentPlayerName)
        end
    end)

    peframe:SetHeight(111)
    peframe:SetWidth(200)
    peframe:SetPoint("TOPLEFT", parent, "TOPRIGHT", 10, -10)
    peframe:Hide()

    ---Set selected player and show form.
    ---@param name string|nil The player's name, set nil to hide form.
    ---@param classId integer?
    function peframe:SetSelectedPlayer(name, classId)
        if name and classId then
            heading:SetText(ColorByClassId(name, classId))
            currentPlayerName = name
            editClassDropdown:SetSelected(classId)
            peframe:Show()
        else
            peframe:Hide()
        end
    end

    function peframe:GetSelected()
        return currentPlayerName
    end

    playerEditFrame = peframe
end

---@type ST_EventFunc
local function PlayerTableClick(rowFrame, cellFrame, data, cols, row, realrow, column, stable, button)
    if button == "LeftButton" and row then
        if stable:GetSelection() == realrow then
            stable:ClearSelection()
            playerEditFrame:SetSelectedPlayer()
        else
            local name = data[realrow][PLAYER_TABLE_IDICES.NAME] ---@type string
            local dbEntry = Env.Database:GetPlayer(name)
            if not dbEntry then
                Env:PrintError(name .. " does not exist in DB!")
                return false
            end
            stable:SetSelection(realrow)
            playerEditFrame:SetSelectedPlayer(name, dbEntry.classId)
        end
        return true
    end
    return false
end

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

local function UpdatePlayerTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in pairs(Env.Database.players) do
        local rowData = { v.classId, v.playerName, v.points } ---@type any[]
        table.insert(dataTable, rowData)
    end
    playerTable:SetData(dataTable, true)
end

-- Setup player DB tab.
Env:OnAddonLoaded(function()
    playerTable = ScrollingTable:CreateST({
        [PLAYER_TABLE_IDICES.ICON] = { name = "", width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateClassIcon },
        [PLAYER_TABLE_IDICES.NAME] = { name = L["Name"], width = 90, DoCellUpdate = CellUpdateName, sort = ScrollingTable.SORT_ASC, defaultsort = ScrollingTable.SORT_ASC },
        [PLAYER_TABLE_IDICES.SANITY] = { name = L["Sanity"], width = 50 },
    }, 20, TABLE_ROW_HEIGHT, nil, mainWindow)
    playerTable:RegisterEvents({ OnClick = PlayerTableClick })
    playerTable:EnableSelection(true)
    CreateAddPlayerForm(playerTable.frame)
    CreatePlayerEditForm(playerTable.frame)
    AddTab("player", playerTable.frame, L["Players"], UpdatePlayerTable, -playerTable.head:GetHeight() - 4)
end)

Env.Database.OnPlayerChanged:RegisterCallback(function(playerName)
    if state == "player" then
        UpdatePlayerTable()
        if playerEditFrame:GetSelected() == playerName then
            local entry = Env.Database:GetPlayer(playerName)
            if entry then
                playerEditFrame:SetSelectedPlayer(entry.playerName, entry.classId)
            end
        end
    end
end)

---------------------------------------------------------------------------
--- Point history DB tab
---------------------------------------------------------------------------

local pointHistoryTable ---@type ST_ScrollingTable

---Display readable datetime from unix timestamp.
---@type ST_CellUpdateFunc
local function CellUpdateTimeStamp(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local timeStamp = data[realrow][column] ---@type integer
    cellFrame.text:SetText(date("%Y-%m-%d %H:%M:%S", timeStamp))
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

local function UpdatePointsHistoryTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.pointHistory) do
        local rowData = { v.timeStamp, v.playerName, v.change, v.newPoints, v.type, v.reason } ---@type any[]
        table.insert(dataTable, rowData)
    end
    pointHistoryTable:SetData(dataTable, true)
end

-- Setup point history DB tab.
Env:OnAddonLoaded(function()
    pointHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],   width = 125, DoCellUpdate = CellUpdateTimeStamp },
        { name = L["Name"],   width = 90,  DoCellUpdate = CellUpdateName,             defaultsort = ScrollingTable.SORT_ASC },
        { name = L["Change"], width = 40,  DoCellUpdate = CellUpdatePointChangeValue },
        { name = L["New"],    width = 40 },
        { name = L["Type"],   width = 150 },
        { name = L["Reason"], width = 175, DoCellUpdate = CellUpdatePointChangeReason },
    }, 20, TABLE_ROW_HEIGHT, nil, mainWindow)
    AddTab("points", pointHistoryTable.frame, L["Sanity History"], UpdatePointsHistoryTable, -pointHistoryTable.head:GetHeight() - 4)
end)

Env.Database.OnPlayerPointHistoryUpdate:RegisterCallback(function(playerName)
    if state == "points" then
        UpdatePointsHistoryTable()
    end
end)

---------------------------------------------------------------------------
--- Loot history DB tab
---------------------------------------------------------------------------

local lootHistoryTable ---@type ST_ScrollingTable

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

---Displays formatted response string from DB.
---@type ST_CellUpdateFunc
local function CellUpdateLootResponse(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local response = data[realrow][column] ---@type string {id,rgb_hexcolor}displayString
    local _, hexColor, displayString = Env.Database.FormatResponseStringForUI(response)
    cellFrame.text:SetText(("|cFF%s%s|r"):format(hexColor, displayString))
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

local function UpdateLootHistoryTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.lootHistory) do
        local rowData = { v.timeStamp, v.playerName, v.itemId, v.itemId, v.response, v.reverted } ---@type any[]
        table.insert(dataTable, rowData)
    end
    lootHistoryTable:SetData(dataTable, true)
end

-- Setup loot history DB tab.
Env:OnAddonLoaded(function()
    lootHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],     width = 125,              DoCellUpdate = CellUpdateTimeStamp },
        { name = L["Player"],   width = 90,               DoCellUpdate = CellUpdateName,        defaultsort = ScrollingTable.SORT_ASC },
        { name = "",            width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateItemIcon },
        { name = L["Item"],     width = 150,              DoCellUpdate = CellUpdateItemId },
        { name = L["Response"], width = 100,              DoCellUpdate = CellUpdateLootResponse },
        { name = L["Reverted"], width = 60,               DoCellUpdate = CellUpdateReverted },
    }, 20, TABLE_ROW_HEIGHT, nil, mainWindow)
    AddTab("loot", lootHistoryTable.frame, L["Loot History"], UpdateLootHistoryTable, -lootHistoryTable.head:GetHeight() - 4)
end)

Env.Database.OnLootHistoryEntryChanged:RegisterCallback(function(entryGuid)
    if state == "loot" then
        UpdateLootHistoryTable()
    end
end)

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

Env:RegisterSlashCommand("db", L["Show database window."], function(args)
    if state == "none" then
        SwitchTab("player")
    end
    mainWindow:Show()
end)

Env:RegisterSlashCommand("dbpa", "TEST CMD REMOVE", function(args)
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

Env:RegisterSlashCommand("dbc", "TEST CMD REMOVE", function(args)
    Env:PrintWarn("Clearing DB!")
    wipe(Env.Database.players)
    wipe(Env.Database.lootHistory)
    wipe(Env.Database.pointHistory)
end)
