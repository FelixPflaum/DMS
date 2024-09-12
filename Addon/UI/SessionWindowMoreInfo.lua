---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

local ColorByClassId = Env.UI.ColorByClassId
local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady

local CONTENT_MARGIN = 5
local ITEM_ROW_MARGIN = 2
local RESPONSE_WIDTH = 35

local tinyFont = CreateFont("DmsTinyFont")
tinyFont:CopyFontObject(GameFontNormalTiny) ---@diagnostic disable-line: undefined-global, no-unknown
tinyFont:SetJustifyH("LEFT")

local extraTinyFont = CreateFont("DmsExtraTinyFont")
extraTinyFont:CopyFontObject(GameFontWhiteTiny2) ---@diagnostic disable-line: undefined-global, no-unknown
extraTinyFont:SetJustifyH("LEFT")

local extraTinyFontYellow = CreateFont("DmsExtraTinyFontYellow")
extraTinyFontYellow:CopyFontObject(DmsExtraTinyFont) ---@diagnostic disable-line: undefined-global, no-unknown
extraTinyFontYellow:SetJustifyH("LEFT")
extraTinyFontYellow:SetTextColor(1, 0.82, 0)

local headerFont = "DmsTinyFont"
local headerFontTiny = "DmsExtraTinyFontYellow"
local textFont = "DmsExtraTinyFont"

---@param self SessionWindowMoreInfoPanelItemRowFrame
---@param response string
---@param age string
---@param name string
local function SetItemRowContent(self, response, age, name)
    self.ItemResponse:SetText(response)
    self.ItemAge:SetText(age)
    self.ItemName:SetText(name)
    self:SetWidth(self.ItemResponse:GetWidth() + self.ItemAge:GetWidth() + self.ItemName:GetWidth())
end

---@param parent WoWFrame
local function CreateLastItemRow(parent)
    ---@class SessionWindowMoreInfoPanelItemRowFrame : WoWFrame
    local itemRow = CreateFrame("Frame", nil, parent)
    itemRow.ItemResponse = itemRow:CreateFontString(nil, "OVERLAY", textFont)
    itemRow.ItemResponse:SetPoint("TOPLEFT", 0, 0)
    itemRow.ItemResponse:SetText("-") -- Init height
    itemRow.ItemResponse:SetWidth(RESPONSE_WIDTH)
    itemRow.ItemAge = itemRow:CreateFontString(nil, "OVERLAY", textFont)
    itemRow.ItemAge:SetPoint("LEFT", itemRow.ItemResponse, "RIGHT", 0, 0)
    itemRow.ItemAge:SetWidth(55)
    itemRow.ItemName = itemRow:CreateFontString(nil, "OVERLAY", textFont)
    itemRow.ItemName:SetPoint("LEFT", itemRow.ItemAge, "RIGHT", 0, 0)
    itemRow:SetHeight(itemRow.ItemResponse:GetHeight())
    itemRow.SetContent = SetItemRowContent
    return itemRow
end

---@param self SessionWindowMoreInfoPanelFrame
---@param pos integer
---@param response string
---@param age string
---@param name string
local function ShowLastItemRow(self, pos, response, age, name)
    if not self.lastItemRows[pos] then
        local newRow = CreateLastItemRow(self.LastItems)
        if pos == 1 then
            newRow:SetPoint("TOPLEFT", 0, 0)
        else
            newRow:SetPoint("TOPLEFT", self.lastItemRows[pos - 1], "BOTTOMLEFT", 0, -ITEM_ROW_MARGIN)
        end
        newRow:Hide()
        self.lastItemRows[pos] = newRow
    end
    local row = self.lastItemRows[pos]
    row:SetContent(response, age, name)
    if not row:IsShown() then
        if row:GetWidth() > self.LastItems:GetWidth() then
            self.LastItems:SetWidth(row:GetWidth())
        end
        local newHeight = self.LastItems:GetHeight() + row:GetHeight()
        if pos > 1 then
            newHeight = newHeight + ITEM_ROW_MARGIN
        end
        self.LastItems:SetHeight(newHeight)
        row:Show()
    end
    return row
