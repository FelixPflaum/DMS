---@type string
local addonName = select(1, ...)
---@class AddonEnv
local Env = select(2, ...)

local LibWindow = LibStub("LibWindow-1.1")
local LibDialog = LibStub("LibDialog-1.1")
local L = Env:GetLocalization()
local ScrollingTable = LibStub("ScrollingTable") ---@type LibScrollingTable
local LootCandidateStatus = Env.Session.LootCandidateStatus

local GetImagePath = Env.UI.GetImagePath
local ColorByClassId = Env.UI.ColorByClassId
local DoWhenItemInfoReady = Env.Item.DoWhenItemInfoReady
local ColorStringFromArray = Env.UI.ColorStringFromArray
local DoesRollCountAsPointRoll = Env.PointLogic.DoesRollCountAsPointRoll

local Host = Env.SessionHost
local Client = Env.SessionClient

---Is host with the same guid as client running.
local function IsHosting()
    return Client.guid == Host.guid and Host.isRunning
end

local frame ---@type SessionWindowFrame
local itemSelectIcons = {} ---@type IconButon[]
local selectedItemGuid ---@type string|nil

---@class (exact) SessionWindowContextMenuFrame : MSA_DropDownMenuFrame
---@field selectedItemResponse SessionClient_ItemResponse? The selected item response the context menu is open for.
local contextMenuFrame = MSA_DropDownMenu_Create("DMSSessionTableContextMenu", UIParent)

local TABLE_INDICES = {
    ICON = 1,
    NAME = 2,
    RESPONSES = 3,
    ROLL = 4,
    SANITY = 5,
    TOTAL = 6,
    CURRENT_GEAR1 = 7,
    CURRENT_GEAR2 = 8,
}

---------------------------------------------------------------------------
--- Frame Functions
---------------------------------------------------------------------------

---Update the session item shown in the window.
local function UpdateShownItem()
    local item = selectedItemGuid and Client.items[selectedItemGuid]

    if not item then
        frame.ItemInfoIcon:SetItemData()
        frame.ItenInfoItemName:SetText("")
        frame.ItemInfoItemInfo:SetText("")
        frame.st:SetData({}, true)
        return
    end

    frame.ItemInfoIcon:SetItemData(item.itemId)
    DoWhenItemInfoReady(item.itemId,
        function(_, itemLink, _, _, _, _, itemSubType, _, itemEquipLoc, _, _, classID, subclassID)
            frame.ItenInfoItemName:SetText(itemLink)
            frame.ItemInfoItemInfo:SetText(Env.UI.GetItemTypeString(classID, subclassID, itemSubType, itemEquipLoc))
        end)

    local tableData = {}
    for _, itemResponse in pairs(item.responses) do
        local points = 0
        if itemResponse.response and itemResponse.response.isPointsRoll then
            points = itemResponse.candidate.currentPoints
            if item.awarded and item.awarded.pointsSnapshot and item.awarded.pointsSnapshot[itemResponse.candidate.name] then
                points = item.awarded.pointsSnapshot[itemResponse.candidate.name]
            end
        end
        local roll = itemResponse.roll or 0
        local total = points ~= 0 and roll + points or 0
        ---@type ResponseTableRowData
        local rowData = {
            itemResponse.candidate.classId,
            itemResponse.candidate,
            itemResponse,
            roll, points, total,
            itemResponse.currentItem and itemResponse.currentItem[1],
            itemResponse.currentItem and itemResponse.currentItem[2],
        }
        table.insert(tableData, rowData)
    end
    frame.st.item = item
    frame.st:SetData(tableData, true)

    frame.UpdateItemStatus(item)
end

local dialogData = {
    text = L["Do you want to abort the loot session?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Abort"],
            on_click = function()
                Host:Destroy()
                frame:Hide()
            end
        },
        {
            text = L["Minimize"],
            on_click = function() frame:Hide() end
        },
    },
}

local function Script_OnCloseClicked()
    if IsHosting() then
        if not LibDialog:ActiveDialog(dialogData) then
            LibDialog:Spawn(dialogData)
        end
    else
        frame:Hide()
        if Client.isRunning then
            Env:PrintWarn(L["Session is still running. You can reopen the window with /dms open"])
        end
    end
end

---@param guid string
local function Script_ItemSelectClicked(guid)
    MSA_CloseDropDownMenus()
    selectedItemGuid = guid
    UpdateShownItem()
    for _, v in ipairs(itemSelectIcons) do
        if v:GetArg() == selectedItemGuid then
            v:ShowBorder(true)
        else
            v:ShowBorder(false)
        end
    end
end

