-- Branch graph + drawing (Vanilla 1.12 / Turtle WoW)
-- Uses addon-exposed constants to avoid load-order issues.

local addon = _G.TalentCrafter or {}
_G.TalentCrafter = addon

-- Local accessors with sane fallbacks
local function C(key, default)
    local v = addon[key]
    if v == nil then return default else return v end
end

local ICON_SIZE    = C('ICON_SIZE', 40)
local GRID_SPACING = C('GRID_SPACING', 70)
local NUM_COLS     = C('NUM_COLS', 4)
local INITIAL_X    = C('INITIAL_X', 35)
local INITIAL_Y    = C('INITIAL_Y', 28)
local BRANCH_W     = C('BRANCH_W', 32)
local BRANCH_H     = C('BRANCH_H', 32)
local ARROW_W      = C('ARROW_W', 32)
local ARROW_H      = C('ARROW_H', 32)
local VERT_SEG     = C('VERT_SEG', math.floor((GRID_SPACING or 70)/2 + 0.5))
local GOLD_WINS    = C('GOLD_WINS', true)
local COLOR_ENABLED  = C('COLOR_ENABLED', {1.00, 0.90, 0.20, 1.0})
local COLOR_DISABLED = C('COLOR_DISABLED', {0.70, 0.72, 0.78, 1.0})

-- Pools
local MAX_BRANCH_TEXTURES, MAX_ARROW_TEXTURES = 128, 96

local function EnsurePools(tree)
    if tree._branches then return end
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
            if not addon._poolWarnedBranches then
                addon._poolWarnedBranches = true
                if addon.Print then addon:Print("Branch pool limit reached; some lines may not render.") end
            end
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
            if not addon._poolWarnedArrows then
                addon._poolWarnedArrows = true
                if addon.Print then addon:Print("Arrow pool limit reached; some arrows may not render.") end
            end
            return nil
        end
    end
    tree._arrowTexIndex = i + 1
    t:Show()
    return t
end
local function HideUnused(tree)
    for i = tree._branchTexIndex, table.getn(tree._branches or {}) do
        if tree._branches[i] then tree._branches[i]:Hide() end
    end
    for i = tree._arrowTexIndex, table.getn(tree._arrows or {}) do
        if tree._arrows[i] then tree._arrows[i]:Hide() end
    end
end

local function BranchXY(col, tier)
    local x = ((col - 1) * GRID_SPACING) + INITIAL_X
    local y = -((tier - 1) * GRID_SPACING) - INITIAL_Y
    return x, y
end

local function SafeGetCoord(tbl, key1, key2)
    if not tbl then return end
    local sub = tbl[key1]
    return sub and sub[key2] or nil
end

local function SetBranchTex(tree, kind, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_BRANCH_TEXTURECOORDS, kind, 1)
    if not uv then return end
    local t = GetBranchTex(tree)
    if not t then return end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(BRANCH_W)
    if kind == 'up' or kind == 'down' then
        t:SetHeight(VERT_SEG)
    else
        t:SetHeight(BRANCH_H)
    end
    local isUnmet = (addon and addon._drawingUnmet) or (color == COLOR_DISABLED)
    if isUnmet then
        if t.SetDesaturated then t:SetDesaturated(true); t:SetVertexColor(1,1,1,1) else t:SetVertexColor(0.6,0.6,0.6,1) end
    else
        if t.SetDesaturated then t:SetDesaturated(false) end
        local c = color or COLOR_ENABLED
        t:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    t:ClearAllPoints()
    t:SetPoint("CENTER", tree.branchLayer, "TOPLEFT", x, y)
end

local function SetArrowTex(tree, dir, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_ARROW_TEXTURECOORDS, dir, 1)
    if not uv then return end
    local t = GetArrowTex(tree)
    if not t then return end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(ARROW_W)
    t:SetHeight(ARROW_H)
    local isUnmet = (addon and addon._drawingUnmet) or (color == COLOR_DISABLED)
    if isUnmet then
        if t.SetDesaturated then t:SetDesaturated(true); t:SetVertexColor(1,1,1,1) else t:SetVertexColor(0.6,0.6,0.6,1) end
    else
        if t.SetDesaturated then t:SetDesaturated(false) end
        local c = color or COLOR_ENABLED
        t:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    t:ClearAllPoints()
    t:SetPoint("CENTER", tree.arrowLayer, "TOPLEFT", x, y)
end

local function InitBranchNodes()
    local m = {}
    for tier = 1, 11 do
        m[tier] = {}
        for col = 1, NUM_COLS do
            m[tier][col] = {id=nil, up=0, left=0, right=0, down=0, leftArrow=0, rightArrow=0, topArrow=0}
        end
    end
    return m
end

local function currentRankCounts()
    local counts = {}
    for _, id in ipairs(addon.pickOrder or {}) do counts[id] = (counts[id] or 0) + 1 end
    return counts
end

