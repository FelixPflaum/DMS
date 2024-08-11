---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")
local LibDialog = LibStub("LibDialog-1.1")
local L = Env:GetLocalization()
local ScrollingTable = LibStub("ScrollingTable") ---@type LibScrollingTable

local GetImagePath = Env.UI.GetImagePath
local GetClassColor = Env.UI.GetClassColor
local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady
local ColorStringFromArray = Env.UI.ColorStringFromArray

local Host = Env.SessionHost
local Client = Env.SessionClient

---Is host with the same guid as client running.
local function IsHosting()
    return Client.guid == Host.guid and Host.isRunning
end

local frame ---@type SessionWindowFrame
local itemSelectIcons = {} ---@type IconButon[]
local selectedItemGuid ---@type string|nil

---------------------------------------------------------------------------
--- Frame Functions
---------------------------------------------------------------------------

---Update the session item shown in the window.
local function UpdateShownItem()
    local item = selectedItemGuid and Client.items[selectedItemGuid]

    if not item then
        frame.ItemInfoIcon:SetItemData()
        frame.ItenInfoItemName:SetText("")
        frame.ItemInfoItemInfo:SetText("")
        frame.ItemInfoAwarded:SetText("")
        frame.st:SetData({}, true)
        return
    end

    frame.ItemInfoIcon:SetItemData(item.itemId)
    DoWhenItemInfoReady(item.itemId, function(_, itemLink, _, _, _, _, itemSubType, _, itemEquipLoc)
        frame.ItenInfoItemName:SetText(itemLink)
        local equipString = _G[itemEquipLoc] or ""
        frame.ItemInfoItemInfo:SetText(itemSubType .. " " .. equipString)
    end)

    if item.awardedTo then
        frame.ItemInfoAwarded:SetText(L["Awarded to: %s"]:format(item.awardedTo))
    else
        frame.ItemInfoAwarded:SetText("")
    end

    local tableData = {}
    for _, itemResponse in pairs(item.responses) do
        ---@type ResponseTableRowData
        local rowData = {
            itemResponse.candidate.classId,
            itemResponse.candidate,
            itemResponse,
            itemResponse.roll or 0,
            itemResponse.points or 0,
            (itemResponse.roll or 0) + (itemResponse.points or 0)
        }
        table.insert(tableData, rowData)
    end
    frame.st:SetData(tableData, true)
end

local dialogData = {
    text = L["Do you want to abort the loot session?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Abort"],
            on_click = function()
                Host:Destroy()
                frame:Hide()
            end
        },
        {
            text = L["Minimize"],
            on_click = function() frame:Hide() end
        },
    },
}

local function Script_OnCloseClicked()
    if IsHosting() then
        if not LibDialog:ActiveDialog(dialogData) then
            LibDialog:Spawn(dialogData)
        end
    else
        frame:Hide()
        if Client.isRunning then
            Env:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
        end
    end
end

---@param guid string
local function Script_ItemSelectClicked(guid)
    selectedItemGuid = guid
    UpdateShownItem()
    for _, v in ipairs(itemSelectIcons) do
        if v:GetArg() == selectedItemGuid then
            v:ShowBorder(true)
        else
            v:ShowBorder(false)
        end
    end
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local TABLE_ROW_HEIGHT = 18
local ITEM_SELECT_MAX_PER_COLUMN = 9
local ITEM_SELECT_ICON_SIZE = 40
local ITEM_SELECT_ICON_OFFSET_X = -10
local ITEM_SELECT_ICON_OFFSET_Y = -2

