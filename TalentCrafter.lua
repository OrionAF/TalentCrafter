-- ============================================================================
-- TalentCrafter (Vanilla 1.12.1 / Turtle WoW)
-- ============================================================================
local ADDON_NAME = "TalentCrafter"
local addon = {isInitialized = false, talentLines = {}, calcTalents = {}, pickOrder = {}, viewerCollapsed = false}
local mainFrame, calculatorFrame, exportFrame, importFrame, scrollFrame

-- No default guides — keep these nil.
local druidTalentOrder,
    hunterTalentOrder,
    warriorTalentOrder,
    warlockTalentOrder,
    paladinTalentOrder,
    rogueTalentOrder,
    mageTalentOrder,
    priestTalentOrder,
    shamanTalentOrder

local talentGuides = {
    DRUID = druidTalentOrder,
    HUNTER = hunterTalentOrder,
    WARRIOR = warriorTalentOrder,
    WARLOCK = warlockTalentOrder,
    PALADIN = paladinTalentOrder,
    ROGUE = rogueTalentOrder,
    MAGE = mageTalentOrder,
    PRIEST = priestTalentOrder,
    SHAMAN = shamanTalentOrder
}

local _, playerClass = UnitClass("player")
local talentOrder = nil
local manualOverride = false

-- ===== Layout ===============================================================
-- Calculator layout (wider columns, larger icons)
local TREE_W, TREE_H = 340, 388
local ICON_SIZE = 40
local GRID_SPACING = 70
local NUM_COLS = 4
local INITIAL_X, INITIAL_Y = 35, 28
local TOP_PAD, BOTTOM_PAD = 36, 36

-- Branch/arrow tile size
local BRANCH_W, BRANCH_H = 32, 32
local ARROW_W, ARROW_H = 32, 32

-- Colors
local COLOR_ENABLED = {1.00, 0.90, 0.20, 1.0} -- warm gold
local COLOR_DISABLED = {0.70, 0.72, 0.78, 1.0} -- cool opaque gray
local COLOR_WHITE = {1.0, 1.0, 1.0, 1.0}

-- Draw policy: draw unmet (gray) first, then met (gold) on top.
local GOLD_WINS = true

-- Background insets (inside each gold-bordered tree)
local BG_INSET_L, BG_INSET_R = 10, 10
local BG_INSET_TOP = 28
local BG_INSET_BOTTOM = 20

-- Feature flags
local USE_TREE_BACKGROUNDS = false -- single rotating background instead

-- Background rotator timing
local BG_ROTATE_PERIOD = 12 -- seconds fully visible
local BG_FADE_DURATION = 2  -- seconds crossfade

-- ===== Helpers ==============================================================

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFDAA520[TC]|r " .. (msg or ""), 1, 1, 1)
end

-- settings/info UI removed

local function SplitString(s, sep)
    sep = sep or "%s"
    local t = {}
    for str in string.gfind(s or "", "([^" .. sep .. "]+)") do
        tinsert(t, str)
    end
    return t
end

local function SetTexDesaturated(tex, desaturate)
    if not tex then
        return
    end
    if tex.SetDesaturated then
        tex:SetDesaturated(desaturate)
    else
        tex:SetVertexColor(desaturate and 0.4 or 1, desaturate and 0.4 or 1, desaturate and 0.4 or 1)
    end
end

local function FindTalentByPosition(tabIndex, tier, column)
    for i = 1, GetNumTalents(tabIndex) do
        local _, _, t, c = GetTalentInfo(tabIndex, i)
        if t == tier and c == column then
            return i
        end
    end
end

local function ApplyDialogBackdrop(frame)
    frame:SetBackdrop(
        {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        }
    )
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
end

local function ApplyGoldBorder(frame)
    frame:SetBackdrop(
        {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        }
    )
    frame:SetBackdropColor(0, 0, 0, 0.25)
    frame:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.9)
end

-- Stitch 4 tiles to fill exactly the 'frame' rect
local BG_OVERSCAN = 1.15
local function BuildTalentBackground(frame, basename)
    -- Crop via ScrollFrame so oversized tiles never bleed outside the tree
    local atlasW, atlasH = 320, 384
    local W, H = frame:GetWidth() or atlasW, frame:GetHeight() or atlasH
    local s = max(W / atlasW, H / atlasH) * BG_OVERSCAN

    local clip = CreateFrame("ScrollFrame", nil, frame)
    clip:SetAllPoints(frame)
    clip:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
    local holder = CreateFrame("Frame", nil, clip)
    holder:SetWidth(atlasW * s)
    holder:SetHeight(atlasH * s)
    holder:SetPoint("CENTER", clip, "CENTER", 0, 0)
    clip:SetScrollChild(holder)

    local function tile(name, w, h, point)
        local t = holder:CreateTexture(nil, "BACKGROUND")
        t:SetTexture("Interface\\TalentFrame\\" .. basename .. name)
        t:SetWidth(w)
        t:SetHeight(h)
        t:SetPoint(point, holder, point, 0, 0)
        return t
    end

    local wTL, wTR = 256 * s, 64 * s
    local hTL, hBL = 256 * s, 128 * s
    tile("-TopLeft", wTL, hTL, "TOPLEFT")
    tile("-TopRight", wTR, hTL, "TOPRIGHT")
    tile("-BottomLeft", wTL, hBL, "BOTTOMLEFT")
    tile("-BottomRight", wTR, hBL, "BOTTOMRIGHT")
end

function addon:RefreshTalentIcons()
    for tab = 1, GetNumTalentTabs() do
        local parent = getglobal("TC_CalcTree" .. tab)
        if parent and self.calcTalents[tab] then
            for idx, btn in pairs(self.calcTalents[tab]) do
                local _, icon = GetTalentInfo(tab, idx)
                if btn.icon and icon then
                    btn.icon:SetTexture(icon)
                end
            end
        end
    end
end

-- ===== Guide UI updates =====================================================

