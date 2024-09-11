---------------------------------------------------------------------------------------------------------------------------------------
--- A noncomprehensive and in may ways not correct list of Lua LS typings for the WoW lua environment.
---------------------------------------------------------------------------------------------------------------------------------------

---@diagnostic disable: lowercase-global, missing-return
---@diagnostic disable: param-type-mismatch

SlashCmdList = {}
UIParent = CreateFrame("")
WorldFrame = CreateFrame("")

local function SetScript(self, eventName, func) end

---@class GameTooltip : ScriptRegionResizing
GameTooltip = {
    SetOwner = function(self, frame, anchor) end,
    SetText = function(self, text, a, r, g, b, wrap) end,
    AddLine = function(self, text, red, green, blue) end,
    AddDoubleLine = function(self, textL, textR, rL, gL, bL, rR, gR, bR) end,
    SetHyperlink = function(self, link) end,
    SetScript = SetScript,
    ClearLines = function() end,
    SetBagItem = function(self, bagID, slot) end,
    NumLines = function() return 1 end
}

AceGUIWidgetLSMlists = { font = {} };

bit = {
    band = function(arg1, arg2) return 0 end,
}

LE_ITEM_CLASS_WEAPON = 2;

--- mhBase, mhMod, ohBase, ohMod
function UnitAttackBothHands(unit)
    return 1, 1, 1, 1;
end

-- base, mod
function UnitRangedAttack(unit)
    return 1, 1;
end

---@return string|nil
function GetGuildInfoText() end

---Get the itemLink for the specified item.
---@param unit string
---@param slotId number
---@return string itemLink
function GetInventoryItemLink(unit, slotId) end

---Get Rank or whatever of spell.
---@param spellId number
---@return string subtext
function GetSpellSubtext(spellId) end

---Unit damage returns information about your current damage stats.
---@param unit string
---@return number lowDmg
---@return number hiDmg
---@return number offlowDmg
---@return number offhiDmg
---@return number posBuff
---@return number negBuff
---@return number percentmod
function UnitDamage(unit) end

---Returns the unit's ranged damage and speed.
---@param unit string
---@return number speed
---@return number lowDmg
---@return number hiDmg
---@return number posBuff
---@return number negBuff
---@return number percentmod
function UnitRangedDamage(unit) end

--- as percent
function GetCritChance()
    return 2.5;
end

--- as percent
function GetRangedCritChance()
    return 2.5;
end

---@param unit string
---@return string className Localized name, e.g. "Warrior" or "Guerrier".
---@return string classFileName Locale-independent name, e.g. "WARRIOR".
---@return integer classId
function UnitClass(unit) end

function GetAddOnMetadata(addonName, metaKey)
    return "value";
end

---@alias ostimeInput {year:integer,month:integer,day:integer,hour:integer,min:integer,sec:integer,isdst:boolean}

--- UNIX timestamp
---@param d ostimeInput?
function time(d)
    return 123;
end

-- ms since start
function debugprofilestop()
    return 123;
end

--- Splits a string using a delimiter (optionally: into a specified number of pieces)
---@param delimiter string
---@param subject string
---@param pieces number|nil
function strsplit(delimiter, subject, pieces)
    return "", "", "", "", "", "", "", "", "", "";
end

---@alias DrawLayer "BACKGROUND"|"BORDER"|"ARTWORK"|"OVERLAY"|"HIGHLIGHT"

