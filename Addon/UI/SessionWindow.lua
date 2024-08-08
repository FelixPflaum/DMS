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
local ShowItemTooltip = Env.UI.ShowItemTooltip

---@class (exact) SessionWindowController
local Controller = {}

local frame ---@type SessionWindow
local itemIcons = {} ---@type IconButon[]
local Host = Env.Session.Host
local Client = Env.Session.Client

---Is host with the same guid as client running.
local function IsHosting()
    return Client.sessionGUID == Host.sessionGUID and Host.isRunning
end

---------------------------------------------------------------------------
--- Status Headers
---------------------------------------------------------------------------

-- Frame Script Handlers

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

-- Create Frames

local function CreateStatusHeaders()
    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    frame.HostNameLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.HostNameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 65, -6)
    frame.HostNameLabel:SetText(L["Host:"])

    frame.HostName = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.HostName:SetPoint("TOPLEFT", frame.HostNameLabel, "TOPRIGHT", 10, 0)
    frame.HostName:SetText("---")

    frame.SessionStatus = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.SessionStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -6)
    frame.SessionStatus:SetText("---")

    frame.SessionStatusLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.SessionStatusLabel:SetPoint("TOPRIGHT", frame.SessionStatus, "TOPLEFT", -10, 0)
    frame.SessionStatusLabel:SetText(L["Status:"])

    frame.ClientsStatus = frame:CreateFontString(nil, "OVERLAY", fontValue)
    frame.ClientsStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -37)
    frame.ClientsStatus:SetText("---")
    frame.ClientsStatus:SetScript("OnEnter", ShowCandidateTooltip)
    frame.ClientsStatus:SetScript("OnLeave", GameTooltip_Hide)

    frame.ClientsStatusLabel = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.ClientsStatusLabel:SetPoint("TOPRIGHT", frame.ClientsStatus, "TOPLEFT", -10, 0)
    frame.ClientsStatusLabel:SetText(L["Players ready:"])
    frame.ClientsStatusLabel:SetScript("OnEnter", function() ShowCandidateTooltip(frame.ClientsStatus) end)
    frame.ClientsStatusLabel:SetScript("OnLeave", GameTooltip_Hide)
end

-- Event Hooks

Client.OnStart:RegisterCallback(function()
    frame.HostName:SetText(Client.hostName)
    frame.SessionStatus:SetText("|cFF44FF44" .. L["Running"])
end)

Client.OnEnd:RegisterCallback(function()
    frame.SessionStatus:SetText("|cFFFFFF44" .. L["Ended"])
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
    frame.ClientsStatus:SetText(text)
end)

---------------------------------------------------------------------------
--- Item Details
---------------------------------------------------------------------------

local ROW_HEIGHT = 20

local selectedItemGuid ---@type string|nil

-- Frame Script Handlers


-- Create Frames

---@type ST_CellUpdateFunc
local function CellUpdateClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    local classId = data[realrow][column]
    if classId then
        cellFrame:SetNormalTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
        local texCoords = CLASS_ICON_TCOORDS[select(2, GetClassInfo(classId))]
        cellFrame:GetNormalTexture():SetTexCoord(unpack(texCoords))
    end
end

local function CreateItemDetails()
    frame.ItemInfoIcon = Env.UI.CreateIconButton(frame, 35, true)
    frame.ItemInfoIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -25)

    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    frame.ItenInfoItemName = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.ItenInfoItemName:SetPoint("TOPLEFT", frame.ItemInfoIcon, "TOPRIGHT", 5, -3)

    frame.ItemInfoItemInfo = frame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    frame.ItemInfoItemInfo:SetPoint("TOPLEFT", frame.ItenInfoItemName, "BOTTOMLEFT", 0, -3)

    frame.ItemInfoAwarded = frame:CreateFontString(nil, "OVERLAY", fontLabel)
    frame.ItemInfoAwarded:SetPoint("TOP", frame, "TOP", 0, -37)
    frame.ItemInfoAwarded:SetText("")

    frame.st = ScrollingTable:CreateST({
        { name = "",            width = ROW_HEIGHT, DoCellUpdate = CellUpdateClassIcon }, -- Class icon
        { name = L["Name"],     width = 100 },
        { name = L["Status"],   width = 175 },
        { name = L["Response"], width = 80 },
        { name = L["Roll"],     width = 40 },
        { name = L["Sanity"],   width = 40 },
        { name = L["Total"],    width = 40 },
    }, 15, ROW_HEIGHT, nil, frame)

    frame.st.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -frame.st.head:GetHeight() - 4)
    --st:RegisterEvents({ OnClick = Script_TableRemoveClicked })

    frame:SetWidth(frame.st.frame:GetWidth() + 7)
    frame:SetHeight(frame.st.frame:GetHeight() + 86)
end