function addon:UpdateTalentDisplay()
    if not addon.isInitialized then
        return
    end
    if not manualOverride then
        _, playerClass = UnitClass("player")
        talentOrder = talentGuides[playerClass] -- intentionally nil unless user saves a custom build
    end
    for level, line in pairs(addon.talentLines) do
        local info = talentOrder and talentOrder[level]
        if info then
            local name, icon = unpack(info)
            line.icon:SetTexture(icon)
            line.text:SetText(name or "")
        else
            line.icon:SetTexture(nil)
            line.text:SetText("")
        end
    end
end

function addon:UpdateGlow()
    if not addon.isInitialized then
        return
    end
    if addon.glowingLine then
        addon.glowingLine.glow:Hide()
        addon.glowingLine = nil
    end
    local current = addon.talentLines[UnitLevel("player")]
    if current then
        current.glow:Show()
        addon.glowingLine = current
    end
end

function addon:Show()
    if not addon.isInitialized or UnitLevel("player") < 10 then
        return
    end
    addon:UpdateTalentDisplay()
    addon:UpdateGlow()
    mainFrame:Show()
    local off = max(0, (UnitLevel("player") - 10) * 30)
    if scrollFrame and scrollFrame:IsShown() then
        local child = scrollFrame:GetScrollChild()
        local maxOff = 0
        if child and scrollFrame:GetHeight() and child:GetHeight() then
            maxOff = max(0, (child:GetHeight() - scrollFrame:GetHeight()))
        end
        scrollFrame:SetVerticalScroll(min(off, maxOff))
    end
end
function addon:Hide()
    if addon.isInitialized then
        mainFrame:Hide()
    end
end

-- ===== Calculator logic =====================================================

local function currentRankCounts()
    local counts = {}
    for _, id in ipairs(addon.pickOrder) do
        counts[id] = (counts[id] or 0) + 1
    end
    return counts
end

-- Turtle talents data loader (for per-rank descriptions)
local function EnsureTurtleTalentData()
    if addon._descCache then return true end
    if not Turtle_TalentsData then
        if LoadAddOn then
            pcall(LoadAddOn, "Turtle_InspectTalentsUI")
        end
    end
    if not Turtle_TalentsData then return false end
    local cache = {}
    for class, trees in pairs(Turtle_TalentsData) do
        cache[class] = {}
        for t = 1, 3 do
            cache[class][t] = {}
            local tree = trees[t]
            if tree then
                -- Some builds store talents in tree.talents, others inline by index
                local list = tree.talents or tree
                for _, rec in pairs(list) do
                    if type(rec) == "table" and rec.name and rec.desc then
                        cache[class][t][rec.name] = rec.desc
                    end
                end
            end
        end
    end
    addon._descCache = cache
    return true
end

-- Rebuild pickOrder by applying each pick in sequence and dropping any that
-- no longer meet tree points or prerequisite max-rank requirements.
function addon:RevalidatePickOrder()
    local newOrder = {}
    local counts = {}
    local tabSpent = { [1]=0, [2]=0, [3]=0 }
    local function addCount(id)
        counts[id] = (counts[id] or 0) + 1
        local dash = string.find(id, "-")
        if dash then
            local t = tonumber(string.sub(id, 1, dash - 1))
            if t then tabSpent[t] = (tabSpent[t] or 0) + 1 end
        end
    end
    for _, id in ipairs(self.pickOrder) do
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
                    local preIndex = FindTalentByPosition(tab, pTier, pCol)
                    local _, _, _, _, _, preMaxRank = GetTalentInfo(tab, preIndex)
                    local have = counts[tab .. "-" .. preIndex] or 0
                    okPrereq = preMaxRank and have >= preMaxRank
                end

                -- also respect per-talent max rank
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
    local counts = currentRankCounts()
    local tabTotals = { [1]=0, [2]=0, [3]=0 }
    for k, v in pairs(counts) do
        local dash = string.find(k, "-")
        if dash then
            local t = tonumber(string.sub(k, 1, dash - 1))
            if t and tabTotals[t] then
                tabTotals[t] = tabTotals[t] + (v or 0)
            end
        end
    end
    for tab, t in pairs(addon.calcTalents) do
        for idx, btn in pairs(t) do
            local id = tab .. "-" .. idx
            local _, _, tier, _, _, maxRank = GetTalentInfo(tab, idx)
            local r = counts[id] or 0
            -- availability (can pick next point)
            local requiredPoints = ((tier or 1) - 1) * 5
            local spent = tabTotals[tab] or 0
            local pTier, pCol = GetTalentPrereqs(tab, idx)
            local prereqOK = true
            if pTier and pCol then
                local preIndex = FindTalentByPosition(tab, pTier, pCol)
                local _, _, _, _, _, preMaxRank = GetTalentInfo(tab, preIndex)
                local have = counts[tab .. "-" .. preIndex] or 0
                prereqOK = preMaxRank and have >= preMaxRank
            end
            local totalSpent = (tabTotals[1] + tabTotals[2] + tabTotals[3])
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
                SetTexDesaturated(btn.icon, false)
                if r == maxRank then
                    btn.border:Show()
                else
                    btn.border:Hide()
                end
            else
                SetTexDesaturated(btn.icon, true)
                btn.border:Hide()
            end
        end
        local tree = getglobal("TC_CalcTree" .. tab)
        if tree and tree.pointsText then
            tree.pointsText:SetText("Points: " .. (tabTotals[tab] or 0))
        end
    end
    -- Update header (CLASS a/b/c | Points left: N)
    local _, classToken = UnitClass("player")
    local className = classToken or "CLASS"
    local left = 51 - (tabTotals[1] + tabTotals[2] + tabTotals[3])
    if calculatorFrame and calculatorFrame.summaryText then
        calculatorFrame.summaryText:SetText(string.format("%s %d/%d/%d  |  Points left: %d",
            className, tabTotals[1] or 0, tabTotals[2] or 0, tabTotals[3] or 0, max(0, left)))
    end