---@type ST_CellUpdateFunc
local function Script_TableRightClick(rowFrame, cellFrame, data, cols, row, realrow, column, table, button)
    if IsHosting() and button == "RightButton" and row then
        if MSA_DropDownList1:IsShown() then
            MSA_ToggleDropDownMenu(1, nil, contextMenuFrame)
        end

        local itemResponse = data[realrow][TABLE_INDICES.RESPONSES] ---@type SessionClient_ItemResponse
        if itemResponse.status == LootCandidateStatus.veiled then return false end
        contextMenuFrame.selectedItemResponse = itemResponse

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        MSA_DropDownMenu_SetAnchor(contextMenuFrame, x / scale, y / scale, "TOPLEFT", UIParent, "BOTTOMLEFT")
        MSA_ToggleDropDownMenu(1, nil, contextMenuFrame)
        MSA_DropDownMenu_StartCounting(contextMenuFrame)
    end
    return false
end

local function UpdateItemSelect()
    ---@type SessionClient_Item[]
    local ordered = {}
    for _, item in pairs(Client.items) do
        table.insert(ordered, item)
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    for k, item in ipairs(ordered) do
        local btn = itemSelectIcons[k]
        btn:SetItemData(item.itemId, item.guid)
        if item.awarded then
            btn:ShowStatus("checked")
        elseif item.endTime > time() then
            btn:ShowStatus("roll")
        else
            btn:ShowStatus()
        end
        if item.guid == selectedItemGuid then
            btn:ShowBorder(true)
        else
            btn:ShowBorder(false)
        end
        btn:SetDesaturated(item.veiled)
        btn:Show()
    end

    for i = #ordered + 1, #itemSelectIcons do
        itemSelectIcons[i]:Hide()
    end
end

local function Script_StopRollClick()
    if not IsHosting() or not selectedItemGuid then return end
    local stoppedItem = Host:ItemStopRoll(selectedItemGuid)
    MSA_CloseDropDownMenus()
    if stoppedItem then
        local _, itemLink = C_Item.GetItemInfo(stoppedItem.itemId)
        Host:SendMessageToTargetChannel(L["Stopped roll for item %s!"]:format(itemLink))
    end
end

---@param self SessionWindowContextMenuFrame
---@param candidateName string
---@param arg2 any
local function Script_AwardClick(self, candidateName, arg2)
    if not IsHosting() or not selectedItemGuid then return end
    local item = Client.items[selectedItemGuid]
    local itemResp = Client.items[selectedItemGuid].responses[candidateName]
    if not item or not itemResp then return end
    local errMsg, responseUsed, pointsUsed, pointUsageReason = Host:AwardItem(item.guid, candidateName)
    MSA_CloseDropDownMenus()
    if errMsg then
        Env:PrintError(L["Awarding item failed!"])
        Env:PrintError(errMsg)
    else
        local reasonStr = responseUsed and responseUsed.displayString or itemResp.status.displayString
        DoWhenItemInfoReady(item.itemId, function(_, itemLink)
            if pointsUsed then
                Host:SendMessageToTargetChannel(L["Awarded %s to %s for %s! Removed %d sanity."]:format(itemLink, candidateName,
                    reasonStr, pointsUsed) .. " " .. pointUsageReason)
            else
                Host:SendMessageToTargetChannel(L["Awarded %s to %s for %s!"]:format(itemLink, candidateName, reasonStr))
            end
        end)
    end
end

---@param self SessionWindowContextMenuFrame
---@param candidateName string
---@param arg2 any
local function Script_RevokeAwardClick(self, candidateName, arg2)
    if not IsHosting() or not selectedItemGuid then return end
    local item = Client.items[selectedItemGuid]
    if not item then return end
    local errMsg, pointsReturned = Host:RevokeAwardItem(item.guid, candidateName)
    MSA_CloseDropDownMenus()
    if errMsg then
        Env:PrintError(L["Revoking awarded item failed!"])
        Env:PrintError(errMsg)
    else
        DoWhenItemInfoReady(item.itemId, function(_, itemLink)
            if pointsReturned then
                Host:SendMessageToTargetChannel(L["Revoked award of %s from %s! Refunded %d sanity."]:format(itemLink,
                    candidateName, pointsReturned))
            else
                Host:SendMessageToTargetChannel(L["Revoked award of %s from %s!"]:format(itemLink, candidateName))
            end
        end)
    end
end

---@param self SessionWindowContextMenuFrame
---@param candidateName string
---@param responseId integer
local function Script_ChanceChoiceClick(self, candidateName, responseId)
    if not IsHosting() or not selectedItemGuid then return end
    local resp = Client.responses:GetResponse(responseId)
    local item = Client.items[selectedItemGuid]
    if not resp or not item then return end
    local errMsg = Host:SetItemResponse(selectedItemGuid, candidateName, responseId, true)
    MSA_CloseDropDownMenus()
    if errMsg then
        Env:PrintError(L["Changing roll choice failed:"])
        Env:PrintError(errMsg)
    else
        DoWhenItemInfoReady(item.itemId, function(_, itemLink)
            Host:SendMessageToTargetChannel(L["Response of %s for %s was changed to %s!"]:format(candidateName, itemLink,
                resp.displayString))
        end)
    end