---@class WoWFrame : ScriptRegionResizing
---@field SetFrameLevel fun(self:WoWFrame, level:integer)
---@field GetParent fun(self:WoWFrame):WoWFrame|nil
---@field SetClampedToScreen fun(self:WoWFrame, enable:boolean):nil
---@field SetMovable fun(self:WoWFrame, enable:boolean):nil
---@field EnableMouse fun(self:WoWFrame, enable:boolean):nil
---@field RegisterForDrag fun(self:WoWFrame, button:string):nil
---@field SetScript fun(self:WoWFrame, handler:string, callback:nil|fun(frame:WoWFrame, ...)):nil
---@field Show fun(self:WoWFrame):nil
---@field Hide fun(self:WoWFrame):nil
---@field SetBackdrop fun(self:WoWFrame, def:table):nil
---@field SetBackdropColor fun(self:WoWFrame, red:number, green:number, blue:number, alpha:number):nil
---@field GetBackdropBorderColor fun():number,number,number,number - rgba Returns the border color. {BackdropTemplateMixin:GetBackdropBorderColor at Townlong-Yak⁠}
---@field SetBackdropBorderColor fun(self:WoWFrame, red:number, green:number, blue:number, alpha:number):nil - Returns the border color. {BackdropTemplateMixin:GetBackdropBorderColor at Townlong-Yak⁠}
---@field UnregisterEvent fun(self:WoWFrame, event:string):nil
---@field RegisterEvent fun(self:WoWFrame, event:string):nil
---@field StartMoving any
---@field StopMovingOrSizing any
---@field SetClipsChildren fun(self:WoWFrame, enable:boolean):nil
---@field ScrollBar WoWFrame
---@field SetScrollChild fun(self:WoWFrame, child:WoWFrame):nil
---@field CreateFontString fun(self:WoWFrame, name:string|nil, layer:any, inherits: any):FontString
---@field CreateTexture fun(self:WoWFrame, name:string|nil, drawLayer:DrawLayer|nil, templateName:string|nil, subLevel:number|nil):Texture -- https://warcraft.wiki.gg/wiki/API_Frame_CreateTexture
---@field SetFrameStrata fun(self:WoWFrame, strata:string) [Wiki](https://warcraft.wiki.gg/wiki/Frame_Strata)
---@field SetScale fun(self:WoWFrame, scale:number)
---@field IsShown fun(self:WoWFrame):boolean
---@field SetToplevel fun(self:WoWFrame, isTopLevel:boolean)
---@field SetHighlightLocked fun(self:WoWFrame, locked:boolean)

---@class ButtonFrameTemplate : WoWFrame
---@field TitleText FontString
---@field portrait any
---@field CloseButton WoWFrame

---@class WoWGameTooltip : WoWFrame
---@field SetOwner fun(self:WoWFrame, owner:WoWFrame, anchor:string):nil
---@field AddFontStrings fun(self:WoWFrame, ...:FontString):nil
---@field ClearLines fun(self:WoWFrame):nil
---@field NumLines fun(self:WoWFrame):integer
---@field SetHyperlink fun(self:WoWFrame, hl:string):nil

---@class FontString : WoWFrame
---@field SetText fun(self:WoWFrame, t:string):nil
---@field GetText fun(self:WoWFrame):string
---@field SetJustifyH fun(self:WoWFrame, j:string):nil
---@field SetWordWrap fun(self:WoWFrame, w:boolean):nil
---@field GetStringHeight fun(self:WoWFrame):number
---@field SetTextColor fun(self:WoWFrame, r:number, g:number, b:number):nil
---@field SetFont fun(self:WoWFrame, path:string, height:number, flags:string|nil);
local FontStringDummy = {

}

---@alias FramePoint  "TOPLEFT" | "TOPRIGHT" | "BOTTOMLEFT" | "BOTTOMRIGHT" | "TOP" | "BOTTOM" | "LEFT" | "RIGHT" | "CENTER"

---@param self ScriptRegionResizing
---@param point FramePoint
---@param relativeFrame WoWFrame
---@param relativePoint FramePoint
---@param ofsx number
---@param ofsy number
---@overload fun(self:WoWFrame, point:string, relativeFrame:WoWFrame, relativePoint:string): boolean
---@overload fun(self:WoWFrame, point:string, ofsx:number, ofsy:number): boolean
local function SetPointDummy(self, point, relativeFrame, relativePoint, ofsx, ofsy) end

---@class ScriptRegionResizing : Region
---@field SetWidth fun(self:ScriptRegionResizing, w:number):nil
---@field SetHeight fun(self:ScriptRegionResizing, h:number):nil
---@field GetWidth fun(self:ScriptRegionResizing):number
---@field GetHeight fun(self:ScriptRegionResizing):number
---@field SetSize fun(self:ScriptRegionResizing, w:number, h:number):nil
---@field ClearAllPoints fun(self:ScriptRegionResizing):nil
---@field Show fun(self:ScriptRegionResizing)
---@field Hide fun(self:ScriptRegionResizing)
---@field GetTop fun(self:ScriptRegionResizing):number Bottom side of the screen to the top edge of the region.
local ScriptRegionResizing = {
    SetPoint = SetPointDummy
}

---Returns an anchor point for the region.
---@param index integer
---@return FramePoint point
---@return WoWFrame relativeTo
---@return FramePoint relativePoint
---@return number offsetX
---@return number offsetY
function ScriptRegionResizing:GetPoint(index) end

---@class Font : FontInstance -- https://warcraft.wiki.gg/wiki/UIOBJECT_Font
---@field CopyFontObject fun(self:Font, sourceFont) -- https://warcraft.wiki.gg/wiki/API_Font_CopyFontObject
---@field GetAlpha fun(self:Font):number -- https://warcraft.wiki.gg/wiki/API_Font_GetAlpha
---@field SetAlpha fun(self:Font, alpha) -- https://warcraft.wiki.gg/wiki/API_Font_SetAlpha

---@class FontInstance : FrameScriptObject
---@field GetFont fun(self:FontInstance):string, number, string  -- Returns the font path, height, and flags. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetFont
---@field GetFontObject fun(self:FontInstance):Font?  -- Returns the "parent" font object. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetFontObject
---@field GetIndentedWordWrap fun(self:FontInstance):boolean  -- Returns the indentation when text wraps beyond the first line. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetIndentedWordWrap
---@field GetJustifyH fun(self:FontInstance):string  -- Returns the horizontal text justification. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetJustifyH
---@field GetJustifyV fun(self:FontInstance):string  -- Returns the vertical text justification. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetJustifyV
---@field GetShadowColor fun(self:FontInstance):number, number, number, number RGBA -- Sets the text shadow color. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetShadowColor
---@field GetShadowOffset fun(self:FontInstance):number, number  -- Returns the text shadow offset. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetShadowOffset
---@field GetSpacing fun(self:FontInstance):number  -- Returns the line spacing. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetSpacing
---@field GetTextColor fun(self:FontInstance):number, number, number, number RGBA -- Returns the default text color. -- https://warcraft.wiki.gg/wiki/API_FontInstance_GetTextColor
---@field SetFont fun(self:FontInstance, fontFile, height, flags) -- Sets the basic font properties. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetFont
---@field SetFontObject fun(self:FontInstance, font) -- Sets the "parent" font object from which this object inherits properties. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetFontObject
---@field SetIndentedWordWrap fun(self:FontInstance, wordWrap) -- Sets the indentation when text wraps beyond the first line. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetIndentedWordWrap
---@field SetJustifyH fun(self:FontInstance, justifyH) -- Sets the horizontal text justification -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetJustifyH
---@field SetJustifyV fun(self:FontInstance, justifyV) -- Sets the vertical text justification. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetJustifyV
---@field SetShadowColor fun(self:FontInstance, colorR:number, colorG:number, colorB:number, a:number?) -- Returns the color of text shadow. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetShadowColor
---@field SetShadowOffset fun(self:FontInstance, offsetX, offsetY) -- Sets the text shadow offset. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetShadowOffset
---@field SetSpacing fun(self:FontInstance, spacing) -- Sets the spacing between lines of text in the object. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetSpacing
---@field SetTextColor fun(self:FontInstance, colorR:number, colorG:number, colorB:number, a:number?) -- Sets the default text color. -- https://warcraft.wiki.gg/wiki/API_FontInstance_SetTextColor

---@class FrameScriptObject
---@field GetName fun(self:FrameScriptObject):string  -- Returns the object's global name. -- https://warcraft.wiki.gg/wiki/API_FrameScriptObject_GetName
---@field GetObjectType fun(self:FrameScriptObject):string  -- Returns the object's widget type. -- https://warcraft.wiki.gg/wiki/API_FrameScriptObject_GetObjectType
---@field IsForbidden fun(self:FrameScriptObject):boolean  -- Returns true if insecure interaction with the object is forbidden. -- https://warcraft.wiki.gg/wiki/API_FrameScriptObject_IsForbidden
---@field IsObjectType fun(self:FrameScriptObject, objectType):boolean  -- Returns true if the object belongs to a given widget type or its subtypes. -- https://warcraft.wiki.gg/wiki/API_FrameScriptObject_IsObjectType
---@field SetForbidden fun(self:FrameScriptObject) -- #protected  Sets the object to be forbidden from an insecure execution path. -- https://warcraft.wiki.gg/wiki/API_FrameScriptObject_SetForbidden

---@class Region
---@field GetAlpha fun(self:Region):number  -- Returns the region's opacity. -- https://warcraft.wiki.gg/wiki/API_Region_GetAlpha
---@field GetDrawLayer fun(self:Region):DrawLayer, integer  -- Returns the layer in which the region is drawn. -- https://warcraft.wiki.gg/wiki/API_Region_GetDrawLayer
---@field GetEffectiveScale fun(self:Region):number  -- Returns the scale of the region after propagating from its parents. -- https://warcraft.wiki.gg/wiki/API_Region_GetEffectiveScale
---@field GetScale fun(self:Region):number  -- Returns the scale of the region. -- https://warcraft.wiki.gg/wiki/API_Region_GetScale
---@field GetVertexColor fun(self:Region):number, number, number, number RGBA -- Returns the vertex color shading of the region. -- https://warcraft.wiki.gg/wiki/API_Region_GetVertexColor
---@field IsIgnoringParentAlpha fun(self:Region):boolean  -- Returns true if the region is ignoring parent alpha. -- https://warcraft.wiki.gg/wiki/API_Region_IsIgnoringParentAlpha
---@field IsIgnoringParentScale fun(self:Region):boolean  -- Returns true if the region is ignoring parent scale. -- https://warcraft.wiki.gg/wiki/API_Region_IsIgnoringParentScale
---@field IsObjectLoaded fun(self:Region):boolean  -- Returns true if the region is fully loaded. -- https://warcraft.wiki.gg/wiki/API_Region_IsObjectLoaded
---@field SetAlpha fun(self:Region, alpha) -- Sets the opacity of the region. -- https://warcraft.wiki.gg/wiki/API_Region_SetAlpha
---@field SetDrawLayer fun(self:Region, layer:DrawLayer, sublevel:integer?) -- Sets the layer in which the region is drawn. -- https://warcraft.wiki.gg/wiki/API_Region_SetDrawLayer
---@field SetIgnoreParentAlpha fun(self:Region, ignore) -- Sets whether the region should ignore its parent's alpha. -- https://warcraft.wiki.gg/wiki/API_Region_SetIgnoreParentAlpha
---@field SetIgnoreParentScale fun(self:Region, ignore) -- Sets whether the region should ignore its parent's scale. -- https://warcraft.wiki.gg/wiki/API_Region_SetIgnoreParentScale
---@field SetScale fun(self:Region, scale) -- Sets the size scaling of the region. -- https://warcraft.wiki.gg/wiki/API_Region_SetScale
---@field SetVertexColor fun(self:Region, colorR:number, colorG:number, colorB:number, a:number?) -- Sets the vertex shading color of the region. -- https://warcraft.wiki.gg/wiki/API_Region_SetVertexColor

---@class TextureBase : ScriptRegionResizing
---@field ClearTextureSlice fun(self:TextureBase) -- https://warcraft.wiki.gg/wiki/API_TextureBase_ClearTextureSlice
---@field GetAtlas fun(self:TextureBase):string  -- Returns the atlas for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetAtlas
---@field GetBlendMode fun(self:TextureBase):BlendMode  -- Returns the blend mode of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetBlendMode
---@field GetDesaturation fun(self:TextureBase):number  -- Returns the desaturation level of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetDesaturation
---@field GetHorizTile fun(self:TextureBase):boolean  -- Returns true if the texture is tiling horizontally. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetHorizTile
---@field GetRotation fun(self:TextureBase):number, any  -- Returns the rotation of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetRotation
---@field GetTexCoord fun(self:TextureBase):number, number, number, number, number, number, number, number  -- Returns the texture space coordinates of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTexCoord
---@field GetTexelSnappingBias fun(self:TextureBase):number  -- Returns the texel snapping bias for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTexelSnappingBias
---@field GetTexture fun(self:TextureBase):number  -- Returns the FileID for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTexture
---@field GetTextureFileID fun(self:TextureBase):number  -- Returns the FileID for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTextureFileID
---@field GetTextureFilePath fun(self:TextureBase):number  -- Returns the FileID for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTextureFilePath
---@field GetTextureSliceMargins fun(self:TextureBase):number, number, number, number -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTextureSliceMargins
---@field GetTextureSliceMode fun(self:TextureBase):0|1 -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetTextureSliceMode
---@field GetVertTile fun(self:TextureBase):boolean  -- Returns true if the texture is tiling vertically. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetVertTile
---@field GetVertexOffset fun(self:TextureBase, vertexIndex):number, number  -- Returns a vertex offset for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_GetVertexOffset
---@field IsBlockingLoadRequested fun(self:TextureBase):boolean -- https://warcraft.wiki.gg/wiki/API_TextureBase_IsBlockingLoadRequested
---@field IsDesaturated fun(self:TextureBase):boolean  -- Returns true if the texture is desaturated. -- https://warcraft.wiki.gg/wiki/API_TextureBase_IsDesaturated
---@field IsSnappingToPixelGrid fun(self:TextureBase):boolean  -- Returns true if the texture is snapping to the pixel grid. -- https://warcraft.wiki.gg/wiki/API_TextureBase_IsSnappingToPixelGrid
---@field SetAtlas fun(self:TextureBase, atlas:string, useAtlasSize:boolean?, filterMode:string?, resetTexCoords:boolean?) -- Sets the texture to an atlas. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetAtlas
---@field SetBlendMode fun(self:TextureBase, blendMode) -- Sets the blend mode of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetBlendMode
---@field SetBlockingLoadsRequested fun(self:TextureBase, blocking:boolean?) -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetBlockingLoadsRequested
---@field SetColorTexture fun(self:TextureBase, colorR:number, colorG:number, colorB:number, a:number?) -- Sets the texture to a solid color. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetColorTexture
---@field SetDesaturated fun(self:TextureBase, desaturated:boolean) -- Sets the texture to be desaturated. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetDesaturated
---@field SetDesaturation fun(self:TextureBase, desaturation) -- Sets the desaturation level of the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetDesaturation
---@field SetGradient fun(self:TextureBase, orientation, minColor, maxColor) -- Sets a gradient color shading for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetGradient
---@field SetHorizTile fun(self:TextureBase, tiling:boolean?) -- Sets whether the texture should tile horizontally. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetHorizTile
---@field SetMask fun(self:TextureBase, file) -- Applies a mask to the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetMask
---@field SetRotation fun(self:TextureBase, radians:number, normalizedRotationPoint:any) -- Applies a rotation to the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetRotation
---@field SetSnapToPixelGrid fun(self:TextureBase, snap:boolean?) -- Sets the texture to snap to the pixel grid. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetSnapToPixelGrid
---@field SetTexCoord fun(self:TextureBase, left, right, top, bottom) -- Sets the coordinates for cropping or transforming the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexCoord
---@field SetTexelSnappingBias fun(self:TextureBase, bias) -- Returns the texel snapping bias for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexelSnappingBias
---@field SetTexture fun(self:TextureBase, textureAsset, wrapModeHorizontal, wrapModeVertical, filterMode) -- Sets the texture to an image. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexture
---@field SetTextureSliceMargins fun(self:TextureBase, left, top, right, bottom) -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetTextureSliceMargins
---@field SetTextureSliceMode fun(self:TextureBase, sliceMode) -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetTextureSliceMode
---@field SetVertTile fun(self:TextureBase, tiling) -- Sets whether the texture should tile vertically. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetVertTile
---@field SetVertexOffset fun(self:TextureBase, vertexIndex, offsetX, offsetY) -- Sets a vertex offset for the texture. -- https://warcraft.wiki.gg/wiki/API_TextureBase_SetVertexOffset

---@class Texture : TextureBase https://warcraft.wiki.gg/wiki/UIOBJECT_Texture
---@field AddMaskTexture fun(self:Texture, mask) -- https://warcraft.wiki.gg/wiki/API_Texture_AddMaskTexture
---@field GetMaskTexture fun(self:Texture, index):any -- https://warcraft.wiki.gg/wiki/API_Texture_GetMaskTexture
---@field GetNumMaskTextures fun(self:Texture):number -- https://warcraft.wiki.gg/wiki/API_Texture_GetNumMaskTextures
---@field RemoveMaskTexture fun(self:Texture, mask) -- https://warcraft.wiki.gg/wiki/API_Texture_RemoveMaskTexture

---@alias ButtonState "DISABLED"|"NORMAL"|"PUSHED"
---@alias BlendMode
---| "DISABLE" - opaque texture
---| "BLEND" - normal painting on top of the background, obeying alpha channels if present in the image (uses alpha)
---| "ALPHAKEY" - one-bit alpha
---| "ADD" - additive blend
---| "MOD" - modulating blend
---@alias ButtonClickIdentifier
---| "AnyUp" - Responds to the up action of any mouse button.
---| "AnyDown" - Responds to the down action of any mouse button.
---| "LeftButtonUp"
---| "LeftButtonDown"
---| "RightButtonUp"
---| "RightButtonDown"
---| "MiddleButtonUp"
---| "MiddleButtonDown"
---| "Button4Up"
---| "Button4Down"
---| "Button5Up"
---| "Button5Down"

---@class (exact) WoWFrameButton : WoWFrame
---@field ClearDisabledTexture fun(self:WoWFrameButton)
---@field ClearHighlightTexture fun(self:WoWFrameButton)
---@field ClearNormalTexture fun(self:WoWFrameButton)
---@field ClearPushedTexture fun(self:WoWFrameButton)
---@field Click fun(self:WoWFrameButton, button:ButtonClickIdentifier|nil, isDown:boolean|nil) -- Performs a virtual mouse click on the button.
---@field Disable fun(self:WoWFrameButton)
---@field Enable fun(self:WoWFrameButton)
---@field GetButtonState fun(self:WoWFrameButton):ButtonState
---@field GetDisabledFontObject fun(self:WoWFrameButton):Font
---@field GetDisabledTexture fun(self:WoWFrameButton):Texture
---@field GetFontString fun(self:WoWFrameButton):FontString
---@field GetHighlightFontObject fun(self:WoWFrameButton):Font
---@field GetHighlightTexture fun(self:WoWFrameButton):Texture -- Returns the highlight texture for the button.
---@field GetMotionScriptsWhileDisabled fun(self:WoWFrameButton):boolean
---@field GetNormalFontObject fun(self:WoWFrameButton):Font -- Returns the font object for the button's normal state.
---@field GetNormalTexture fun(self:WoWFrameButton):Texture
---@field GetPushedTextOffset fun(self:WoWFrameButton):number,number
---@field GetPushedTexture fun(self:WoWFrameButton):Texture
---@field GetText fun(self:WoWFrameButton):string -- Returns the text on the button.
---@field GetTextHeight fun(self:WoWFrameButton):number
---@field GetTextWidth fun(self:WoWFrameButton):number
---@field IsEnabled fun(self:WoWFrameButton):boolean -- Returns true if the button is enabled.
---@field RegisterForClicks fun(self:WoWFrameButton,button1:ButtonClickIdentifier|nil, ...) -- Registers the button widget to receive OnClick script events.
---@field RegisterForMouse fun(self:WoWFrameButton,button1:ButtonClickIdentifier|nil, ...) -- Registers the button widget to receive OnMouse script events.
---@field SetButtonState fun(self:WoWFrameButton,state:ButtonState,lock:boolean|nil)
---@field SetDisabledAtlas fun(self:WoWFrameButton,atlas:string)
---@field SetDisabledFontObject fun(self:WoWFrameButton,font)
---@field SetDisabledTexture fun(self:WoWFrameButton,asset)
---@field SetEnabled fun(self:WoWFrameButton,enabled:boolean|nil)
---@field SetFontString fun(self:WoWFrameButton,fontString)
---@field SetFormattedText fun(self:WoWFrameButton,text)
---@field SetHighlightAtlas fun(self:WoWFrameButton,atlas:string, blendMode:BlendMode|nil)
---@field SetHighlightFontObject fun(self:WoWFrameButton,font)
---@field SetHighlightTexture fun(self:WoWFrameButton,asset:string,blendMode:BlendMode|nil)
---@field SetMotionScriptsWhileDisabled fun(self:WoWFrameButton,motionScriptsWhileDisabled:boolean)
---@field SetNormalAtlas fun(self:WoWFrameButton,atlas:string)
---@field SetNormalFontObject fun(self:WoWFrameButton,font:Font) -- Sets the font object used for the button's normal state.
---@field SetNormalTexture fun(self:WoWFrameButton,asset) -- Sets the normal texture for a button.
---@field SetPushedAtlas fun(self:WoWFrameButton,atlas:string)
---@field SetPushedTextOffset fun(self:WoWFrameButton,offsetX:number, offsetY:number)
---@field SetPushedTexture fun(self:WoWFrameButton,asset)
---@field SetText fun(self:WoWFrameButton,text:string|nil) -- Sets the text of the button.

---@param frame WoWFrame
function ButtonFrameTemplate_HideButtonBar(frame) end

---@class StatusBar : WoWFrame
---@field SetMinMaxValues fun(self:StatusBar, minValue, maxValue) - Set the bounds of the statusbar.
---@field SetOrientation fun(self:StatusBar, orientation) - Sets the orientation of the statusbar.
---@field SetReverseFill fun(self:StatusBar, isReverseFill) - Sets the fill direction of the statusbar.
---@field SetRotatesTexture fun(self:StatusBar, rotatesTexture) - Set the color of the statusbar.
---@field SetStatusBarColor fun(self:StatusBar, colorR, colorG, colorB, a:number|nil)
---@field SetStatusBarDesaturated fun(self:StatusBar, desaturated:boolean)
---@field SetStatusBarDesaturation fun(self:StatusBar, desaturation)
---@field SetStatusBarTexture fun(self:StatusBar, asset) - Sets the texture of the statusbar.
---@field SetValue fun(self:StatusBar, value) - Set the value of the statusbar.

---@class EditBox : WoWFrame
---@field SetAutoFocus fun(self:EditBox, autofocus:boolean) Sets whether the cursor should automatically focus on the edit box when it is shown.
---@field SetFontObject fun(self:EditBox, fo)
---@field SetTextInsets fun(self:EditBox, left, right, top, bottom)
---@field SetMaxLetters fun(self:EditBox, maxLetters:integer)
---@field SetText fun(self:EditBox, text:string)
---@field GetText fun(self:EditBox):string

ChatFontNormal = {}

---Creates a Frame object.
---@return WoWFrame
---@overload fun(frameType:"Frame", frameName: string|nil, parentFrame: any, inheritsFrame: string|nil): WoWFrame
---@overload fun(frameType:"Button", frameName: string|nil, parentFrame: any, inheritsFrame: string|nil): WoWFrameButton
---@overload fun(frameType:"GameTooltip", frameName: string|nil, parentFrame: any, inheritsFrame: string|nil): GameTooltip
---@overload fun(frameType:"StatusBar", frameName: string|nil, parentFrame: any, inheritsFrame: string|nil): StatusBar
---@overload fun(frameType:"EditBox", frameName: string|nil, parentFrame: any, inheritsFrame: string|nil): EditBox
function CreateFrame(frameType, frameName, parentFrame, inheritsFrame) end

---@class UIDropDownMenu : WoWFrame
---@field Left Texture
---@field Middle Texture
---@field Right Texture
---@field Button WoWFrameButton
---@field Icon Texture
---@field Text FontString

--- name, rank, icon, castTime, minRange, maxRange
function GetSpellInfo(spellId_spellName_spellLink)
    return "name", "rank", "icon", 1, 1, 1;
end

function UIDropDownMenu_SetWidth(dropDown, width) end

function UIDropDownMenu_Initialize(dropDown, initFunc) end

function UIDropDownMenu_CreateInfo()
    return {
        arg1 = "",
        arg2 = "",
        checked = false,
        func = function() end,
        text = "",
    }
end

C_Item = {}

---@param id number|string Item ID, Link or name
---@return integer itemID
---@return string itemType
---@return string itemSubType
---@return string itemEquipLoc
---@return number icon
---@return number classID
---@return number subClassID
function C_Item.GetItemInfoInstant(id) end

GetItemInfoInstant = C_Item.GetItemInfoInstant

---@param ident string|number ItemLink, Name or ID
---@return string itemName
---@return string itemLink
---@return integer itemQuality
---@return number itemLevel
---@return number itemMinLevel
---@return string itemType
---@return string itemSubType
---@return number itemStackCount
---@return string itemEquipLoc
---@return number itemTexture
---@return number sellPrice
---@return integer classID
---@return integer subclassID
---@return integer bindType
---@return integer expacID
---@return integer setID
---@return boolean isCraftingReagent
function C_Item.GetItemInfo(ident) end

GetItemInfo = C_Item.GetItemInfo

---@param itemId integer
---@return boolean
function C_Item.DoesItemExistByID(itemId) end

---@param itemId integer
---@return boolean
function C_Item.IsItemDataCachedByID(itemId) end

---Return the icon texture for the item.
---@param itemID integer
---@return string
function GetItemIcon(itemID) end

function UIDropDownMenu_SetText(self, text) end

--- See UIDropDownMenu_CreateInfo
function UIDropDownMenu_AddButton(buttonInfo) end

function hooksecurefunc(table, key, func) end

--- actionType, actionId
function GetActionInfo(slot)
    return "type", 123
end

function GetMacroSpell(actionId)
    return 123;
end

function UnitName(unit)
    return "name";
end

function UnitLevel(unit)
    return 1;
end

function UnitIsPlayer(unit)
    return true;
end

function GetSpellBonusDamage(schoolNum)
    return 123;
end

---@return boolean
function IsControlKeyDown() end

---@return boolean
function IsAltKeyDown() end

---@return boolean
function IsShiftKeyDown() end

function GetSpellBonusHealing()
    return 123;
end

--- as percent
function GetSpellCritChance(schoolNum)
    return 123;
end

---Get attack power.
---@param unit string
---@return number base The unit's base attack power
---@return number posBuff The total effect of positive buffs to attack power.
---@return number negBuff The total effect of negative buffs to the attack power (a negative number)
function UnitAttackPower(unit) end

---Get ranged attack power.
---@param unit string
---@return number base The unit's base ranged attack power (seems to give a positive number even if no ranged weapon equipped)
---@return number posBuff The total effect of positive buffs to ranged attack power.
---@return number negBuff The total effect of negative buffs to the ranged attack power (a negative number)
function UnitRangedAttackPower(unit) end

---Get melee haste.
---@return number haste in percent.
function GetHaste() end

---Get ranged haste.
---@return number haste in percent.
function GetRangedHaste() end

---Get blovk value.
---@return number
function GetShieldBlock() end

---Gets the player's current mana regeneration rates (in mana per 1 seconds).
---@return number base @Full regen while outside the fsr
---@return number casting @Regen from mp5 and uninterrupted spirit/int regen
function GetManaRegen() end

function UnitPowerMax(unit, powerType)
    return 123;
end

--- mainhand, offhand
function UnitAttackSpeed(unit)
    return 1.5, 1.2;
end

function GetInventoryItemID(unit, slot)
    return 123;
end

function GetInventoryItemDurability(slot)
    return 123;
end

---Returns information about a specified talent in a specified tab.
---@param tree any
---@param talent any
---@return string name
---@return string icon
---@return integer tier
---@return integer column
---@return integer currentRank
---@return integer maxRank
function GetTalentInfo(tree, talent) end

---Returns the buffs/debuffs for the unit.
---@param unit string
---@param index number
---@param filter string|nil What auras to iterate (HELPFUL, HARMFUL), defaults to HELPFUL.
---@return string name The localized name of the aura, otherwise nil if there is no aura for the index.
---@return integer icon FileID - The icon texture.
---@return integer count The amount of stacks, otherwise 0.
---@return string|nil dispelType The locale-independent magic type of the aura: Curse, Disease, Magic, Poison, otherwise nil.
---@return number duration The full duration of the aura in seconds.
---@return number expirationTime Time the aura expires compared to GetTime(), e.g. to get the remaining duration: expirationtime - GetTime()
---@return string source The unit that applied the aura.
---@return boolean isStealable If the aura may be stolen.
---@return boolean nameplateShowPersonal If the aura should be shown on the player/pet/vehicle nameplate.
---@return integer spellId The spell ID for e.g. GetSpellInfo()
---@return boolean canApplyAura If the player can apply the aura.
---@return boolean isBossDebuff If the aura was cast by a boss.
---@return boolean castByPlayer If the aura was applied by a player.
---@return boolean nameplateShowAll If the aura should be shown on nameplates.
---@return number timeMod The scaling factor used for displaying time left.
function UnitAura(unit, index, filter) end

AuraUtil = {}

---@param name string
---@param unit string
---@param filter string|nil What auras to iterate (HELPFUL, HARMFUL), defaults to HELPFUL.
---@return string? name The localized name of the aura, otherwise nil if there is no aura for the index.
---@return integer icon FileID - The icon texture.
---@return integer count The amount of stacks, otherwise 0.
---@return string|nil dispelType The locale-independent magic type of the aura: Curse, Disease, Magic, Poison, otherwise nil.
---@return number duration The full duration of the aura in seconds.
---@return number expirationTime Time the aura expires compared to GetTime(), e.g. to get the remaining duration: expirationtime - GetTime()
---@return string source The unit that applied the aura.
---@return boolean isStealable If the aura may be stolen.
---@return boolean nameplateShowPersonal If the aura should be shown on the player/pet/vehicle nameplate.
---@return integer spellId The spell ID for e.g. GetSpellInfo()
---@return boolean canApplyAura If the player can apply the aura.
---@return boolean isBossDebuff If the aura was cast by a boss.
---@return boolean castByPlayer If the aura was applied by a player.
---@return boolean nameplateShowAll If the aura should be shown on nameplates.
---@return number timeMod The scaling factor used for displaying time left.
function AuraUtil.FindAuraByName(name, unit, filter) end

--- name, _, count, _, _, _, _, _, _, spellId
function UnitBuff(unit, i)
    return "name", "_", 1, "_", "_", "_", "_", "_", "_", 123;
end

--- Wipe table
function wipe(table) end

function GetLocale()
    return "enUS";
end

--- localized, english
function UnitRace(unit)
    return "localized", "English";
end

---Returns info about one of the unit's stats (strength, agility, stamina, intellect, spirit).
---@param unit string
---@param statID number
---@return number base @The unit's base stat.
---@return number stat @The unit's current stat.
---@return number posBuff @Any positive buffs applied to the stat.
---@return number negBuff @Any negative buffs applied to the stat.
function UnitStat(unit, statID) end

---@class SpellPowerEntry
local SpellPowerEntry = {
    hasRequiredAura = true,
    ---@type PowerType
    type = 1,
    name = "name",
    cost = 1,
    minCost = 0,
    requiredAuraID = 0,
    costPercent = 0,
    costPerSec = 0
}

---@return table<number,SpellPowerEntry>
function GetSpellPowerCost(spellName_spellID) end

function GetShapeshiftForm()
    return 0;
end

function GetRealmName()
    return "";
end

---@param libName string
---@return table
function LibStub(libName) end

Bartender4 = {}

Bartender4DB = {
    namespaces = {},
    profileKeys = {},
}

DominosDB = {
    profileKeys = {},
    profiles = {},
}

ElvUISpellBookTooltip = {};

ElvDB = {
    profileKeys = {},
    profiles = {},
}

--- initpos is optional. Returns the matched substring(s) found within string. Multiple return values can occur.
function strmatch(string, pattern, initpos)
    return "", "", "", "";
end

--- icon, active, castable, spellId
function GetShapeshiftFormInfo(index)
    return "", true, true, 1;
end

function GetHitModifier()
    return 1;
end

function GetSpellHitModifier()
    return 1;
end

CR_WEAPON_SKILL = 1;
CR_DEFENSE_SKILL = 2;
CR_DODGE = 3;
CR_PARRY = 4;
CR_BLOCK = 5;
CR_HIT_MELEE = 6;
CR_HIT_RANGED = 7;
CR_HIT_SPELL = 8;
CR_CRIT_MELEE = 9;
CR_CRIT_RANGED = 10;
CR_CRIT_SPELL = 11;
CR_MULTISTRIKE = 12;
CR_READINESS = 13;
CR_SPEED = 14;
COMBAT_RATING_RESILIENCE_CRIT_TAKEN = 15;
COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN = 16;
CR_LIFESTEAL = 17;
CR_HASTE_MELEE = 18;
CR_HASTE_RANGED = 19;
CR_HASTE_SPELL = 20;
CR_AVOIDANCE = 21;
CR_WEAPON_SKILL_OFFHAND = 22;
CR_WEAPON_SKILL_RANGED = 23;
CR_EXPERTISE = 24;
CR_ARMOR_PENETRATION = 25;
CR_MASTERY = 26;
CR_PVP_POWER = 27;
CR_VERSATILITY_DAMAGE_DONE = 29;
CR_VERSATILITY_DAMAGE_TAKEN = 31;

---Returns the bonus, in percent (or other converted units, such as skill points), of a specific combat rating for the player.
---@param combatRatingId number
---@return number bonusPct
function GetCombatRatingBonus(combatRatingId)
end

--- Returns the current power of the specified unit.
---@param unitId string
---@param powerType number @Type of resource (mana/rage/energy/etc) to query
---@param unmodified boolean|nil @Return the higher precision internal value (for graphical use only)
---@return number
function UnitPower(unitId, powerType, unmodified)
    return 1;
end

--- Returns the GUID of the specified unit.
---@param unitId string
---@return string
function UnitGUID(unitId)
    return "Creature-0-1133-870-141-71953-0000432FBD";
end

--- Returns the creature type of the specified unit.
---@param unitId string
---@return string
function UnitCreatureType(unitId)
    return "Beast";
end

function InterfaceOptionsFrame_OpenToCategory(panelName) end

function InterfaceOptions_AddCategory(frame) end

InterfaceOptionsFrameAddOns = {};
function OptionsListButtonToggle_OnClick() end

function ChatConfigFrame_PlayCheckboxSound() end

function EditBox_ClearFocus(frame) end

function GameTooltip_Hide() end

function GetWeaponEnchantInfo()
    return true, 1, 1, 1, true, 1, 1, 1;
end

---Returns information on a glyph socket.
---@param socketID number glyph [Glyph SocketID|socket index]] (1 to GetNumGlyphSockets() )
---@param talentGroup number|nil (dual) specialization index (1 to GetNumTalentGroups(...)).
---@return boolean enabled
---@return integer type
---@return integer spellId
---@return string icon
function GetGlyphSocketInfo(socketID, talentGroup) end