local function BuildGraphs(tree, counts)
    local unmet, met = InitBranchNodes(), InitBranchNodes()
    for idx in pairs(addon.calcTalents[tree._tab] or {}) do
        local _, _, tier, col = GetTalentInfo(tree._tab, idx)
        unmet[tier][col].id = idx; met[tier][col].id = idx
    end
    for idx in pairs(addon.calcTalents[tree._tab] or {}) do
        local _, _, bTier, bCol = GetTalentInfo(tree._tab, idx)
        local pTier, pCol = GetTalentPrereqs(tree._tab, idx)
        if pTier and pCol then
            local preIndex = (addon.FindTalentByPosition and addon.FindTalentByPosition(tree._tab, pTier, pCol)) or nil
            local have = counts[tree._tab .. "-" .. preIndex] or 0
            local _, _, _, _, _, preMaxRank = GetTalentInfo(tree._tab, preIndex)
            local spent = 0
            for k, v in pairs(counts) do
                local dash = string.find(k, "-")
                if dash and tonumber(string.sub(k, 1, dash - 1)) == tree._tab then spent = spent + (v or 0) end
            end
            local requiredPoints = ((bTier or 1) - 1) * 5
            local tierUnlocked = (spent >= requiredPoints)
            local ok = (preMaxRank and have >= preMaxRank) and tierUnlocked
            local target = ok and met or unmet
            local flag = 1
            if bCol == pCol then
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = flag
                    if (t + 1) < bTier then target[t + 1][bCol].up = flag else target[bTier][bCol].up = flag end
                end
                target[bTier][bCol].topArrow = flag
            elseif bTier == pTier then
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do target[bTier][c].right = flag; target[bTier][c + 1].left = flag end
                if bCol < pCol then target[bTier][bCol].rightArrow = flag else target[bTier][bCol].leftArrow = flag end
            else
                for t = pTier, bTier - 1 do target[t][bCol].down = flag; target[t + 1][bCol].up = flag end
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do target[bTier][c].right = flag; target[bTier][c + 1].left = flag end
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
                if m.up ~= 0 then u.up = 0 end
                if m.down ~= 0 then u.down = 0 end
                if m.left ~= 0 then u.left = 0 end
                if m.right ~= 0 then u.right = 0 end
                if m.leftArrow ~= 0 then u.leftArrow = 0 end
                if m.rightArrow ~= 0 then u.rightArrow = 0 end
                if m.topArrow ~= 0 then u.topArrow = 0 end
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
                if n.up ~= 0 then SetBranchTex(tree, "up", n.up, x, y + (ICON_SIZE / 2 + VERT_SEG / 2), color) end
                if n.down ~= 0 then SetBranchTex(tree, "down", n.down, x, y - (ICON_SIZE / 2 + VERT_SEG / 2) + 1, color) end
                if n.left ~= 0 then SetBranchTex(tree, "left", n.left, x - (ICON_SIZE / 2 + BRANCH_W / 2), y, color) end
                if n.right ~= 0 then SetBranchTex(tree, "right", n.right, x + (ICON_SIZE / 2 + BRANCH_W / 2) + 1, y, color) end
                if n.rightArrow ~= 0 then SetArrowTex(tree, "right", n.rightArrow, x + ICON_SIZE / 2 + 5, y, color) end
                if n.leftArrow ~= 0 then SetArrowTex(tree, "left", n.leftArrow, x - ICON_SIZE / 2 - 5, y, color) end
                if n.topArrow ~= 0 then SetArrowTex(tree, "top", n.topArrow, x, y + ICON_SIZE / 2 + 5, color) end
            else
                if n.up ~= 0 and n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "tup", n.up, x, y, color)
                elseif n.down ~= 0 and n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "tdown", n.down, x, y, color)
                elseif n.left ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "topright", n.left, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - (VERT_SEG / 2), color)
                elseif n.left ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomright", n.left, x, y, color)
                elseif n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "right", n.right, x + ICON_SIZE, y, color)
                    SetBranchTex(tree, "left", n.left, x + 1, y, color)
                elseif n.right ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "topleft", n.right, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - (VERT_SEG / 2), color)
                elseif n.right ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomleft", n.right, x, y, color)
                elseif n.up ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "up", n.up, x, y + (VERT_SEG / 2), color)
                    SetBranchTex(tree, "down", n.down, x, y - (VERT_SEG / 2), color)
                elseif n.down ~= 0 then
                    SetBranchTex(tree, "down", n.down, x, y - (VERT_SEG / 2), color)
                elseif n.up ~= 0 then
                    SetBranchTex(tree, "up", n.up, x, y + (VERT_SEG / 2), color)
                end
            end
        end
    end
end

function addon:Branches_DrawPrereqGraph(tree)
    if not self.calcTalents or not tree or not tree._tab or not self.calcTalents[tree._tab] then return end
    EnsurePools(tree)
    local counts = currentRankCounts()
    local unmet, met = BuildGraphs(tree, counts)
    if GOLD_WINS then PruneUnmetWhereMet(unmet, met) end
    tree._branchTexIndex, tree._arrowTexIndex = 1, 1
    addon._drawingUnmet = true; DrawFromNodes(tree, unmet, COLOR_DISABLED)
    addon._drawingUnmet = false; DrawFromNodes(tree, met, COLOR_ENABLED)
    HideUnused(tree)
end

