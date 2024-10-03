---@class AddonEnv
local Env = select(2, ...)

Env.Item = {}

local L = Env:GetLocalization()
local TOOLTIP_NAME = "DMSItemScanTooltip"
local scanTip = CreateFrame("GameTooltip", TOOLTIP_NAME, nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

do
    local timePatterns = {
        [INT_SPELL_DURATION_HOURS] = 60 * 60,
        [INT_SPELL_DURATION_MIN] = 60,
        [INT_SPELL_DURATION_SEC] = 1
    }

    ---@type table<string, integer>
    local lookupPatterns = {}

    for pattern, secondsPerUnit in pairs(timePatterns) do
        local pre = ""
        pattern = pattern:gsub("%%d(%s?)", function(whitespace) ---@cast whitespace string
            pre = "(%d+)" .. whitespace
            return ""
        end)
        -- Reformat singular and plural forms from "|4sing:plur" to "sing plur".
        pattern = pattern:gsub("|4", ""):gsub("[:;]", " ")
        -- Add all formats with their number format placeholder
        for s in pattern:gmatch("(%S+)") do
            lookupPatterns[pre .. s] = secondsPerUnit
        end
    end

    local timeRemainingPattern = BIND_TRADE_TIME_REMAINING:gsub("%%s", ".*")

    ---Check the trade timer on an item in bags.
    ---@param bagID integer
    ---@param slot integer
    ---@param minQuality ItemQuality
    ---@return number|nil secsRemaining The remaining seconds or nil if not tradeable.
    function Env.Item:GetTradeTimer(bagID, slot, minQuality)
        local containerItemInfo = C_Container.GetContainerItemInfo(bagID, slot)
        if not containerItemInfo then
            return
        end
        if containerItemInfo.quality and containerItemInfo.quality >= minQuality then
            scanTip:ClearLines()
            scanTip:SetBagItem(bagID, slot)

            for i = scanTip:NumLines(), 1, -1 do
                ---@type FontString|nil
                local left = _G[TOOLTIP_NAME .. "TextLeft" .. i]
                if left then
                    local text = left:GetText() or ""
                    if text:find(timeRemainingPattern) then
                        local remainingSeconds = 0
                        for pattern, secsPerUnit in pairs(lookupPatterns) do
                            local num = tonumber(text:match(pattern))
                            if num then
                                remainingSeconds = remainingSeconds + num * secsPerUnit
                            end
                        end
                        return remainingSeconds
                    end
                end
            end
        end
    end
end

---Get item Id from an item link. Matches the "|Hitem:id:" part, everything else is irrelevant.
---@param itemLink string
---@return integer|nil
function Env.Item.GetIdFromLink(itemLink)
    local match = itemLink:match("|Hitem:(%d+):")
    if match then
        local num = tonumber(match)
        if num then
            return math.floor(num)
        end
    end
end

do
    ---@alias ItemInfoRdyFunc fun(itemName:string|nil,itemLink:string,itemQuality:integer,itemLevel:number,itemMinLevel:number,itemType:string,itemSubType:string,itemStackCount:number,itemEquipLoc:string,itemTexture:number,sellPrice:number,classID:integer,subclassID:integer,bindType:integer,expacID:integer,setID:integer,isCraftingReagent:boolean)

    local itemsToWaitFor = {} ---@type table<number, ItemInfoRdyFunc[]>
    local itemsWaitedOn = 0

    ---@param itemId integer
    ---@param success boolean
    local function OnItemInfoReceived(itemId, success)
        Env:PrintDebug("Item data for item " .. itemId .. " received. Success:", success)
        itemsWaitedOn = itemsWaitedOn - 1
        local cbs = itemsToWaitFor[itemId]
        if cbs then
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent =
                C_Item.GetItemInfo(itemId)
            for _, cb in ipairs(cbs) do
                cb(itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc,
                    itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent)
            end
        end
        if itemsToWaitFor == 0 then
            Env:UnregisterEvent("ITEM_DATA_LOAD_RESULT", OnItemInfoReceived)
        end
    end

    ---Trigger callback with GetItemInfo() data when it is available on the client.
    ---@param itemId integer
    ---@param onReady ItemInfoRdyFunc
    Env.Item.DoWhenItemInfoReady = function(itemId, onReady)
        if not C_Item.DoesItemExistByID(itemId) then
            Env:PrintError(L["Invalid item Id given to DoWhenItemInfoReady! %d"]:format(itemId))
            ---@diagnostic disable-next-line: missing-parameter
            onReady()
            return
        end

        if C_Item.IsItemDataCachedByID(itemId) then
            onReady(C_Item.GetItemInfo(itemId))
            return
        end

        Env:PrintDebug("Item info for item " .. itemId .. " was not ready, waiting for data from server.")
        itemsToWaitFor[itemId] = itemsToWaitFor[itemId] or {}
        table.insert(itemsToWaitFor[itemId], onReady)
        if itemsWaitedOn == 0 then
            Env:RegisterEvent("ITEM_DATA_LOAD_RESULT", OnItemInfoReceived)
        end
        C_Item.RequestLoadItemDataByID(itemId)
        itemsWaitedOn = itemsWaitedOn + 1
    end
end

---@type table<string, integer|integer[]|nil>
local INVTYPE_TO_SLOTS = {
    -- INVTYPE_NON_EQUIP = nil,
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_BODY = 4,
    INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_SHIELD = 17,
    INVTYPE_RANGED = Env.IS_CLASSIC and 18 or 16,
    INVTYPE_CLOAK = 15,
    INVTYPE_2HWEAPON = 16,
    -- INVTYPE_BAG = nil,
    INVTYPE_TABARD = 19,
    INVTYPE_ROBE = 5,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 16,
    INVTYPE_HOLDABLE = 17,
    INVTYPE_AMMO = 0,
    INVTYPE_THROWN = 16,
    INVTYPE_RANGEDRIGHT = 16,
    -- INVTYPE_QUIVER
    INVTYPE_RELIC = 18,
    -- INVTYPE_PROFESSION_TOOL = { 20, 23 }
    -- INVTYPE_PROFESSION_GEAR = { 21, 22, 24, 25 }
}

---Get currently equipped items for inventory type.
---@param invType string
---@return string? item1Link
---@return string? item2Link If slot is ring, weapon, or trinket this will be the 2nd one.
function Env.Item.GetCurrentlyEquippedItem(invType)
    local slotOrSlots = INVTYPE_TO_SLOTS[invType]
    if not slotOrSlots then return end
    if type(slotOrSlots) == "number" then
        return GetInventoryItemLink("player", slotOrSlots)
    end
    local link1 = GetInventoryItemLink("player", slotOrSlots[1])
    local link2 = GetInventoryItemLink("player", slotOrSlots[2])
    return link1, link2
end

---Get the class restriction string on an item, if it has one.
---@param itemLink string
---@return string? #The localized "Classes: ClassA, ClassB" string, nil if the item has no class restriction.
function Env.Item.GetItemClassRestrictionString(itemLink)
    local classRestrictionPattern = ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)") -- Classes: %s -> Classes: (.+)
    scanTip:ClearLines()
    scanTip:SetHyperlink(itemLink)
    for i = scanTip:NumLines(), 1, -1 do
        ---@type FontString|nil
        local left = _G[TOOLTIP_NAME .. "TextLeft" .. i]
        if left then
            local text = left:GetText() or ""
            local classListString = text:match(classRestrictionPattern)
            if classListString then
                return classListString
            end
        end
    end
end