---@return number
function GetNumGlyphSockets() end

C_Timer = {
    ---@param delay number Delay in seconds.
    ---@param callback fun():nil
    After = function(delay, callback) end
}

---@return number expertise
---@return number offhandExpertise
function GetExpertise() end

---Returns the percentage of target's armory your physical attacks ignore due to armor penetration.
---@return number armorPenPct
function GetArmorPenetration() end

---Retrieves the number of combo points gained by a player.
---@param unit "player"|"vehicle"
---@param target "target"
---@return integer
function GetComboPoints(unit, target) end

---Are 2 units the same?
---@param unit1 string
---@param unit2 string
---@return boolean
function UnitIsUnit(unit1, unit2) end

---Retrieves information about a specific SpellBook item
---@param entryName string
---@return string skillType The type of the spell (known values: "SPELL", "PETACTION", "FUTURESPELL", "FLYOUT")
---@return integer contextualID For SPELL and FUTURESPELL this is the spellID. For PetAction is it an integer value that is troublesome to use outside of two functions related solely to the PetBarUI. For Flyout, it is the FlyoutID.
function GetSpellBookItemInfo(entryName) end

---@param delim string
---@param str string
---@return string[]
function strsplittable(delim, str) end

---@type string
WOW_PROJECT_ID = ""
WOW_PROJECT_CLASSIC = "CLASSIC";
WOW_PROJECT_WRATH_CLASSIC = "WRATH";
WOW_PROJECT_CATACLYSM_CLASSIC = "WOW_PROJECT_CATACLYSM_CLASSIC"
WOW_PROJECT_MAINLINE = "WOW_PROJECT_MAINLINE"