end

---------------------------------------------------------------------------
--- Create Frames
---------------------------------------------------------------------------

local TABLE_ROW_HEIGHT = 18
local ITEM_SELECT_MAX_PER_COLUMN = 9
local ITEM_SELECT_ICON_SIZE = 40
local ITEM_SELECT_ICON_OFFSET_X = -10
local ITEM_SELECT_ICON_OFFSET_Y = -2

---@param f SessionWindowFrame
local function CreateStatusHeaders(f)
    ---@param anchorFrame WoWFrame
    local function ShowCandidateTooltip(anchorFrame)
        local tooltipText = ""
        local grey = "FF777777"
        for _, v in pairs(Client.candidates) do
            local nameStr = v.name
            if v.leftGroup then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Left group"] .. ")|r"
            elseif v.isOffline then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Offline"] .. ")|r"
            elseif not v.isResponding then
                nameStr = "|c" .. grey .. nameStr .. " (" .. L["Not responding"] .. ")|r"
            else
                nameStr = ColorByClassId(nameStr, v.classId)
            end
            tooltipText = tooltipText .. nameStr .. "\n"
        end
        GameTooltip:SetOwner(anchorFrame, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(tooltipText)
    end

    local fontLabel = "GameTooltipTextSmall"
    local fontValue = fontLabel

    local hostNameLabel = f:CreateFontString(nil, "OVERLAY", fontLabel)
    hostNameLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 65, -6)
    hostNameLabel:SetText(L["Host:"])

    local hostName = f:CreateFontString(nil, "OVERLAY", fontValue)
    hostName:SetPoint("TOPLEFT", hostNameLabel, "TOPRIGHT", 10, 0)
    hostName:SetText("---")

    local clientsStatus = f:CreateFontString(nil, "OVERLAY", fontValue)
    clientsStatus:SetPoint("TOPRIGHT", f, "TOPRIGHT", -35, -6)
    clientsStatus:SetText("---")
    clientsStatus:SetScript("OnEnter", ShowCandidateTooltip)
    clientsStatus:SetScript("OnLeave", GameTooltip_Hide)

    local sessionStatus = f:CreateFontString(nil, "OVERLAY", fontValue)
    sessionStatus:SetPoint("TOPRIGHT", clientsStatus, "TOPLEFT", -20, 0)
    sessionStatus:SetText("---")

    -- Event Hooks

    Client.OnStart:RegisterCallback(function()
        hostName:SetText(Client.hostName)
        sessionStatus:SetText("|cFF44FF44" .. L["Running"])
    end)

    Client.OnEnd:RegisterCallback(function()
        sessionStatus:SetText("|cFFFFFF44" .. L["Ended"])
    end)

    Client.OnCandidateUpdate:RegisterCallback(function()
        local count = 0
        local ready = 0
        for _, candidate in pairs(Client.candidates) do
            count = count + 1
            if candidate.isResponding and not candidate.isOffline and not candidate.leftGroup then
                ready = ready + 1
            end
        end
        local text = ready .. "/" .. count
        if ready < count then
            text = "|cFFFFFF44" .. text
        end
        clientsStatus:SetText(text)
    end)
end

