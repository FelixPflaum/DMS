---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

local Client = Env.Session.Client
local frame ---@type ButtonWindow
local rollItemFrames = {} ---@type RollItemFrame[]
local responsesOrdered = {} ---@type LootResponse[]

---------------------------------------------------------------------------
--- Frame Script Handlers
---------------------------------------------------------------------------

---@param self RollItemFrameResponseButton
local function Script_ResponseClicked(self)
    Client:RespondToItem(self.itemGuid, self.responseId)
end

---@param self RollItemFrameTimerBar
local function Script_TimerBarUpdate(self)
    if self.expirationTime then
        local remaining = self.expirationTime - time()
        if remaining <= 0 then
            self.Text:SetText(L["Timeout"])
            self:SetValue(0)
        else
            self.Text:SetText(L["%d sec"]:format(remaining))
            self:SetValue(remaining)
        end
    end
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local MAX_ITEMS_SHOWN = 4
local MIN_WIDTH = 300
local ITEM_ROLL_FRAME_ICON_SIZE = 60
local ITEM_ROLL_FRAME_BUTTON_HIGHT = 25
local ITEM_ROLL_FRAME_TIMER_HIGHT = 13
local ITEM_ROLL_FRAME_HEIGHT = ITEM_ROLL_FRAME_ICON_SIZE + ITEM_ROLL_FRAME_TIMER_HIGHT + 10
local ITEM_ROLL_FRAME_BUTTON_MARGIN = 5

---Set button response text and data.
---@param self RollItemFrameResponseButton
---@param reponseText string
---@param itemGuid string
---@param responseId integer
local function RollFrameButtonSetResponse(self, reponseText, itemGuid, responseId)
    self.itemGuid = itemGuid
    self.responseId = responseId
    self:SetText(reponseText)
    self:SetWidth(self:GetTextWidth() + 18)
end

---Get response button for position.
---Creates the button if it doesn't exist.
---@param self RollItemFrame
---@param btnIndex integer
local function RollFrameGetResponseButton(self, btnIndex)
    if not self.Buttons[btnIndex] then
        ---@class RollItemFrameResponseButton : WoWFrameButton
        ---@field itemGuid string|nil
        ---@field responseId integer|nil
        local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        button:SetSize(50, ITEM_ROLL_FRAME_BUTTON_HIGHT)
        button:SetScript("OnClick", Script_ResponseClicked)
        button.SetResponse = RollFrameButtonSetResponse
        if btnIndex == 1 then
            button:SetPoint("BOTTOMLEFT", self.ItemIcon, "BOTTOMRIGHT", 3, 1)
        else
            button:SetPoint("LEFT", self.Buttons[btnIndex - 1], "RIGHT", ITEM_ROLL_FRAME_BUTTON_MARGIN, 0)
        end
        self.Buttons[btnIndex] = button
    end
    return self.Buttons[btnIndex]
end

---Set item data, showing icon, name and timer bar
---@param self RollItemFrame
---@param itemId integer
---@param itemLink string
---@param infoText string
---@param startTime integer
---@param endTime integer
local function RollFrameSetItemData(self, itemId, itemLink, infoText, startTime, endTime)
    self.ItemIcon:SetItemData(itemId)
    self.ItenInfoItemName:SetText(itemLink)
    self.ItemInfoItemInfo:SetText(infoText)
    self.TimerBar:SetMinMaxValues(0, endTime - startTime)
    self.TimerBar.expirationTime = endTime
end