---@param spellID integer
---@param isPetSpell boolean|nil if true, will check if the currently active pet knows the spell; if false or omitted, will check if the player knows the spell
---@return boolean
function IsSpellKnown(spellID, isPetSpell) end

---@param spellID integer
---@return integer|nil
function FindBaseSpellByID(spellID) end

---@param spellID integer
---@return integer|nil
function FindSpellOverrideByID(spellID) end

---@param spellID integer
---@return boolean
function IsPlayerSpell(spellID) end

LE_PARTY_CATEGORY_HOME = ""
LE_PARTY_CATEGORY_INSTANCE = ""

---Returns the number of players in the group.
---@param groupType any If omitted, defaults to INSTANCE if applicable, HOME otherwise. LE_PARTY_CATEGORY_HOME|LE_PARTY_CATEGORY_INSTANCE
---@return integer numGroupMembers total number of players in the group (either party or raid), 0 if not in a group.
function GetNumGroupMembers(groupType) end

---Returns true if the player is in a raid.
---@param groupType any If omitted, defaults to INSTANCE if applicable, HOME otherwise. LE_PARTY_CATEGORY_HOME|LE_PARTY_CATEGORY_INSTANCE
---@return boolean isInRaid true if the player is currently in a groupType raid group (if groupType was not specified, true if in any type of raid), false otherwise
function IsInRaid(groupType) end