---@param f SessionWindowFrame
local function CreateStatusHeaders(f)
    ---@param anchorFrame WoWFrame
    local function ShowCandidateTooltip(anchorFrame)
        local tooltipText = ""
        local grey = "FF555555"
        for _, v in pairs(Client.candidates) do
            local nameStr = v.name
            if v.leftGroup then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Left group"] .. ")"
            elseif v.isOffline then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Offline"] .. ")"
            elseif not v.isResponding then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Not responding"] .. ")"
            else
                nameStr = "|c" .. GetClassColor(v.classId).argbstr .. nameStr
            end
            tooltipText = tooltipText .. nameStr .. "\n"
        end
        GameTooltip:SetOwner(anchorFrame, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(tooltipText)
    end

    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    local hostNameLabel = f:CreateFontString(nil, "OVERLAY", fontLabel)
    hostNameLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 65, -6)
    hostNameLabel:SetText(L["Host:"])

    local hostName = f:CreateFontString(nil, "OVERLAY", fontValue)
    hostName:SetPoint("TOPLEFT", hostNameLabel, "TOPRIGHT", 10, 0)
    hostName:SetText("---")

    local sessionStatus = f:CreateFontString(nil, "OVERLAY", fontValue)
    sessionStatus:SetPoint("TOPRIGHT", f, "TOPRIGHT", -35, -6)
    sessionStatus:SetText("---")

    local sessionStatusLabel = f:CreateFontString(nil, "OVERLAY", fontLabel)
    sessionStatusLabel:SetPoint("TOPRIGHT", sessionStatus, "TOPLEFT", -10, 0)
    sessionStatusLabel:SetText(L["Status:"])

    local clientsStatus = f:CreateFontString(nil, "OVERLAY", fontValue)
    clientsStatus:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -37)
    clientsStatus:SetText("---")
    clientsStatus:SetScript("OnEnter", ShowCandidateTooltip)
    clientsStatus:SetScript("OnLeave", GameTooltip_Hide)

    local clientsStatusLabel = f:CreateFontString(nil, "OVERLAY", fontLabel)
    clientsStatusLabel:SetPoint("TOPRIGHT", clientsStatus, "TOPLEFT", -10, 0)
    clientsStatusLabel:SetText(L["Players ready:"])
    clientsStatusLabel:SetScript("OnEnter", function() ShowCandidateTooltip(clientsStatus) end)
    clientsStatusLabel:SetScript("OnLeave", GameTooltip_Hide)

    -- Event Hooks

    Client.OnStart:RegisterCallback(function()
        hostName:SetText(Client.hostName)
        sessionStatus:SetText("|cFF44FF44" .. L["Running"])
    end)

    Client.OnEnd:RegisterCallback(function()
        sessionStatus:SetText("|cFFFFFF44" .. L["Ended"])
    end)

    Client.OnCandidateUpdate:RegisterCallback(function()
        local count = 0
        local ready = 0
        for _, candidate in pairs(Client.candidates) do
            count = count + 1
            if candidate.isResponding and not candidate.isOffline and not candidate.leftGroup then
                ready = ready + 1
            end
        end
        local text = ready .. "/" .. count
        if ready < count then
            text = "|cFFFFFF44" .. text
        end
        clientsStatus:SetText(text)
    end)
end


