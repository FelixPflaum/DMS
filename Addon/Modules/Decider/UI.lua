---@class AddonEnv
local Env = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")

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

local sliceFont = CreateFont("DmsSliceFont")
sliceFont:CopyFontObject(GameTooltipText) ---@diagnostic disable-line: undefined-global, no-unknown
sliceFont:SetJustifyH("LEFT")
sliceFont:SetTextColor(1, 1, 1)
sliceFont:SetShadowColor(0, 0, 0, 1)
sliceFont:SetShadowOffset(1, 1)

---Create a new slice frame.
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
        name = frame:CreateFontString(nil, "OVERLAY", "DmsSliceFont"),
        sliceCount = 0,
        slicePos = 0,
        sliceSize = 0,
    }
    setmetatable(sf, self)

    sf.frame:SetAllPoints(parent)
    sf.tex:SetTexture(Env.UI.GetImagePath("gw_halfcircle.png"))
    sf.tex:SetAllPoints(sf.frame)
    sf.mask:SetAllPoints(sf.tex)
    sf.mask:SetTexture(Env.UI.GetImagePath("gw_halfcircle.png"))
    sf.tex:AddMaskTexture(sf.mask)

    sf:SetData(2, 1, { 1, 1, 1 }, "---")

    return sf
end

---Set rotation of this slice.
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

---Set display data for this slice.
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
---@field frames {main:WoWFrame, wheel:WoWFrame, closeBtn:Texture, title:FontString}
---@field slicesActive SliceFrame[]
---@field slicesInactive SliceFrame[]
local GambaWheel = {}
GambaWheel.__index = GambaWheel ---@diagnostic disable-line: inject-field

---Place decorational art.
---@param parent WoWFrame
local function GW_PlaceArt(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)

    local caret = overlay:CreateTexture(nil, "OVERLAY")
    caret:SetTexture(Env.UI.GetImagePath("downmarker.png"))
    caret:SetTexCoord(45 / 64, 61 / 64, 0, 1)
    caret:SetRotation(-math.pi / 2)
    caret:SetPoint("RIGHT", 1, 0)
    caret:SetVertexColor(1, 0, 0, 1)
    caret:SetSize(16, 16)

    local center = overlay:CreateTexture(nil, "OVERLAY")
    center:SetTexture(Env.UI.GetImagePath("gw_center.png"))
    center:SetSize(100, 100)
    center:SetPoint("CENTER", 0, 0)

    local border = parent:CreateTexture(nil, "ARTWORK")
    border:SetTexture(Env.UI.GetImagePath("gw_border.png"))
    border:SetPoint("TOPLEFT", -30, 30)
    border:SetPoint("BOTTOMRIGHT", 30, -30)

    local crown = parent:CreateTexture(nil, "BORDER")
    crown:SetTexture(Env.UI.GetImagePath("gw_crown.png"))
    crown:SetSize(80, 80)
    crown:SetRotation(math.pi * 0.2)
    crown:SetPoint("TOPLEFT", -5, 20)

    local coin = parent:CreateTexture(nil, "BORDER")
    coin:SetTexture(Env.UI.GetImagePath("gw_coin.png"))
    coin:SetSize(50, 50)
    coin:SetRotation(math.pi * 0.15)
    coin:SetPoint("TOPRIGHT", -40, 15)

    local clover = parent:CreateTexture(nil, "BORDER")
    clover:SetTexture(Env.UI.GetImagePath("gw_clover.png"))
    clover:SetSize(64, 64)
    clover:SetTexCoord(1, 0, 0, 1)
    clover:SetPoint("TOPRIGHT", 15, 3)

    local stars = parent:CreateTexture(nil, "BORDER")
    stars:SetTexture(Env.UI.GetImagePath("gw_stars.png"))
    stars:SetSize(100, 100)
    stars:SetRotation(math.pi * 0.75)
    stars:SetPoint("BOTTOMLEFT", -20, -20)

    local stars2 = parent:CreateTexture(nil, "BORDER")
    stars2:SetTexture(Env.UI.GetImagePath("gw_stars.png"))
    stars2:SetSize(100, 100)
    stars2:SetRotation(math.pi * 1.25)
    stars2:SetPoint("BOTTOMRIGHT", 20, -20)
end