---@param groupType any If omitted, defaults to INSTANCE if applicable, HOME otherwise. LE_PARTY_CATEGORY_HOME|LE_PARTY_CATEGORY_INSTANCE
---@return boolean isInRaid
function IsInGroup(groupType) end

---Returns true if the unit is connected to the game (i.e. not offline).
---@param unit string
---@return boolean
function UnitIsConnected(unit) end

---@param msg string
---@param chatType string See https://warcraft.wiki.gg/wiki/API_SendChatMessage
---@param languageID integer|nil
---@param target string|nil
function SendChatMessage(msg, chatType, languageID, target) end

C_Engraving = {}
---@return boolean
C_Engraving.IsEngravingEnabled = function() end

---@return boolean
function IsInGuild() end

---Requests updated guild roster information from the server.
function GuildRoster() end

C_GuildInfo = {
    GuildRoster = GuildRoster,
}

---@param unit string
---@param groupType any If omitted, defaults to INSTANCE if applicable, HOME otherwise. LE_PARTY_CATEGORY_HOME|LE_PARTY_CATEGORY_INSTANCE
function UnitIsGroupLeader(unit, groupType) end

---@return "freeforall"|"roundrobin"|"master"|"group"|"needbeforegreed" method
---@return integer masterlooterPartyID Returns 0 if player is the mater looter, 1-4 if party member is master looter (corresponding to party1-4) and nil if the master looter isn't in the player's party or master looting is not used.
---@return integer masterlooterRaidID Returns index of the master looter in the raid (corresponding to a raidX unit), or nil if the player is not in a raid or master looting is not used.
function GetLootMethod() end

