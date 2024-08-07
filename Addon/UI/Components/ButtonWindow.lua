---@class AddonEnv
local Env = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")

---@class DefaultPanelTemplate : WoWFrame
---@field NineSlice any
---@field Bg Texture

---@param self ButtonWindow
local function SetContent(self)

end

---@param self ButtonWindow
---@param text string
---@param onClick fun(button:ButtonWindowLeftButton)
local function AddLeftButton(self, text, onClick)
    if not self.LeftButton then
        ---@class ButtonWindowLeftButton : WoWFrameButton
        local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("BOTTOMLEFT", 7, 6)
        button.RightSeparator = button:CreateTexture(nil, "BORDER");
        button.RightSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
        button.RightSeparator:SetTexCoord(0.90625000, 0.99218750, 0.00781250, 0.20312500);
        button.RightSeparator:SetWidth(11);
        button.RightSeparator:SetHeight(25);
        button.RightSeparator:SetPoint("TOPLEFT", button, "TOPRIGHT", -6, 1);
        self.LeftButton = button
    end

    self.LeftButton:SetText(text)
    self.LeftButton:SetScript("OnClick", onClick)
end

---@param self ButtonWindow
---@param text string
---@param onClick fun(button:ButtonWindowLeftButton)
local function AddRightButton(self, text, onClick)
    if not self.RightButton then
        ---@class ButtonWindowRightButton : WoWFrameButton
        local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("BOTTOMRIGHT", -3, 6)
        button.LeftSeparator = button:CreateTexture(nil, "BORDER");
        button.LeftSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
        button.LeftSeparator:SetTexCoord(0.24218750, 0.32812500, 0.63281250, 0.82812500);
        button.LeftSeparator:SetWidth(11);
        button.LeftSeparator:SetHeight(25);
        button.LeftSeparator:SetPoint("TOPRIGHT", button, "TOPLEFT", 6, 1);
        self.RightButton = button
    end

    self.RightButton:SetText(text)
    self.RightButton:SetScript("OnClick", onClick)
end

---It works, ok?
---@param name string
---@param title string
---@param width integer
---@param height integer
---@param topInsetOffset integer
---@param hasButtonBar boolean
---@param libWinConfig table
---@return ButtonWindow
local function CreateButtonWindow(name, title, width, height, topInsetOffset, hasButtonBar, libWinConfig)
    ---@class ButtonWindow : DefaultPanelTemplate
    ---@field SetTitle fun(self:ButtonWindow, title:string)
    ---@field onTopCloseClicked fun()|nil
    ---@field LeftButton ButtonWindowLeftButton|nil
    ---@field RightButton ButtonWindowRightButton|nil
    local frame = CreateFrame("Frame", name, UIParent, "DefaultPanelTemplate")
    frame:Hide()

    -- Fix those stupid borders.
    frame.NineSlice.RightEdge:SetPoint("TOPRIGHT", frame.NineSlice.TopRightCorner, "BOTTOMRIGHT", 1, 0)
    frame.Bg:SetPoint("TOPLEFT", 7, -21)
    frame.Bg:SetPoint("BOTTOMRIGHT", -3, 8)

    -- Content inset area.
    topInsetOffset = topInsetOffset + 23 or 60
    local bottomInsetOffset = hasButtonBar and 26 or 6
    frame.Inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    frame.Inset:SetPoint("TOPLEFT", 7, -topInsetOffset)
    frame.Inset:SetPoint("BOTTOMRIGHT", -4, bottomInsetOffset)

    -- Add that close button in the top right.
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
    frame.CloseButton:SetScript("OnClick", function()
        if frame.onTopCloseClicked then
            return frame.onTopCloseClicked()
        end
        frame:Hide()
    end)

    -- Set default values.
    frame:SetTitle(title)
    frame:SetFrameLevel(2)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    -- LibWindow scroll rescaling.
    LibWindow:Embed(frame)
    frame:RegisterConfig(libWinConfig) ---@diagnostic disable-line: undefined-field
    frame:SetScale(libWinConfig.scale or 1.0)
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    frame:MakeDraggable() ---@diagnostic disable-line: undefined-field
    frame:SetScript("OnMouseWheel", function(f, d) if IsControlKeyDown() then LibWindow.OnMouseWheel(f, d) end end)

    -- Custom functions
    frame.SetContent = SetContent
    frame.AddLeftButton = AddLeftButton
    frame.AddRightButton = AddRightButton

    return frame
end

Env.UI = Env.UI or {}
Env.UI.CreateButtonWindow = CreateButtonWindow