do
    local info = { text = "text not set" } ---@type MSA_InfoTable

    local function ContextAddSpacer(level)
        wipe(info)
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        MSA_DropDownMenu_AddButton(info, level)
    end

    ---@param self SessionWindowContextMenuFrame
    ---@param level integer
    local function FillContextMenu(self, level)
        local item = selectedItemGuid and Client.items[selectedItemGuid]
        local itemResponse = self.selectedItemResponse
        if not itemResponse then
            MSA_CloseDropDownMenus()
            return
        end

        if level == 1 then
            wipe(info)
            info.text = ColorByClassId(itemResponse.candidate.name, itemResponse.candidate.classId)
            info.isTitle = true
            info.disabled = true
            info.notCheckable = true
            MSA_DropDownMenu_AddButton(info, level)

            ContextAddSpacer()

            if item then
                local isAwarded = item.awarded ~= nil
                local canAward = not isAwarded and itemResponse.response and
                    itemResponse.response.id >= Env.Session.REPSONSE_ID_FIRST_CUSTOM
                if time() < item.endTime then
                    wipe(info)
                    info.text = "|cFFFF4444" .. L["Stop roll now!"] .. "|r"
                    info.notCheckable = true
                    info.func = Script_StopRollClick
                    MSA_DropDownMenu_AddButton(info, level)
                    canAward = false
                end
                if not item.awarded or item.awarded.candidateName ~= itemResponse.candidate.name then
                    wipe(info)
                    info.text = L["Award"]
                    info.notCheckable = true
                    info.disabled = not canAward
                    info.func = Script_AwardClick
                    info.arg1 = itemResponse.candidate.name
                    MSA_DropDownMenu_AddButton(info, level)
                else
                    wipe(info)
                    info.text = L["Revoke Award"]
                    info.notCheckable = true
                    info.func = Script_RevokeAwardClick
                    info.arg1 = itemResponse.candidate.name
                    MSA_DropDownMenu_AddButton(info, level)
                end

                wipe(info)
                info.text = L["Change Choice"]
                info.notCheckable = true
                info.hasArrow = true
                info.disabled = isAwarded
                info.value = "CHANGE_CHOICE"
                MSA_DropDownMenu_AddButton(info, level)
            else
                Env:PrintError("Item could not be found when opening context menu!")
            end

            ContextAddSpacer()

            wipe(info)
            info.text = L["Close"]
            info.notCheckable = true
            info.func = function() MSA_CloseDropDownMenus() end
            MSA_DropDownMenu_AddButton(info, level)
        elseif level == 2 then
            if MSA_DROPDOWNMENU_MENU_VALUE == "CHANGE_CHOICE" then
                for i = #Client.responses.responses, 1, -1 do
                    local res = Client.responses.responses[i]
                    if not res.noButton then
                        wipe(info)
                        info.text = ColorStringFromArray(res.color, res.displayString)
                        info.notCheckable = true
                        info.func = Script_ChanceChoiceClick
                        info.arg1 = itemResponse.candidate.name
                        info.arg2 = res.id
                        MSA_DropDownMenu_AddButton(info, level)
                    end
                end
            end
        end
    end

    MSA_DropDownMenu_Initialize(contextMenuFrame, FillContextMenu, "MENU")
end