---@param posIndex integer
local function GetOrCreateRollItemFrame(posIndex)
    if rollItemFrames[posIndex] then
        return rollItemFrames[posIndex]
    end

    ---@class RollItemFrame : WoWFrame
    local rollItemFrame = CreateFrame("Frame", nil, frame.Inset)

    rollItemFrame:SetSize(MIN_WIDTH, ITEM_ROLL_FRAME_HEIGHT)
    if posIndex == 1 then
        rollItemFrame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 0, 0)
    else
        rollItemFrame:SetPoint("TOPLEFT", rollItemFrames[posIndex - 1], "BOTTOMLEFT", 0, -2)
    end

    ---@type RollItemFrameResponseButton[]
    rollItemFrame.Buttons = {}

    rollItemFrame.Seperator = rollItemFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    rollItemFrame.Seperator:SetTexture(frame.NineSlice.BottomEdge:GetTexture())
    rollItemFrame.Seperator:SetPoint("BOTTOMLEFT", 0, 0)
    rollItemFrame.Seperator:SetPoint("BOTTOMRIGHT", 0, 0)
    rollItemFrame.Seperator:SetTexCoord(0, 1, 0.52, 0.54)
    rollItemFrame.Seperator:SetHeight(3)

    rollItemFrame.ItemIcon = Env.UI.CreateIconButton(rollItemFrame, ITEM_ROLL_FRAME_ICON_SIZE, true)
    rollItemFrame.ItemIcon:SetPoint("TOPLEFT", 4, -4)

    rollItemFrame.ItenInfoItemName = rollItemFrame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    rollItemFrame.ItenInfoItemName:SetPoint("TOPLEFT", rollItemFrame.ItemIcon, "TOPRIGHT", 5, -3)
    rollItemFrame.ItenInfoItemName:SetWordWrap(false)

    rollItemFrame.ItemInfoItemInfo = rollItemFrame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    rollItemFrame.ItemInfoItemInfo:SetPoint("TOPLEFT", rollItemFrame.ItenInfoItemName, "BOTTOMLEFT", 0, -3)

    ---@class RollItemFrameTimerBar : StatusBar
    ---@field expirationTime number|nil
    rollItemFrame.TimerBar = CreateFrame("StatusBar", nil, rollItemFrame, "TextStatusBar")
    rollItemFrame.TimerBar:SetHeight(ITEM_ROLL_FRAME_TIMER_HIGHT)
    rollItemFrame.TimerBar:SetPoint("BOTTOMLEFT", 0, 4)
    rollItemFrame.TimerBar:SetPoint("BOTTOMRIGHT", 0, 4)
    rollItemFrame.TimerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rollItemFrame.TimerBar:SetStatusBarColor(0.8, 0.7, 0.6, 1)
    rollItemFrame.TimerBar.Text = rollItemFrame.TimerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollItemFrame.TimerBar.Text:SetPoint("CENTER", rollItemFrame.TimerBar, 0, 0)
    rollItemFrame.TimerBar.Text:SetTextColor(1, 1, 1)
    rollItemFrame.TimerBar:SetScript("OnUpdate", Script_TimerBarUpdate)

    -- Attach custom functions
    rollItemFrame.GetResponseButton = RollFrameGetResponseButton
    rollItemFrame.SetItemData = RollFrameSetItemData

    rollItemFrames[posIndex] = rollItemFrame
    return rollItemFrame
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    frame = Env.UI.CreateButtonWindow("DMSResponseWindow", L["Roll on Loot"], 300, 75, 25, false, DMS_Settings.UI.ResponseWindow,
        "TOPLEFT", 125, -200)
    frame:SetToplevel(true)
end)

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

---Show item at given position.
---@param posIndex integer
---@param item LootSessionClientItem|nil Set nil to hide frame.
local function SetitemAtPosition(posIndex, item)
    local rif = GetOrCreateRollItemFrame(posIndex)
    if not item then
        rif:Hide()
        return
    end
    rif:Show()

    local _, itemLink, _, _, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(item.itemId)
    local equipString = _G[itemEquipLoc] or ""
    local infoText = (itemSubType or "") .. " " .. equipString
    rif:SetItemData(item.itemId, itemLink, infoText, item.startTime, item.endTime)

    local buttonWidth = 0
    local nextBtnIndex = 1
    for _, response in ipairs(responsesOrdered) do
        if not response.noButton then
            local button = rif:GetResponseButton(nextBtnIndex)
            button:SetResponse(response.displayString, item.guid, response.id)
            nextBtnIndex = nextBtnIndex + 1
            buttonWidth = buttonWidth + button:GetWidth() + ITEM_ROLL_FRAME_BUTTON_MARGIN
        end
    end

    for i = nextBtnIndex, #rif.Buttons do
        rif.Buttons[i]:Hide()
    end

    rif:SetWidth(math.max(MIN_WIDTH, buttonWidth + ITEM_ROLL_FRAME_ICON_SIZE + 5))
end

Env.Session.Client.OnStart:RegisterCallback(function()
    if not Client.responses then return end
    local responses = Client.responses.responses
    ---Make a reverse array of the current response data the client has. Filtering out those that shouldn't be shown.
    ---Responses are created with the "top" response also having the highest id, but the "top" should be shown left most.
    responsesOrdered = {}
    for i = #responses, 1, -1 do
        table.insert(responsesOrdered, responses[i])
    end
end)

Env.Session.Client.OnItemUpdate:RegisterCallback(function()
    local now = time()
    ---@type LootSessionClientItem[]
    local itemsOrdered = {}
    local shown = 0

    for _, v in pairs(Client.items) do
        if not v.isChild and not v.responseSent and v.endTime - now > 0 then
            table.insert(itemsOrdered, v)
        end
    end

    table.sort(itemsOrdered, function(a, b)
        return a.endTime < b.endTime
    end)

    for i = 1, MAX_ITEMS_SHOWN do
        local itemToShow = itemsOrdered[i]
        SetitemAtPosition(i, itemToShow)
        if itemToShow then
            shown = shown + 1
        end
    end

    if shown == 0 then
        frame:Hide()
    else
        frame:Show()
    end

    frame:SetHeight(shown * ITEM_ROLL_FRAME_HEIGHT + 54)
    frame:SetWidth(rollItemFrames[1]:GetWidth() + 13)
end)

Env.Session.Client.OnEnd:RegisterCallback(function()
    frame:Hide()
end)

Env.UI:RegisterOnReset(function()
    frame:Reset()
end)
