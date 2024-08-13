---@class AddonEnv
local Env = select(2, ...)

local GetImagePath = Env.UI.GetImagePath

---Set normal texture desatured state.
---@param self IconButon
---@param desaturated boolean
local function SetDesaturated(self, desaturated)
    self:GetNormalTexture():SetDesaturated(desaturated)
end

---(Un)set callback for click action.
---@param self IconButon
---@param func fun(arg:any)|nil
local function SetOnClick(self, func)
    self.onClickCallback = func
end

---@param self IconButon
---@param itemId integer|nil
---@param arg any Data given to the click callback.
local function SetItemData(self, itemId, arg)
    local icon = itemId and GetItemIcon(itemId) or nil
    if not icon then
        self:SetNormalTexture([[Interface/Icons/inv_misc_questionmark]])
    else
        self:SetNormalTexture(icon)
    end
    self.itemId = itemId
    self.clickCallbackArg = arg
end

---@param self IconButon
---@return any
local function GetArg(self)
    return self.clickCallbackArg
end

---Show or hide checkmark.
---@param self IconButon
---@param show boolean
local function ShowCheckmark(self, show)
    if show then
        self.OverlayCheckmark:Show()
    else
        self.OverlayCheckmark:Hide()
    end
end

---Show or hide border.
---@param self IconButon
---@param show boolean
---@param color number[]|nil RGB or predifined color, defaults to white.
local function ShowBorder(self, show, color)
    if show then
        if color then
            self.OverLayTexture:SetVertexColor(color[1], color[2], color[3])
        else
            self.OverLayTexture:SetVertexColor(1, 1, 1)
        end
        self.OverLayTexture:Show()
    else
        self.OverLayTexture:Hide()
    end
end

---@param parent WoWFrame
---@param size number
---@param noHighlight boolean|nil
---@return IconButon
local function CreateIconButton(parent, size, noHighlight)
    ---@class (exact) IconButon : WoWFrameButton
    ---@field onClickCallback fun(arg:any)|nil
    ---@field itemId integer|nil
    ---@field clickCallbackArg any
    local iicon = CreateFrame("Button", nil, parent, "BackdropTemplate")
    iicon:SetSize(size, size)
    if not noHighlight then
        iicon:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
        iicon:GetHighlightTexture():SetBlendMode("ADD")
    end
    iicon:SetNormalTexture([[Interface\InventoryItems\WoWUnknownItem01]])
    iicon:GetNormalTexture():SetDrawLayer("BACKGROUND")
    iicon:GetNormalTexture():SetVertexColor(1, 1, 1)
    iicon:SetBackdrop({ bgFile = "", edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 15 })
    iicon:EnableMouse(true)
    iicon:RegisterForClicks("AnyUp")
    iicon.SetDesaturated = SetDesaturated ---@diagnostic disable-line: inject-field
    iicon.SetOnClick = SetOnClick ---@diagnostic disable-line: inject-field
    iicon.SetItemData = SetItemData ---@diagnostic disable-line: inject-field
    iicon.GetArg = GetArg ---@diagnostic disable-line: inject-field
    iicon:SetScript("OnClick", function()
        if iicon.onClickCallback then
            iicon.onClickCallback(iicon.clickCallbackArg)
        end
    end)
    iicon:SetScript("OnEnter", function(frame)
        if iicon.itemId == nil then return end
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetHyperlink("item:" .. iicon.itemId)
    end)
    iicon:SetScript("OnLeave", GameTooltip_Hide)

    local checkMarkOverlayInset = size / 10
    iicon.OverlayCheckmark = iicon:CreateTexture(nil, "OVERLAY") ---@diagnostic disable-line: inject-field
    iicon.OverlayCheckmark:SetTexture(GetImagePath("check_shadow.png"))
    iicon.OverlayCheckmark:SetPoint("TOPLEFT", checkMarkOverlayInset, -checkMarkOverlayInset)
    iicon.OverlayCheckmark:SetPoint("BOTTOMRIGHT", -checkMarkOverlayInset, checkMarkOverlayInset)
    iicon.OverlayCheckmark:Hide()
    iicon.ShowCheckmark = ShowCheckmark ---@diagnostic disable-line: inject-field

    local borderOverlayInset = 1
    iicon.OverLayTexture = iicon:CreateTexture(nil, "OVERLAY") ---@diagnostic disable-line: inject-field
    iicon.OverLayTexture:SetTexture(GetImagePath("border_r10_thick.png"))
    iicon.OverLayTexture:SetPoint("TOPLEFT", borderOverlayInset, -borderOverlayInset)
    iicon.OverLayTexture:SetPoint("BOTTOMRIGHT", -borderOverlayInset, borderOverlayInset)
    iicon.OverLayTexture:SetAlpha(0.8)
    iicon.OverLayTexture:Hide()
    iicon.ShowBorder = ShowBorder ---@diagnostic disable-line: inject-field

    return iicon
end

Env.UI = Env.UI or {}
Env.UI.CreateIconButton = CreateIconButton
