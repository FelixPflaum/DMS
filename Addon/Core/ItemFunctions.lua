---@class AddonEnv
local DMS = select(2, ...)

DMS.Item = {}

---@param itemLink string
---@return integer|nil
function DMS.Item:GetIdFromLink(itemLink)
    local match = itemLink:match("|Hitem:(%d+):")
    if match then
        local num = tonumber(match)
        if num then
            return math.floor(num)
        end
    end
end