end

function addon:OnTalentClick(tabIndex, talentIndex, ownerBtn)
    -- prerequisite check vs current pickOrder (not character talents)
    local reqTier, reqColumn = GetTalentPrereqs(tabIndex, talentIndex)
    if reqTier and reqColumn then
        local pre = FindTalentByPosition(tabIndex, reqTier, reqColumn)
        if pre then
            local preName, _, _, _, _, preMaxRank = GetTalentInfo(tabIndex, pre)
            local preId = tabIndex .. "-" .. pre
            local have = 0
            for _, v in ipairs(self.pickOrder) do
                if v == preId then
                    have = have + 1
                end
            end
            if preMaxRank and have < preMaxRank then
                self:Print("|cFFFF0000Requires max rank in " .. (preName or "that talent") .. "|r")
                return
            end
        end
    end

    -- tree points gate: require enough points in the tree to open this tier
    local _, _, tier = GetTalentInfo(tabIndex, talentIndex)
    local requiredPoints = ((tier or 1) - 1) * 5
    if requiredPoints > 0 then
        local spent = 0
        for _, id in ipairs(self.pickOrder) do
            local dash = string.find(id, "-")
            if dash then
                local t = tonumber(string.sub(id, 1, dash - 1))
                if t == tabIndex then
                    spent = spent + 1
                end
            end
        end
        if spent < requiredPoints then
            self:Print("|cFFFF0000Requires " .. requiredPoints .. " points in this tree.|r")
            return
        end
    end

    local id = tabIndex .. "-" .. talentIndex
    local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    local have = 0
    for _, v in ipairs(self.pickOrder) do
        if v == id then
            have = have + 1
        end
    end
    if have < maxRank then
        -- global cap: 51 points
        if table.getn(self.pickOrder) >= 51 then
            self:Print("|cFFFF0000Points cap reached (51).|r")
            return
        end
        tinsert(self.pickOrder, id)
        self:UpdateCalculatorOverlays()
        for t = 1, 3 do
            self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t))
        end
        if ownerBtn and GameTooltip and GameTooltip:IsOwned(ownerBtn) then
            addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex)
        end
    end
end

function addon:OnTalentRightClick(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    for i = table.getn(self.pickOrder), 1, -1 do
        if self.pickOrder[i] == id then
            table.remove(self.pickOrder, i)
            -- Revalidate the remaining picks after removal
            if self.RevalidatePickOrder then self:RevalidatePickOrder() end
            self:UpdateCalculatorOverlays()
            for t = 1, 3 do
                self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t))
            end
            if ownerBtn and GameTooltip and GameTooltip:IsOwned(ownerBtn) then
                addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex)
            end
            return
        end
    end
end

function addon:ExportToString()
    return playerClass .. ":" .. table.concat(addon.pickOrder, ",")
end

function addon:ImportFromString(s)
    local p = SplitString(s or "", ":")
    local cls, data = p[1], p[2]
    if cls ~= playerClass then
        addon:Print("|cFFFF0000Error:|r Build is for " .. (cls or "?") .. ", not " .. (playerClass or "?") .. ".")
        return
    end
    addon.pickOrder = {}
    if data then
        for _, id in ipairs(SplitString(data, ",")) do
            -- Strict token check: only TAB-INDEX with digits
            if string.find(id, "^%d+%-%d+$") then
                local parts = SplitString(id, "-")
                local tab = tonumber(parts[1])
                local idx = tonumber(parts[2])
                if tab and idx and tab >= 1 and tab <= (GetNumTalentTabs() or 0) then
                    if idx >= 1 and idx <= (GetNumTalents(tab) or 0) then
                        local name = GetTalentInfo(tab, idx)
                        if name then
                            tinsert(addon.pickOrder, id)
                        end
                    end
                end
            end
        end
    end
    if self.RevalidatePickOrder then self:RevalidatePickOrder() end
    addon:UpdateCalculatorOverlays()
    addon:Print("Build imported successfully.")
    for t = 1, 3 do
        addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. t))
    end
end

function addon:SaveAndUseCustomBuild()
    if table.getn(addon.pickOrder) == 0 then
        addon:Print("Cannot save an empty build.")
        return
    end
    local new = {}
    for i, id in ipairs(addon.pickOrder) do
        local pp = SplitString(id, "-")
        local tab, idx = tonumber(pp[1]), tonumber(pp[2])
        local name, icon = GetTalentInfo(tab, idx)
        local level = 9 + i
        if name then
            new[level] = {name, icon}
        end
    end
    talentOrder = new
    manualOverride = true
    addon:UpdateTalentDisplay()
    addon:UpdateGlow()
    addon:Print("Custom build saved and applied.")
end

-- ===== Branch system (Blizzard atlas) ======================================

local MAX_BRANCH_TEXTURES, MAX_ARROW_TEXTURES = 128, 96 -- soft caps (lazy grow)

local function EnsurePools(tree)
    if tree._branches then
        return
    end
    tree._branches, tree._arrows = {}, {}
end
local function GetBranchTex(tree)
    local i = tree._branchTexIndex
    local t = tree._branches[i]
    if not t then
        if i <= MAX_BRANCH_TEXTURES then
            t = tree.branchLayer:CreateTexture(nil, "BORDER")
            t:SetTexture("Interface\\TalentFrame\\UI-TalentBranches")
            tree._branches[i] = t
        else
            return nil
        end
    end
    tree._branchTexIndex = i + 1
    t:Show()
    return t
end
local function GetArrowTex(tree)
    local i = tree._arrowTexIndex
    local t = tree._arrows[i]
    if not t then
        if i <= MAX_ARROW_TEXTURES then
            t = tree.arrowLayer:CreateTexture(nil, "OVERLAY")
            t:SetTexture("Interface\\TalentFrame\\UI-TalentArrows")
            tree._arrows[i] = t
        else
            return nil
        end
    end
    tree._arrowTexIndex = i + 1
    t:Show()
    return t
