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

---Show or hide status texture overlay.
---@param self IconButon
---@param status "checked"|"roll"|"trash"|nil
local function ShowStatus(self, status)
    if not status then
        self.OverlayTexStatus:Hide()
        return
    end
    local tex = ""
    if status == "checked" then
        tex = GetImagePath("check_shadow.png")
    elseif status == "roll" then
        tex = GetImagePath("icon_die_trans80.png")
    elseif status == "trash" then
        tex = GetImagePath("bars.png")
    end
    self.OverlayTexStatus:SetTexture(tex)
    self.OverlayTexStatus:Show()
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
    ---@class IconButon : WoWFrameButton
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
    iicon.SetDesaturated = SetDesaturated
    iicon.SetOnClick = SetOnClick
    iicon.SetItemData = SetItemData
    iicon.GetArg = GetArg
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
    iicon.OverlayTexStatus = iicon:CreateTexture(nil, "OVERLAY")
    iicon.OverlayTexStatus:SetPoint("TOPLEFT", checkMarkOverlayInset, -checkMarkOverlayInset)
    iicon.OverlayTexStatus:SetPoint("BOTTOMRIGHT", -checkMarkOverlayInset, checkMarkOverlayInset)
    iicon.OverlayTexStatus:Hide()
    iicon.ShowStatus = ShowStatus ---@diagnostic disable-line: inject-field

    local borderOverlayInset = 1
    iicon.OverLayTexture = iicon:CreateTexture(nil, "OVERLAY")
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
