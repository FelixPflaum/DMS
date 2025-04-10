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

local TOP_INSET = 112
local TABLE_ROW_HEIGHT = 18
local NON_CONTENT_WIDTH = 8
local NON_CONTENT_HEIGHT = 28

---@alias StateKey "player"|"points"|"loot"|"none"|"imexport"

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
        btn:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, -27)
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
--- Filter
---------------------------------------------------------------------------

local FILTER_BTN_OFFSET = 25
local DEFAULT_MAX_DATE_RANGE = 60 * 86400

---@class (exact) DBFilterChangedEvent
---@field RegisterCallback fun(self:DBFilterChangedEvent, cb:fun())
---@field Trigger fun(self:DBFilterChangedEvent)

---@class (exact) DBWindowFilter
---@field frame WoWFrame
---@field Date DBWindowDateFilter
---@field Name DBWindowNameFilter
---@field Loot DBWindowLootFilter
---@field OnChanged DBFilterChangedEvent
local Filter = {
    OnChanged = Env:NewEventEmitter()
}

---Display readable datetime from unix timestamp.
---@type ST_CellUpdateFunc
local function CellUpdateTimeStampDate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    local timeStamp = data[realrow][column] ---@type integer
    cellFrame.text:SetText(date("%Y-%m-%d", timeStamp) --[[@as string]])
end

