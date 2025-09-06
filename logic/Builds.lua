-- Build planning and calculator logic
-- Overrides methods on the shared addon table.

local addon = _G.TalentCrafter or {}
_G.TalentCrafter = addon

local function currentCounts()
    if addon.CurrentRankCounts then return addon.CurrentRankCounts() end
    local counts = {}
    for _, id in ipairs(addon.pickOrder or {}) do counts[id] = (counts[id] or 0) + 1 end
    return counts
end

function addon:RevalidatePickOrder()
    local newOrder = {}
    local counts = {}
    local tabSpent = {[1] = 0, [2] = 0, [3] = 0}
    local function addCount(id)
        counts[id] = (counts[id] or 0) + 1
        local dash = string.find(id, "-")
        if dash then
            local t = tonumber(string.sub(id, 1, dash - 1))
            if t then tabSpent[t] = (tabSpent[t] or 0) + 1 end
        end
    end
    for _, id in ipairs(self.pickOrder or {}) do
        local dash = string.find(id, "-")
        if dash then
            local tab = tonumber(string.sub(id, 1, dash - 1))
            local idx = tonumber(string.sub(id, dash + 1))
            if tab and idx then
                local _, _, tier = GetTalentInfo(tab, idx)
                local requiredPoints = ((tier or 1) - 1) * 5
                local okTier = (tabSpent[tab] or 0) >= requiredPoints
                local pTier, pCol = GetTalentPrereqs(tab, idx)
                local okPrereq = true
                if pTier and pCol then
                    local preIndex = (addon.FindTalentByPosition and addon.FindTalentByPosition(tab, pTier, pCol))
                    local _, _, _, _, _, preMaxRank = GetTalentInfo(tab, preIndex)
                    local have = counts[tab .. "-" .. preIndex] or 0
                    okPrereq = preMaxRank and have >= preMaxRank
                end
                local _, _, _, _, _, maxRank = GetTalentInfo(tab, idx)
                local haveSelf = counts[id] or 0
                local okSelf = not maxRank or haveSelf < maxRank
                if okTier and okPrereq and okSelf then
                    tinsert(newOrder, id)
                    addCount(id)
                end
            end
        end
    end
    self.pickOrder = newOrder
end

function addon:UpdateCalculatorOverlays()
    local counts = currentCounts()
    local tabTotals = {[1] = 0, [2] = 0, [3] = 0}
    for k, v in pairs(counts) do
        local dash = string.find(k, "-")
        if dash then
            local t = tonumber(string.sub(k, 1, dash - 1))
            if t and tabTotals[t] then tabTotals[t] = tabTotals[t] + (v or 0) end
        end
    end
    local totalSpent = (tabTotals[1] + tabTotals[2] + tabTotals[3])
    for tab, t in pairs(addon.calcTalents or {}) do
        for idx, btn in pairs(t) do
            local id = tab .. "-" .. idx
            local _, _, tier, _, _, maxRank = GetTalentInfo(tab, idx)
            local r = counts[id] or 0
            btn._planned = r
            btn._maxRank = maxRank or 0
            local requiredPoints = ((tier or 1) - 1) * 5
            local spent = tabTotals[tab] or 0
            local pTier, pCol = GetTalentPrereqs(tab, idx)
            local prereqOK = true
            if pTier and pCol then
                local preIndex = (addon.FindTalentByPosition and addon.FindTalentByPosition(tab, pTier, pCol))
                local _, _, _, _, _, preMaxRank = GetTalentInfo(tab, preIndex)
                local have = counts[tab .. "-" .. preIndex] or 0
                prereqOK = preMaxRank and have >= preMaxRank
            end
            local capOK = totalSpent < 51
            local canPick = (r < (maxRank or 0)) and (spent >= requiredPoints) and prereqOK and capOK
            if btn.rankText then
                btn.rankText:SetText((r or 0) .. "/" .. (maxRank or 0))
                if r > 0 then
                    btn.rankText:SetTextColor(1.0, 0.82, 0.0)
                else
                    btn.rankText:SetTextColor(0.7, 0.72, 0.78)
                end
            end
            if r > 0 or canPick then
                if SetTexDesaturated then SetTexDesaturated(btn.icon, false) end
                if r == maxRank then btn.border:Show() else btn.border:Hide() end
            else
                if SetTexDesaturated then SetTexDesaturated(btn.icon, true) end
                btn.border:Hide()
            end
        end
        local tree = getglobal("TC_CalcTree" .. tab)
        if tree and tree.pointsText then tree.pointsText:SetText("Points: " .. (tabTotals[tab] or 0)) end
    end
    local _, classToken = UnitClass("player")
    local className = classToken or "CLASS"
    local left = 51 - (tabTotals[1] + tabTotals[2] + tabTotals[3])
    local calc = getglobal("TC_TalentCalculator")
    if calc and calc.summaryText then
        calc.summaryText:SetText(string.format("%s %d/%d/%d  |  Points left: %d",
            className, tabTotals[1] or 0, tabTotals[2] or 0, tabTotals[3] or 0, max(0, left)))
    end
end

