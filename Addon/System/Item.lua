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
function Env.Item:GetIdFromLink(itemLink)
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
            Env:PrintError(L["Invalid item Id given to DoWhenItemInfoReady!"])
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