---@param parent WoWFrame
---@param onChange fun()
local function CreateDateFilter(parent, onChange)
    ---@class (exact) DBWindowDateFilter
    ---@field frame WoWFrame
    ---@field timestampFrom integer
    ---@field timestampTo integer
    local dateFilter = {
        frame = CreateFrame("Frame", nil, parent),
        timestampFrom = 0,
        timestampTo = 0,
    }

    dateFilter.frame:SetHeight(parent:GetHeight())
    dateFilter.frame:SetPoint("TOPLEFT", 0, 0)

    local ROW_HEIGHT = 15
    local rowCount = math.floor(dateFilter.frame:GetHeight() / ROW_HEIGHT)
    local filterDateTable = ScrollingTable:CreateST({
        { name = "", width = 70, DoCellUpdate = CellUpdateTimeStampDate, sort = ScrollingTable.SORT_DSC },
    }, rowCount, ROW_HEIGHT, nil, dateFilter.frame)
    filterDateTable.head:SetHeight(0)
    filterDateTable.frame:SetPoint("TOPLEFT", dateFilter.frame, "TOPLEFT", 0, 0)

    ---Set date table entries.
    ---@param data ST_DataMinimal[]
    function dateFilter:SetDateList(data)
        filterDateTable:SetData(data, true)
    end

    local fromLabel = dateFilter.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fromLabel:SetText(L["From"])
    fromLabel:SetPoint("TOPLEFT", filterDateTable.frame, "TOPRIGHT", 5, 0)
    local datepickerFrom = Env.UI.CreateDatePicker(dateFilter.frame)
    datepickerFrom.frame:SetPoint("TOPLEFT", fromLabel, "BOTTOMLEFT", 0, -4)

    local toLabel = dateFilter.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toLabel:SetText(L["To"])
    toLabel:SetPoint("TOPLEFT", datepickerFrom.frame, "BOTTOMLEFT", 0, -8)
    local datepickerTo = Env.UI.CreateDatePicker(dateFilter.frame)
    datepickerTo.frame:SetPoint("TOPLEFT", toLabel, "BOTTOMLEFT", 0, -4)

    ---@param year integer
    ---@param month integer
    ---@param day integer
    local function TimeStampFromDate(year, month, day)
        return time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0, isdst = false })
    end

    ---@param year integer
    ---@param month integer
    ---@param day integer
    local function DateWeight(year, month, day)
        return year * 1000 + month * 100 + day
    end

    ---@param picker DmsDatePicker
    ---@param year integer
    ---@param month integer
    ---@param day integer
    local function OnPickerChange(picker, year, month, day)
        if picker == datepickerFrom then
            if DateWeight(year, month, day) > DateWeight(datepickerTo:GetSelectedDate()) then
                return datepickerFrom:SetSelectedDate(datepickerTo:GetSelectedDate())
            end
            dateFilter.timestampFrom = TimeStampFromDate(year, month, day)
        else
            if DateWeight(year, month, day) < DateWeight(datepickerFrom:GetSelectedDate()) then
                return datepickerTo:SetSelectedDate(datepickerFrom:GetSelectedDate())
            end
            dateFilter.timestampTo = TimeStampFromDate(year, month, day)
        end
        onChange()
    end

    datepickerFrom:SetOnChange(OnPickerChange)
    datepickerTo:SetOnChange(OnPickerChange)

    ---@param ts integer
    local function DateFromTimestamp(ts)
        local td = date("*t", ts) ---@cast td ostimeInput
        return td.year, td.month, td.day
    end

    ---@param timestamp  integer
    local function SetBothTimestamps(timestamp)
        if timestamp then
            local y, m, d = DateFromTimestamp(timestamp)
            if timestamp < dateFilter.timestampFrom then
                datepickerFrom:SetSelectedDate(y, m, d, true)
                dateFilter.timestampFrom = TimeStampFromDate(datepickerFrom:GetSelectedDate())
                datepickerTo:SetSelectedDate(y, m, d)
            else
                datepickerTo:SetSelectedDate(y, m, d, true)
                dateFilter.timestampTo = TimeStampFromDate(datepickerTo:GetSelectedDate())
                datepickerFrom:SetSelectedDate(y, m, d)
            end
        end
    end

    filterDateTable:RegisterEvents({
        OnClick = function(_, _, data, _, _, realrow)
            local timestamp = data[realrow][1] ---@type integer?
            if timestamp then
                SetBothTimestamps(timestamp)
            end
        end
    })

    ---Set selected date range.
    ---@param fromTs integer
    ---@param toTs integer
    function dateFilter:SetDateRange(fromTs, toTs)
        SetBothTimestamps(fromTs)
        datepickerTo:SetSelectedDate(DateFromTimestamp(toTs))
    end

    ---Check if timestamp is in filtered range.
    ---@param timestamp integer
    function dateFilter:IsTimestampInRange(timestamp)
        local from = self.timestampFrom
        local to = self.timestampTo + 86400 -- == Start of day + 24 hours
        return timestamp >= from and timestamp <= to
    end

    ---Set filter date data from scrolling table instance.
    ---@param stable ST_ScrollingTable
    ---@param columnIndex integer The index of the column containing the timestamps.
    function dateFilter:SetDatesFromTable(stable, columnIndex)
        local dataTable = {} ---@type ST_DataMinimal[]
        local haveDate = {} ---@type table<integer,boolean>
        local ts ---@type integer
        local td ---@type any
        local tsdate ---@type integer
        local high = 0
        local low = 2524604400
        for _, v in ipairs(stable.data) do
            ts = v[columnIndex]
            td = date("*t", ts) ---@cast td ostimeInput
            td.hour = 0
            td.min = 0
            td.sec = 0
            tsdate = time(td)
            if not haveDate[tsdate] then
                local rowData = { tsdate } ---@type any[]
                table.insert(dataTable, rowData)
                haveDate[tsdate] = true
                if high < tsdate then high = tsdate end
                if low > tsdate then low = tsdate end
            end
        end
        self:SetDateList(dataTable)
        low = math.max(low, high - DEFAULT_MAX_DATE_RANGE)
        self:SetDateRange(low, high)
    end

    dateFilter.frame:SetWidth(filterDateTable.frame:GetWidth() + datepickerFrom.frame:GetWidth() + 5)
    return dateFilter
end

---@param parent WoWFrame
---@param onChange fun()
local function CreateNameFilter(parent, onChange)
    ---@class (exact) DBWindowNameFilter
    ---@field frame WoWFrame
    ---@field value string
    local nameFilter = {
        frame = CreateFrame("Frame", nil, parent),
        value = "",
    }

    local nameLabel = nameFilter.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetText(L["Name"])
    nameLabel:SetPoint("TOPLEFT", 0, 0)

    local ebox = CreateFrame("EditBox", nil, nameFilter.frame, "InputBoxTemplate")
    ebox:SetAutoFocus(false)
    ebox:SetFontObject(ChatFontNormal)
    ebox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    ebox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    ebox:SetScript("OnTextChanged", function()
        nameFilter.value = ebox:GetText():gsub("%s+", ""):lower()
        onChange()
    end)
    ebox:SetTextInsets(0, 0, 3, 3)
    ebox:SetMaxLetters(12)
    ebox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
    ebox:SetHeight(19)
    ebox:SetWidth(120)

    ---Check if name is searched for.
    ---@param name string
    ---@return boolean isSearched True if name is matching search term or no search term set.
    function nameFilter:IsMatching(name)
        local pos = name:lower():find(Filter.Name.value)
        return pos ~= nil
    end

    nameFilter.frame:SetWidth(ebox:GetWidth())
    nameFilter.frame:SetHeight(nameLabel:GetHeight() + 5 + ebox:GetHeight())

    return nameFilter
