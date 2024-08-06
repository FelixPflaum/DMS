---@class AddonEnv
local Env = select(2, ...)

Env.Item = {}

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