---@class TimerHandle
---@field IsCancelled fun(self:TimerHandle)
---@field Cancel fun(self:TimerHandle)
---@field Invoke fun(self:TimerHandle)

---@param interval number Interval in seconds.
---@param callback fun(t:TimerHandle)
---@param interations integer|nil nil for inf
---@return TimerHandle
function C_Timer.NewTicker(interval, callback, interations) end

---@param duration number duration in seconds.
---@param callback fun(t:TimerHandle)
---@return TimerHandle
function C_Timer.NewTimer(duration, callback) end

---Returns the system uptime of your computer in seconds, with millisecond precision.
---@return number
function GetTime() end

---@param classID integer
---@return string className
---@return string classFile
---@return integer classId
function GetClassInfo(classID) end

INT_SPELL_DURATION_HOURS = "%d hrs"
INT_SPELL_DURATION_MIN = "%d min"
INT_SPELL_DURATION_SEC = "%d sec"
BIND_TRADE_TIME_REMAINING = "blablabla %s"

C_Container = {}

Enum = {}

---@enum ItemQuality
Enum.ItemQuality = {
    Poor = 0,
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Artifact = 6,
    Heirloom = 7,
    WoWToken = 8,
}

---@class ContainerItemInfo
---@field iconFileID number
---@field stackCount number 	
---@field isLocked boolean 	
---@field quality ItemQuality|nil
---@field isReadable boolean 	
---@field hasLoot boolean 	
---@field hyperlink string 	
---@field isFiltered boolean 	
---@field hasNoValue boolean 	
---@field itemID integer 	
---@field isBound boolean