local TABLE_DEF ---@type ST_ColDef[]
do
    ---@type ST_CellUpdateFunc
    local function CellUpdateClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        local classId = data[realrow][column]
        if classId then
            cellFrame:SetNormalTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
            local texCoords = CLASS_ICON_TCOORDS[select(2, GetClassInfo(classId))]
            cellFrame:GetNormalTexture():SetTexCoord(unpack(texCoords))
        end
    end

    ---@type ST_CellUpdateFunc
    local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        local candidate = data[realrow][column] ---@type SessionClient_Candidate
        cellFrame.text:SetText("|c" .. GetClassColor(candidate.classId).argbstr .. candidate.name)
    end

    ---@type ST_CellUpdateFunc
    local function CellUpdateResponse(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        local itemResponse = data[realrow][column] ---@type SessionClient_ItemResponse
        if itemResponse.response then
            cellFrame.text:SetText(ColorStringFromArray(itemResponse.response.color, itemResponse.response.displayString))
        else
            cellFrame.text:SetText(ColorStringFromArray(itemResponse.status.color, itemResponse.status.displayString))
        end
    end

    ---@type ST_CellUpdateFunc
    local function CellUpdateShowIfNotZero(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        local num = data[realrow][column] ---@type number|nil
        if num and num ~= 0 then
            cellFrame.text:SetText(tostring(num))
        else
            cellFrame.text:SetText("")
        end
    end

    ---@param st ST_ScrollingTable
    ---@param rowa integer
    ---@param rowb integer
    ---@param sortbycol integer
    local function SortCandidate(st, rowa, rowb, sortbycol)
        local column = st.cols[sortbycol]
        local a, b = st.data[rowa][sortbycol], st.data[rowb][sortbycol] ---@type SessionClient_Candidate, SessionClient_Candidate
        if a.name == b.name then
            if column.sortnext then
                local nextcol = st.cols[column.sortnext]
                if not (nextcol.sort) then
                    if nextcol.comparesort then
                        return nextcol.comparesort(st, rowa, rowb, column.sortnext)
                    else
                        return st:CompareSort(rowa, rowb, column.sortnext)
                    end
                else
                    return false
                end
            else
                return false
            end
        else
            local direction = column.sort or column.defaultsort or ScrollingTable.SORT_DSC
            if direction == ScrollingTable.SORT_ASC then
                return a.name < b.name
            else
                return a.name > b.name
            end
        end
    end

    ---@param resp SessionClient_ItemResponse
    local function GetResponseWeight(resp)
        local REPSONSE_ID_FIRST_CUSTOM = Env.Session.REPSONSE_ID_FIRST_CUSTOM
        local weight = resp.status.id
        if resp.response then
            if resp.response.id < REPSONSE_ID_FIRST_CUSTOM then
                -- Show pass and autopass below everything
                weight = -100 + resp.response.id
            else
                -- Show other actual responses above any non-response status
                weight = 100 + resp.response.id
            end
        end
        return weight
    end

    ---@param st ST_ScrollingTable
    ---@param rowa any
    ---@param rowb any
    ---@param sortbycol any
    local function SortResponse(st, rowa, rowb, sortbycol)
        local column = st.cols[sortbycol]
        ---@type SessionClient_ItemResponse, SessionClient_ItemResponse
        local a, b = st.data[rowa][sortbycol], st.data[rowb][sortbycol]
        local aWeight = GetResponseWeight(a)
        local bWeight = GetResponseWeight(b)
        if aWeight == bWeight then
            if column.sortnext then
                local nextcol = st.cols[column.sortnext]
                if not (nextcol.sort) then
                    if nextcol.comparesort then
                        return nextcol.comparesort(st, rowa, rowb, column.sortnext)
                    else
                        return st:CompareSort(rowa, rowb, column.sortnext)
                    end
                else
                    return false
                end
            else
                return false
            end
        else
            local direction = column.sort or column.defaultsort or ScrollingTable.SORT_DSC
            if direction == ScrollingTable.SORT_ASC then
                return aWeight < bWeight
            else
                return aWeight > bWeight
            end
        end
    end

    ---@alias ResponseTableRowData [integer,SessionClient_Candidate,SessionClient_ItemResponse,integer,integer,integer]

    TABLE_DEF = {
        { name = "",            width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateClassIcon }, -- Class icon
        { name = L["Name"],     width = 100,              DoCellUpdate = CellUpdateName,          comparesort = SortCandidate },
        { name = L["Response"], width = 200,              DoCellUpdate = CellUpdateResponse,      sort = ScrollingTable.SORT_DSC, comparesort = SortResponse, sortnext = 6 },
        { name = L["Roll"],     width = 40,               DoCellUpdate = CellUpdateShowIfNotZero, sortnext = 2 },
        { name = L["Sanity"],   width = 40,               DoCellUpdate = CellUpdateShowIfNotZero },
        { name = L["Total"],    width = 40,               DoCellUpdate = CellUpdateShowIfNotZero, sortnext = 4 },
    }
end

local function CreateWindow()
    ---@class SessionWindowFrame : ButtonFrameTemplate
    frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetSize(600, 400)
    frame:SetClampedToScreen(true)
    ButtonFrameTemplate_HideButtonBar(frame)
    LibWindow:Embed(frame)
    frame:RegisterConfig(Env.settings.UI.SessionWindow) ---@diagnostic disable-line: undefined-field
    frame:SetScale(Env.settings.UI.SessionWindow.scale or 1.0)
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    frame:EnableMouse(true)
    frame:MakeDraggable() ---@diagnostic disable-line: undefined-field
    frame:SetScript("OnMouseWheel", function(f, d) if IsControlKeyDown() then LibWindow.OnMouseWheel(f, d) end end)
    frame.TitleText:SetText(addonName)
    frame.portrait:SetTexture(GetImagePath("logo.png"))
    frame.CloseButton:SetScript("OnClick", Script_OnCloseClicked)

    -- Item details header

    frame.ItemInfoIcon = Env.UI.CreateIconButton(frame, 35, true)
    frame.ItemInfoIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -25)

    frame.ItenInfoItemName = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.ItenInfoItemName:SetPoint("TOPLEFT", frame.ItemInfoIcon, "TOPRIGHT", 5, -3)

    frame.ItemInfoItemInfo = frame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    frame.ItemInfoItemInfo:SetPoint("TOPLEFT", frame.ItenInfoItemName, "BOTTOMLEFT", 0, -3)

    frame.ItemInfoAwarded = frame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    frame.ItemInfoAwarded:SetPoint("TOP", frame, "TOP", 0, -37)
    frame.ItemInfoAwarded:SetText("")

    -- Response table

    frame.st = ScrollingTable:CreateST(TABLE_DEF, 15, TABLE_ROW_HEIGHT, nil, frame)
    frame.st.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -frame.st.head:GetHeight() - 4)
    --st:RegisterEvents({ OnClick = Script_TableRemoveClicked })

    frame:SetWidth(frame.st.frame:GetWidth() + 7)
    frame:SetHeight(frame.st.frame:GetHeight() + 86)

    CreateStatusHeaders(frame)
