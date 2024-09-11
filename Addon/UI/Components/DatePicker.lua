---@class AddonEnv
local Env = select(2, ...)

---Set selected y-m-d date.
---@param self DmsDatePicker
---@param year integer
---@param month integer
---@param day integer
---@param noEmitChange boolean? Do not emit a changed event.
local function SetSelectedDate(self, year, month, day, noEmitChange)
    self.dropdownYear:SetSelected(year, nil, noEmitChange)
    self.dropdownMonth:SetSelected(month, nil, noEmitChange)
    self.dropdownDay:SetSelected(day, nil, noEmitChange)
    if noEmitChange then
        self.selectedDate.year = year
        self.selectedDate.month = month
        self.selectedDate.day = day
    end
end

---Get currently selected date.
---@param self DmsDatePicker
---@return integer year
---@return integer month
---@return integer day
local function GetSelectedDate(self)
    return self.dropdownYear.selectedValue, self.dropdownMonth.selectedValue, self.dropdownDay.selectedValue
end

---Set on change callback.
---@param self DmsDatePicker
---@param callback fun(picker:DmsDatePicker, year:integer, month:integer, day:integer)|nil
local function SetOnChange(self, callback)
    self.OnChange = callback
end

---@param parent WoWFrame
local function CreateDatePicker(parent)
    local MARGIN = 7
    ---@class (exact) DmsDatePicker
    ---@field frame WoWFrame
    ---@field selectedDate {year:integer, month:integer, day:integer}
    ---@field OnChange fun(picker:DmsDatePicker, year:integer, month:integer, day:integer)|nil
    ---@field dropdownYear DmsDropdown
    ---@field dropdownMonth DmsDropdown
    ---@field dropdownDay DmsDropdown
    local picker = {
        frame = CreateFrame("Frame", nil, parent)
    }

    picker.selectedDate = {
        year = 0,
        month = 0,
        day = 0,
    }

    picker.dropdownYear = Env.UI.CreateMSADropdown(parent, nil, function(value)
        picker.selectedDate.year = value
        if picker.OnChange then
            picker.OnChange(picker, picker.selectedDate.year, picker.selectedDate.month, picker.selectedDate.day)
        end
    end)
    picker.dropdownYear:SetPoint("TOPLEFT", picker.frame, "TOPLEFT", 0, 0)
    picker.dropdownYear:SetWidth(63)
    picker.dropdownYear:SetEntries((function()
        local entries = {} ---@type { displayText: string, value: any }[]
        local thisyear = tonumber(date("%Y", time()))
        for i = thisyear, thisyear - 3, -1 do
            table.insert(entries, { displayText = tostring(i), value = i })
        end
        return entries
    end)())

    picker.dropdownMonth = Env.UI.CreateMSADropdown(parent, nil, function(value)
        picker.selectedDate.month = value
        if picker.OnChange then
            picker.OnChange(picker, picker.selectedDate.year, picker.selectedDate.month, picker.selectedDate.day)
        end
    end)
    picker.dropdownMonth:SetPoint("LEFT", picker.dropdownYear, "RIGHT", MARGIN, 0)
    picker.dropdownMonth:SetWidth(48)
    picker.dropdownMonth:SetEntries((function()
        local entries = {} ---@type { displayText: string, value: any }[]
        for i = 1, 12 do
            table.insert(entries, { displayText = tostring(i), value = i })
        end
        return entries
    end)())

    picker.dropdownDay = Env.UI.CreateMSADropdown(parent, nil, function(value)
        picker.selectedDate.day = value
        if picker.OnChange then
            picker.OnChange(picker, picker.selectedDate.year, picker.selectedDate.month, picker.selectedDate.day)
        end
    end)
    picker.dropdownDay:SetPoint("LEFT", picker.dropdownMonth, "RIGHT", MARGIN, 0)
    picker.dropdownDay:SetWidth(48)
    picker.dropdownDay:SetEntries((function()
        local entries = {} ---@type { displayText: string, value: any }[]
        for i = 1, 31 do -- TODO: get max when selecting month
            table.insert(entries, { displayText = tostring(i), value = i })
        end
        return entries
    end)())

    picker.SetSelectedDate = SetSelectedDate ---@diagnostic disable-line: inject-field
    picker.GetSelectedDate = GetSelectedDate ---@diagnostic disable-line: inject-field
    picker.SetOnChange = SetOnChange ---@diagnostic disable-line: inject-field

    picker.frame:SetWidth(picker.dropdownYear:GetWidth() + picker.dropdownMonth:GetWidth() + picker.dropdownDay:GetWidth() + 2 * MARGIN)
    picker.frame:SetHeight(picker.dropdownYear:GetHeight())
    return picker
end

Env.UI = Env.UI or {}
Env.UI.CreateDatePicker = CreateDatePicker