end
local function HideUnused(tree)
    for i = tree._branchTexIndex, table.getn(tree._branches) do
        if tree._branches[i] then tree._branches[i]:Hide() end
    end
    for i = tree._arrowTexIndex, table.getn(tree._arrows) do
        if tree._arrows[i] then tree._arrows[i]:Hide() end
    end
end

local function BranchXY(col, tier)
    local x = ((col - 1) * GRID_SPACING) + INITIAL_X + 2
    local y = -((tier - 1) * GRID_SPACING) - INITIAL_Y - 2
    return x, y
end

local function SafeGetCoord(tbl, key1, key2)
    if not tbl then
        return
    end
    local sub = tbl[key1]
    return sub and sub[key2] or nil
end

local function SetBranchTex(tree, kind, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_BRANCH_TEXTURECOORDS, kind, variant)
    if not uv then
        return
    end
    local t = GetBranchTex(tree)
    if not t then
        return
    end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(BRANCH_W)
    t:SetHeight(BRANCH_H)
    local c = color or COLOR_ENABLED
    t:SetVertexColor(c[1], c[2], c[3], c[4])
    t:ClearAllPoints()
    t:SetPoint("CENTER", tree.branchLayer, "TOPLEFT", x, y)
end

local function SetArrowTex(tree, dir, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_ARROW_TEXTURECOORDS, dir, variant)
    if not uv then
        return
    end
    local t = GetArrowTex(tree)
    if not t then
        return
    end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(ARROW_W)
    t:SetHeight(ARROW_H)
    local c = color or COLOR_ENABLED
    t:SetVertexColor(c[1], c[2], c[3], c[4])
    t:ClearAllPoints()
    t:SetPoint("CENTER", tree.arrowLayer, "TOPLEFT", x, y)
end

-- Build two graphs: unmet (gray) and met (gold)
local function InitBranchNodes()
    local m = {}
    for tier = 1, 11 do
        m[tier] = {}
        for col = 1, NUM_COLS do
            m[tier][col] = {
                id = nil,
                up = 0,
                left = 0,
                right = 0,
                down = 0,
                leftArrow = 0,
                rightArrow = 0,
                topArrow = 0
            }
        end
    end
    return m
end

local function BuildGraphs(tree, counts)
    local unmet, met = InitBranchNodes(), InitBranchNodes()
    -- mark present ids on both maps so junction logic works
    for idx in pairs(addon.calcTalents[tree._tab]) do
        local _, _, tier, col = GetTalentInfo(tree._tab, idx)
        unmet[tier][col].id = idx
        met[tier][col].id = idx
    end
    for idx in pairs(addon.calcTalents[tree._tab]) do
        local _, _, bTier, bCol = GetTalentInfo(tree._tab, idx)
        local pTier, pCol = GetTalentPrereqs(tree._tab, idx)
        if pTier and pCol then
            local preIndex = FindTalentByPosition(tree._tab, pTier, pCol)
            -- GOLD only when you have the prerequisite fully ranked
            local have = counts[tree._tab .. "-" .. preIndex] or 0
            local _, _, _, _, _, preMaxRank = GetTalentInfo(tree._tab, preIndex)
            -- Tree points gate for tier unlock
            local spent = 0
            for k, v in pairs(counts) do
                local dash = string.find(k, "-")
                if dash and tonumber(string.sub(k, 1, dash - 1)) == tree._tab then
                    spent = spent + (v or 0)
                end
            end
            local requiredPoints = ((bTier or 1) - 1) * 5
            local tierUnlocked = (spent >= requiredPoints)
            local ok = (preMaxRank and have >= preMaxRank) and tierUnlocked
            local target = ok and met or unmet
            local flag = (target == met) and 1 or -1

            if bCol == pCol then
                -- vertical
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = flag
                    if (t + 1) < bTier then
                        target[t + 1][bCol].up = flag
                    end
                end
                target[bTier][bCol].topArrow = flag
            elseif bTier == pTier then
                -- horizontal
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do
                    target[bTier][c].right = flag
                    target[bTier][c + 1].left = flag
                end
                if bCol < pCol then
                    target[bTier][bCol].rightArrow = flag
                else
                    target[bTier][bCol].leftArrow = flag
                end
            else
                -- L-shape: down on child col, then across on child's row
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = flag
                    target[t + 1][bCol].up = flag
                end
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do
                    target[bTier][c].right = flag
                    target[bTier][c + 1].left = flag
                end
                target[bTier][bCol].topArrow = flag
            end
        end
    end
    return unmet, met
end

local function PruneUnmetWhereMet(unmet, met)
    for tier = 1, 11 do
        for col = 1, NUM_COLS do
            local u, m = unmet[tier][col], met[tier][col]
            if u and m then
                if m.up ~= 0 then
                    u.up = 0
                end
                if m.down ~= 0 then
                    u.down = 0
                end
                if m.left ~= 0 then
                    u.left = 0
                end
                if m.right ~= 0 then
                    u.right = 0
                end
                if m.leftArrow ~= 0 then
                    u.leftArrow = 0
                end
                if m.rightArrow ~= 0 then
                    u.rightArrow = 0
                end
                if m.topArrow ~= 0 then
                    u.topArrow = 0
                end
            end
        end
    end
end