function addon:OnTalentClick(tabIndex, talentIndex, ownerBtn)
    local reqTier, reqColumn = GetTalentPrereqs(tabIndex, talentIndex)
    if reqTier and reqColumn then
        local pre = addon.FindTalentByPosition and addon.FindTalentByPosition(tabIndex, reqTier, reqColumn)
        if pre then
            local preName, _, _, _, _, preMaxRank = GetTalentInfo(tabIndex, pre)
            local preId = tabIndex .. "-" .. pre
            local have = 0
            for _, v in ipairs(self.pickOrder or {}) do if v == preId then have = have + 1 end end
            if preMaxRank and have < preMaxRank then
                if self.Print then self:Print("|cFFFF0000Requires max rank in " .. (preName or "that talent") .. "|r") end
                return
            end
        end
    end
    local _, _, tier = GetTalentInfo(tabIndex, talentIndex)
    local requiredPoints = ((tier or 1) - 1) * 5
    if requiredPoints > 0 then
        local spent = 0
        for _, id in ipairs(self.pickOrder or {}) do
            local dash = string.find(id, "-")
            if dash then
                local t = tonumber(string.sub(id, 1, dash - 1))
                if t == tabIndex then spent = spent + 1 end
            end
        end
        if spent < requiredPoints then
            if self.Print then self:Print("|cFFFF0000Requires " .. requiredPoints .. " points in this tree.|r") end
            return
        end
    end
    local id = tabIndex .. "-" .. talentIndex
    local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    maxRank = maxRank or 0
    local have = 0
    for _, v in ipairs(self.pickOrder or {}) do if v == id then have = have + 1 end end
    if have < maxRank then
        if table.getn(self.pickOrder or {}) >= 51 then
            if self.Print then self:Print("|cFFFF0000Points cap reached (51).|r") end
            return
        end
        tinsert(self.pickOrder, id)
        if ownerBtn then ownerBtn._planned = (have or 0) + 1; ownerBtn._maxRank = maxRank or 0 end
        self:UpdateCalculatorOverlays()
        for t = 1, 3 do self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
        if ownerBtn and GameTooltip and addon.ShowTalentTooltip then addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex) end
    end
end

function addon:OnTalentRightClick(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    for i = table.getn(self.pickOrder or {}), 1, -1 do
        if self.pickOrder[i] == id then
            table.remove(self.pickOrder, i)
            if self.RevalidatePickOrder then self:RevalidatePickOrder() end
            if ownerBtn then
                local counts = currentCounts()
                ownerBtn._planned = counts[id] or 0
                local _, _, _, _, _, maxRank2 = GetTalentInfo(tabIndex, talentIndex)
                ownerBtn._maxRank = maxRank2 or 0
            end
            self:UpdateCalculatorOverlays()
            for t = 1, 3 do self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
            if ownerBtn and GameTooltip and addon.ShowTalentTooltip then addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex) end
            return
        end
    end
end

function addon:FillTalentToMax(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    maxRank = maxRank or 0
    local prevCount = -1
    for _i = 1, maxRank do
        local counts = currentCounts()
        local have = counts[id] or 0
        if have == prevCount then break end
        prevCount = have
        if have >= maxRank then break end
        local before = table.getn(self.pickOrder or {})
        self:OnTalentClick(tabIndex, talentIndex, ownerBtn)
        if table.getn(self.pickOrder or {}) == before then break end
    end
end

function addon:ClearTalentAllRanks(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    local changed = false
    while true do
        local before = table.getn(self.pickOrder or {})
        self:OnTalentRightClick(tabIndex, talentIndex, ownerBtn)
        if table.getn(self.pickOrder or {}) == before then break end
        changed = true
    end
    if changed and ownerBtn and GameTooltip and addon.ShowTalentTooltip then addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex) end
end

function addon:ExportToString()
    local _, cls = UnitClass("player")
    return (cls or "?") .. ":" .. table.concat(addon.pickOrder or {}, ",")
end

function addon:ImportFromString(s)
    local p = (addon.SplitString and addon.SplitString(s or "", ":")) or {}
    local cls, data = p[1], p[2]
    local _, playerClass = UnitClass("player")
    if cls ~= playerClass then
        if self.Print then self:Print("|cFFFF0000Error:|r Build is for " .. (cls or "?") .. ", not " .. (playerClass or "?") .. ".") end
        return
    end
    addon.pickOrder = {}
    if data then
        local list = (addon.SplitString and addon.SplitString(data, ",")) or {}
        for _, id in ipairs(list) do
            if string.find(id, "^%d+%-%d+$") then
                local parts = (addon.SplitString and addon.SplitString(id, "-")) or {}
                local tab = tonumber(parts[1])
                local idx = tonumber(parts[2])
                if tab and idx and tab >= 1 and tab <= (GetNumTalentTabs() or 0) then
                    if idx >= 1 and idx <= (GetNumTalents(tab) or 0) then
                        local name = GetTalentInfo(tab, idx)
                        if name then tinsert(addon.pickOrder, id) end
                    end
                end
            end
        end
    end
    if self.RevalidatePickOrder then self:RevalidatePickOrder() end
    addon:UpdateCalculatorOverlays()
    if self.Print then self:Print("Build imported successfully.") end
    for t = 1, 3 do addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
end