end

---@param parent WoWFrame
---@param onChange fun()
local function CreateLootFilter(parent, onChange)
    ---@class (exact) DBWindowLootFilter
    ---@field frame WoWFrame
    ---@field classesSelected table<integer,boolean>
    ---@field responsesSelected table<string,boolean>
    local lootFilter = {
        frame = CreateFrame("Frame", nil, parent),
        classesSelected = {},
        responsesSelected = {},
    }

    local responseList = {} ---@type {rawName:string, coloredName:string, id:integer}[]

    local button = CreateFrame("Button", nil, lootFilter.frame, "UIPanelButtonTemplate")
    button:SetText(L["More Filters"])
    button:SetWidth(button:GetTextWidth() + 45)
    button:SetPoint("TOPLEFT", 0, 0)

    local arrowDownBtn = CreateFrame("Button", nil, lootFilter.frame, nil)
    arrowDownBtn:SetSize(button:GetHeight(), button:GetHeight())
    arrowDownBtn:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    arrowDownBtn:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
    arrowDownBtn:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
    arrowDownBtn:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])

    button:SetScript("OnEnter", function(frame, ...)
        arrowDownBtn:SetHighlightLocked(true)
    end)
    button:SetScript("OnLeave", function(frame, ...)
        arrowDownBtn:SetHighlightLocked(false)
    end)

    local dropdownMenu = MSA_DropDownMenu_Create("DMSLootFilterDropdown", UIParent)
    local info = { text = "text not set" } ---@type MSA_InfoTable

    for _, v in ipairs(Env.classList) do
        lootFilter.classesSelected[v.id] = true
    end

    ---@param classId integer
    local function ToggleClass(_, classId)
        lootFilter.classesSelected[classId] = not lootFilter.classesSelected[classId]
        onChange()
    end

    ---@param responseName string
    local function ToggleResponse(_, responseName)
        lootFilter.responsesSelected[responseName] = not lootFilter.responsesSelected[responseName]
        onChange()
    end

    ---@param level integer
    local function FillContextMenu(menu, level)
        if level == 1 then
            info.text = L["Responses"]
            info.isTitle = true
            info.notCheckable = true
            MSA_DropDownMenu_AddButton(info, 1)

            for _, v in ipairs(responseList) do
                wipe(info)
                info.text = v.coloredName
                info.func = ToggleResponse
                info.checked = lootFilter.responsesSelected[v.rawName] == true
                info.arg1 = v.rawName
                MSA_DropDownMenu_AddButton(info, 1)
            end

            wipe(info)
            info.text = L["Other"]
            info.isTitle = true
            info.notCheckable = true
            MSA_DropDownMenu_AddButton(info, 1)

            wipe(info)
            info.text = L["Classes"]
            info.notCheckable = true
            info.hasArrow = true
            info.value = "CLASS"
            MSA_DropDownMenu_AddButton(info, 1)

            wipe(info)
            info.text = L["Close"]
            info.notCheckable = true
            info.func = function() MSA_CloseDropDownMenus() end
            MSA_DropDownMenu_AddButton(info, 1)
        elseif level == 2 then
            for _, v in ipairs(Env.classList) do
                wipe(info)
                info.text = ColorByClassId(v.displayText, v.id)
                info.func = ToggleClass
                info.checked = lootFilter.classesSelected[v.id] == true
                info.arg1 = v.id
                MSA_DropDownMenu_AddButton(info, level)
            end
        end
    end

    MSA_DropDownMenu_Initialize(dropdownMenu, FillContextMenu, "MENU")

    local function OnClicked()
        MSA_DropDownMenu_SetAnchor(dropdownMenu, 0, 0, "TOPRIGHT", button, "BOTTOMRIGHT")
        MSA_ToggleDropDownMenu(1, nil, dropdownMenu)
    end

    button:SetScript("OnClick", OnClicked)
    arrowDownBtn:SetScript("OnClick", OnClicked)

    ---Set response filter list.
    ---@param stable ST_ScrollingTable
    ---@param column any
    function lootFilter:SetResponseFromTable(stable, column)
        wipe(responseList)
        wipe(lootFilter.responsesSelected)
        for _, v in ipairs(stable.data) do
            local responseDataStr = v[column] ---@type string
            if responseDataStr and responseDataStr ~= "" then
                local id, color, display = Env.Database.FormatResponseStringForUI(responseDataStr)
                if not lootFilter.responsesSelected[display] then
                    table.insert(responseList, { rawName = display, coloredName = ("|cFF%s%s|r"):format(color, display), id = id })
                    lootFilter.responsesSelected[display] = true
                end
            end
        end
        table.sort(responseList, function(a, b)
            return a.id > b.id
        end)
        onChange()
    end

    ---Check if response is selected.
    ---@param response string
    ---@param isDataString boolean If true then response is given as a DB response data string.
    function lootFilter:IsResponseSelected(response, isDataString)
        if isDataString then
            local _, _, display = Env.Database.FormatResponseStringForUI(response)
            return self.responsesSelected[display]
        end
        return self.responsesSelected[response]
    end

    lootFilter.frame:SetHeight(200) --btn:GetHeight())
    lootFilter.frame:SetWidth(200)  --btn:GetWidth())
    return lootFilter