local TABLE_DEF ---@type ST_ColDef[]
do
    ---Update function for the class icon cell.
    ---@type ST_CellUpdateFunc
    local function CellUpdateClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        local classId = data[realrow][column]
        if classId then
            cellFrame:SetNormalTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
            local texCoords = CLASS_ICON_TCOORDS[select(2, GetClassInfo(classId))]
            if not texCoords then
                print(data[realrow][TABLE_INDICES.NAME].name, classId)
            end
            cellFrame:GetNormalTexture():SetTexCoord(unpack(texCoords))
        end
    end

    ---Update function for the gear icon cell.
    ---@type ST_CellUpdateFunc
    local function CellUpdateGearIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        local itemLink = data[realrow][column] ---@type string?
        if not itemLink then
            cellFrame:ClearNormalTexture()
            cellFrame:SetScript("OnEnter", nil)
            return
        end
        local itemId = Env.Item.GetIdFromLink(itemLink)
        local icon = itemId and GetItemIcon(itemId)
        cellFrame:SetNormalTexture(icon or [[Interface/Icons/inv_misc_questionmark]])
        cellFrame:SetScript("OnEnter", function() Env.UI.ShowItemTooltip(cellFrame, itemLink) end)
        cellFrame:SetScript("OnLeave", GameTooltip_Hide)
    end

    ---Update function for the candidate name cell.
    ---@type ST_CellUpdateFunc
    local function CellUpdateName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        local candidate = data[realrow][column] ---@type SessionClient_Candidate
        cellFrame.text:SetText(ColorByClassId(candidate.name, candidate.classId))
    end

    ---Update function for the response/status cell.
    ---@type ST_CellUpdateFunc
    local function CellUpdateResponse(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
        if not fShow then return end
        local item = selectedItemGuid and Client.items[selectedItemGuid]
        local itemResponse = data[realrow][column] ---@type SessionClient_ItemResponse
        -- Check if the item or any of its duplicates were awarded to this player.
        if item then
            local candidateName = itemResponse.candidate.name
            local awardCountThisPlayer = 0
            local awardCountAll = 0
            local awardedThis = false
            local awardResponse = nil ---@type LootResponse|nil
            Client:DoForEachRelatedItem(item, true, function(relatedItem, isThis)
                if relatedItem.awarded then
                    awardCountAll = awardCountAll + 1
                    if relatedItem.awarded.candidateName == candidateName then
                        awardCountThisPlayer = awardCountThisPlayer + 1
                        awardResponse = awardResponse or relatedItem.awarded.usedResponse
                        if isThis then
                            awardedThis = true
                            awardResponse = relatedItem.awarded.usedResponse -- Prioritize reason for this item. TODO: This sucks
                        end
                    end
                end
            end)
            -- Item was awarded to this player at least one time.
            if awardCountThisPlayer > 0 then
                local respString = "???"
                if awardResponse then
                    respString = ColorStringFromArray(awardResponse.color, awardResponse.displayString)
                elseif itemResponse.response then
                    respString = ColorStringFromArray(itemResponse.response.color, itemResponse.response.displayString)
                end
                local txt ---@type string
                if awardCountThisPlayer > 1 then
                    txt = L["Awarded (%s) (%dx)"]:format(respString, awardCountThisPlayer)
                else
                    txt = L["Awarded (%s)"]:format(respString)
                end
                if awardCountAll > awardCountThisPlayer and awardedThis then
                    txt = "> " .. txt .. " <"
                end
                cellFrame.text:SetText(txt)
                return
            end
        end
        -- Set response or status as text
        if itemResponse.response then
            -- Set different display if point roll is treated as another roll.
            if item and itemResponse.response.isPointsRoll then
                local points = data[realrow][TABLE_INDICES.SANITY] ---@type integer
                local doesCount, respReplace = DoesRollCountAsPointRoll(points, itemResponse.response, Client.responses.responses, Client.pointsMinForRoll)
                if not doesCount then
                    cellFrame.text:SetText(L["%s (Counts as %s)"]:format(
                        ColorStringFromArray(itemResponse.response.color, itemResponse.response.displayString),
                        ColorStringFromArray(respReplace.color, respReplace.displayString)))
                    return
                end
            end
            cellFrame.text:SetText(ColorStringFromArray(itemResponse.response.color, itemResponse.response.displayString))
        else
            cellFrame.text:SetText(ColorStringFromArray(itemResponse.status.color, itemResponse.status.displayString))
        end
    end

    ---Update function for roll cell.
    ---@type ST_CellUpdateFunc
    local function CellUpdateShowIfNotZero(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, st)
        ---@cast st SessionWindowScrollingTable
        if not fShow then return end
        local value = data[realrow][column] ---@type number|nil
        if value and value ~= 0 then
            cellFrame.text:SetText(tostring(value))
        else
            cellFrame.text:SetText("")
        end
    end

    ---Update function for points and total cells. Will color "frozen" if point snapshot exists.
    ---@type ST_CellUpdateFunc
    local function CellUpdatePointsAndTotal(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, st)
        ---@cast st SessionWindowScrollingTable
        if not fShow then return end
        local value = data[realrow][column] ---@type number|nil
        cellFrame:ClearNormalTexture()
        if value and value ~= 0 then
            local valueString = tostring(value)
            local pointsAreSnapshotted = st.item and st.item.awarded and st.item.awarded.pointsSnapshot
            if pointsAreSnapshotted then
                valueString = "|cFF70acc0" .. valueString .. "|r"
            elseif column == TABLE_INDICES.SANITY and row > 1 then
                local maxRange = Env.settings.lootSession.pointsMaxRange
                -- No need to show or do anything if rolls can't influence the result anyways.
                if maxRange < 100 then
                    local pointsAbove = data[st.filtered[row - 1]][column]
                    if pointsAbove - value > maxRange then
                        cellFrame:SetNormalTexture(GetImagePath("downmarker.png"))
                        local tex = cellFrame:GetNormalTexture()
                        tex:ClearAllPoints()
                        tex:SetSize(32, 8)
                        tex:SetPoint("TOPRIGHT", 0, -5)
                    end
                end
            end
            cellFrame.text:SetText(valueString)
        else
            cellFrame.text:SetText("")
        end
    end

    ---Sort function for the name column.
    ---@param st ST_ScrollingTable
    ---@param rowa integer
    ---@param rowb integer
    ---@param sortbycol integer
    local function SortCandidate(st, rowa, rowb, sortbycol)
        local column = st.cols[sortbycol]
        local a, b = st.data[rowa][sortbycol], st.data[rowb][sortbycol] ---@type SessionClient_Candidate, SessionClient_Candidate
        if a.name == b.name then
            if column.sortnext then
                local nextcol = st.cols[column.sortnext]
                if not (nextcol.sort) then
                    if nextcol.comparesort then
                        return nextcol.comparesort(st, rowa, rowb, column.sortnext)
                    else
                        return st:CompareSort(rowa, rowb, column.sortnext)
                    end
                else
                    return false
                end
            else
                return false
            end
        else
            local direction = column.sort or column.defaultsort or ScrollingTable.SORT_DSC
            if direction == ScrollingTable.SORT_ASC then
                return a.name < b.name
            else
                return a.name > b.name
            end
        end
    end

    ---Returns a weight depending on status and selected response.
    ---@param status LootCandidateStatus
    ---@param response LootResponse|nil
    ---@param item SessionClient_Item
    local function GetResponseWeight(status, response, item)
        local REPSONSE_ID_FIRST_CUSTOM = Env.Session.REPSONSE_ID_FIRST_CUSTOM
        local weight = status.id
        if response then
            if response.id < REPSONSE_ID_FIRST_CUSTOM then
                -- Show pass and autopass below everything
                weight = -100 + response.id
            else
                -- Show other actual responses above any non-response status
                weight = 100 + response.id
            end
        end
        --[[ Client:DoForEachRelatedItem(item, true, function(relatedItem)
            if relatedItem.awarded and relatedItem.awarded.candidateName == resp.candidate.name then
                -- Show awarded row at the top, regardless of status or response
                weight = weight + 1000
                return true
            end
        end) ]]
        return weight
    end

    ---Sort function for responses.
    ---Cares for ordering point rolls correctly if they are not valid.
    ---Checks max point range and forwards to total column if equal.
    ---Forwards normal roll responses directly to the roll column for sortig equal responses.
    ---@param st SessionWindowScrollingTable
    ---@param rowa any
    ---@param rowb any
    ---@param sortbycol any
    local function SortResponse(st, rowa, rowb, sortbycol)
        local column = st.cols[sortbycol]
        ---@type SessionClient_ItemResponse, SessionClient_ItemResponse
        local itemResA, itemResB = st.data[rowa][sortbycol], st.data[rowb][sortbycol]
        local resA = itemResA.response
        local resB = itemResB.response

        if resA and resA.isPointsRoll then
            local aPoints = st.data[rowa][TABLE_INDICES.SANITY] ---@type integer
            local _, respToUse = DoesRollCountAsPointRoll(aPoints, resA, Client.responses.responses, Client.pointsMinForRoll)
            resA = respToUse
        end

        if resB and resB.isPointsRoll then
            local bPoints = st.data[rowb][TABLE_INDICES.SANITY] ---@type integer
            local _, respToUse = DoesRollCountAsPointRoll(bPoints, resB, Client.responses.responses, Client.pointsMinForRoll)
            resB = respToUse
        end

        local weightA = GetResponseWeight(itemResA.status, resA, st.item)
        local weightB = GetResponseWeight(itemResB.status, resB, st.item)

        if weightA == weightB then
            local nextcolIndex ---@type integer

            if resA and resA.isPointsRoll then
                local colIdxSanity = TABLE_INDICES.SANITY
                local columnSanity = st.cols[colIdxSanity]
                local pointsA, pointsB = st.data[rowa][colIdxSanity], st.data[rowb][colIdxSanity] ---@type integer, integer
                local maxDist = Env.settings.lootSession.pointsMaxRange
                -- Always treat equal if max range is higher than max roll diff (99)
                if maxDist > 99 or math.abs(pointsA - pointsB) <= maxDist then
                    nextcolIndex = TABLE_INDICES.TOTAL
                else
                    local direction = columnSanity.sort or columnSanity.defaultsort or ScrollingTable.SORT_DSC
                    if direction == ScrollingTable.SORT_ASC then
                        return pointsA < pointsB
                    else
                        return pointsA > pointsB
                    end
                end
            else
                nextcolIndex = TABLE_INDICES.ROLL
            end

            local nextcol = st.cols[nextcolIndex]
            if not (nextcol.sort) then
                if nextcol.comparesort then
                    return nextcol.comparesort(st, rowa, rowb, nextcolIndex)
                else
                    return st:CompareSort(rowa, rowb, nextcolIndex)
                end
            else
                return false
            end
        else
            local direction = column.sort or column.defaultsort or ScrollingTable.SORT_DSC
            if direction == ScrollingTable.SORT_ASC then
                return weightA < weightB
            else
                return weightA > weightB
            end
        end
    end

    ---@alias ResponseTableRowData [integer,SessionClient_Candidate,SessionClient_ItemResponse,integer,integer,integer,string?,string?]

    TABLE_DEF = {
        [TABLE_INDICES.ICON] = { name = "", width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateClassIcon },
        [TABLE_INDICES.NAME] = { name = L["Name"], width = 100, DoCellUpdate = CellUpdateName, comparesort = SortCandidate },
        [TABLE_INDICES.RESPONSES] = { name = L["Response"], width = 200, DoCellUpdate = CellUpdateResponse, sort = ScrollingTable.SORT_DSC, comparesort = SortResponse },
        [TABLE_INDICES.ROLL] = { name = L["Roll"], width = 40, DoCellUpdate = CellUpdateShowIfNotZero, sortnext = TABLE_INDICES.NAME },
        [TABLE_INDICES.SANITY] = { name = L["Sanity"], width = 40, DoCellUpdate = CellUpdatePointsAndTotal, sortnext = TABLE_INDICES.TOTAL },
        [TABLE_INDICES.TOTAL] = { name = L["Sum"], width = 40, DoCellUpdate = CellUpdatePointsAndTotal, sortnext = TABLE_INDICES.ROLL },
        [TABLE_INDICES.CURRENT_GEAR1] = { name = "E1", width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateGearIcon },
        [TABLE_INDICES.CURRENT_GEAR2] = { name = "E2", width = TABLE_ROW_HEIGHT, DoCellUpdate = CellUpdateGearIcon },
    }
end

local function CreateItemStatusDisplay()
    local W_HEIGHT = 32
    local wrapper = CreateFrame("Frame", nil, frame)
    wrapper:SetPoint("TOPRIGHT", -20, -27)
    wrapper:SetSize(100, W_HEIGHT)

    local icon = wrapper:CreateTexture(nil, "OVERLAY")
    icon:SetSize(W_HEIGHT, W_HEIGHT)
    icon:SetPoint("TOPRIGHT", 0, 0)

    local statusLabel = wrapper:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    statusLabel:SetPoint("RIGHT", icon, "LEFT", -30, 0)
    statusLabel:SetText("-")

    local statusText = wrapper:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    statusText:SetPoint("LEFT", statusLabel, "RIGHT", 3, 0)
    statusText:SetText("-")

    local lastState = "none" ---@type "none"|"awarded"|"timer"
    local itemForTimerUpdate = nil ---@type SessionClient_Item|nil

    local function TimerTextUpdateFunc()
        local now = time()
        if not itemForTimerUpdate or itemForTimerUpdate.endTime < now then
            wrapper:SetScript("OnUpdate", nil)
            itemForTimerUpdate = nil
            return
        end
        statusText:SetText(tostring(itemForTimerUpdate.endTime - now))
    end

    ---Update item status display.
    ---@param item SessionClient_Item
    ---@diagnostic disable-next-line: inject-field
    frame.UpdateItemStatus = function(item)
        if item.awarded then
            if lastState ~= "awarded" then
                icon:SetTexture("")
                statusLabel:SetText(L["Awarded to:"])
                lastState = "awarded"
                itemForTimerUpdate = nil
            end
            local cname = item.awarded.candidateName
            local classId = Client.candidates[cname] and Client.candidates[cname].classId or 1
            statusText:SetText(ColorByClassId(item.awarded.candidateName, classId))
        elseif item.endTime > time() then
            if lastState ~= "timer" then
                icon:SetTexture(GetImagePath("icon_die_trans.png"))
                statusLabel:SetText(L["Expires in:"])
                lastState = "timer"
            end
            if itemForTimerUpdate ~= item then
                itemForTimerUpdate = item
                wrapper:SetScript("OnUpdate", TimerTextUpdateFunc)
            end
        elseif lastState ~= "none" then
            icon:SetTexture("")
            statusLabel:SetText("")
            statusText:SetText("")
            itemForTimerUpdate = nil
            lastState = "none"
        end
    end
end

local function CreateWindow()
    ---@class SessionWindowFrame : ButtonFrameTemplate
    frame = CreateFrame("Frame", "DMSSessionWindow", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", 0, 0)
    frame:SetSize(600, 400)
    frame:SetClampedToScreen(true)
    ButtonFrameTemplate_HideButtonBar(frame)
    LibWindow:Embed(frame)
    frame:RegisterConfig(Env.settings.UI.SessionWindow) ---@diagnostic disable-line: undefined-field
    frame:SetScale(Env.settings.UI.SessionWindow.scale or 1.0)
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    frame:EnableMouse(true)
    frame:MakeDraggable() ---@diagnostic disable-line: undefined-field
    frame:SetScript("OnMouseWheel", function(f, d) if IsControlKeyDown() then LibWindow.OnMouseWheel(f, d) end end)
    frame.TitleText:SetText(addonName)
    frame.portrait:SetTexture(GetImagePath("logo.png"))
    frame.CloseButton:SetScript("OnClick", Script_OnCloseClicked)

    -- Item details header

    frame.ItemInfoIcon = Env.UI.CreateIconButton(frame, 35, true)
    frame.ItemInfoIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -25)

    frame.ItenInfoItemName = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.ItenInfoItemName:SetPoint("TOPLEFT", frame.ItemInfoIcon, "TOPRIGHT", 5, -3)

    frame.ItemInfoItemInfo = frame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    frame.ItemInfoItemInfo:SetPoint("TOPLEFT", frame.ItenInfoItemName, "BOTTOMLEFT", 0, -3)

    -- Response table

    ---@class SessionWindowScrollingTable : ST_ScrollingTable
    ---@field item SessionClient_Item
    frame.st = ScrollingTable:CreateST(TABLE_DEF, 15, TABLE_ROW_HEIGHT, nil, frame)
    frame.st.frame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", -1, -frame.st.head:GetHeight() - 4)
    frame.st:RegisterEvents({
        OnClick = Script_TableRightClick,
        OnEnter = function(_, _, data, _, row, realrow)
            if row then
                local candidate = data[realrow][TABLE_INDICES.NAME] ---@type SessionClient_Candidate
                if candidate then
                    frame.MoreInfoPanel:SetPlayer(candidate.name)
                end
            end
        end,
        OnLeave = function(_, _, data, _, row, realrow)
            if row then
                frame.MoreInfoPanel:SetPlayer()
            end
        end
    })

    frame:SetWidth(frame.st.frame:GetWidth() + 7)
    frame:SetHeight(frame.st.frame:GetHeight() + 86)

    CreateItemStatusDisplay()
    CreateStatusHeaders(frame)

    frame.MoreInfoPanel = Env.UI.CreateMoreInfoPanel(frame)
    frame.MoreInfoPanel.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
end

---@param index integer
local function CreateItemSelectIconIfMissing(index)
    if itemSelectIcons[index] then return end
    local newBtn = Env.UI.CreateIconButton(frame, ITEM_SELECT_ICON_SIZE)
    itemSelectIcons[index] = newBtn
    newBtn:SetOnClick(Script_ItemSelectClicked)
    if index == 1 then
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", ITEM_SELECT_ICON_OFFSET_X, 0)
    elseif math.fmod(index - 1, ITEM_SELECT_MAX_PER_COLUMN) == 0 then
        local column = math.ceil(index / ITEM_SELECT_MAX_PER_COLUMN)
        local columnOffset = ITEM_SELECT_ICON_OFFSET_X - (ITEM_SELECT_ICON_SIZE + 5) * (column - 1)
        newBtn:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnOffset, 0)
    else
        newBtn:SetPoint("TOP", itemSelectIcons[index - 1], "BOTTOM", 0, ITEM_SELECT_ICON_OFFSET_Y)
    end