---comment
---@param containerIndex integer
---@param slotIndex integer
---@return ContainerItemInfo|nil info Returns nil if the container slot is empty.
function C_Container.GetContainerItemInfo(containerIndex, slotIndex) end

---@type number[][]
CLASS_ICON_TCOORDS = {}

---@param index integer
---@return string name
---@return string rankName
---@return integer rankIndex
---@return integer level
---@return string classDisplayName
---@return string zone
---@return string publicNote
---@return string officerNote
---@return boolean isOnline
---@return integer status 0: none - 1: AFK - 2: Busy (Do Not Disturb) (changed in 4.3.2)
---@return string class
---@return integer achievementPoints
---@return integer achievementRank
---@return boolean isMobile
---@return boolean canSoR
---@return integer repStanding
---@return string guid
function GetGuildRosterInfo(index) end

---@return integer members
---@return integer online
---@return integer mobile
function GetNumGuildMembers() end

---@param fullName string
---@param context "all"|"guild"|"mail"|"none"|"short" context the name will be used in, one of: "all", "guild", "mail", "none", or "short"
---@return string
function Ambiguate(fullName, context) end

---Returns cursor position relative to the bottom left of the screen.
---This needs to be divided by the UI scale to get correct coordinates relative to other frames.
---@return number x
---@return number y
function GetCursorPosition() end

