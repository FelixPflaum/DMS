---@diagnostic disable: missing-return
---------------------------------------------------------------------------------------------------------------------------------------
--- A noncomprehensive list of typings for lib-ScrollingTable https://www.wowace.com/projects/lib-st
---------------------------------------------------------------------------------------------------------------------------------------

---@class CallFrame : WoWFrameButton
---@field text FontString

---@alias ST_CellUpdateFunc fun(rowFrame:WoWFrame, cellFrame:CallFrame, data:ST_DataMinimal[]|ST_Data[], cols:ST_ColDef[], row:integer, realrow:integer, column:integer, fShow:boolean, table:ST_ScrollingTable, ...):boolean|nil
---@alias ST_EventFunc fun(rowFrame:WoWFrame, cellFrame:CallFrame, data:ST_DataMinimal[]|ST_Data[], cols:ST_ColDef[], row:integer, realrow:integer, column:integer, table:ST_ScrollingTable, button:"LeftButton"|"RightButton", ...):boolean|nil

---@class ST_ColDef
---@field name string The name to use as the column header.
---@field width number The width in pixels that the column should be drawn.
---@field align "LEFT"|"RIGHT"|"CENTER"|nil (Optional) Alignment of values in the column. Must be one of ( "LEFT" | "RIGHT" | "CENTER" ) Defaults to "LEFT".
---@field color number[]|nil (Optional) RGBA color object. Defaults to white.
---@field colorargs any[]|nil (Opional) An array of args that will be passed to the function specified for color. See color object. Defaults to (data, cols, realrow, column, table)
---@field bgcolor number[]|nil (Optional) A color object. Defaults to clear. In other areas of lib-st, you will find that you can assign a function to return a color object instead. That is not the case with the bgcolor of a column.
---@field defaultsort? "asc"|"dsc"|1|2  One of ( "asc" | "dsc" or SORT_ASC|SORT_DSC which is 1|2). Defaults to "asc"
---@field sort? 1|2 This is SORT_ASC|SORT_DSC
---@field sortnext integer|nil (Optional) Must be a valid column number (lua indecies start at 1). Be careful with this value, you can chain across multiple columns, and get yourself into a circular loop.
---@field comparesort fun(self:ST_ScrollingTable, cella, cellb, column)|nil (Optional) A comparator function used to sort values that may not be easily sorted. ex. Dates... and stuff... Be sure to check for and call the comparator of the sortnext column if you wish to keep secondary column sort functionality. See the CompareSort method in Core.lua for an example.
---@field DoCellUpdate ST_CellUpdateFunc|nil A custom display function.

---@class LibScrollingTable
---@field SORT_ASC 1
---@field SORT_DSC 2
local LibST = {}

---@param cols ST_ColDef[]|nil This arg is expected to be an array of tables that contain information about each column.
---@param numRows integer|nil This arg defines how many rows you wish the table to show. If nil, it will default to 12.
---@param rowHeight number|nil This arg defines how tall each row will be. If nil, it will default to 15.
---@param highlight number[]|nil This arg defines the color object for the row highlight to use as you mouse-over a row. If nil, it will default to mostly-yellow:
---@param parent WoWFrame|nil This arg defines the frame that is to be used as the parent frame for the new scrolling table. If nil, it will default to UIParent
---@param multiselection any
---@return ST_ScrollingTable
---@diagnostic disable-next-line: missing-return
function LibST:CreateST(cols, numRows, rowHeight, highlight, parent, multiselection) end

---@class ST_ScrollingTable
---@field frame WoWFrame
---@field head WoWFrame
---@field cols ST_ColDef[]
---@field data ST_DataMinimal[]|ST_Data[]
---@field CompareSort fun(self:ST_ScrollingTable,rowa:integer,rowb:integer,col:integer)
---@field filtered table<integer,integer> Maps visible row index to real/data row index.
local ST_ScrollingTable = {}

---@class ST_DataColCell
---@field value any Just like color objects, '''value''' can be a function or a value to display. If the type of '''value''' is a function, it is evaluated for display using the args table of arguments.
---@field args any[]|nil (Optional) An array of args that will be passed to the '''function''' specified for '''value'''. Defaults to (data, cols, realrow, column, table)
---@field color number[]|nil (Optional) A color object. Defaults to '''white'''.
---@field colorargs any[]|nil (Opional) An array of args that will be passed to the '''function''' specified for '''color'''. See color object. Defaults to (data, cols, realrow, column, table)
---@field DoCellUpdate ST_CellUpdateFunc|nil A custom display function.

---@class ST_Data
---@field cols ST_DataColCell[]
---@field color number[] (Optional) A RGBA color object. Defaults to '''white'''.
---@field colorargs any[]|nil (Opional) An array of args that will be passed to the '''function''' specified for '''color'''. See color object. Defaults to (data, cols, realrow, column, table)
---@field DoCellUpdate ST_CellUpdateFunc|nil A custom display function.

---@alias ST_DataMinimal any[] Each cell value in an array.

---@overload fun(self:ST_ScrollingTable, rowData:ST_Data[], isMinimal:false|nil)
---@overload fun(self:ST_ScrollingTable, rowData:ST_DataMinimal[], isMinimal:true)
function ST_ScrollingTable:SetData(rowData, isMinimal) end

function ST_ScrollingTable:Refresh() end

---@param events table<string, ST_CellUpdateFunc>
---@param removeOld boolean|nil
function ST_ScrollingTable:RegisterEvents(events, removeOld) end

---Sets the currently selected row to 'realrow'.
---@param realrow integer Realrow is the unaltered index of the data row in your table. You should not need to refresh the table.
function ST_ScrollingTable:SetSelection(realrow) end

---@return integer realrow The unaltered index of the data row in your table. You should not need to refresh the table.
function ST_ScrollingTable:GetSelection() end

function ST_ScrollingTable:ClearSelection() end

---Enable or disbale selection of rows.
---@param enable boolean
function ST_ScrollingTable:EnableSelection(enable) end

---Enable or disbale selection of rows.
---@param Filter fun(self:ST_ScrollingTable, rowData:ST_DataMinimal|ST_Data):boolean Should return true if row should be filtered out.
function ST_ScrollingTable:SetFilter(Filter) end

function ST_ScrollingTable:SortData() end
