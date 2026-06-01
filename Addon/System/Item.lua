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
    INVTYPE_RANGED = 18, -- TODO: Change to MH for addons that do not have ranged slot.
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

---@type table<integer,integer|integer[]>
local tokenToItem = {
    -- T4
    [29757] = INVSLOT_HAND,
    [29758] = INVSLOT_HAND,
    [29756] = INVSLOT_HAND,
    [29759] = INVSLOT_HEAD,
    [29761] = INVSLOT_HEAD,
    [29760] = INVSLOT_HEAD,
    [29764] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=29764/pauldrons-of-the-fallen-defender
    [29763] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=29763/pauldrons-of-the-fallen-champion
    [29762] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=29762/pauldrons-of-the-fallen-hero
    [29767] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=29767/leggings-of-the-fallen-defender
    [29766] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=29766/leggings-of-the-fallen-champion
    [29765] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=29765/leggings-of-the-fallen-hero
    [29755] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=29755/chestguard-of-the-fallen-hero
    [29754] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=29754/chestguard-of-the-fallen-champion
    [29753] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=29753/chestguard-of-the-fallen-defender
    [32385] = { INVSLOT_FINGER1, INVSLOT_FINGER2 }, -- https://www.wowhead.com/tbc/item=32385/magtheridons-head
    -- T5
    [30241] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=30241/gloves-of-the-vanquished-hero
    [30240] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=30240/gloves-of-the-vanquished-defender
    [30239] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=30239/gloves-of-the-vanquished-champion
    [30247] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=30247/leggings-of-the-vanquished-hero
    [30245] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=30245/leggings-of-the-vanquished-champion
    [30246] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=30246/leggings-of-the-vanquished-defender
    [30244] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30244/helm-of-the-vanquished-hero
    [30243] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30243/helm-of-the-vanquished-defender
    [30242] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30242/helm-of-the-vanquished-champion
    [30248] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=30248/pauldrons-of-the-vanquished-champion
    [30249] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=30249/pauldrons-of-the-vanquished-defender
    [30250] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=30250/pauldrons-of-the-vanquished-hero
    [30236] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30236/chestguard-of-the-vanquished-champion
    [30238] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30238/chestguard-of-the-vanquished-hero
    [30237] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=30237/chestguard-of-the-vanquished-defender
    [32405] = INVSLOT_NECK,                         -- https://www.wowhead.com/tbc/item=32405/verdant-sphere#starts
    -- T6
    [31097] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=31097/helm-of-the-forgotten-conqueror
    [31095] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=31095/helm-of-the-forgotten-protector
    [31096] = INVSLOT_HEAD,                         -- https://www.wowhead.com/tbc/item=31096/helm-of-the-forgotten-vanquisher
    [31102] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=31102/pauldrons-of-the-forgotten-vanquisher
    [31101] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=31101/pauldrons-of-the-forgotten-conqueror
    [31103] = INVSLOT_SHOULDER,                     -- https://www.wowhead.com/tbc/item=31103/pauldrons-of-the-forgotten-protector
    [31100] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=31100/leggings-of-the-forgotten-protector
    [31098] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=31098/leggings-of-the-forgotten-conqueror
    [31099] = INVSLOT_LEGS,                         -- https://www.wowhead.com/tbc/item=31099/leggings-of-the-forgotten-vanquisher
    [31091] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=31091/chestguard-of-the-forgotten-protector
    [31089] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=31089/chestguard-of-the-forgotten-conqueror
    [31090] = INVSLOT_CHEST,                        -- https://www.wowhead.com/tbc/item=31090/chestguard-of-the-forgotten-vanquisher
    [31092] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=31092/gloves-of-the-forgotten-conqueror
    [31093] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=31093/gloves-of-the-forgotten-vanquisher
    [31094] = INVSLOT_HAND,                         -- https://www.wowhead.com/tbc/item=31094/gloves-of-the-forgotten-protector
    [34848] = INVSLOT_WRIST,                        -- https://www.wowhead.com/tbc/item=34848/bracers-of-the-forgotten-conqueror
    [34851] = INVSLOT_WRIST,                        -- https://www.wowhead.com/tbc/item=34851/bracers-of-the-forgotten-protector
    [34852] = INVSLOT_WRIST,                        -- https://www.wowhead.com/tbc/item=34852/bracers-of-the-forgotten-vanquisher
    [34856] = INVSLOT_FEET,                         -- https://www.wowhead.com/tbc/item=34856/boots-of-the-forgotten-conqueror
    [34857] = INVSLOT_FEET,                         -- https://www.wowhead.com/tbc/item=34857/boots-of-the-forgotten-protector
    [34858] = INVSLOT_FEET,                         -- https://www.wowhead.com/tbc/item=34858/boots-of-the-forgotten-vanquisher
    [34854] = INVSLOT_WAIST,                        -- https://www.wowhead.com/tbc/item=34854/belt-of-the-forgotten-protector
    [34855] = INVSLOT_WAIST,                        -- https://www.wowhead.com/tbc/item=34855/belt-of-the-forgotten-vanquisher
    [34853] = INVSLOT_WAIST,                        -- https://www.wowhead.com/tbc/item=34853/belt-of-the-forgotten-conqueror
}

---Get currently equipped items for inventory type.
---@param invType string
---@param itemId integer
---@return string? item1Link
---@return string? item2Link If slot is ring, weapon, or trinket this will be the 2nd one.
function Env.Item.GetCurrentlyEquippedItem(invType, itemId)
    ---@type integer|integer[]|nil
    local slotOrSlots = nil

    if tokenToItem[itemId] then
        slotOrSlots = tokenToItem[itemId]
    elseif INVTYPE_TO_SLOTS[invType] then
        slotOrSlots = INVTYPE_TO_SLOTS[invType]
    else
        return
    end

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