local function DrawFromNodes(tree, nodes, color)
    for tier = 1, 11 do
        for col = 1, NUM_COLS do
            local n = nodes[tier][col]
            local x, y = BranchXY(col, tier)
            if n.id then
                if n.up ~= 0 then
                    SetBranchTex(tree, "up", n.up, x, y + ICON_SIZE, color)
                end
                if n.down ~= 0 then
                    SetBranchTex(tree, "down", n.down, x, y - ICON_SIZE + 1, color)
                end
                if n.left ~= 0 then
                    SetBranchTex(tree, "left", n.left, x - ICON_SIZE, y, color)
                end
                if n.right ~= 0 then
                    SetBranchTex(tree, "right", n.right, x + ICON_SIZE + 1, y, color)
                end

                if n.rightArrow ~= 0 then
                    SetArrowTex(tree, "right", n.rightArrow, x + ICON_SIZE / 2 + 5, y, color)
                end
                if n.leftArrow ~= 0 then
                    SetArrowTex(tree, "left", n.leftArrow, x - ICON_SIZE / 2 - 5, y, color)
                end
                if n.topArrow ~= 0 then
                    SetArrowTex(tree, "top", n.topArrow, x, y + ICON_SIZE / 2 + 5, color)
                end
            else
                if n.up ~= 0 and n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "tup", n.up, x, y, color)
                elseif n.down ~= 0 and n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "tdown", n.down, x, y, color)
                elseif n.left ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "topright", n.left, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - 32, color)
                elseif n.left ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomright", n.left, x, y, color)
                elseif n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "right", n.right, x + ICON_SIZE, y, color)
                    SetBranchTex(tree, "left", n.left, x + 1, y, color)
                elseif n.right ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "topleft", n.right, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - 32, color)
                elseif n.right ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomleft", n.right, x, y, color)
                elseif n.up ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "up", n.up, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - 32, color)
                end
            end
        end
    end
end

function addon:DrawPrereqGraph(tree)
    if not self.calcTalents or not tree or not tree._tab or not self.calcTalents[tree._tab] then
        return
    end
    local counts = currentRankCounts()
    local unmet, met = BuildGraphs(tree, counts)
    if GOLD_WINS then
        PruneUnmetWhereMet(unmet, met)
    end
    tree._branchTexIndex, tree._arrowTexIndex = 1, 1
    -- Use atlas variants (-1 gray, 1 gold) instead of tinting
    DrawFromNodes(tree, unmet, COLOR_WHITE)
    DrawFromNodes(tree, met, COLOR_WHITE)
    HideUnused(tree)
end

-- ===== Dynamic sizing / centering ==========================================

local function ComputeInitialX(treeWidth)
    local gridWidth = (NUM_COLS - 1) * GRID_SPACING
    return floor((treeWidth - gridWidth) / 2)
end
local function ComputeInitialY(treeHeight, maxTier)
    local gridHeight = (maxTier - 1) * GRID_SPACING
    return floor((treeHeight - gridHeight) / 2)
end

-- ===== UI creation ==========================================================