end

---@param self SessionWindowMoreInfoPanelFrame
---@param pos integer
---@param name string
local function UpdateLastItemRowName(self, pos, name)
    local row = self.lastItemRows[pos]
    row:SetContent(row.ItemResponse:GetText(), row.ItemAge:GetText(), name)
    if row:IsShown() then
        if row:GetWidth() > self.LastItems:GetWidth() then
            self.LastItems:SetWidth(row:GetWidth())
            self:FitContent()
        end
    end
end

---@param self SessionWindowMoreInfoPanelFrame
---@param fromPos integer
local function HideLastItemRows(self, fromPos)
    for i = fromPos, #self.lastItemRows do
        if self.lastItemRows[i]:IsShown() then
            self.lastItemRows[i]:Hide()
            if self.lastItemRows[i]:GetWidth() > self.LastItems:GetWidth() - 0.01 then
                local max = 0
                for _, v in ipairs(self.lastItemRows) do
                    if v:IsShown() then
                        max = math.max(max, v:GetWidth())
                    end
                end
                self.LastItems:SetWidth(max)
            end
            local newHeight = self.LastItems:GetHeight() - self.lastItemRows[i]:GetHeight()
            if i > 1 then
                newHeight = newHeight - ITEM_ROW_MARGIN
            end
            self.LastItems:SetHeight(newHeight)
        else
            break
        end
    end
end

---@param self SessionWindowMoreInfoPanelResponseRowFrame
---@param response string
---@param count string
local function SetItemResponseCountContent(self, response, count)
    self.ItemResponse:SetText(response)
    self.Count:SetText(count)
    self:SetWidth(self.ItemResponse:GetWidth() + self.Count:GetWidth())
end

---@param parent WoWFrame
local function CreateItemResponseCountRow(parent)
    ---@class SessionWindowMoreInfoPanelResponseRowFrame : WoWFrame
    local responseRow = CreateFrame("Frame", nil, parent)
    responseRow.ItemResponse = responseRow:CreateFontString(nil, "OVERLAY", textFont)
    responseRow.ItemResponse:SetPoint("TOPLEFT", 0, 0)
    responseRow.ItemResponse:SetText("-") -- Init height
    responseRow.ItemResponse:SetWidth(RESPONSE_WIDTH)
    responseRow.Count = responseRow:CreateFontString(nil, "OVERLAY", textFont)
    responseRow.Count:SetPoint("LEFT", responseRow.ItemResponse, "RIGHT", 0, 0)
    responseRow:SetHeight(responseRow.ItemResponse:GetHeight())
    responseRow.SetContent = SetItemResponseCountContent
    return responseRow
end

---@param self SessionWindowMoreInfoPanelFrame
---@param pos integer
---@param response string
---@param count string
local function ShowItemResponseCountRow(self, pos, response, count)
    if not self.itemResponseCountRows[pos] then
        local newRow = CreateItemResponseCountRow(self.LastItemResponses)
        if pos == 1 then
            newRow:SetPoint("TOPLEFT", 0, 0)
        else
            newRow:SetPoint("TOPLEFT", self.itemResponseCountRows[pos - 1], "BOTTOMLEFT", 0, -ITEM_ROW_MARGIN)
        end
        newRow:Hide()
        self.itemResponseCountRows[pos] = newRow
    end
    local row = self.itemResponseCountRows[pos]
    row:SetContent(response, count)
    if not row:IsShown() then
        if row:GetWidth() > self.LastItemResponses:GetWidth() then
            self.LastItemResponses:SetWidth(row:GetWidth())
        end
        local newHeight = self.LastItemResponses:GetHeight() + row:GetHeight()
        if pos > 1 then
            newHeight = newHeight + ITEM_ROW_MARGIN
        end
        self.LastItemResponses:SetHeight(newHeight)
        row:Show()
    end

    return row
