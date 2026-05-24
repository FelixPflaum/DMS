---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()
---@type LibScrollingTable
local LibDialog = LibStub("LibDialog-1.1")
-- TODO: Reuse from Database, probably a good idea to put it higher in the hirarchy
local Base64 = Env.Base64

local START_TOKEN = "DMMRT-"
local END_TOKEN = "-DMMRT"
local SEPERATOR = "=END="

local function SplitString(inputStr, seperator)
    local t = {}
    for str in string.gmatch(inputStr, "(.-)(" .. SEPERATOR .. ")") do
        table.insert(t, str)
    end
    return t
end

---@param note string
local function UpdateNote(note)
    local noteArray = _G.VMRT.Note.Black
    local noteNames = _G.VMRT.Note.BlackNames

    local heading = strmatch(note, "|cff%w%w%w%w%w%w(.-)|r")

    for k, v in pairs(noteArray) do
        local headingExisting = strmatch(v, "|cff%w%w%w%w%w%w(" .. heading .. ")|r")
        if heading == headingExisting then
            print("Updating existing note", heading)
            noteArray[k] = note
            return
        end
    end

    table.insert(noteArray, note)
    noteNames[#noteArray] = heading
    print("Added new note", heading)
end

---@param importString string
local function ImportNotes(importString)
    local decoded = Base64.decode(importString)

    --print("decoded")
    --print(decoded)

    if not decoded:find("^" .. START_TOKEN) then
        return L["Note import string has invalid start."]
    end

    if not decoded:find(END_TOKEN .. "$") then
        return L["Note import string has invalid end."]
    end

    local noteStr = decoded:sub(START_TOKEN:len() + 1, decoded:len() - END_TOKEN:len())
    local notes = SplitString(noteStr, SEPERATOR)
    for _, note in ipairs(notes) do
        UpdateNote(note)
    end
end


local lazyValueCache = nil ---@type string|nil
local importDialog = {
    text = "Import MRT Notes",
    show_while_dead = true,
    on_cancel = function(self, data, source) end,
    editboxes = {
        {
            on_enter_pressed = EditBox_ClearFocus,
            on_escape_pressed = EditBox_ClearFocus,
            on_text_changed = function(self, userInput)
                lazyValueCache = self:GetText() ---@type string
            end,
            auto_focus = false,
            label = "Import String",
            width = 200,
        },
    },
    buttons = {
        {
            text = L["Import"],
            on_click = function(self, source)
                if lazyValueCache then
                    local error = ImportNotes(lazyValueCache)
                    if error then
                        Env:PrintError(error)
                    else
                        Env:PrintSuccess(L["Notes Updated"])
                    end
                end
            end
        },
    },
}

Env:RegisterSlashCommand("note", "", function(args)
    if LibDialog:ActiveDialog(importDialog) then
        LibDialog:Dismiss(importDialog)
    end
    LibDialog:Spawn(importDialog)
end)
