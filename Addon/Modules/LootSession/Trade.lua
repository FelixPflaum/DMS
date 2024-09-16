---@class AddonEnv
local Env = select(2, ...)

local function LogDebug(...)
    Env:PrintDebug("Trade:", ...)
end

---@class (exact) Trade
local Trade = {}
Env.Trade = Trade

---@alias AwardedItem {itemId:integer, receiver:string}
---@type AwardedItem[]
local itemList = {}

---@class TradeItemsChangedEvent
---@field RegisterCallback fun(self:TradeItemsChangedEvent, cb:fun(items:AwardedItem[]))
---@field Trigger fun(self:TradeItemsChangedEvent, items:AwardedItem[])
---@diagnostic disable-next-line: inject-field
Trade.OnItemsChanged = Env:NewEventEmitter()

------------------------------------------------------------------------------------------------
--- Tradable item list.
------------------------------------------------------------------------------------------------

---Find item in tradable items list for receiver by item id.
---@param itemId integer
---@param receiver string
---@param excludeIndices table<integer,boolean>? Optionally exclude indices.
---@return integer? index
---@return AwardedItem?
local function FindTradeableItem(itemId, receiver, excludeIndices)
    for k, v in ipairs(itemList) do
        if v.itemId == itemId and v.receiver == receiver and
            (not excludeIndices or not excludeIndices[k]) then
            return k, v
        end
    end
end

---Add item to trade list.
---@param itemId integer
---@param receiver string
function Trade:AddItem(itemId, receiver)
    if receiver == UnitName("player") then return end
    table.insert(itemList, {
        itemId = itemId,
        receiver = receiver,
    })
    Trade.OnItemsChanged:Trigger(itemList)
    return true
end

---Remove item from trade list.
---@param itemId integer
---@param receiver string
function Trade:RemoveItem(itemId, receiver)
    local entryPos = FindTradeableItem(itemId, receiver)
    if not entryPos then return end
    table.remove(itemList, entryPos)
    Trade.OnItemsChanged:Trigger(itemList)
end

function Trade:Clear()
    itemList = {}
    Trade.OnItemsChanged:Trigger(itemList)
end

------------------------------------------------------------------------------------------------
--- Auto trading
------------------------------------------------------------------------------------------------

local TRADE_CAPACITY = 6
local PUT_IN_TRADE_DELAY = 0.15 -- No clue if needed, just went with something so it hopefully works without problems.

local currentTrade = nil ---@type {target:string, items:integer[]}|nil
local tradeOpen = false

