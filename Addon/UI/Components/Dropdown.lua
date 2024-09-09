---@class AddonEnv
local Env = select(2, ...)

local ddinfo = { text = "text not set" } ---@type MSA_InfoTable

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
local function SetSelected(self, value, displayText)
    if not displayText then
        displayText = tostring(value)
        for _, v in ipairs(self._entries) do
            if v.value == value then
                displayText = v.displayText
            end
        end
    end
    self._Select(nil, value, displayText)
end

---Create a dropdown using the MSA_Dropdown lib.
---@param parent WoWFrame
---@param updateFunc fun(entries:{displayText:string, value:any}[])|nil Will be called when dropdown is opened. Fill entries table with entries to show. Can be nil if entries are static, see dropdown:SetEntries()
---@param onSelectionChange fun(value:any)? Will be called if selection changes.
local function CreateMSADropdown(name, parent, updateFunc, onSelectionChange)
    ---@class DmsDropdown : UIDropDownMenu
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    local dropdownMenu = MSA_DropDownMenu_Create(name, UIParent)

    dropdown._updateFunc = updateFunc
    dropdown._entries = {} ---@type {displayText:string, value:any}[]
    dropdown.selectedValue = nil ---@type any

    ---@param value any
    ---@param display string
    dropdown._Select = function(btn, value, display)
        local changed = dropdown.selectedValue ~= value
        if changed then
            dropdown.selectedValue = value
            dropdown.Text:SetText(display)
            if onSelectionChange then onSelectionChange(value) end
        end
    end

    dropdown.SetEntries = SetEntries
    dropdown.SetSelected = SetSelected

    MSA_DropDownMenu_Initialize(dropdownMenu, function() FillContextMenu(dropdown) end, "")

    dropdown.Button:SetScript("OnClick", function()
        MSA_DropDownMenu_SetAnchor(dropdownMenu, 0, 0, "TOPRIGHT", dropdown.Button, "BOTTOMRIGHT")
        MSA_ToggleDropDownMenu(1, nil, dropdownMenu)
    end)

    return dropdown
end

Env.UI = Env.UI or {}
Env.UI.CreateMSADropdown = CreateMSADropdown
