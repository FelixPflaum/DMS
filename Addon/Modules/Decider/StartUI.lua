---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local ScrollingTable = LibStub("ScrollingTable")
local ColorByClassId = Env.UI.ColorByClassId
local GetImagePath = Env.UI.GetImagePath

local WIN_WIDTH = 350
local TABLE_ROW_HEIGHT = 15
local TABLE_ROWS = 10

local mainWindow ---@type DbWindow
local entryTable ---@type ST_ScrollingTable
local ENTRY_TABLE_INDICES = {
    NAME = 1,
    TOGGLE = 2,
}
---@alias DeciderStartUIDataTableEntry [string,integer]
local DATA_INDICES = {
    NAME = 1,
    CLASS_ID = 2,
}
local currentData = {} ---@type table<string, integer>

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

---Display x icon.
---@type ST_CellUpdateFunc
local function CellUpdateRemoveButton(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow then return end
    cellFrame:SetNormalTexture(GetImagePath("bars_05.png"))
end

---Fill entry table with group members.
local function UpdateTable()
    Env:PrintDebug("UpdateNearbyTable")
    ---@type DeciderStartUIDataTableEntry[]
    local dataTable = {}
    for name, classId in pairs(currentData) do
        local rowData = { ---@type DeciderStartUIDataTableEntry
            [DATA_INDICES.NAME] = name,
            [DATA_INDICES.CLASS_ID] = classId
        }
        table.insert(dataTable, rowData)
    end
    entryTable:SetData(dataTable, true)
end

---@param parent WoWFrame
---@param text string
---@param width number
---@param fillFunc fun(info:MSA_InfoTable, level:integer)
local function CreateFillDropdown(parent, text, width, fillFunc)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(text)
    button:SetWidth(width)

    local arrowDownBtn = CreateFrame("Button", nil, parent, nil)
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

    local dropdownMenu = MSA_DropDownMenu_Create("DMSDeciderClassDropdown", UIParent)
    local info = { text = "text not set" } ---@type MSA_InfoTable

    MSA_DropDownMenu_Initialize(dropdownMenu, function(menu, level)
        fillFunc(info, level)
    end, "MENU")

    local function OnClicked()
        MSA_DropDownMenu_SetAnchor(dropdownMenu, 0, 0, "TOPRIGHT", button, "BOTTOMRIGHT")
        MSA_ToggleDropDownMenu(1, nil, dropdownMenu)
    end

    button:SetScript("OnClick", OnClicked)
    arrowDownBtn:SetScript("OnClick", OnClicked)

    return button
end

---@param filterClassId integer|nil
local function FillFromGroup(filterClassId)
    for unit in Env.MakeGroupIterator() do
        local name = UnitName(unit)
        if name then
            local classId = select(3, UnitClass(unit))
            if not filterClassId or classId == filterClassId then
                currentData[name] = classId
            end
        end
    end
    UpdateTable()
end

---@param parent WoWFrame
---@param width number
local function CreateFillClassBtn(parent, width)
    ---@param classId integer
    local function SelectClass(_, classId)
        FillFromGroup(classId)
    end

    return CreateFillDropdown(parent, L["Add Group Class"], width, function(info, level)
        for _, v in ipairs(Env.classList) do
            wipe(info)
            info.text = ColorByClassId(v.displayText, v.id)
            info.notCheckable = true
            info.func = SelectClass
            info.arg1 = v.id
            MSA_DropDownMenu_AddButton(info, level)
        end
    end)
end

---@param parent WoWFrame
---@param width number
local function CreateAddMemberBtn(parent, width)
    ---@param member {name:string, classId:integer}
    local function SelectMember(_, member)
        currentData[member.name] = member.classId
        UpdateTable()
    end

    return CreateFillDropdown(parent, L["Add Group Member"], width, function(info, level)
        for unit in Env.MakeGroupIterator() do
            local name = UnitName(unit)
            if name then
                local classId = select(3, UnitClass(unit))
                wipe(info)
                info.text = ColorByClassId(name, classId)
                info.notCheckable = true
                info.func = SelectMember
                info.arg1 = { name = name, classId = classId }
                MSA_DropDownMenu_AddButton(info, level)
            end
        end
    end)
end

---@type ST_CellUpdateFunc
local function TableRemoveClicked(rowFrame, cellFrame, data, cols, row, realrow, column)
    if column == ENTRY_TABLE_INDICES.TOGGLE then
        local name = data[realrow][DATA_INDICES.NAME]
        currentData[name] = nil
        UpdateTable()
    end
    return false
end

-- Create decider start UI window.
Env:OnAddonLoaded(function()
    local height = TABLE_ROWS * TABLE_ROW_HEIGHT + 85

    ---@class DbWindow : ButtonWindow
    mainWindow = Env.UI.CreateButtonWindow("DMSDeciderStartWindow", L["Decider Wheel Creation"], WIN_WIDTH, height, 0,
        false, Env.settings.UI.DeciderStartWindow)
    mainWindow:SetFrameStrata("HIGH")

    local contentFrame = mainWindow.Inset

    local labelTitle = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelTitle:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, -8)
    labelTitle:SetText(L["Title"])

    local titleBox = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    titleBox:SetAutoFocus(false)
    titleBox:SetFontObject(ChatFontNormal)
    titleBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    titleBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    titleBox:SetTextInsets(0, 0, 3, 3)
    titleBox:SetMaxLetters(75)
    titleBox:SetPoint("LEFT", labelTitle, "RIGHT", 10, 0)
    titleBox:SetHeight(19)
    titleBox:SetWidth(WIN_WIDTH - 50)

    local fillPartyButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    fillPartyButton:SetText(L["Add Whole Party"])
    fillPartyButton:SetWidth(125)
    fillPartyButton:SetPoint("TOPLEFT", labelTitle, "BOTTOMLEFT", 15, -20)
    fillPartyButton:SetScript("OnClick", FillFromGroup)

    local fillClassBtn = CreateFillClassBtn(contentFrame, 125)
    fillClassBtn:SetPoint("TOPLEFT", fillPartyButton, "TOPLEFT", 0, -25)

    local addMemberBtn = CreateAddMemberBtn(contentFrame, 125)
    addMemberBtn:SetPoint("TOPLEFT", fillClassBtn, "TOPLEFT", 0, -25)

    local buttonStart = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    buttonStart:SetText(L["Spin!"])
    buttonStart:SetWidth(buttonStart:GetTextWidth() + 30)
    buttonStart:SetPoint("TOP", addMemberBtn, "TOP", 0, -40)
    buttonStart:SetScript("OnClick", function()
        local data = {} ---@type DeciderPlayerData[]
        for name, classId in pairs(currentData) do
            table.insert(data, { name = name, classId = classId })
        end
        Env.Decider.Start(titleBox:GetText(), data)
    end)

    entryTable = ScrollingTable:CreateST({
        [ENTRY_TABLE_INDICES.NAME] = { name = L["Name"], width = 100, DoCellUpdate = CellUpdateName, defaultsort = ScrollingTable.SORT_ASC },
        [ENTRY_TABLE_INDICES.TOGGLE] = { name = "", width = 32, DoCellUpdate = CellUpdateRemoveButton },
    }, TABLE_ROWS, TABLE_ROW_HEIGHT, nil, contentFrame)
    entryTable.frame:SetPoint("TOPRIGHT", titleBox, "BOTTOMRIGHT", 0, -entryTable.head:GetHeight() - 4)
    entryTable:RegisterEvents({ OnClick = TableRemoveClicked })

    mainWindow:Show()
end)

Env.UI:RegisterOnReset(function()
    mainWindow:Reset()
end)

Env:RegisterSlashCommand("decide", "", function(args)
    mainWindow:Show()
    currentData = {}
    UpdateTable()
end)