function addon:CreateFrames()
    -- Ensure Blizzard's Talent UI (and atlas tables) are loaded before we query
    if not IsAddOnLoaded("Blizzard_TalentUI") or not TALENT_BRANCH_TEXTURECOORDS then
        if TalentFrame_LoadUI then
            TalentFrame_LoadUI()
        else
            LoadAddOn("Blizzard_TalentUI")
        end
    end

    -- main (guide) anchored to Blizzard TalentFrame
    local TF = getglobal("TalentFrame")
    mainFrame = CreateFrame("Frame", "TalentCrafterFrame", TF or UIParent)
    mainFrame:SetWidth(280)
    mainFrame:SetHeight(300)
    if TF then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOPLEFT", TF, "TOPRIGHT", 0, 0)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    ApplyDialogBackdrop(mainFrame)
    mainFrame:SetMovable(false)
    mainFrame:SetScript(
        "OnUpdate",
        function()
            if addon.glowingLine and mainFrame:IsShown() then
                local a = 0.5 + (math.sin(GetTime() * 6) * 0.3)
                addon.glowingLine.glow:SetAlpha(a)
            end
        end
    )

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    title:SetText("|cFFDAA520TalentCrafter|r")

    -- Toggle button on the side of TalentFrame to show/hide the viewer
    if TF and not getglobal("TC_ViewerToggle") then
        local toggle = CreateFrame("Button", "TC_ViewerToggle", TF)
        toggle:SetWidth(16)
        toggle:SetHeight(40)
        toggle:SetPoint("RIGHT", TF, "RIGHT", -2, 0)
        local tex = toggle:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(true)
        toggle.tex = tex
        local function UpdateToggleIcon()
            if addon.viewerCollapsed then
                toggle.tex:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up") -- right arrow
            else
                toggle.tex:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up") -- left arrow
            end
        end
        UpdateToggleIcon()
        toggle:SetScript("OnClick", function()
            addon.viewerCollapsed = not addon.viewerCollapsed
            if addon.viewerCollapsed then
                mainFrame:Hide()
            else
                mainFrame:Show()
            end
            UpdateToggleIcon()
        end)
        -- Keep viewer hidden if collapsed when TF is shown again (child hidden state persists)
    end

    scrollFrame = CreateFrame("ScrollFrame", "TC_ScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 8, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 8)
    local child = CreateFrame("Frame", "TC_ScrollChild", scrollFrame)
    child:SetWidth(220)
    child:SetHeight(1530)
    scrollFrame:SetScrollChild(child)
    for i = 10, 60 do
        local line = CreateFrame("Frame", nil, child)
        line:SetWidth(220)
        line:SetHeight(30)
        line:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i - 10) * 30))
        local glow = line:CreateTexture(nil, "LOW")
        glow:SetAllPoints(true)
        glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.8, 0, 1)
        glow:Hide()
        line.glow = glow
        line.levelText = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.levelText:SetPoint("LEFT", line, "LEFT", 5, 0)
        line.levelText:SetText("lvl " .. i .. ":")
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetWidth(24)
        line.icon:SetHeight(24)
        line.icon:SetPoint("LEFT", line.levelText, "RIGHT", 5, 0)
        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.text:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
        line.text:SetWidth(140)
        line.text:SetJustifyH("LEFT")
        addon.talentLines[i] = line
    end

    -- settings/info removed

    -- Robust tier detection: fallback to 11 tiers if early snapshot is low.
    local function DetectMaxTier()
        local tabs = GetNumTalentTabs() or 0
        local m = 1
        for tab = 1, tabs do
            for i = 1, GetNumTalents(tab) do
                local _, _, t = GetTalentInfo(tab, i)
                if t and t > m then
                    m = t
                end
            end
        end
        -- Early during login, some cores report too-low tiers briefly. 1.12 has 11 tiers.
        if m < 7 then
            m = 11
        end
        return m
    end

    local maxTier = DetectMaxTier()
    TREE_H = TOP_PAD + BOTTOM_PAD + (maxTier - 1) * GRID_SPACING + ICON_SIZE
    INITIAL_X = ComputeInitialX(TREE_W)
    INITIAL_Y = ComputeInitialY(TREE_H, maxTier)

    -- calculator frame
    calculatorFrame = CreateFrame("Frame", "TC_TalentCalculator", UIParent)
    calculatorFrame:SetWidth(3 * (TREE_W + 20) + 40)
    calculatorFrame:SetHeight(TREE_H + 100)
    calculatorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ApplyDialogBackdrop(calculatorFrame)
    calculatorFrame:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "TC_TalentCalculator") end
    -- Rotating global background
    addon:InitBackgroundRotator(calculatorFrame)
    calculatorFrame:SetMovable(true)
    calculatorFrame:EnableMouse(true)
    calculatorFrame:RegisterForDrag("LeftButton")
    calculatorFrame:SetScript(
        "OnDragStart",
        function()
            this:StartMoving()
        end
    )
    calculatorFrame:SetScript(
        "OnDragStop",
        function()
            this:StopMovingOrSizing()
        end
    )
    local calcTitle = calculatorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    calcTitle:SetPoint("TOP", calculatorFrame, "TOP", 0, -10)
    local _, classToken = UnitClass("player")
    local className = classToken or "UNKNOWN"
    calcTitle:SetText(className .. " 0/0/0  |  Points left: 51")
    calculatorFrame.summaryText = calcTitle
    local calcClose = CreateFrame("Button", nil, calculatorFrame)
    calcClose:SetWidth(16)
    calcClose:SetHeight(16)
    calcClose:SetPoint("TOPRIGHT", calculatorFrame, "TOPRIGHT", -5, -5)
    local cc = calcClose:CreateTexture(nil, "ARTWORK")
    cc:SetAllPoints()
    cc:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    calcClose:SetScript(
        "OnClick",
        function()
            calculatorFrame:Hide()
        end
    )

    -- trees + backgrounds
    for tab = 1, 3 do
        local name, _, _, background = GetTalentTabInfo(tab)
        local tree = CreateFrame("Frame", "TC_CalcTree" .. tab, calculatorFrame)
        tree._tab = tab
        tree:SetWidth(TREE_W)
        tree:SetHeight(TREE_H)
        tree:SetPoint("TOPLEFT", calculatorFrame, "TOPLEFT", (tab - 1) * (TREE_W + 20) + 20, -40)
        ApplyGoldBorder(tree)

        local gridHeight = (maxTier - 1) * GRID_SPACING + ICON_SIZE
        local bgFrame = CreateFrame("Frame", nil, tree)
        bgFrame:SetWidth(TREE_W - (BG_INSET_L + BG_INSET_R))
        bgFrame:SetHeight(gridHeight)
        bgFrame:SetPoint("TOPLEFT", tree, "TOPLEFT", BG_INSET_L, -BG_INSET_TOP)
        bgFrame:SetFrameLevel(max(0, tree:GetFrameLevel() - 1))
        tree.bgFrame = bgFrame

        local base = background or ""
        local slash = string.find(base, "[/\\][^/\\]*$")
        if slash then
            base = string.sub(base, slash + 1)
        end
        -- subtle dark backing to improve contrast
        local shade = bgFrame:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints(true)
        shade:SetTexture("Interface\\Buttons\\WHITE8X8")
        shade:SetVertexColor(0, 0, 0, 0.30)
        -- per-tree backgrounds disabled when using global rotator
        if USE_TREE_BACKGROUNDS and base ~= "" then
            BuildTalentBackground(bgFrame, base)
        end

        local tfs = tree:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tfs:SetPoint("TOP", tree, "TOP", 0, -8)
        tfs:SetText(name or ("Tree " .. tab))
        local pts = tree:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pts:SetPoint("TOP", tree, "TOP", 0, -22)
        pts:SetText("Points: 0")
        tree.pointsText = pts

        tree.branchLayer = CreateFrame("Frame", nil, tree)
        tree.branchLayer:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, 0)
        tree.branchLayer:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)
        tree.arrowLayer = CreateFrame("Frame", nil, tree)
        tree.arrowLayer:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, 0)
        tree.arrowLayer:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)
        EnsurePools(tree)

        -- per-tree clear button
        local clearTree = CreateFrame("Button", nil, tree, "UIPanelButtonTemplate")
        clearTree:SetWidth(90)
        clearTree:SetHeight(18)
        clearTree:SetText("Clear points")
        clearTree:SetPoint("BOTTOM", tree, "BOTTOM", 0, 6)
        clearTree:SetScript("OnClick", function()
            local keep = {}
            for _, id in ipairs(addon.pickOrder) do
                local dash = string.find(id, "-")
                local t = tonumber(string.sub(id, 1, dash - 1))
                if t ~= tree._tab then tinsert(keep, id) end
            end
            addon.pickOrder = keep
            if addon.RevalidatePickOrder then addon:RevalidatePickOrder() end
            addon:UpdateCalculatorOverlays()
            for i = 1, 3 do addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. i)) end
        end)
    end

    -- buttons (talent icons)
    for tab = 1, GetNumTalentTabs() do
        addon.calcTalents[tab] = {}
        local parent = getglobal("TC_CalcTree" .. tab)
        for idx = 1, GetNumTalents(tab) do
            local _, icon, tier, col = GetTalentInfo(tab, idx)
            local btn = CreateFrame("Button", nil, parent)
            btn:SetWidth(ICON_SIZE)
            btn:SetHeight(ICON_SIZE)
            local x = INITIAL_X + (col - 1) * GRID_SPACING - ICON_SIZE / 2
            local y = INITIAL_Y + (tier - 1) * GRID_SPACING - ICON_SIZE / 2
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(true)
            btn.icon:SetTexture(icon)
            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetAllPoints(true)
            btn.border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            btn.border:Hide()
            btn.rankText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local T, I = tab, idx
            btn:SetScript("OnEnter", function()
                addon:ShowTalentTooltip(btn, T, I)
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", function(self, button)
                local b = button or arg1
                if b == "LeftButton" or b == "LeftButtonUp" then
                    addon:OnTalentClick(T, I, self)
                elseif b == "RightButton" or b == "RightButtonUp" then
                    addon:OnTalentRightClick(T, I, self)
                end
            end)
            addon.calcTalents[tab][idx] = btn
        end
        addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
    end

    -- export/import
    exportFrame = CreateFrame("Frame", "TC_ExportFrame", calculatorFrame)
    exportFrame:SetWidth(420)
    exportFrame:SetHeight(100)
    exportFrame:SetPoint("CENTER", calculatorFrame, "CENTER", 0, 0)
    ApplyDialogBackdrop(exportFrame)
    exportFrame:Hide()
    local exportBox = CreateFrame("EditBox", "TC_ExportBox", exportFrame, "InputBoxTemplate")
    exportBox:SetWidth(380)
    exportBox:SetHeight(32)
    exportBox:SetPoint("CENTER", exportFrame, "CENTER", 0, 10)
    exportBox:SetAutoFocus(false)
    local exportClose = CreateFrame("Button", "TC_ExportClose", exportFrame, "UIPanelButtonTemplate")
    exportClose:SetWidth(80)
    exportClose:SetHeight(24)
    exportClose:SetText("Close")
    exportClose:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 15)
    exportClose:SetScript(
        "OnClick",
        function()
            exportFrame:Hide()
        end
    )

    importFrame = CreateFrame("Frame", "TC_ImportFrame", calculatorFrame)
    importFrame:SetWidth(420)
    importFrame:SetHeight(100)
    importFrame:SetPoint("CENTER", calculatorFrame, "CENTER", 0, 0)
    ApplyDialogBackdrop(importFrame)
    importFrame:Hide()
    local importBox = CreateFrame("EditBox", "TC_ImportBox", importFrame, "InputBoxTemplate")
    importBox:SetWidth(380)
    importBox:SetHeight(32)
    importBox:SetPoint("CENTER", importFrame, "CENTER", 0, 10)
    importBox:SetAutoFocus(true)
    local importAccept = CreateFrame("Button", "TC_ImportAccept", importFrame, "UIPanelButtonTemplate")
    importAccept:SetWidth(80)
    importAccept:SetHeight(24)
    importAccept:SetText("Import")
    importAccept:SetPoint("BOTTOM", importFrame, "BOTTOM", 45, 15)
    importAccept:SetScript(
        "OnClick",
        function()
            addon:ImportFromString(importBox:GetText())
            importFrame:Hide()
        end
    )
    local importCancel = CreateFrame("Button", "TC_ImportCancel", importFrame, "UIPanelButtonTemplate")
    importCancel:SetWidth(80)
    importCancel:SetHeight(24)
    importCancel:SetText("Cancel")
    importCancel:SetPoint("BOTTOM", importFrame, "BOTTOM", -45, 15)
    importCancel:SetScript(
        "OnClick",
        function()
            importFrame:Hide()
        end
    )

    -- bottom buttons
    local clear = CreateFrame("Button", "TC_ClearButton", calculatorFrame, "UIPanelButtonTemplate")
    clear:SetWidth(120)
    clear:SetHeight(24)
    clear:SetText("Clear Build")
    clear:SetPoint("BOTTOMLEFT", calculatorFrame, "BOTTOMLEFT", 20, 15)
    clear:SetScript(
        "OnClick",
        function()
            addon.pickOrder = {}
            addon:UpdateCalculatorOverlays()
            for tab = 1, 3 do
                addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
            end
        end
    )

    local save = CreateFrame("Button", "TC_SaveButton", calculatorFrame, "UIPanelButtonTemplate")
    save:SetWidth(120)
    save:SetHeight(24)
    save:SetText("Save & Use")
    save:SetPoint("BOTTOMRIGHT", calculatorFrame, "BOTTOMRIGHT", -20, 15)
    save:SetScript(
        "OnClick",
        function()
            -- Snapshot the current pickOrder to avoid aliasing the saved build
            local copy = {}
            for i, v in ipairs(addon.pickOrder) do
                copy[i] = v
            end
            TC_CustomBuilds[playerClass] = copy
            addon:SaveAndUseCustomBuild()
        end
    )

    local ibtn = CreateFrame("Button", "TC_ImportButton", calculatorFrame, "UIPanelButtonTemplate")
    ibtn:SetWidth(80)
    ibtn:SetHeight(24)
    ibtn:SetText("Import")
    ibtn:SetPoint("BOTTOM", calculatorFrame, "BOTTOM", -45, 15)
    ibtn:SetScript(
        "OnClick",
        function()
            exportFrame:Hide()
            getglobal("TC_ImportBox"):SetText("")
            importFrame:Show()
        end
    )

    local ebtn = CreateFrame("Button", "TC_ExportButton", calculatorFrame, "UIPanelButtonTemplate")
    ebtn:SetWidth(80)
    ebtn:SetHeight(24)
    ebtn:SetText("Export")
    ebtn:SetPoint("BOTTOM", calculatorFrame, "BOTTOM", 45, 15)
    ebtn:SetScript(
        "OnClick",
        function()
            importFrame:Hide()
            getglobal("TC_ExportBox"):SetText(addon:ExportToString())
            getglobal("TC_ExportBox"):HighlightText()
            exportFrame:Show()
        end
    )

    addon.isInitialized = true