---Create new spinny wheel frame.
---@param libWinConfig table
function GambaWheel:New(libWinConfig)
    local WHEEL_SIZE = 300
    local TITLE_SIZE = 30

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetSize(WHEEL_SIZE, WHEEL_SIZE + TITLE_SIZE)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    -- LibWindow scroll rescaling.
    LibWindow:Embed(frame)
    frame:RegisterConfig(libWinConfig) ---@diagnostic disable-line: undefined-field
    frame:SetScale(libWinConfig.scale or 1.0)
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    frame:MakeDraggable() ---@diagnostic disable-line: undefined-field
    frame:SetScript("OnMouseWheel", function(f, d) if IsControlKeyDown() then LibWindow.OnMouseWheel(f, d) end end)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -TITLE_SIZE)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetText("The Decider")
    title:SetPoint("CENTER", 0, 0)

    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetNormalTexture(Env.UI.GetImagePath("bars.png"))
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn:SetSize(16, 16)

    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    local wheelFrame = CreateFrame("Frame", nil, frame)
    wheelFrame:SetPoint("BOTTOM", 0, 0)
    wheelFrame:SetSize(WHEEL_SIZE, WHEEL_SIZE)

    GW_PlaceArt(wheelFrame)

    ---@type GambaWheel
    ---@diagnostic disable-next-line: missing-fields
    local gw = {
        frames = {
            main = frame,
            wheel = wheelFrame,
            title = title,
        },
        slicesActive = {},
        slicesInactive = {},
    }
    setmetatable(gw, self)

    gw:SetData({
        { color = { 0.5, 0.5, 0.5 }, text = "" },
        { color = { 0.5, 0.5, 0.5 }, text = "" },
    })

    return gw
end

---Get or create a slice frame.
---@param gw GambaWheel
---@return SliceFrame
local function GW_GetSliceFrame(gw)
    local slice ---@type SliceFrame
    if #gw.slicesInactive > 0 then
        slice = table.remove(gw.slicesInactive, #gw.slicesInactive)
    else
        slice = SliceFrame:New(gw.frames.wheel)
    end
    table.insert(gw.slicesActive, slice)
    slice.frame:Show()
    return slice
end

---Hide and store any unneeded slice frames for later use.
---@param gw GambaWheel
---@param maxCount integer
local function GW_StoreUnused(gw, maxCount)
    local activeCount = #gw.slicesActive
    for i = activeCount, maxCount + 1, -1 do
        local slice = table.remove(gw.slicesActive, i)
        slice.frame:Hide()
        table.insert(gw.slicesInactive, slice)
    end
end

---Set choice data.
---@param data {color:[number, number, number], text:string}[]
function GambaWheel:SetData(data)
    local count = #data;
    for k, v in ipairs(data) do
        local slice = self.slicesActive[k] or GW_GetSliceFrame(self)
        slice:SetData(count, k, v.color, v.text)
    end
    GW_StoreUnused(self, count)
end

---Visually spin the wheel.
---@param targetPos number
---@param duration number
function GambaWheel:Spin(targetPos, duration)
    assert(targetPos and targetPos <= #self.slicesActive, "Target position can't be above active slices!")
    local targetRotationOffset = (targetPos - 1) / #self.slicesActive * math.pi * 2
    local animationStart = GetTime()
    local initSpeed = math.pi * 2 * 4
    local finalRotation = duration * initSpeed / 2
    -- Align final rotation to be at the target rotation offset.
    finalRotation = finalRotation + (math.pi * 2 - math.fmod(finalRotation, math.pi * 2)) - targetRotationOffset
    -- Calculate (negative) acceleration needed to reach final rotation in duration.
    local accel = ((finalRotation - initSpeed * duration) * 2) / math.pow(duration, 2)

    local musicPlaying, musicHandle = PlaySoundFile(Env.UI.GetMediaPath("quiz_loop.mp3"), "Master")

    local animateFunc = function()
        local t = (GetTime() - animationStart)
        local rota = initSpeed * t + 0.5 * accel * math.pow(t, 2)
        if t >= duration or not self.frames.main:IsShown() then
            rota = finalRotation
            self.frames.wheel:SetScript("OnUpdate", nil)
            if musicPlaying then
                StopSound(musicHandle, 2000)
                PlaySoundFile(Env.UI.GetMediaPath("violin_win.mp3"), "Master")
            end
        end
        for _, slice in ipairs(self.slicesActive) do
            slice:SetRotation(rota)
        end
    end

    C_Timer.After(1.75, function()
        self.frames.wheel:SetScript("OnUpdate", animateFunc)
    end)
end

Env.DeciderUI = {}

local gw = nil ---@type GambaWheel
Env:OnAddonLoaded(function()
    gw = GambaWheel:New(Env.settings.UI.DeciderWindow)
end)

---Show the decider wheel frame.
function Env.DeciderUI:Show()
    gw.frames.main:Show()
end

---Hide the decider wheel frame.
function Env.DeciderUI:Hide()
    gw.frames.main:Hide()
end

---Set frame title.
---@param title string
function Env.DeciderUI:SetTitle(title)
    gw.frames.title:SetText(title)
end

---Set choice data.
---@param data {color:[number, number, number], text:string}[]
function Env.DeciderUI:SetData(data)
    gw:SetData(data)
end

---Spin the wheel.
---@param targetPos number The position it should stop at. Index of a data entry set with SetData().
---@param duration number Spin duration in seconds.
function Env.DeciderUI:Spin(targetPos, duration)
    gw:Spin(targetPos, duration)
end
