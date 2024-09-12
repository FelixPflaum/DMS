---@class AddonEnv
local Env = select(2, ...)

local ddinfo = { text = "text not set" } ---@type MSA_InfoTable
local currentDropdownFrame = nil ---@type DmsDropdown?
local dropdownMenu = MSA_DropDownMenu_Create("DMSGenericDropdown", UIParent)

---@param self DmsDropdown
local function FillContextMenu(self)
    if self._updateFunc then
        self._updateFunc(self._entries)
    end
    for _, v in ipairs(self._entries) do
        wipe(ddinfo)
        ddinfo.text = v.displayText
        ddinfo.isNotRadio = true
        ddinfo.checked = v.value == self.selectedValue
        ddinfo.func = self._Select
        ddinfo.arg1 = v.value
        ddinfo.arg2 = v.displayText
        MSA_DropDownMenu_AddButton(ddinfo, 1)
    end
end

MSA_DropDownMenu_Initialize(dropdownMenu, function()
    if currentDropdownFrame then
        FillContextMenu(currentDropdownFrame)
    end
end, "")

---Manually set selected value.
---@param self DmsDropdown
---@param newEntries {displayText:string, value:any}[]
local function SetEntries(self, newEntries)
    self._entries = newEntries
    self._Select(nil, self._entries[1].value, self._entries[1].displayText)
end

---Manually set selected value.
---@param self DmsDropdown
---@param value any
---@param displayText string? Optionally provide display text. If nil will pick from last updated entries, if possible.
---@param noEmit boolean? If true will not call change callback.
local function SetSelected(self, value, displayText, noEmit)
    if not displayText then
        displayText = tostring(value)
        for _, v in ipairs(self._entries) do
            if v.value == value then
                displayText = v.displayText
            end
        end
    end
    self._Select(nil, value, displayText, noEmit)
end

---@param parent WoWFrame
local function CreateDropdownButton(parent)
    local HEIGHT = 20

    ---@class (exact) DmsDropdownButton : WoWFrame
    ---@field Left Texture
    ---@field Right Texture
    ---@field Middle Texture
    ---@field Text FontString
    ---@field Button WoWFrameButton
    local dropdown = CreateFrame("Frame", nil, parent) --, "UIDropDownMenuTemplate")
    dropdown:SetSize(100, HEIGHT)

    local SHADOW_PADDING = 20                                -- To include more of the texture than the actual border
    local uiScaleShadowOffset = (256 / 768) * SHADOW_PADDING -- texture px to UI px scaling

    dropdown.Left = dropdown:CreateTexture(nil, "ARTWORK")
    dropdown.Left:SetTexture([[Interface\Glues\CharacterCreate\CharacterCreate-LabelFrame]])
    dropdown.Left:SetTexCoord((74 - SHADOW_PADDING) / 512, 148 / 512, (78 - SHADOW_PADDING) / 256, (167 + SHADOW_PADDING) / 256)
    dropdown.Left:SetSize(HEIGHT + uiScaleShadowOffset, HEIGHT + uiScaleShadowOffset * 2)
    dropdown.Left:SetPoint("LEFT", -uiScaleShadowOffset, 0)

    dropdown.Right = dropdown:CreateTexture(nil, "ARTWORK")
    dropdown.Right:SetTexture([[Interface\Glues\CharacterCreate\CharacterCreate-LabelFrame]])
    dropdown.Right:SetTexCoord(374 / 512, (443 + SHADOW_PADDING) / 512, (78 - SHADOW_PADDING) / 256, (167 + SHADOW_PADDING) / 256)
    dropdown.Right:SetSize(HEIGHT + uiScaleShadowOffset, HEIGHT + uiScaleShadowOffset * 2)
    dropdown.Right:SetPoint("RIGHT", uiScaleShadowOffset, 0)

    dropdown.Middle = dropdown:CreateTexture(nil, "ARTWORK")
    dropdown.Middle:SetTexture([[Interface\Glues\CharacterCreate\CharacterCreate-LabelFrame]])
    dropdown.Middle:SetTexCoord(149 / 512, 373 / 512, (78 - SHADOW_PADDING) / 256, (167 + SHADOW_PADDING) / 256)
    dropdown.Middle:SetPoint("TOPLEFT", dropdown.Left, "TOPRIGHT", 0, 0)
    dropdown.Middle:SetPoint("BOTTOMRIGHT", dropdown.Right, "BOTTOMLEFT", 0, 0)

    dropdown.Text = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dropdown.Text:SetPoint("LEFT", 10, 0)

    dropdown.Button = CreateFrame("Button", nil, dropdown, nil)
    dropdown.Button:SetSize(HEIGHT, HEIGHT)
    dropdown.Button:SetPoint("RIGHT", dropdown, "RIGHT", -1, 0)
    dropdown.Button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
    dropdown.Button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
    dropdown.Button:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])

    dropdown:SetScript("OnEnter", function(frame, ...)
        dropdown.Button:SetHighlightLocked(true)
    end)
    dropdown:SetScript("OnLeave", function(frame, ...)
        dropdown.Button:SetHighlightLocked(false)
    end)

    local onButtonClicked = nil ---@type fun()|nil
    local function OnClicked()
        if onButtonClicked then
            onButtonClicked()
        end
    end
    dropdown:SetScript("OnMouseDown", OnClicked)
    dropdown.Button:SetScript("OnClick", OnClicked)

    function dropdown:SetOnClick(cb)
        onButtonClicked = cb
    end

    return dropdown
end

---Create a dropdown using the MSA_Dropdown lib.
---@param parent WoWFrame
---@param updateFunc fun(entries:{displayText:string, value:any}[])|nil Will be called when dropdown is opened. Fill entries table with entries to show. Can be nil if entries are static, see dropdown:SetEntries()
---@param onSelectionChange fun(value:any)? Will be called if selection changes.
local function CreateMSADropdown(parent, updateFunc, onSelectionChange)
    ---@class DmsDropdown : DmsDropdownButton
    ---@field _entries {displayText:string, value:any}[]
    ---@field selectedValue any
    local dropdown = CreateDropdownButton(parent)

    dropdown:SetOnClick(function()
        if currentDropdownFrame ~= dropdown then
            MSA_CloseDropDownMenus()
        end
        currentDropdownFrame = dropdown
        MSA_DropDownMenu_SetAnchor(dropdownMenu, 0, 0, "TOPRIGHT", dropdown.Button, "BOTTOMRIGHT")
        MSA_ToggleDropDownMenu(1, nil, dropdownMenu)
    end)

    dropdown._updateFunc = updateFunc
    dropdown._entries = {}

    ---@param value any
    ---@param display string
    ---@param noEmit boolean?
    dropdown._Select = function(btn, value, display, noEmit)
        local changed = dropdown.selectedValue ~= value
        if changed then
            dropdown.selectedValue = value
            dropdown.Text:SetText(display)
            if onSelectionChange and not noEmit then onSelectionChange(value) end
        end
    end

    dropdown.SetEntries = SetEntries
    dropdown.SetSelected = SetSelected

    return dropdown
end

Env.UI = Env.UI or {}
Env.UI.CreateMSADropdown = CreateMSADropdown