end

Env:OnAddonLoaded(function()
    Filter.frame = CreateFrame("Frame", nil, mainWindow)
    Filter.frame:SetPoint("TOPLEFT", 10, -(27 + FILTER_BTN_OFFSET))
    local height = TOP_INSET - 4 - FILTER_BTN_OFFSET
    Filter.frame:SetSize(200, height)

    Filter.Date = CreateDateFilter(Filter.frame, function()
        Filter.OnChanged:Trigger()
    end)

    Filter.Name = CreateNameFilter(Filter.frame, function()
        Filter.OnChanged:Trigger()
    end)
    Filter.Name.frame:SetPoint("TOPLEFT", Filter.Date.frame, "TOPRIGHT", 15, 0)

    Filter.Loot = CreateLootFilter(Filter.frame, function()
        Filter.OnChanged:Trigger()
    end)
    Filter.Loot.frame:SetPoint("TOPLEFT", Filter.Name.frame, "BOTTOMLEFT", 0, -10)
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

        local classDropdown = Env.UI.CreateMSADropdown(addForm)
        classDropdown:SetPoint("LEFT", labelClass, "RIGHT", -labelClass:GetWidth() + 57, 0)
        classDropdown:SetWidth(100)
        local entries = {} ---@type { displayText: string, value: any }[]
        for _, classData in ipairs(Env.classList) do
            table.insert(entries, { displayText = ColorByClassId(classData.displayText, classData.id), value = classData.id })
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

        local rankDropdown = Env.UI.CreateMSADropdown(addAllRankForm, function(entries)
            local ranks = Env.Guild.rankCache
            wipe(entries)
            for rankIndex = 0, #ranks do
                if ranks[rankIndex] then
                    table.insert(entries, { displayText = ranks[rankIndex].name, value = rankIndex })
                end
            end
        end)
        rankDropdown:SetPoint("LEFT", labelRank, "RIGHT", -labelRank:GetWidth() + 50, 0)
        rankDropdown:SetWidth(100)
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

    local editClassDropdown = Env.UI.CreateMSADropdown(peframe, nil, function(value)
        if not currentPlayerName then return end
        Env.Database:UpdatePlayerEntry(currentPlayerName, value)
    end)
    editClassDropdown:SetPoint("LEFT", labelClass, "RIGHT", -labelClass:GetWidth() + 50, 0)
    editClassDropdown:SetWidth(100)
    local entries = {} ---@type { displayText: string, value: any }[]
    for _, classData in ipairs(Env.classList) do
        table.insert(entries, { displayText = ColorByClassId(classData.displayText, classData.id), value = classData.id })
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
    for _, v in pairs(Env.Database.db.players) do
        local rowData = { v.classId, v.playerName, v.points } ---@type any[]
        table.insert(dataTable, rowData)
    end
    playerTable:SetData(dataTable, true)
    Filter.frame:Hide()
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
    if mainWindow:IsShown() and state == "player" then
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
    cellFrame.text:SetText(date("%Y-%m-%d %H:%M:%S", timeStamp) --[[@as string]])
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
    for _, v in ipairs(Env.Database.db.pointHistory) do
        local rowData = { v.timeStamp, v.playerName, v.change, v.newPoints, v.type, v.reason } ---@type any[]
        table.insert(dataTable, rowData)
    end
    pointHistoryTable:SetData(dataTable, true)
    Filter.frame:Show()
    Filter.Loot.frame:Hide()
    Filter.Date:SetDatesFromTable(pointHistoryTable, 1)
end

-- Setup point history DB tab.
Env:OnAddonLoaded(function()
    pointHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],   width = 125, DoCellUpdate = CellUpdateTimeStamp,        sort = ScrollingTable.SORT_ASC,       sortnext = 2 },
        { name = L["Player"], width = 90,  DoCellUpdate = CellUpdateName,             defaultsort = ScrollingTable.SORT_ASC },
        { name = L["Change"], width = 55,  DoCellUpdate = CellUpdatePointChangeValue },
        { name = L["New"],    width = 55 },
        { name = L["Type"],   width = 80 },
        { name = L["Reason"], width = 200, DoCellUpdate = CellUpdatePointChangeReason },
    }, 20, TABLE_ROW_HEIGHT, nil, mainWindow)

    pointHistoryTable:SetFilter(function(_, rowData)
        if not Filter.Date:IsTimestampInRange(rowData[1]) or
            not Filter.Name:IsMatching(rowData[2]) then
            return false
        end
        return true
    end)
    Filter.OnChanged:RegisterCallback(function()
        if state == "points" then
            pointHistoryTable:SortData()
        end
    end)

    AddTab("points", pointHistoryTable.frame, L["Sanity History"], UpdatePointsHistoryTable, -pointHistoryTable.head:GetHeight() - 4)
