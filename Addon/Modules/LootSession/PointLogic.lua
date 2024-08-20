---@class AddonEnv
local Env = select(2, ...)

local PointLogic = {}
Env.PointLogic = PointLogic

---Check if roll should be counted as a points roll. Returns false and the response if it's not a point response to begin with.
---@param pointCount integer
---@param response LootResponse
---@param responseList LootResponse[]
---@param minPoints integer The minimum point value to use point rolls.
---@return boolean doesCount True if roll can be treated as a point roll.
---@return LootResponse countsAs Response the roll should be treated as. Can be input resoponse if not point roll or valid points roll.
---@return "sanityToLow"|nil reason Reason for why it doesn't count as a point roll.
function PointLogic.DoesRollCountAsPointRoll(pointCount, response, responseList, minPoints)
    if not response.isPointsRoll then
        return false, response, nil
    end
    if pointCount < minPoints then
        -- Just use the next highest response.
        local replacement = responseList[response.id - 1]
        return false, replacement, "sanityToLow"
    end
    return true, response
end

---Remove flat and percentage value from a value. Floors result.
---@param val integer
---@param flat integer
---@param pct integer
local function RemoveFlatAndPctFromValue(val, flat, pct)
    local mult = 1 - (pct / 100)
    return math.floor((val - flat) * mult)
end

---@alias DeductReason
---| "contested" Other point or need rolls exist for the item.
---| "uncontested" This is the only need roll on the item
---| "notPointRoll" Is no point roll, nothing should be done.

---Get how many points should be removed from the given winner.
---@param hostItem SessionHost_Item
---@param winnerItemResponse SessionHost_ItemResponse
---@param winnerCurrentPoints integer
---@return integer? pointsToDeduct The flat and pct points to remove, nil if no points should be removed.
---@return DeductReason reason
function PointLogic.ShouldDeductPoints(hostItem, winnerItemResponse, winnerCurrentPoints)
    local sessionSettings = Env.settings.lootSession
    local removeCompetition = sessionSettings.pointsRemoveIfCompetition
    local removeUncontested = sessionSettings.pointsRemoveIfSoloRoll

    if not winnerItemResponse.response or not winnerItemResponse.response.isPointsRoll then
        return nil, "notPointRoll"
    end

    -- Look for another point or need roll
    for candidateName, itemResponse in pairs(hostItem.responses) do
        if candidateName ~= winnerItemResponse.candidate.name then
            local ir = itemResponse.response
            -- Have other need or point roll.
            if ir and (ir.isNeedRoll or ir.isPointsRoll) then
                local removedPoints = winnerCurrentPoints - RemoveFlatAndPctFromValue(winnerCurrentPoints, removeCompetition.flat, removeCompetition.pct)
                return removedPoints, "contested"
            end
        end
    end

    local removedPoints = winnerCurrentPoints - RemoveFlatAndPctFromValue(winnerCurrentPoints, removeUncontested.flat, removeUncontested.pct)
    return removedPoints, "uncontested"
end