---@param key string
---@return string
function GetCVar(key) end

---@enum ItemClass
Enum.ItemClass = {
    Consumable = 0,             -- Consumable Enum.ItemConsumableSubclass
    Container = 1,              -- Container
    Weapon = 2,                 -- Weapon Enum.ItemWeaponSubclass
    Gem = 3,                    -- Gem Enum.ItemGemSubclass
    Armor = 4,                  -- Armor Enum.ItemArmorSubclass
    Reagent = 5,                -- Reagent Enum.ItemReagentSubclass
    Projectile = 6,             -- Projectile Obsolete
    Tradegoods = 7,             -- Tradeskill
    ItemEnhancement = 8,        -- Item Enhancement
    Recipe = 9,                 -- Recipe Enum.ItemRecipeSubclass
    CurrencyTokenObsolete = 10, -- Money(OBSOLETE) Obsolete
    Quiver = 11,                -- Quiver Obsolete
    Questitem = 12,             -- Quest
    Key = 13,                   -- Key
    PermanentObsolete = 14,     -- Permanent(OBSOLETE) Obsolete
    Miscellaneous = 15,         -- Miscellaneous Enum.ItemMiscellaneousSubclass
    Glyph = 16,                 -- Glyph
    Battlepet = 17,             -- Battle Pets Enum.BattlePetTypes
    WoWToken = 18,              -- WoW Token
    Profession = 19,            -- Profession Enum.ItemProfessionSubclass Added in 10.0.0
}

---@enum ItemWeaponSubclass
Enum.ItemWeaponSubclass = {
    Axe1H = 0,        -- One-Handed Axes
    Axe2H = 1,        -- Two-Handed Axes
    Bows = 2,         -- Bows
    Guns = 3,         -- Guns
    Mace1H = 4,       -- One-Handed Maces
    Mace2H = 5,       -- Two-Handed Maces
    Polearm = 6,      -- Polearms
    Sword1H = 7,      -- One-Handed Swords
    Sword2H = 8,      -- Two-Handed Swords
    Warglaive = 9,    -- Warglaives
    Staff = 10,       -- Staves
    Bearclaw = 11,    -- Bear Claws
    Catclaw = 12,     -- CatClaws
    Unarmed = 13,     -- Fist Weapons
    Generic = 14,     -- Miscellaneous
    Dagger = 15,      -- Daggers
    Thrown = 16,      -- Thrown Classic
    Obsolete3 = 17,   -- Spears
    Crossbow = 18,    -- Crossbows
    Wand = 19,        -- Wands
    Fishingpole = 20, -- Fishing Poles
}

---@enum ItemArmorSubclass
Enum.ItemArmorSubclass = {
    Generic = 0,  -- Miscellaneous  Includes Spellstones, Firestones, Trinkets, Rings and Necks
    Cloth = 1,    -- Cloth
    Leather = 2,  -- Leather
    Mail = 3,     -- Mail
    Plate = 4,    -- Plate
    Cosmetic = 5, -- Cosmetic
    Shield = 6,   -- Shields
    Libram = 7,   -- Librams  Classic
    Idol = 8,     -- Idols  Classic
    Totem = 9,    -- Totems  Classic
    Sigil = 10,   -- Sigils  Classic
    Relic = 11,   -- Relic
}

ITEM_CLASSES_ALLOWED = "Classes: %s"

---Plays the specified audio file once. Unlike PlayMusic, you cannot stop the playback.
---@param path string
---@param channel string Either "Master" (this will play the sound also with disabled sounds like before 4.0.1), "SFX", "Ambience", "Music".
function PlaySoundFile(path, channel) end

---@param format string|"*t"
---@param time number
---@overload fun(format:string, time:number): string
---@overload fun(format:"*t", time:number): ostimeInput
function date(format, time) end
