---@class AddonEnv
local Env = select(2, ...)

local L = Env:GetLocalization()

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
    local LF = Env.UI.LootWindow

    if not args[1] then
        local items = GetTradeableItemsFromBags()
        for _, v in ipairs(items) do
            LF:AddItem(v.itemId)
        end
    elseif tonumber(args[1]) and tonumber(args[1]) < 50 then
        local items = GetTradeableItemsFromBags(tonumber(args[1]))
        for _, v in ipairs(items) do
            LF:AddItem(v.itemId)
        end
    else
        for _, arg in ipairs(args) do
            local links = ItemLinkSplit(arg)
            for _, v in pairs(links) do
                local id = Env.Item:GetIdFromLink(v)
                if id then
                    LF:AddItem(id)
                end
            end
        end
    end

    if LF:HaveItems() then
        LF:Show()
    else
        Env:PrintWarn(L["No items added!"])
    end
end)
