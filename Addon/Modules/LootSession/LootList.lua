---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

---@class (exact) LootList
local LootList = {}
Env.Session.LootList = LootList

---@alias LootListItem integer
---@type LootListItem[]
local itemList = {}

---@class LootlistAddEventEmitter
---@field RegisterCallback fun(self:LootlistAddEventEmitter, cb:fun(items:LootListItem[]))
---@field Trigger fun(self:LootlistAddEventEmitter, items:LootListItem[])
---@diagnostic disable-next-line: inject-field
LootList.OnListUpdate = Env:NewEventEmitter()

---Split multiple connected itemlinks.
---@param str string
---@return string[]
local function ItemLinkSplit(str)
    local links = {}
    ---@type integer|nil, integer|nil
    local startPos, endPos = 1, nil
    while startPos do
        if str:sub(1, 2) == "|c" then
            startPos, endPos = str:find("|c.-|r", startPos)
        else
            startPos = nil
        end
        if startPos then
            table.insert(links, str:sub(startPos, endPos))
            startPos = startPos + 1
        end
    end
    return links
end

---Get tradeable items from bags. Optionally only return numItems, sorted from lowest remaining time to highest.
---@param numItems number|nil
local function GetTradeableItemsFromBags(numItems)
    ---@type {itemId:integer, remainingTrageTimer:number}[]
    local items = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local remaining = Env.Item:GetTradeTimer(bag, slot, Enum.ItemQuality.Rare)
            if remaining then
                local iinfo = C_Container.GetContainerItemInfo(bag, slot)
                if iinfo then
                    table.insert(items, { itemId = iinfo.itemID, remainingTrageTimer = remaining })
                end
            end
        end
    end

    table.sort(items, function(a, b)
        return a.remainingTrageTimer < b.remainingTrageTimer
    end)

    if numItems then
        for i = #items, numItems, -1 do
            table.remove(items, i)
        end
    end

    return items
end

Env:RegisterSlashCommand("add", L["Add items to a session."], function(args)
    if not args[1] then
        local items = GetTradeableItemsFromBags()
        for _, v in ipairs(items) do
            table.insert(itemList, v.itemId)
        end
    elseif tonumber(args[1]) and tonumber(args[1]) < 50 then
        local items = GetTradeableItemsFromBags(tonumber(args[1]))
        for _, v in ipairs(items) do
            table.insert(itemList, v.itemId)
        end
    else
        for _, arg in ipairs(args) do
            local links = ItemLinkSplit(arg)
            for _, v in pairs(links) do
                local id = Env.Item:GetIdFromLink(v)
                if id then
                    table.insert(itemList, id)
                end
            end
        end
    end
    LootList.OnListUpdate:Trigger(itemList)
end)

---@param self any
---@param button string|"LeftButton"
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if IsAltKeyDown() then
        local itemInfo = C_Container.GetContainerItemInfo(self:GetParent():GetID(), self:GetID())
        if itemInfo then
            table.insert(itemList, itemInfo.itemID)
            print(#itemList)
            LootList.OnListUpdate:Trigger(itemList)
        end
    end
end)

-- Add current items in list to (new) session.
function LootList:AddListToSession()
    if #itemList == 0 then
        return
    end

    local hostSession = Env.Session.Host:GetSession()
    if not hostSession then
        local session, err = Env.Session.Host:Start("self")
        if not session or err then
            if err then Env:PrintError(err) end
            return
        end
        hostSession = session
    end
    for _, v in ipairs(itemList) do
        hostSession:ItemAdd(v)
    end

    itemList = {}
    LootList.OnListUpdate:Trigger(itemList)
end

---Does list currently contain items.
function LootList:HaveItems()
    return #itemList > 0
end

---Remove item at index.
---@param index integer
function LootList:Remove(index)
    if #itemList < index then return end
    table.remove(itemList, index)
    LootList.OnListUpdate:Trigger(itemList)
end