end

---------------------------------------------------------------------------
--- Event Hooks
---------------------------------------------------------------------------

Env:OnAddonLoaded(CreateWindow)

local openDialogData = {
    text = L["A loot session started. Do you want to open the session window?"],
    on_cancel = function(self, data, reason) end,
    buttons = {
        {
            text = L["Yes"],
            on_click = function()
                frame:Show()
            end
        },
        {
            text = L["No"],
            on_click = function() end
        },
    },
}

Client.OnStart:RegisterCallback(function()
    selectedItemGuid = nil
    if not IsHosting() and not Env.settings.autoOpenOnStart == "yes" then
        if Env.settings.autoOpenOnStart == "no" then
            return
        end
        if not LibDialog:ActiveDialog(openDialogData) then
            LibDialog:Spawn(openDialogData)
        end
        return
    end
    frame:Show()
    frame:SetFrameLevel(888)
end)

Client.OnEnd:RegisterCallback(function()

end)

Client.OnCandidateUpdate:RegisterCallback(function()
    UpdateShownItem()
end)

Client.OnItemUpdate:RegisterCallback(function(item, isAwardEvent)
    if selectedItemGuid == nil then
        Env:PrintDebug("Setting shown item because no item selected.")
        selectedItemGuid = item.guid
    end
    local itemCount = Client:GetItemCount()
    for i = 1, itemCount do
        CreateItemSelectIconIfMissing(i)
    end
    UpdateItemSelect()
    Client:DoForEachRelatedItem(item, true, function(relatedItem)
        if relatedItem.guid == selectedItemGuid then
            UpdateShownItem()
            return true
        end
    end)

    -- After award, if item is selected and still selected 1s later, select next unawarded item in order.
    if isAwardEvent and item.guid == selectedItemGuid and Env.settings.autoSwitchToNextItem then
        C_Timer.NewTimer(0.5, function()
            MSA_CloseDropDownMenus()
            if item.guid == selectedItemGuid then
                local nextOrder = 99999999
                local nextItemGuid ---@type string?
                for _, it in pairs(Client.items) do
                    if it.order ~= item.order and it.order < nextOrder and not it.awarded then
                        nextOrder = it.order
                        nextItemGuid = it.guid
                    end
                end
                if nextItemGuid then
                    selectedItemGuid = nextItemGuid
                    UpdateItemSelect()
                    UpdateShownItem()
                end
            end
        end)
    end
end)

---------------------------------------------------------------------------
--- Slash Commands
---------------------------------------------------------------------------

Env:RegisterSlashCommand("open", L["Opens session window if a session is running."], function(args)
    if not Client.isRunning then
        Env:PrintError(L["No session is running!"])
        return
    end
    frame:Show()
end)

Env.UI:RegisterOnReset(function()
    local libWinConfig = Env.settings.UI.SessionWindow
    libWinConfig.x = 0
    libWinConfig.y = 0
    libWinConfig.point = "CENTER"
    frame:RestorePosition() ---@diagnostic disable-line: undefined-field
    libWinConfig.scale = 1.0
    frame:SetScale(1.0)
end)