end

-- ===== Events ===============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript(
    "OnEvent",
    function()
        if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
            if not TC_CustomBuilds then
                TC_CustomBuilds = {}
            end
            if TC_CustomBuilds[playerClass] then
                addon.pickOrder = TC_CustomBuilds[playerClass]
            else
                addon.pickOrder = {}
            end
            -- do NOT create frames here; wait until PLAYER_LOGIN when all core data is ready
            this:UnregisterEvent("ADDON_LOADED")
        elseif event == "PLAYER_LOGIN" then
            -- Defer frame creation until talent data is ready (some cores are late)
            local function TalentDataReady()
                local tabs = GetNumTalentTabs() or 0
                if tabs < 1 then return false end
                for t = 1, tabs do
                    local n = GetNumTalents(t)
                    if not n or n == 0 then
                        return false
                    end
                end
                return true
            end

            if TalentDataReady() then
                addon:CreateFrames()
            else
                -- Try again when spells/talent data loads
                eventFrame:RegisterEvent("SPELLS_CHANGED")
            end
        elseif event == "SPELLS_CHANGED" then
            if not addon.isInitialized then
                local tabs = GetNumTalentTabs() or 0
                if tabs > 0 then
                    local ready = true
                    for t = 1, tabs do
                        if (GetNumTalents(t) or 0) == 0 then
                            ready = false
                            break
                        end
                    end
                    if ready then
                        addon:CreateFrames()
                        this:UnregisterEvent("SPELLS_CHANGED")
                    end
                end
            end

            -- Viewer now anchors to TalentFrame and inherits its visibility.
        elseif event == "PLAYER_ENTERING_WORLD" then
            if addon.isInitialized then
                addon:UpdateGlow()
            end
        elseif event == "PLAYER_LEVEL_UP" then
            if addon.isInitialized and mainFrame:IsShown() then
                addon:UpdateGlow()
            end
        end
    end
)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

