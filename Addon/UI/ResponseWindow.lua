---@class AddonEnv
local Env = select(2, ...)

local LibDialog = LibStub("LibDialog-1.1")
local L = Env:GetLocalization()

local GetImagePath = Env.UI.GetImagePath

local Client = Env.SessionClient
local frame ---@type ResponseFrame
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

local itemsNotRolled = {} ---@type SessionClient_Item[]

local areYouSure = {
    show_while_dead = true,
    text = L["Do you really want to pass on all open rolls?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Yes"],
            on_click = function()
                for _, inr in ipairs(itemsNotRolled) do
                    Client:RespondToItem(inr.guid, Client.responses:GetPass().id)
                end
                frame:Hide()
            end
        },
        {
            text = L["No"],
            on_click = function() frame:Hide() end
        },
    },
}

local function CloseClicked()
    local now = time()
    itemsNotRolled = {} ---@type SessionClient_Item[]
    for _, v in pairs(Client.items) do
        if not v.parentGuid and not v.responseSent and v.endTime - now > 0 then
            table.insert(itemsNotRolled, v)
        end
    end
    if #itemsNotRolled > 0 then
        if not LibDialog:ActiveDialog(areYouSure) then
            LibDialog:Spawn(areYouSure)
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
---@param isPointRoll boolean
---@param canUsePoints boolean
local function RollFrameButtonSetResponse(self, reponseText, itemGuid, responseId, isPointRoll, canUsePoints)
    self.itemGuid = itemGuid
    self.responseId = responseId
    self:SetText(reponseText)
    self:SetWidth(self:GetTextWidth() + 18)
    local texture = isPointRoll and GetImagePath("btn_sanity.png") or [[Interface\Buttons\UI-Panel-Button-Up]]
    if isPointRoll and not canUsePoints then
        self:Disable()
    else
        self:Enable()
    end
    self.Left:SetTexture(texture)
    self.Middle:SetTexture(texture)
    self.Right:SetTexture(texture)
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
        ---@field Left Texture
        ---@field Right Texture
        ---@field Middle Texture
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

local function CreateWindow()
    ---@class ResponseFrame : ButtonWindow
    frame = Env.UI.CreateButtonWindow("DMSResponseWindow", L["Roll on Loot"], 300, 75, 25, false, DMS_Settings.UI.ResponseWindow,
        "LEFT", 125, 200)
    frame:SetToplevel(true)

    frame.TopLeftText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.TopLeftText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -31)

    frame.TopRightText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.TopRightText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -31)

    frame.onTopCloseClicked = CloseClicked
end

-- Create frame when settings are ready.
Env:OnAddonLoaded(function()
    CreateWindow()
end)

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady

---Show item at given position.
---@param posIndex integer
---@param item SessionClient_Item|nil Set nil to hide frame.
---@param canUsePoints boolean
local function SetitemAtPosition(posIndex, item, canUsePoints)
    local rif = GetOrCreateRollItemFrame(posIndex)
    if not item then
        rif:Hide()
        return
    end
    rif:Show()

    rif:SetItemData(item.itemId, tostring(item.itemId), "...", item.startTime, item.endTime)
    DoWhenItemInfoReady(item.itemId,
        function(_, itemLink, _, _, _, _, itemSubType, _, itemEquipLoc, _, _, classID, subclassID)
            local infoText = Env.UI.GetItemTypeString(classID, subclassID, itemSubType, itemEquipLoc)
            rif:SetItemData(item.itemId, itemLink, infoText, item.startTime, item.endTime)
        end)

    local buttonWidth = 0
    local nextBtnIndex = 1
    for _, response in ipairs(responsesOrdered) do
        if not response.noButton then
            local button = rif:GetResponseButton(nextBtnIndex)
            button:SetResponse(response.displayString, item.guid, response.id, response.isPointsRoll, canUsePoints)
            nextBtnIndex = nextBtnIndex + 1
            buttonWidth = buttonWidth + button:GetWidth() + ITEM_ROLL_FRAME_BUTTON_MARGIN
            button:Show()
        end
    end

    for i = nextBtnIndex, #rif.Buttons do
        rif.Buttons[i]:Hide()
    end

    rif.ItenInfoItemName:SetWidth(math.min(MIN_WIDTH - ITEM_ROLL_FRAME_ICON_SIZE, buttonWidth))
    rif:SetWidth(math.max(MIN_WIDTH, buttonWidth + ITEM_ROLL_FRAME_ICON_SIZE + 5))
end

Client.OnStart:RegisterCallback(function()
    if not Client.responses then return end
    local responses = Client.responses.responses
    ---Make a reverse array of the current response data the client has. Filtering out those that shouldn't be shown.
    ---Responses are created with the "top" response also having the highest id, but the "top" should be shown left most.
    responsesOrdered = {}
    for i = #responses, 1, -1 do
        table.insert(responsesOrdered, responses[i])
    end
end)

Client.OnItemUpdate:RegisterCallback(function()
    local now = time()
    ---@type SessionClient_Item[]
    local itemsOrdered = {}
    local shown = 0

    for _, v in pairs(Client.items) do
        if not v.parentGuid and not v.responseSent and v.endTime - now > 0 then
            table.insert(itemsOrdered, v)
        end
    end

    table.sort(itemsOrdered, function(a, b)
        return a.endTime < b.endTime or a.order < b.order
    end)

    frame.TopRightText:SetText(L["Items to roll: %d"]:format(#itemsOrdered))

    local selfCandidate = Client.candidates[UnitName("player")]
    local canUsePoints = (selfCandidate.currentPoints or 0) >= Client.pointsMinForRoll

    for i = 1, MAX_ITEMS_SHOWN do
        local itemToShow = itemsOrdered[i]
        SetitemAtPosition(i, itemToShow, canUsePoints)
        if itemToShow then
            shown = shown + 1
        end
    end

    if shown == 0 then
        frame:Hide()
    else
        frame:Show()
    end

    local prevTop = frame:GetTop()
    frame:SetHeight(shown * ITEM_ROLL_FRAME_HEIGHT + 54)
    frame:SetWidth(rollItemFrames[1]:GetWidth() + 13)
    local topDelta = frame:GetTop() - prevTop
    local point, rel, relPoint, xo, yo = frame:GetPoint(1)
    frame:SetPosition(point, rel, relPoint, xo, yo - topDelta)
end)

Client.OnCandidateUpdate:RegisterCallback(function()
    local selfCandidate = Client.candidates[UnitName("player")]
    local currentPoints = selfCandidate and selfCandidate.currentPoints or 0
    local canUsePoints = selfCandidate.currentPoints >= Client.pointsMinForRoll
    local color = canUsePoints and "88FF88" or "FF8888"
    frame.TopLeftText:SetText(L["Sanity: |cFF%s%d|r"]:format(color, currentPoints))
end)

Client.OnEnd:RegisterCallback(function()
    frame:Hide()
end)

Env.UI:RegisterOnReset(function()
    frame:Reset()
end)