---Get list of tradable (BoE or trade timer remaining) items from bags.
---@param receiver string Name of the receiving player.
---@param maxCount integer? Defaults to 6.
local function GetTradeableItemListForReceiver(receiver, maxCount)
    maxCount = maxCount or TRADE_CAPACITY
    local receiverItems = {} ---@type table<integer,integer> itemId -> count
    local itemsAdded = 0
    local items = {} ---@type {bag:integer, slot:integer}[]

    for _, v in ipairs(itemList) do
        if v.receiver == receiver then
            receiverItems[v.itemId] = receiverItems[v.itemId] and receiverItems[v.itemId] + 1 or 1
            itemsAdded = itemsAdded + 1
            if itemsAdded == maxCount then
                break
            end
        end
    end

    LogDebug("Have", itemsAdded, "items to trade for receiver", receiver)

    if itemsAdded > 0 then
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local iinfo = C_Container.GetContainerItemInfo(bag, slot)
                if iinfo then
                    local canTrade = not iinfo.isBound
                    if not canTrade then
                        local remaining = Env.Item:GetTradeTimer(bag, slot, Enum.ItemQuality.Rare)
                        canTrade = remaining ~= nil and remaining > 0
                    end
                    if canTrade and receiverItems[iinfo.itemID] and receiverItems[iinfo.itemID] > 0 then
                        table.insert(items, { bag = bag, slot = slot })
                        receiverItems[iinfo.itemID] = receiverItems[iinfo.itemID] - 1
                        LogDebug("Found item", iinfo.hyperlink, "for trade in bags")
                    end
                end
            end
        end
        LogDebug("Found", #items, "items to trade in bags")
    end

    return items
end

---Open trade if not already trading.
---@param unit string
function Trade:InitiateTrade(unit)
    if currentTrade == nil and not tradeOpen then
        if CheckInteractDistance(unit, 2) then
            InitiateTrade(unit)
        end
    end
end

Env:RegisterEvent("TRADE_SHOW", function()
    LogDebug("Trade opened")
    tradeOpen = true
    local target = TradeFrameRecipientNameText:GetText()
    if not target or target == "" then
        LogDebug("No trade target!")
        return
    end
    LogDebug("Trade target", target)

    local containerItemsToTrade = GetTradeableItemListForReceiver(target)

    if #containerItemsToTrade == 0 then
        return
    end

    currentTrade = {
        target = target,
        items = {},
    }

    -- Put items into trade window.
    for i = 1, #containerItemsToTrade do
        local thisItem = containerItemsToTrade[i]
        C_Timer.NewTimer(PUT_IN_TRADE_DELAY * i, function(t)
            local containerInfo = C_Container.GetContainerItemInfo(thisItem.bag, thisItem.slot)
            if not currentTrade then
                LogDebug("Trade was canceled, not adding item to trade.")
            elseif not containerInfo then
                LogDebug("Item", thisItem.bag, thisItem.slot, "is gone??")
            else
                LogDebug("Add item to trade", thisItem.bag, thisItem.slot, containerInfo.hyperlink)
                ClearCursor()
                C_Container.PickupContainerItem(thisItem.bag, thisItem.slot)
                ClickTradeButton(i)
            end
        end)
    end
end)

Env:RegisterEvent("TRADE_CLOSED", function()
    LogDebug("Trade closed")
    tradeOpen = false
end)

-- If trade accept state changes to accept (for any party) record items currently in trade window.
Env:RegisterEvent("TRADE_ACCEPT_UPDATE", function(playerAccepted, targetAccepted)
    LogDebug("Trade accept update")
    if currentTrade and (playerAccepted == 1 or targetAccepted == 1) then
        currentTrade.items = {}
        local listIndicesUsed = {} ---@type table<integer,boolean>
        for slot = 1, TRADE_CAPACITY do
            local itemLink = GetTradePlayerItemLink(slot)
            if itemLink then
                local itemId = Env.Item.GetIdFromLink(itemLink)
                if itemId then
                    local idx, entry = FindTradeableItem(itemId, currentTrade.target, listIndicesUsed)
                    if idx and entry then
                        LogDebug("Add item to current trade list:", slot, idx, entry.itemId, entry.receiver)
                        table.insert(currentTrade.items, entry.itemId)
                        listIndicesUsed[idx] = true
                    end
                end
            end
        end
    end
end)

local TRADE_FAIL_MSGS = {
    [ERR_TRADE_CANCELLED] = true,
    [ERR_TRADE_NOT_ON_TAPLIST] = true,
    [ERR_TRADE_QUEST_ITEM] = true,
    [ERR_TRADE_TARGET_BAG_FULL] = true,
    [ERR_TRADE_TARGET_DEAD] = true,
    [ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED] = true,
}

---On trade success remove items from list of trade items.
---Items removed here don't need to be the same indices added in TRADE_ACCEPT_UPDATE,
---it just needs to remove the correct count of items for each item Id, if multiple Ids
---for the same receiver exist at all.
---@param msg string
Env:RegisterEvent("UI_INFO_MESSAGE", function(errType, msg)
    if msg == ERR_TRADE_COMPLETE and currentTrade then
        LogDebug("Trade with", currentTrade.target, "completed, removing items from trade list.")
        for _, tradedItemId in ipairs(currentTrade.items) do
            for i = #itemList, 1, -1 do
                if itemList[i].receiver == currentTrade.target and itemList[i].itemId == tradedItemId then
                    table.remove(itemList, i)
                    LogDebug("Removed item", i, tradedItemId)
                end
            end
        end
        Trade.OnItemsChanged:Trigger(itemList)
        currentTrade = nil
    elseif TRADE_FAIL_MSGS[msg] then
        currentTrade = nil
        LogDebug("Trade failed:", msg)
    end
end)

Env:RegisterEvent("UI_ERROR_MESSAGE", function(errType, msg)
    if TRADE_FAIL_MSGS[msg] then
        currentTrade = nil
        LogDebug("Trade failed:", msg)
    end
end)