end

---@param self SessionWindowMoreInfoPanelFrame
---@param fromPos integer
local function HideItemResponseCountRows(self, fromPos)
    for i = fromPos, #self.itemResponseCountRows do
        if self.itemResponseCountRows[i]:IsShown() then
            self.itemResponseCountRows[i]:Hide()
            if self.itemResponseCountRows[i]:GetWidth() > self.LastItemResponses:GetWidth() - 0.01 then
                local max = 0
                for _, v in ipairs(self.itemResponseCountRows) do
                    if v:IsShown() then
                        max = math.max(max, v:GetWidth())
                    end
                end
                self.LastItemResponses:SetWidth(max)
            end
            local newHeight = self.LastItemResponses:GetHeight() - self.itemResponseCountRows[i]:GetHeight()
            if i > 1 then
                newHeight = newHeight - ITEM_ROW_MARGIN
            end
            self.LastItemResponses:SetHeight(newHeight)
        else
            break
        end
    end
end

---@param self SessionWindowMoreInfoPanelFrame
local function FitContent(self)
    local maxWidth = self.PlayerName:GetWidth()
    maxWidth = math.max(maxWidth, self.LastItemsHeading:GetWidth())
    maxWidth = math.max(maxWidth, self.LastItems:GetWidth())
    maxWidth = math.max(maxWidth, self.LastItemsResponsesHeading:GetWidth())
    maxWidth = math.max(maxWidth, self.LastItemResponses:GetWidth())
    self:SetWidth(maxWidth + CONTENT_MARGIN * 2)

    local height = CONTENT_MARGIN * 2.0
    height = height + self.PlayerName:GetHeight()
    height = height + self.LastItemsHeading:GetHeight() + CONTENT_MARGIN
    height = height + self.LastItems:GetHeight() + CONTENT_MARGIN
    height = height + self.LastItemsResponsesHeading:GetHeight() + CONTENT_MARGIN
    height = height + self.LastItemResponses:GetHeight() + CONTENT_MARGIN
    self:SetHeight(height)
end

---@param parent WoWFrame
local function CreateBaseFrame(parent)
    ---@class SessionWindowMoreInfoPanelFrame : WoWFrame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 400)
    frame:Hide()

    frame.Bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.Bg:SetColorTexture(0.15, 0.15, 0.15, 0.75)
    frame.Bg:SetPoint("TOPLEFT", 0, 0)
    frame.Bg:SetPoint("BOTTOMRIGHT", 0, 0)

    frame.PlayerName = frame:CreateFontString(nil, "OVERLAY", headerFont)
    frame.PlayerName:SetPoint("TOPLEFT", CONTENT_MARGIN, -CONTENT_MARGIN)

    frame.LastItemsHeading = frame:CreateFontString(nil, "OVERLAY", headerFontTiny)
    frame.LastItemsHeading:SetPoint("TOPLEFT", frame.PlayerName, "BOTTOMLEFT", 0, -CONTENT_MARGIN)

    frame.LastItems = CreateFrame("Frame", nil, frame)
    frame.LastItems:SetPoint("TOPLEFT", frame.LastItemsHeading, "BOTTOMLEFT", 0, -CONTENT_MARGIN)
    frame.lastItemRows = {} ---@type SessionWindowMoreInfoPanelItemRowFrame[]
    frame.ShowLastItemRow = ShowLastItemRow
    frame.UpdateLastItemRowName = UpdateLastItemRowName
    frame.HideLastItemRows = HideLastItemRows

    frame.LastItemsResponsesHeading = frame:CreateFontString(nil, "OVERLAY", headerFontTiny)
    frame.LastItemsResponsesHeading:SetPoint("TOPLEFT", frame.LastItems, "BOTTOMLEFT", 0, -CONTENT_MARGIN)

    frame.LastItemResponses = CreateFrame("Frame", nil, frame)
    frame.LastItemResponses:SetPoint("TOPLEFT", frame.LastItemsResponsesHeading, "BOTTOMLEFT", 0, -CONTENT_MARGIN)
    frame.itemResponseCountRows = {} ---@type SessionWindowMoreInfoPanelResponseRowFrame[]
    frame.ShowItemResponseCountRow = ShowItemResponseCountRow
    frame.HideItemResponseCountRows = HideItemResponseCountRows

    frame.FitContent = FitContent

    return frame