local function SetSelectedItem(guid)
    local item = Client.items[guid]
    if not item then return end

    selectedItemGuid = guid

    frame.ItemInfoIcon:SetItemData(item.itemId)
    local _, itemLink, _, _, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(item.itemId)
    frame.ItenInfoItemName:SetText(itemLink)
    local equipString = _G[itemEquipLoc] or ""
    frame.ItemInfoItemInfo:SetText(itemSubType .. " " .. equipString)

    if item.awardedTo then
        frame.ItemInfoAwarded:SetText(L["Awarded to: %s"]:format(item.awardedTo))
    else
        frame.ItemInfoAwarded:SetText("")
    end

    --TODO: tooltip

    local tableData = {}
    for _, v in pairs(item.responses) do
        table.insert(tableData, {
            v.candidate.classId,
            "|c" .. GetClassColor(v.candidate.classId).argbstr .. v.candidate.name,
            v.status.displayString,
            v.response and v.response.displayString or "",
            v.roll or "",
            v.sanity or "",
            v.roll and v.sanity and v.roll + v.sanity or "" })
    end
    frame.st:SetData(tableData, true)
end

-- Event Hooks

Client.OnStart:RegisterCallback(function()
    frame.HostName:SetText(Client.hostName)
    frame.SessionStatus:SetText("|cFF44FF44" .. L["Running"])
end)

Client.OnEnd:RegisterCallback(function()
    frame.SessionStatus:SetText("|cFFFFFF44" .. L["Ended"])
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
    frame.ClientsStatus:SetText(text)
end)

---------------------------------------------------------------------------
--- Item List
---------------------------------------------------------------------------

-- Frame Script Handlers

---@param guid string
local function Script_SelectItem(guid)
    selectedItemGuid = guid
    SetSelectedItem(guid)
end

-- Create Frames

local MAX_ICONS_PER_COLUMN = 9
local SELECT_ICON_SIZE = 40
local ICON_SLECT_OFFSET_X = -10

---@param index integer
local function GetOrCreateItemSelectIcon(index)
    if itemIcons[index] then
        return itemIcons[index]
    end

    local newBtn = Env.UI.CreateIconButton(frame, SELECT_ICON_SIZE)
    itemIcons[index] = newBtn

    if index == 1 then
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", ICON_SLECT_OFFSET_X, 0)
    elseif math.fmod(index - 1, MAX_ICONS_PER_COLUMN) == 0 then
        local column = math.ceil(index / MAX_ICONS_PER_COLUMN)
        local columnOffset = ICON_SLECT_OFFSET_X - (SELECT_ICON_SIZE + 5) * (column - 1)
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnOffset, 0)
    else
        newBtn:SetPoint("TOP", itemIcons[index - 1], "BOTTOM", 0, -2)
    end

    return newBtn
end

local function UpdateItemSelect()
    ---@type LootSessionClientItem[]
    local ordered = {}
    for _, item in pairs(Client.items) do
        table.insert(ordered, item)
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    for k, item in ipairs(ordered) do
        local btn = GetOrCreateItemSelectIcon(k)
        btn:SetBorderColor("grey")
        btn:SetItemData(item.itemId, item.guid)
        btn:SetOnClick(Script_SelectItem)
        btn:Show()
    end

    for i = #ordered + 1, #itemIcons do
        itemIcons[i]:Hide()
    end
end

-- Event Hooks

Client.OnItemUpdate:RegisterCallback(function(item)
    UpdateItemSelect()
    if item.guid == selectedItemGuid then
        SetSelectedItem(selectedItemGuid)
    end
end)

Client.OnStart:RegisterCallback(function()
    UpdateItemSelect()
end)

---------------------------------------------------------------------------
--- Main Window
---------------------------------------------------------------------------

local WIDTH = 600
local HEIGHT = 400

local function CreateWindow()
    ---@class SessionWindow : ButtonFrameTemplate
    frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetWidth(WIDTH)
    frame:SetHeight(HEIGHT)
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
    frame.CloseButton:SetScript("OnClick", function() Controller:CloseClicked() end)

    CreateStatusHeaders()
    CreateItemDetails()
end

Env:OnAddonLoaded(function()
    CreateWindow()
end)

function Controller:CloseClicked()
    if IsHosting() then
        LibDialog:Spawn({
            text = "Do you want to abort the loot session?",
            on_cancel = function(self, data, reason) end,
            buttons = {
                {
                    text = "Abort",
                    on_click = function()
                        Host:Destroy()
                        frame:Hide()
                    end,
                },
                {
                    text = "Minimize",
                    on_click = function()
                        frame:Hide()
                    end,
                },
            },
        })
        return
    end
    frame:Hide()
    if Client.isRunning then
        Env:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
    end
end

Client.OnStart:RegisterCallback(function()
    frame:Show()
end)

---------------------------------------------------------------------------
--- API
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
