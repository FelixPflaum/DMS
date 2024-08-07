---@class ST_ScrollingTable
---@field frame WoWFrame
---@field head WoWFrame
local ST_ScrollingTable = {}

---@alias ST_CellUpdateFunc fun(rowFrame:WoWFrame, cellFrame:WoWFrameButton, data:ST_DataMinimal[]|ST_Data[], cols:ST_ColDef[], row:integer, realrow:integer, column:integer, fShow:boolean, table, ...):boolean|nil

---@class ST_ColDef
---@field name string The name to use as the column header.
---@field width number The width in pixels that the column should be drawn.
---@field align "LEFT"|"RIGHT"|"CENTER"|nil (Optional) Alignment of values in the column. Must be one of ( "LEFT" | "RIGHT" | "CENTER" ) Defaults to "LEFT".
---@field color number[]|nil (Optional) RGBA color object. Defaults to white.
---@field colorargs any[]|nil (Opional) An array of args that will be passed to the function specified for color. See color object. Defaults to (data, cols, realrow, column, table)
---@field bgcolor number[]|nil (Optional) A color object. Defaults to clear. In other areas of lib-st, you will find that you can assign a function to return a color object instead. That is not the case with the bgcolor of a column.
---@field defaultsort "asc"|"dsc"|nil (Optional) One of ( "asc" | "dsc" ). Defaults to "asc"
---@field sortnext integer|nil (Optional) Must be a valid column number (lua indecies start at 1). Be careful with this value, you can chain across multiple columns, and get yourself into a circular loop.
---@field comparesort fun(cella, cellb, column)|nil (Optional) A comparator function used to sort values that may not be easily sorted. ex. Dates... and stuff... Be sure to check for and call the comparator of the sortnext column if you wish to keep secondary column sort functionality. See the CompareSort method in Core.lua for an example.
---@field DoCellUpdate ST_CellUpdateFunc|nil A custom display function.

---@class LibScrollingTable
local LibST = {}

---@param cols ST_ColDef[]|nil This arg is expected to be an array of tables that contain information about each column.
---@param numRows integer|nil This arg defines how many rows you wish the table to show. If nil, it will default to 12.
---@param rowHeight number|nil This arg defines how tall each row will be. If nil, it will default to 15.
---@param highlight number[]|nil This arg defines the color object for the row highlight to use as you mouse-over a row. If nil, it will default to mostly-yellow:
---@param parent WoWFrame|nil This arg defines the frame that is to be used as the parent frame for the new scrolling table. If nil, it will default to UIParent
---@param multiselection any
---@return ST_ScrollingTable
function LibST:CreateST(cols, numRows, rowHeight, highlight, parent, multiselection) end

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

---@param events table<string, ST_CellUpdateFunc>
---@param removeOld boolean|nil
function ST_ScrollingTable:RegisterEvents(events, removeOld) end