end)

Env.Database.OnPlayerPointHistoryUpdate:RegisterCallback(function(playerName)
    if mainWindow:IsShown() and state == "points" then
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
    if response and response ~= "" then
        local _, hexColor, displayString = Env.Database.FormatResponseStringForUI(response)
        cellFrame.text:SetText(("|cFF%s%s|r"):format(hexColor, displayString))
    else
        cellFrame.text:SetText("")
    end
end


local function UpdateLootHistoryTable()
    ---@type ST_DataMinimal[]
    local dataTable = {}
    for _, v in ipairs(Env.Database.db.lootHistory) do
        local rowData = { v.timeStamp, v.playerName, v.itemId, v.itemId, v.response } ---@type any[]
        table.insert(dataTable, rowData)
    end
    lootHistoryTable:SetData(dataTable, true)
    Filter.frame:Show()
    Filter.Loot.frame:Show()
    Filter.Date:SetDatesFromTable(lootHistoryTable, 1)
    Filter.Loot:SetResponseFromTable(lootHistoryTable, 5)
end

-- Setup loot history DB tab.
Env:OnAddonLoaded(function()
    lootHistoryTable = ScrollingTable:CreateST({
        { name = L["Time"],     width = 125,              DoCellUpdate = CellUpdateTimeStamp,   sort = ScrollingTable.SORT_ASC,        defaultsort = ScrollingTable.SORT_ASC },
        { name = L["Player"],   width = 90,               DoCellUpdate = CellUpdateName,        defaultsort = ScrollingTable.SORT_ASC, sortnext = 1 },
        { name = "",            width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateItemIcon },
        { name = L["Item"],     width = 175,              DoCellUpdate = CellUpdateItemId },
        { name = L["Response"], width = 100,              DoCellUpdate = CellUpdateLootResponse },
    }, 20, TABLE_ROW_HEIGHT, nil, mainWindow)

    lootHistoryTable:SetFilter(function(_, rowData)
        local playerName = rowData[2]
        local playerEntry = Env.Database:GetPlayer(playerName)
        if not Filter.Date:IsTimestampInRange(rowData[1]) or
            not Filter.Name:IsMatching(playerName) or
            (playerEntry and not Filter.Loot.classesSelected[playerEntry.classId]) or
            (rowData[5] and rowData[5] ~= "" and not Filter.Loot:IsResponseSelected(rowData[5], true)) then
            return false
        end
        return true
    end)
    Filter.OnChanged:RegisterCallback(function()
        if state == "loot" then
            lootHistoryTable:SortData()
        end
    end)

    AddTab("loot", lootHistoryTable.frame, L["Loot History"], UpdateLootHistoryTable, -lootHistoryTable.head:GetHeight() - 4)
end)

Env.Database.OnLootHistoryEntryChanged:RegisterCallback(function(entryGuid)
    if mainWindow:IsShown() and state == "loot" then
        UpdateLootHistoryTable()
    end
end)

---------------------------------------------------------------------------
--- Import/Export DB tab (TODO: backups)
---------------------------------------------------------------------------

-- Setup loot history DB tab.
Env:OnAddonLoaded(function()
    local ief = CreateFrame("Frame", nil, mainWindow)

    local headingExport = ief:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headingExport:SetText(L["Export"])
    headingExport:SetPoint("TOPLEFT", 10, -10)

    local timeFrameLabel = ief:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeFrameLabel:SetPoint("TOPLEFT", headingExport, "BOTTOMLEFT", 0, -15)
    timeFrameLabel:SetText(L["Timeframe"])

    local timeFrameDropdown = Env.UI.CreateMSADropdown(ief)
    timeFrameDropdown:SetPoint("LEFT", timeFrameLabel, "RIGHT", 15, 0)
    timeFrameDropdown:SetWidth(100)
    local days = 84600;
    timeFrameDropdown:SetEntries({
        { displayText = L["%d days"]:format(30),  value = 30 * days },
        { displayText = L["%d days"]:format(60),  value = 60 * days },
        { displayText = L["%d days"]:format(120), value = 120 * days },
        { displayText = L["%d days"]:format(365), value = 365 * days },
    })
    timeFrameDropdown:SetSelected(60 * days)

    local buttonExport = CreateFrame("Button", nil, ief, "UIPanelButtonTemplate")
    buttonExport:SetText(L["Create Export"])
    buttonExport:SetWidth(buttonExport:GetTextWidth() + 30)
    buttonExport:SetPoint("TOPLEFT", timeFrameLabel, "BOTTOMLEFT", 0, -15)

    local exportBox = CreateFrame("EditBox", nil, ief, "InputBoxTemplate")
    exportBox:SetAutoFocus(false)
    exportBox:SetFontObject(ChatFontNormal)
    exportBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    exportBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    exportBox:SetTextInsets(0, 0, 3, 3)
    exportBox:SetPoint("LEFT", buttonExport, "RIGHT", 10, 0)
    exportBox:SetHeight(19)
    exportBox:SetWidth(200)
    exportBox:SetScript("OnCursorChanged", function(frame, ...)
        exportBox:HighlightText()
    end)

    buttonExport:SetScript("OnClick", function()
        local maxAge = timeFrameDropdown.selectedValue ---@type integer
        local export = Env.CreateExportString(maxAge)
        exportBox:SetText(export);
    end)

    local headingImport = ief:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headingImport:SetText(L["Import"])
    headingImport:SetPoint("TOPLEFT", buttonExport, "BOTTOMLEFT", 0, -30)

    local importBox = CreateFrame("EditBox", nil, ief, "InputBoxTemplate")
    importBox:SetAutoFocus(false)
    importBox:SetFontObject(ChatFontNormal)
    importBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    importBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    importBox:SetTextInsets(0, 0, 3, 3)
    importBox:SetPoint("TOPLEFT", headingImport, "BOTTOMLEFT", 0, -15)
    importBox:SetHeight(19)
    importBox:SetWidth(200)

    local buttonImport = CreateFrame("Button", nil, ief, "UIPanelButtonTemplate")
    buttonImport:SetText(L["Import and overwrite DB"])
    buttonImport:SetWidth(buttonImport:GetTextWidth() + 30)
    buttonImport:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", 0, -10)

    local importResult = ief:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importResult:SetPoint("LEFT", buttonImport, "RIGHT", 10, 0)

    local importAge = ief:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    importAge:SetPoint("TOPLEFT", buttonImport, "BOTTOMLEFT", 0, -10)
    importAge:SetText(L["Last import: %s ago"]:format(Env.ToShortTimeUnit(Env.Database:TimeSinceLastImport())))

    buttonImport:SetScript("OnClick", function()
        local input = importBox:GetText()
        if input == "" then return end
        local error = Env.ImportDataFromWeb(input)
        if error then
            importResult:SetText(L["Error: "] .. error);
        else
            importResult:SetText(L["Data was imported!"]);
            importAge:SetText(L["Last import: %s ago"]:format(Env.ToShortTimeUnit(Env.Database:TimeSinceLastImport())));
        end
    end)

    ief:SetSize(pointHistoryTable.frame:GetWidth() - 25, pointHistoryTable.frame:GetHeight() - 25)

    AddTab("imexport", ief, L["Import/Export"], function() end, 0)
end)

---------------------------------------------------------------------------
--- API
---------------------------------------------------------------------------

Env:RegisterSlashCommand("db", L["Show database window."], function(args)
    if state == "none" then
        SwitchTab("player")
    else
        SwitchTab(state)
    end
    mainWindow:Show()
end)
