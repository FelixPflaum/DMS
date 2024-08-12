---------------------------------------------------------------------------------------------------------------------------------------
--- A noncomprehensive list of typings for MSA-DropDownMenu-1.0 https://legacy.curseforge.com/wow/addons/msa-dropdownmenu-10/pages/documentation
---------------------------------------------------------------------------------------------------------------------------------------

---@diagnostic disable: missing-return

---@class MSA_DropDownMenuFrame : WoWFrame

---Creates a dropdown menu or dropdown boxes base frame.
---@param name string Name of the newly created frame or existing frame handle. If it is nil, no frame name is assigned.
---@param parent any Optional - The frame object that will be used as the created Frame's parent (cannot be a string!). No value use nil for created frame.
---@return MSA_DropDownMenuFrame
function MSA_DropDownMenu_Create(name, parent) end

---Initializes a dropdown menu attached to a specific frame.
---@param frame MSA_DropDownMenuFrame Frame handle the menu will be bound to.
---@param initFunction fun(frame:MSA_DropDownMenuFrame,level:integer,menuList:any) Function called when the menu is opened, responsible for adding menu buttons. Signature: (frame, level, menuList); additional global variables (see below) are used to communicate menu state.
---@param displayMode string "MENU" to use context-menu style, any other value to create a dropdown list box.
---@param level integer? 2nd argument to the initialization function when called for the first time.
---@param menuList any? 3rd argument to the initialization function; used by EasyMenu.
function MSA_DropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList) end

---Add a button to the currently open menu.
---@param info MSA_InfoTable Table describing the button: key/value pairs (listed below).
---@param level integer Number specifying nesting level; can typically reuse the level argument to initFunction.
function MSA_DropDownMenu_AddButton(info, level) end

---Opens or closes a menu; arguments marked as internal are used from within the MSA_DropDownMenu implementation to open sub-menus etc.
---@param level integer Internal - level of the opened menu; nil for external calls.
---@param value any Internal - parent node value for the sub menu; nil for external calls.
---@param dropDownFrame MSA_DropDownMenuFrame Both - dropdown menu frame reference (menu handle).
---@param anchorName WoWFrame? Both - Positioning information (anchor and x,y offsets) for context menus.
---@param ofsX? number
---@param ofsY? number
---@param menuList any Internal - EasyMenu wrapper argument, passed as the third argument to the initialization function.
---@param button any Internal - Dropdown menu "open" button.
function MSA_ToggleDropDownMenu(level, value, dropDownFrame, anchorName, ofsX, ofsY, menuList, button) end

---Sets the anchor of the dropdown menu.
---@param dropDownFrame MSA_DropDownMenuFrame Both - dropdown menu frame reference (menu handle).
---@param xOffset number x-offset (negative values will move obj left, positive values will move obj right), defaults to 0 if not specified.
---@param yOffset number y-offset (negative values will move obj down, positive values will move obj up), defaults to 0 if not specified.
---@param point string String - Point of the object to adjust based on the anchor.
---@param relativeTo any String/Widget - Name or reference to a frame to attach the menu to. If nil, it typically defaults to the object's parent. However, if relativePoint is also not defined, relativeFrame will default to UIParent.
---@param relativePoint any String - point of the relativeFrame to attach point of obj to. If not specified, defaults to the value of point.
function MSA_DropDownMenu_SetAnchor(dropDownFrame, xOffset, yOffset, point, relativeTo, relativePoint) end

---Enables a dropdown menu that has been disabled.
---@param dropDownFrame MSA_DropDownMenuFrame Both - dropdown menu frame reference (menu handle).
function MSA_DropDownMenu_EnableDropDown(dropDownFrame) end


---Disables a dropdown menu that is currently enabled.
---@param dropDownFrame MSA_DropDownMenuFrame Both - dropdown menu frame reference (menu handle).
function MSA_DropDownMenu_DisableDropDown(dropDownFrame) end

---Starts the hide countdown.
---@param dropDownFrame MSA_DropDownMenuFrame
function MSA_DropDownMenu_StartCounting(dropDownFrame) end

---@return MSA_InfoTable
function MSA_DropDownMenu_CreateInfo() end

function MSA_CloseDropDownMenus() end

-- Initialization functions
-- The initFunction supplied to MSA_DropDownMenu_Initialize is called when the menu (as well as any nested menu levels) should be constructed, 
-- as well as as part of the MSA_DropDownMenu_Initialize call (this allows you to use the selection API to specify a selection immediately 
-- after binding the function to a menu frame should you so desire). The function is given three arguments:
--
-- frame
-- Frame handle to the menu frame.
-- 
-- level
-- Number specifying nesting level.
-- 
-- menuList
-- An EasyMenu helper argument that can safely be ignored.
-- 
-- Additionally, some global variables (see below) may be useful to determine which entry's nested menu the initializer function is asked to supply.
-- 
-- It is expected that the initialization function will create any required menu entries using MSA_DropDownMenu_AddButton when called.