end

---@param secondsAgo number
---@return string
local function LootAgeString(secondsAgo)
    if secondsAgo > 86400 * 2 then
        return L["%d days ago"]:format(secondsAgo / 86400)
    elseif secondsAgo > 86400 then
        return L["Yesterday"]
    else
        return L["Today"]
    end
end

---Display more info for player.
---@param self SessionWindowMoreInfo
---@param name string? Set nil to hide panel.
local function SetPlayer(self, name)
    if not Env.settings.moreInfoEnabled or not name then
        self.frame:Hide()
        return
    end

    local dbData = Env.Database:GetPlayer(name)
    if not dbData then return end

    self.frame.PlayerName:SetText(ColorByClassId(dbData.playerName, dbData.classId))

    local timeframe = Env.settings.moreInfoTimeframe
    local maxItemsToShow = Env.settings.moreInfoItemCount
    local now = time()
    local lootHistory = Env.Database:GetLootHistory({ playerName = dbData.playerName, untilTime = now, fromTime = now - timeframe })
    local responseCount = {} ---@type table<string,{id:integer, display:string, count:integer}>

    print(maxItemsToShow, timeframe, #lootHistory)

    table.sort(lootHistory, function(a, b)
        return a.timeStamp > b.timeStamp
    end)

    self.frame.LastItemsHeading:SetText(L["Last %d items received:"]:format(maxItemsToShow))

    for i = 1, math.max(#lootHistory, maxItemsToShow, #self.frame.lastItemRows) do
        local item = lootHistory[i]
        if item then
            local id, color, display = Env.Database.FormatResponseStringForUI(item.response)
            if i <= maxItemsToShow then
                local row = self.frame:ShowLastItemRow(i, ("|cFF%s%s|r"):format(color, display), LootAgeString(now - item.timeStamp), tostring(item.itemId))
                DoWhenItemInfoReady(item.itemId, function(_, itemLink)
                    self.frame:UpdateLastItemRowName(i, itemLink)
                    row.ItemName:SetText(itemLink)
                end)
                row:Show()
            end
            if not responseCount[display] then
                responseCount[display] = {
                    id = id,
                    display = ("|cFF%s%s|r"):format(color, display),
                    count = 0
                }
            end
            responseCount[display].count = responseCount[display].count + 1
        else
            self.frame:HideLastItemRows(i)
            break
        end
    end

    self.frame.LastItemsResponsesHeading:SetText(L["Total items in the last %d days:"]:format(math.floor(timeframe / 86400)))

    local respCountArray = {} ---@type {id:integer, display:string, count:integer}[]
    for _, v in pairs(responseCount) do
        table.insert(respCountArray, v)
    end
    table.sort(respCountArray, function(a, b)
        return a.id > b.id
    end)
    local i = 0
    for j = 1, #respCountArray do
        i = j
        local res = respCountArray[j]
        self.frame:ShowItemResponseCountRow(i, res.display, tostring(res.count))
    end
    self.frame:HideItemResponseCountRows(i + 1)

    self.frame:FitContent()
    self.frame:Show()
end

---@param parent WoWFrame
local function CreateMoreInfoPanel(parent)
    ---@class (exact) SessionWindowMoreInfo
    ---@field frame SessionWindowMoreInfoPanelFrame
    local moreInfo = { frame = CreateBaseFrame(parent) }
    moreInfo.SetPlayer = SetPlayer ---@diagnostic disable-line: inject-field
    return moreInfo
end

Env.UI.CreateMoreInfoPanel = CreateMoreInfoPanel