end

---@param index integer
local function GetOrCreateItemSelectIcon(index)
    if itemSelectIcons[index] then
        return itemSelectIcons[index]
    end
    local newBtn = Env.UI.CreateIconButton(frame, ITEM_SELECT_ICON_SIZE)
    itemSelectIcons[index] = newBtn
    newBtn:SetOnClick(Script_ItemSelectClicked)
    if index == 1 then
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", ITEM_SELECT_ICON_OFFSET_X, 0)
    elseif math.fmod(index - 1, ITEM_SELECT_MAX_PER_COLUMN) == 0 then
        local column = math.ceil(index / ITEM_SELECT_MAX_PER_COLUMN)
        local columnOffset = ITEM_SELECT_ICON_OFFSET_X - (ITEM_SELECT_ICON_SIZE + 5) * (column - 1)
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnOffset, 0)
    else
        newBtn:SetPoint("TOP", itemSelectIcons[index - 1], "BOTTOM", 0, ITEM_SELECT_ICON_OFFSET_Y)
    end
    return newBtn
end

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

Env:OnAddonLoaded(CreateWindow)

local function UpdateItemSelect()
    ---@type SessionClient_Item[]
    local ordered = {}
    for _, item in pairs(Client.items) do
        table.insert(ordered, item)
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    for k, item in ipairs(ordered) do
        local btn = GetOrCreateItemSelectIcon(k)
        btn:SetItemData(item.itemId, item.guid)
        btn:ShowCheckmark(item.awardedTo ~= nil)
        if item.guid == selectedItemGuid then
            btn:ShowBorder(true)
        else
            btn:ShowBorder(false)
        end
        btn:SetDesaturated(item.veiled)
        btn:Show()
    end

    for i = #ordered + 1, #itemSelectIcons do
        itemSelectIcons[i]:Hide()
    end
end

local openDialogData = {
    text = L["A loot session started. Do you want to open the session window?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Yes"],
            on_click = function()
                frame:Show()
            end
        },
        {
            text = L["No"],
            on_click = function() end
        },
    },
}

Client.OnStart:RegisterCallback(function()
    selectedItemGuid = nil
    UpdateItemSelect()
    if not IsHosting() and not Env.settings.autoOpenOnStart == "yes" then
        if Env.settings.autoOpenOnStart == "no" then
            return
        end
        if not LibDialog:ActiveDialog(openDialogData) then
            LibDialog:Spawn(openDialogData)
        end
        return
    end
    frame:Show()
end)

Client.OnEnd:RegisterCallback(function()

end)

Client.OnItemUpdate:RegisterCallback(function(item)
    if selectedItemGuid == nil then
        Env:PrintDebug("Setting shown item because no item selected.")
        selectedItemGuid = item.guid
    end
    UpdateItemSelect()
    if item.guid == selectedItemGuid then
        UpdateShownItem()
    end
    -- TODO: child item update (need data for children in client)
end)

---------------------------------------------------------------------------
--- Slash Commands
---------------------------------------------------------------------------

Env:RegisterSlashCommand("open", L["Opens session window if a session is running."], function(args)
    if not Client.isRunning then
        Env:PrintError(L["No session is running!"])
        return
    end
    frame:Show()
end)

Env.UI:RegisterOnReset(function()
    local libWinConfig = Env.settings.UI.SessionWindow
    libWinConfig.x = 0
    libWinConfig.y = 0
    libWinConfig.point = "CENTER"
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    libWinConfig.scale = 1.0
    frame:SetScale(1.0)
end)
