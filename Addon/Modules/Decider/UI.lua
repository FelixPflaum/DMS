---@class AddonEnv
local Env = select(2, ...)

---@class SliceFrame
---@field frame WoWFrame
---@field tex Texture
---@field mask Texture
---@field name FontString
---@field sliceCount integer
---@field slicePos integer
---@field sliceSize number
local SliceFrame = {}
---@diagnostic disable-next-line: inject-field
SliceFrame.__index = SliceFrame

---comment
---@param parent WoWFrame
---@return SliceFrame
function SliceFrame:New(parent)
    local frame = CreateFrame("Frame", nil, parent)

    ---@type SliceFrame
    ---@diagnostic disable-next-line: missing-fields
    local sf = {
        frame = frame,
        tex = frame:CreateTexture(),
        mask = frame:CreateMaskTexture(),
        name = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText"),
        sliceCount = 0,
        slicePos = 0,
        sliceSize = 0,
    }
    setmetatable(sf, self)

    sf.frame:SetAllPoints(parent)
    sf.tex:SetTexture(Env.UI.GetImagePath("halfcircle.png"))
    sf.tex:SetAllPoints(sf.frame)
    sf.mask:SetAllPoints(sf.tex)
    sf.mask:SetTexture(Env.UI.GetImagePath("halfcircle.png"))
    sf.tex:AddMaskTexture(sf.mask)

    sf:SetData(2, 1, { 1, 1, 1 }, "---")

    return sf
end

---comment
---@param rotation number
function SliceFrame:SetRotation(rotation)
    local DIST_FROM_EDGE = 15

    local totalRotation = self.sliceSize * (self.slicePos - 1) + rotation
    local texRotation = totalRotation + self.sliceSize / 2
    self.tex:SetRotation(texRotation)
    self.mask:SetRotation(math.pi - self.sliceSize + texRotation)
    self.name:SetRotation(totalRotation)
    -- FontString rotation sucks, need to manually translate it because
    -- rotation anchor is always topleft of string, regardless of set anchor point(s).
    local cosVal = math.cos(totalRotation)
    local sinVal = math.sin(totalRotation)
    local x = -self.name:GetHeight() / 2 * sinVal
    local y = self.name:GetHeight() / 2 * (cosVal - 1)
    local r = self.frame:GetWidth() / 2
    -- Move to edge on x axis
    x = x + cosVal * (r - self.name:GetWidth() - DIST_FROM_EDGE)
    -- Move to edge on y axis
    y = y + sinVal * (r - self.name:GetWidth() - DIST_FROM_EDGE)
    self.name:ClearAllPoints()
    self.name:SetPoint("LEFT", self.frame, "CENTER", x, y)
end

---comment
---@param sliceCount integer
---@param slicePos integer
---@param color [number, number, number]
---@param text string
function SliceFrame:SetData(sliceCount, slicePos, color, text)
    self.sliceCount = sliceCount
    self.slicePos = slicePos
    self.sliceSize = 2 * math.pi / sliceCount
    self.tex:SetVertexColor(color[1], color[2], color[3], 1)
    self.name:SetText(text)
    self:SetRotation(0)
end

---@class GambaWheel
---@field frame WoWFrame
---@field slicesActive SliceFrame[]
---@field slicesInactive SliceFrame[]
local GambaWheel = {}
GambaWheel.__index = GambaWheel ---@diagnostic disable-line: inject-field

function GambaWheel:New()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetSize(300, 300)
    frame:Hide()

    ---@type GambaWheel
    ---@diagnostic disable-next-line: missing-fields
    local gw = {
        frame = frame,
        slicesActive = {},
        slicesInactive = {},
    }
    setmetatable(gw, self)

    return gw
end

---comment
---@param gw GambaWheel
---@return SliceFrame
local function GW_GetSliceFrame(gw)
    local slice ---@type SliceFrame
    if #gw.slicesInactive > 0 then
        print("Reusing inactive slice frame")
        slice = table.remove(gw.slicesInactive, #gw.slicesInactive)
    else
        print("Creating new slice frame")
        slice = SliceFrame:New(gw.frame)
    end
    table.insert(gw.slicesActive, slice)
    slice.frame:Show()
    return slice
end

---comment
---@param gw GambaWheel
---@param maxCount integer
local function GW_StoreUnused(gw, maxCount)
    local activeCount = #gw.slicesActive
    for i = activeCount, maxCount + 1, -1 do
        print("store slice for later use", i)
        local slice = table.remove(gw.slicesActive, i)
        slice.frame:Hide()
        table.insert(gw.slicesInactive, slice)
    end
end

---comment
---@param data {color:[number, number, number], text:string}[]
function GambaWheel:SetData(data)
    local count = #data;
    for k, v in ipairs(data) do
        local slice = self.slicesActive[k] or GW_GetSliceFrame(self)
        slice:SetData(count, k, v.color, v.text)
    end
    GW_StoreUnused(self, count)
end

---comment
---@param targetPos number
---@param duration number
function GambaWheel:Spin(targetPos, duration)
    assert(targetPos and targetPos <= #self.slicesActive, "Target position can't be above active slices!")
    local targetRotationOffset = (targetPos - 1) / #self.slicesActive * math.pi * 2
    local animationStart = GetTime()
    local initSpeed = math.pi * 2 * 4
    local endPos = duration * initSpeed / 2 + targetRotationOffset
    local accel = ((endPos - initSpeed * duration) * 2) / math.pow(duration, 2)
    local gw = self
    local animateFunc = function()
        local t = (GetTime() - animationStart)
        local rota = initSpeed * t + 0.5 * accel * math.pow(t, 2)
        if t >= duration then
            rota = endPos
            gw.frame:SetScript("OnUpdate", nil)
        end
        for _, slice in ipairs(self.slicesActive) do
            slice:SetRotation(rota)
        end
    end
    self.frame:SetScript("OnUpdate", animateFunc)
end

Env.DeciderUI = {}

local gw = GambaWheel:New()

function Env.DeciderUI:Show()
    gw.frame:Show()
end

function Env.DeciderUI:Hide()
    gw.frame:Hide()
end

---@param data {color:[number, number, number], text:string}[]
function Env.DeciderUI:SetData(data)
    gw:SetData(data)
end

---@param targetPos number
---@param duration number
function Env.DeciderUI:Spin(targetPos, duration)
    gw:Spin(targetPos, duration)
end
