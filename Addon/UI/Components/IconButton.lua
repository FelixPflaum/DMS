---@class AddonEnv
local Env = select(2, ...)

---Set color of border texture.
---@param self IconButon
---@param color [number, number, number]|"grey"|"white" RGB or predifined color.
local function SetBorderColor(self, color)
    if type(color) == "table" then
        self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    elseif color == "grey" then
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    elseif color == "white" then
        self:SetBackdropBorderColor(1, 1, 1, 1)
    end
end

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
    if not itemId then
        self:SetNormalTexture([[Interface\InventoryItems\WoWUnknownItem01]])
    else
        local _, _, _, _, icon, _, _ = C_Item.GetItemInfoInstant(itemId) -- TODO
        self:SetNormalTexture(icon)
    end
    self.itemId = itemId
    self.clickCallbackArg = arg
end

-- varargs: texture
local function CreateIconButton(parent)
    ---@class (exact) IconButon : WoWFrameButton
    ---@field onClickCallback fun(arg:any)|nil
    ---@field itemId integer|nil
    ---@field clickCallbackArg any
    local iicon = CreateFrame("Button", nil, parent, "BackdropTemplate")
    iicon:SetSize(40, 40)
    iicon:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
    iicon:GetHighlightTexture():SetBlendMode("ADD")
    iicon:SetNormalTexture([[Interface\InventoryItems\WoWUnknownItem01]])
    iicon:GetNormalTexture():SetDrawLayer("BACKGROUND")
    iicon:GetNormalTexture():SetVertexColor(1, 1, 1)
    iicon:SetBackdrop({ bgFile = "", edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 18 })
    iicon:EnableMouse(true)
    iicon:RegisterForClicks("AnyUp")
    iicon.SetBorderColor = SetBorderColor ---@diagnostic disable-line: inject-field
    iicon.Desaturate = SetDesaturated ---@diagnostic disable-line: inject-field
    iicon.SetOnClick = SetOnClick ---@diagnostic disable-line: inject-field
    iicon.SetItemData = SetItemData ---@diagnostic disable-line: inject-field
    iicon:SetScript("OnClick", function()
        if iicon.onClickCallback then
            iicon.onClickCallback(iicon.clickCallbackArg)
        end
    end)
    iicon:SetScript("OnEnter", function(frame)
        if iicon.itemId == nil then return end
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetHyperlink("item:" .. iicon.itemId)
    end)
    iicon:SetScript("OnLeave", function() GameTooltip_Hide() end)
    return iicon
end

Env.UI = Env.UI or {}
Env.UI.CreateIconButton = CreateIconButton