---@class MSA_InfoTable The info table
---@field text string Required - Button text for this option.
---@field value any A value tag for this option. Inherits text key if this is undefined.
---@field checked boolean?, Function If true, this button is checked (tick icon displayed next to it)
---@field func fun(self, arg1, arg2, checked)? Function called when this button is clicked. The signature is (self, arg1, arg2, checked)
---@field isTitle boolean? True if this is a title (cannot be clicked, special formatting).
---@field disabled boolean? If true, this button is disabled (cannot be clicked, special formatting)
---@field arg1 any Arguments to the custom function assigned in func.
---@field arg2 any Arguments to the custom function assigned in func.
---@field hasArrow boolean? If true, this button has an arrow and opens a nested menu.
---@field icon string? A texture path. The icon is scaled down and displayed to the right of the text.
---@field tCoordLeft number? SetTexCoord(tCoordLeft, tCoordRight, tCoordTop, tCoordBottom) for the icon. ALL four must be defined for this to work.
---@field tCoordRight number? SetTexCoord(tCoordLeft, tCoordRight, tCoordTop, tCoordBottom) for the icon. ALL four must be defined for this to work.
---@field tCoordTop number? SetTexCoord(tCoordLeft, tCoordRight, tCoordTop, tCoordBottom) for the icon. ALL four must be defined for this to work.
---@field tCoordBottom number? SetTexCoord(tCoordLeft, tCoordRight, tCoordTop, tCoordBottom) for the icon. ALL four must be defined for this to work.
---@field isNotRadio boolean? If true, use a check mark for the tick icon instead of a circular dot.
---@field hasColorSwatch boolean? If true, this button has an attached color selector.
---@field r number? [0.0, 1.0] Initial color value for the color selector.
---@field g number? [0.0, 1.0] Initial color value for the color selector.
---@field b number? [0.0, 1.0] Initial color value for the color selector.
---@field colorCode string? "|cffrrggbb" sequence that is prepended to info.text only if the button is enabled.
---@field swatchFunc fun()? Function called when the color is changed.
---@field hasOpacity boolean? If true, opacity can be customized in addition to color.
---@field opacity number? [0.0, 1.0] Initial opacity value (0 = transparent).
---@field opacityFunc fun()? Function called when opacity is changed.
---@field cancelFunc fun()? Function called when color/opacity alteration is cancelled.
---@field notClickable boolean? If true, this button cannot be clicked.
---@field noClickSound boolean? Set to 1 to suppress the sound when clicking the button. The sound only plays if .func is set.
---@field notCheckable boolean? If true, this button cannot be checked (selected) - this also moves the button to the left, since there's no space stored for the tick-icon
---@field keepShownOnClick boolean? If true, the menu isn't hidden when this button is clicked.
---@field tooltipTitle string? Tooltip title text. The tooltip appears when the player hovers over the button.
---@field tooltipText string? Tooltip content text.
---@field tooltipOnButton boolean? Show the tooltip attached to the button instead of as a Newbie tooltip.
---@field justifyH string? Horizontal text justification: "CENTER" for "CENTER", any other value or nil for "LEFT".
---@field fontObject Font? Font object used to render the button's text.
---@field owner WoWFrame? Dropdown frame that "owns" the current dropdown list.
---@field padding number? Number of pixels to pad the text on the right side.
---@field menuList table? Table used to store nested menu descriptions for the EasyMenu functionality.

 
-- Selection functions
-- 
-- To use the _SetSelected* functions, your dropdown menu must be the currently open / currently being initialized. Otherwise, the functions will not have the desired effect.
-- 
-- MSA_DropDownMenu_SetSelectedName(frame, name, useValue)
-- Sets selection based on info.text values.
-- 
-- MSA_DropDownMenu_SetSelectedValue(frame, value, useValue)
-- Sets selection based on info.value values.
-- 
-- MSA_DropDownMenu_SetSelectedID(frame, id, useValue)
-- Sets selection based on button appearance order.
-- 
-- MSA_DropDownMenu_GetSelectedName(frame)
-- Returns selected button's text field.
-- 
-- MSA_DropDownMenu_GetSelectedID(frame)
-- Return selected button's ID.
-- 
-- MSA_DropDownMenu_GetSelectedValue(frame)
-- Returns selected button's value field.
-- 
-- Layout functions
-- 
-- MSA_DropDownMenu_SetWidth(frame, width, padding)
-- Adjusts dropdown menu width.
-- 
-- MSA_DropDownMenu_SetButtonWidth(frame, width)
-- Adjust the dropdown box button width.
-- 
-- MSA_DropDownMenu_SetText(frame, text)
-- Alters text displayed on the dropdown box.
-- 
-- MSA_DropDownMenu_GetText(frame)
-- Return text displayed on the dropdown box.
-- 
-- MSA_DropDownMenu_JustifyText(frame, justification)
-- Adjusts text justification on the dropdown box.

-- Global variables

MSA_DROPDOWNMENU_OPEN_MENU = ""
MSA_DROPDOWNMENU_INIT_MENU = "" -- Frame handle of the menu currently initializing.
MSA_DROPDOWNMENU_MENU_LEVEL = 1 -- Current menu nesting level.
MSA_DROPDOWNMENU_MENU_VALUE = "" -- Value of the parent node.
MSA_DROPDOWNMENU_SHOW_TIME = 1 -- Number of seconds to keep the menu visible after the cursor leaves it.

---@type MSA_DropDownMenuFrame
MSA_DropDownList1 = nil