-- ===== Slash ================================================================
SLASH_TC1, SLASH_TC2 = "/tc", "/TC"

local function TryInitializeNow()
    if addon.isInitialized then return true end
    -- Try to load Blizzard Talent UI and create frames if data is ready
    if not IsAddOnLoaded("Blizzard_TalentUI") then
        if TalentFrame_LoadUI then TalentFrame_LoadUI() else LoadAddOn("Blizzard_TalentUI") end
    end
    -- Readiness: at least one tab and talents populated
    local tabs = GetNumTalentTabs() or 0
    if tabs > 0 then
        local ok = true
        for t = 1, tabs do
            if (GetNumTalents(t) or 0) == 0 then ok = false break end
        end
        if ok and not addon.isInitialized then
            addon:CreateFrames()
        end
    end
    return addon.isInitialized
end

function SlashCmdList.TC(msg)
    if not addon.isInitialized then
        if not TryInitializeNow() then
            addon:Print("Talent data not ready yet; try again in a moment.")
            return
        end
    end
    local cmd = string.lower(msg or "")
    if cmd == "calc" then
        if UnitLevel("player") < 10 then
            addon:Print("You must be at least level 10 to use the talent calculator.")
            return
        end
        addon:RefreshTalentIcons()
        if calculatorFrame:IsShown() then
            calculatorFrame:Hide()
        else
            calculatorFrame:Show()
            addon:UpdateCalculatorOverlays()
            for tab = 1, 3 do
                addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
            end
        end
    elseif cmd == "reset" then
        manualOverride = false
        addon:UpdateTalentDisplay()
        addon:UpdateGlow()
        addon:Print("Guide reset to default.")
    elseif talentGuides[string.upper(cmd)] ~= nil then
        manualOverride = true
        local sel = string.upper(cmd)
        if talentGuides[sel] then
            talentOrder = talentGuides[sel]
            addon:UpdateTalentDisplay()
            addon:UpdateGlow()
            addon:Print("Now showing " .. sel)
        else
            addon:Print("No guide configured for " .. sel .. ". Opening calculator.")
            addon:RefreshTalentIcons()
            calculatorFrame:Show()
            addon:UpdateCalculatorOverlays()
            for tab = 1, 3 do
                addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
            end
        end
    else
        addon:Print("Usage: /tc [calc | reset]")
    end
end
-- Rotating background for calculator
function addon:InitBackgroundRotator(frame)
    local bases = {}
    for t=1,3 do
        local _, _, _, bg = GetTalentTabInfo(t)
        if bg then
            local base = bg
            local slash = string.find(base, "[/\\][^/\\]*$")
            if slash then base = string.sub(base, slash + 1) end
            if base ~= "" then tinsert(bases, base) end
        end
    end
    if table.getn(bases) == 0 then return end
    frame._bgFrames = {}
    for i, base in ipairs(bases) do
        local holder = CreateFrame("Frame", nil, frame)
        holder:SetAllPoints(frame)
        holder:SetFrameLevel(max(0, frame:GetFrameLevel() - 2))
        BuildTalentBackground(holder, base)
        holder:SetAlpha(i == 1 and 1 or 0)
        frame._bgFrames[i] = holder
    end
    frame._bgIndex = 1
    frame._bgTimer = 0
    frame:SetScript("OnUpdate", function()
        frame._bgTimer = frame._bgTimer + arg1
        local n = table.getn(frame._bgFrames)
        if n <= 1 then return end
        local t = frame._bgTimer % (BG_ROTATE_PERIOD + BG_FADE_DURATION)
        local active = frame._bgIndex
        local nextIndex = active % n + 1
        if t < BG_ROTATE_PERIOD then
            frame._bgFrames[active]:SetAlpha(1)
            frame._bgFrames[nextIndex]:SetAlpha(0)
        else
            local f = (t - BG_ROTATE_PERIOD) / BG_FADE_DURATION
            if f > 1 then f = 1 end
            frame._bgFrames[active]:SetAlpha(1 - f)
            frame._bgFrames[nextIndex]:SetAlpha(f)
            if f >= 1 then
                frame._bgIndex = nextIndex
            end
        end
    end)
end
