-- ============================================================================
-- TalentCrafter (Vanilla 1.12.1 / Turtle WoW)
-- - Centered, dynamic-height trees with stitched backgrounds
-- - Branches/arrows use Blizzard atlas tiles
-- - Branches color by prereq state (gold = met, gray = unmet). A branch is
--   MET when you have >= 1 point in the prerequisite talent (matches Blizzard UI).
-- - Hardened init: build UI at PLAYER_LOGIN (not ADDON_LOADED), and force-load
--   Blizzard_TalentUI before reading talent data.
-- ============================================================================
local ADDON_NAME = "TalentCrafter"
local addon = {isInitialized = false, talentLines = {}, calcTalents = {}, pickOrder = {}}
local mainFrame, settingsPanel, infoPanel, calculatorFrame, exportFrame, importFrame, scrollFrame

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
    DRUID   = druidTalentOrder,
    HUNTER  = hunterTalentOrder,
    WARRIOR = warriorTalentOrder,
    WARLOCK = warlockTalentOrder,
    PALADIN = paladinTalentOrder,
    ROGUE   = rogueTalentOrder,
    MAGE    = mageTalentOrder,
    PRIEST  = priestTalentOrder,
    SHAMAN  = shamanTalentOrder
}

local _, playerClass = UnitClass("player")
local talentOrder = nil
local manualOverride = false

-- ===== Layout ===============================================================
local TREE_W, TREE_H = 296, 354
local ICON_SIZE = 36
local GRID_SPACING = 63
local NUM_COLS = 4
local INITIAL_X, INITIAL_Y = 35, 28
local TOP_PAD, BOTTOM_PAD = 36, 36

-- Branch/arrow tile size
local BRANCH_W, BRANCH_H = 32, 32
local ARROW_W, ARROW_H   = 32, 32

-- Colors
local COLOR_ENABLED  = {1.00, 0.90, 0.20, 1.0} -- warm gold
local COLOR_DISABLED = {0.70, 0.72, 0.78, 1.0} -- cool opaque gray

-- Draw policy: draw unmet (gray) first, then met (gold) on top.
local GOLD_WINS = true

-- Background insets (inside each gold-bordered tree)
local BG_INSET_L, BG_INSET_R = 8, 8
local BG_INSET_TOP    = 25
local BG_INSET_BOTTOM = 18

-- ===== Helpers ==============================================================

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFDAA520[TC]|r " .. (msg or ""), 1, 1, 1)
end

function addon:ToggleSettingsPanel()
    if settingsPanel:IsShown() then settingsPanel:Hide() else settingsPanel:Show() end
end

local function SplitString(s, sep)
    sep = sep or "%s"
    local t = {}
    for str in string.gfind(s or "", "([^" .. sep .. "]+)") do tinsert(t, str) end
    return t
end

local function SetTexDesaturated(tex, desaturate)
    if not tex then return end
    if tex.SetDesaturated then
        tex:SetDesaturated(desaturate)
    else
        tex:SetVertexColor(desaturate and 0.4 or 1, desaturate and 0.4 or 1, desaturate and 0.4 or 1)
    end
end

local function FindTalentByPosition(tabIndex, tier, column)
    for i = 1, GetNumTalents(tabIndex) do
        local _, _, t, c = GetTalentInfo(tabIndex, i)
        if t == tier and c == column then return i end
    end
end

local function ApplyDialogBackdrop(frame)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
end

local function ApplyGoldBorder(frame)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame:SetBackdropColor(0, 0, 0, 0.25)
    frame:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.9)
end

-- Stitch 4 tiles to fill exactly the 'frame' rect
local function BuildTalentBackground(frame, basename)
    local function quad(suffix, vAnchor1, vAnchor2)
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture("Interface\\TalentFrame\\" .. basename .. suffix)
        tex:SetPoint(vAnchor1, frame, vAnchor1, 0, 0)
        tex:SetPoint(vAnchor2, frame, vAnchor2, 0, 0)
        if string.find(suffix, "Top") then tex:SetPoint("BOTTOM", frame, "CENTER", 0, 0)
        else tex:SetPoint("TOP", frame, "CENTER", 0, 0) end
        if string.find(suffix, "Left") then tex:SetPoint("RIGHT", frame, "CENTER", 0, 0)
        else tex:SetPoint("LEFT",  frame, "CENTER", 0, 0) end
    end
    quad("-TopLeft",     "TOPLEFT",     "TOPLEFT")
    quad("-TopRight",    "TOPRIGHT",    "TOPRIGHT")
    quad("-BottomLeft",  "BOTTOMLEFT",  "BOTTOMLEFT")
    quad("-BottomRight", "BOTTOMRIGHT", "BOTTOMRIGHT")
end

-- ===== Guide UI updates =====================================================

function addon:UpdateTalentDisplay()
    if not addon.isInitialized then return end
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
    if not addon.isInitialized then return end
    if addon.glowingLine then addon.glowingLine.glow:Hide(); addon.glowingLine = nil end
    local current = addon.talentLines[UnitLevel("player")]
    if current then current.glow:Show(); addon.glowingLine = current end
end

function addon:Show()
    if not addon.isInitialized or UnitLevel("player") < 10 then return end
    addon:UpdateTalentDisplay()
    addon:UpdateGlow()
    mainFrame:Show()
    local off = max(0, (UnitLevel("player") - 10) * 30)
    if scrollFrame and scrollFrame:IsShown() then scrollFrame:SetVerticalScroll(off) end
end
function addon:Hide() if addon.isInitialized then mainFrame:Hide() end end

-- ===== Calculator logic =====================================================

local function currentRankCounts()
    local counts = {}
    for _, id in ipairs(addon.pickOrder) do counts[id] = (counts[id] or 0) + 1 end
    return counts
end

function addon:UpdateCalculatorOverlays()
    local counts = currentRankCounts()
    for tab, t in pairs(addon.calcTalents) do
        for idx, btn in pairs(t) do
            local id = tab .. "-" .. idx
            local _, _, _, _, _, maxRank = GetTalentInfo(tab, idx)
            local r = counts[id] or 0
            if r > 0 then
                btn.orderText:SetText(r)
                SetTexDesaturated(btn.icon, false)
                if r == maxRank then btn.border:Show() else btn.border:Hide() end
            else
                btn.orderText:SetText("")
                SetTexDesaturated(btn.icon, true)
                btn.border:Hide()
            end
        end
    end
end

function addon:OnTalentClick(tabIndex, talentIndex)
    -- prerequisite check vs current pickOrder (not character talents)
    local reqTier, reqColumn = GetTalentPrereqs(tabIndex, talentIndex)
    if reqTier and reqColumn then
        local pre = FindTalentByPosition(tabIndex, reqTier, reqColumn)
        if pre then
            local preName = GetTalentInfo(tabIndex, pre)
            local preId   = tabIndex .. "-" .. pre
            local have    = 0
            for _, v in ipairs(self.pickOrder) do if v == preId then have = have + 1 end end
            if have < 1 then
                self:Print("|cFFFF0000Requires at least 1 point in " .. (preName or "that talent") .. "|r")
                return
            end
        end
    end

    local id = tabIndex .. "-" .. talentIndex
    local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    local have = 0; for _, v in ipairs(self.pickOrder) do if v == id then have = have + 1 end end
    if have < maxRank then
        tinsert(self.pickOrder, id)
        self:UpdateCalculatorOverlays()
        for t = 1, 3 do self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
    end
end

function addon:OnTalentRightClick(tabIndex, talentIndex)
    local id = tabIndex .. "-" .. talentIndex
    for i = table.getn(self.pickOrder), 1, -1 do
        if self.pickOrder[i] == id then
            table.remove(self.pickOrder, i)
            self:UpdateCalculatorOverlays()
            for t = 1, 3 do self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
            return
        end
    end
end

function addon:ExportToString() return playerClass .. ":" .. table.concat(addon.pickOrder, ",") end

function addon:ImportFromString(s)
    local p = SplitString(s or "", ":")
    local cls, data = p[1], p[2]
    if cls ~= playerClass then
        addon:Print("|cFFFF0000Error:|r Build is for " .. (cls or "?") .. ", not " .. (playerClass or "?") .. ".")
        return
    end
    addon.pickOrder = {}
    if data then
        for _, id in ipairs(SplitString(data, ",")) do if string.find(id, "-") then tinsert(addon.pickOrder, id) end end
    end
    addon:UpdateCalculatorOverlays()
    addon:Print("Build imported successfully.")
    for t = 1, 3 do addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. t)) end
end

function addon:SaveAndUseCustomBuild()
    if table.getn(addon.pickOrder) == 0 then addon:Print("Cannot save an empty build."); return end
    local new = {}
    for i, id in ipairs(addon.pickOrder) do
        local pp = SplitString(id, "-"); local tab, idx = tonumber(pp[1]), tonumber(pp[2])
        local name, icon = GetTalentInfo(tab, idx)
        local level = 9 + i
        if name then new[level] = {name, icon} end
    end
    talentOrder = new; manualOverride = true
    addon:UpdateTalentDisplay(); addon:UpdateGlow()
    addon:Print("Custom build saved and applied.")
end

-- ===== Branch system (Blizzard atlas) ======================================

local MAX_BRANCH_TEXTURES, MAX_ARROW_TEXTURES = 128, 96

local function EnsurePools(tree)
    if tree._branches then return end
    tree._branches, tree._arrows = {}, {}
    local parent = tree.branchLayer
    for i = 1, MAX_BRANCH_TEXTURES do
        local t = parent:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\TalentFrame\\UI-TalentBranches")
        t:Hide(); tree._branches[i] = t
    end
    parent = tree.arrowLayer
    for i = 1, MAX_ARROW_TEXTURES do
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\TalentFrame\\UI-TalentArrows")
        t:Hide(); tree._arrows[i] = t
    end
end
local function GetBranchTex(tree) local i = tree._branchTexIndex; local t = tree._branches[i]; tree._branchTexIndex = i + 1; if t then t:Show(); return t end end
local function GetArrowTex (tree) local i = tree._arrowTexIndex ; local t = tree._arrows[i]  ; tree._arrowTexIndex  = i + 1; if t then t:Show(); return t end end
local function HideUnused(tree)
    for i = tree._branchTexIndex, MAX_BRANCH_TEXTURES do if tree._branches[i] then tree._branches[i]:Hide() end end
    for i = tree._arrowTexIndex,  MAX_ARROW_TEXTURES  do if tree._arrows[i]  then tree._arrows[i]:Hide()  end end
end

local function BranchXY(col, tier)
    local x = ((col - 1) * GRID_SPACING) + INITIAL_X + 2
    local y = -((tier - 1) * GRID_SPACING) - INITIAL_Y - 2
    return x, y
end

local function SafeGetCoord(tbl, key1, key2)
    if not tbl then return end
    local sub = tbl[key1]; return sub and sub[key2] or nil
end

local function SetBranchTex(tree, kind, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_BRANCH_TEXTURECOORDS, kind, variant); if not uv then return end
    local t = GetBranchTex(tree); if not t then return end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4]); t:SetWidth(BRANCH_W); t:SetHeight(BRANCH_H)
    local c = color or COLOR_ENABLED; t:SetVertexColor(c[1], c[2], c[3], c[4])
    t:ClearAllPoints(); t:SetPoint("CENTER", tree.branchLayer, "TOPLEFT", x, y)
end

local function SetArrowTex(tree, dir, variant, x, y, color)
    local uv = SafeGetCoord(TALENT_ARROW_TEXTURECOORDS, dir, variant); if not uv then return end
    local t = GetArrowTex(tree); if not t then return end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4]); t:SetWidth(ARROW_W); t:SetHeight(ARROW_H)
    local c = color or COLOR_ENABLED; t:SetVertexColor(c[1], c[2], c[3], c[4])
    t:ClearAllPoints(); t:SetPoint("CENTER", tree.arrowLayer, "TOPLEFT", x, y)
end

-- Build two graphs: unmet (gray) and met (gold)
local function InitBranchNodes()
    local m = {}
    for tier = 1, 11 do
        m[tier] = {}
        for col = 1, NUM_COLS do
            m[tier][col] = { id=nil, up=0, left=0, right=0, down=0, leftArrow=0, rightArrow=0, topArrow=0 }
        end
    end
    return m
end

local function BuildGraphs(tree, counts)
    local unmet, met = InitBranchNodes(), InitBranchNodes()
    -- mark present ids on both maps so junction logic works
    for idx in pairs(addon.calcTalents[tree._tab]) do
        local _, _, tier, col = GetTalentInfo(tree._tab, idx)
        unmet[tier][col].id = idx; met[tier][col].id = idx
    end
    for idx in pairs(addon.calcTalents[tree._tab]) do
        local _, _, bTier, bCol  = GetTalentInfo(tree._tab, idx)
        local pTier, pCol        = GetTalentPrereqs(tree._tab, idx)
        if pTier and pCol then
            local preIndex = FindTalentByPosition(tree._tab, pTier, pCol)
            -- GOLD only when you have at least 1 point in the prerequisite
            local have    = counts[tree._tab .. "-" .. preIndex] or 0
            local target  = (have >= 1) and met or unmet

            if bCol == pCol then
                -- vertical
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = 1
                    if (t + 1) < bTier then target[t + 1][bCol].up = 1 end
                end
                target[bTier][bCol].topArrow = 1
            elseif bTier == pTier then
                -- horizontal
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do
                    target[bTier][c].right = 1; target[bTier][c + 1].left = 1
                end
                if bCol < pCol then target[bTier][bCol].rightArrow = 1 else target[bTier][bCol].leftArrow = 1 end
            else
                -- L-shape: down on child col, then across on child's row
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = 1; target[t + 1][bCol].up = 1
                end
                local left, right = min(bCol, pCol), max(bCol, pCol)
                for c = left, right - 1 do
                    target[bTier][c].right = 1; target[bTier][c + 1].left = 1
                end
                target[bTier][bCol].topArrow = 1
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
                if m.up ~= 0        then u.up = 0        end
                if m.down ~= 0      then u.down = 0      end
                if m.left ~= 0      then u.left = 0      end
                if m.right ~= 0     then u.right = 0     end
                if m.leftArrow ~= 0 then u.leftArrow = 0 end
                if m.rightArrow ~= 0 then u.rightArrow=0 end
                if m.topArrow ~= 0  then u.topArrow = 0  end
            end
        end
    end
end

local function DrawFromNodes(tree, nodes, color)
    for tier = 1, 11 do
        for col = 1, NUM_COLS do
            local n = nodes[tier][col]; local x, y = BranchXY(col, tier)
            if n.id then
                if n.up    ~= 0 then SetBranchTex(tree, "up",    n.up,    x, y + ICON_SIZE, color) end
                if n.down  ~= 0 then SetBranchTex(tree, "down",  n.down,  x, y - ICON_SIZE + 1, color) end
                if n.left  ~= 0 then SetBranchTex(tree, "left",  n.left,  x - ICON_SIZE, y, color) end
                if n.right ~= 0 then SetBranchTex(tree, "right", n.right, x + ICON_SIZE + 1, y, color) end

                if n.rightArrow ~= 0 then SetArrowTex(tree, "right", n.rightArrow, x + ICON_SIZE/2 + 5, y, color) end
                if n.leftArrow  ~= 0 then SetArrowTex(tree, "left",  n.leftArrow,  x - ICON_SIZE/2 - 5, y, color) end
                if n.topArrow   ~= 0 then SetArrowTex(tree, "top",   n.topArrow,   x, y + ICON_SIZE/2 + 5, color) end
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
                    SetBranchTex(tree, "left",  n.left,  x + 1,         y, color)
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
    if not self.calcTalents or not tree or not tree._tab or not self.calcTalents[tree._tab] then return end
    local counts = currentRankCounts()
    local unmet, met = BuildGraphs(tree, counts)
    if GOLD_WINS then PruneUnmetWhereMet(unmet, met) end
    tree._branchTexIndex, tree._arrowTexIndex = 1, 1
    DrawFromNodes(tree, unmet, COLOR_DISABLED)
    DrawFromNodes(tree, met,   COLOR_ENABLED)
    HideUnused(tree)
end

-- ===== Dynamic sizing / centering ==========================================

local function ComputeInitialX(treeWidth)  local gridWidth  = (NUM_COLS - 1) * GRID_SPACING; return floor((treeWidth  - gridWidth)  / 2) end
local function ComputeInitialY(treeHeight, maxTier)
    local gridHeight = (maxTier - 1) * GRID_SPACING
    return floor((treeHeight - gridHeight) / 2)
end

-- ===== UI creation ==========================================================

function addon:CreateFrames()
    -- Ensure Blizzard's Talent UI (and atlas tables) are loaded before we query
    if not IsAddOnLoaded("Blizzard_TalentUI") or not TALENT_BRANCH_TEXTURECOORDS then
        if TalentFrame_LoadUI then TalentFrame_LoadUI() else LoadAddOn("Blizzard_TalentUI") end
    end

    -- main (guide)
    mainFrame = CreateFrame("Frame", "TalentCrafterFrame", UIParent)
    mainFrame:SetWidth(280); mainFrame:SetHeight(300)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ApplyDialogBackdrop(mainFrame)
    mainFrame:SetMovable(true); mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    mainFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    mainFrame:SetScript("OnUpdate", function()
        if addon.glowingLine and mainFrame:IsShown() then
            local a = 0.5 + (math.sin(GetTime() * 6) * 0.3)
            addon.glowingLine.glow:SetAlpha(a)
        end
    end)

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    title:SetText("|cFFDAA520TalentCrafter|r")

    scrollFrame = CreateFrame("ScrollFrame", "TC_ScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 8, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 8)
    local child = CreateFrame("Frame", "TC_ScrollChild", scrollFrame)
    child:SetWidth(220); child:SetHeight(1530); scrollFrame:SetScrollChild(child)
    for i = 10, 60 do
        local line = CreateFrame("Frame", nil, child)
        line:SetWidth(220); line:SetHeight(30)
        line:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i - 10) * 30))
        local glow = line:CreateTexture(nil, "LOW")
        glow:SetAllPoints(true)
        glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0, 1); glow:Hide()
        line.glow = glow
        line.levelText = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.levelText:SetPoint("LEFT", line, "LEFT", 5, 0); line.levelText:SetText("lvl " .. i .. ":")
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetWidth(24); line.icon:SetHeight(24); line.icon:SetPoint("LEFT", line.levelText, "RIGHT", 5, 0)
        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.text:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
        line.text:SetWidth(140); line.text:SetJustifyH("LEFT")
        addon.talentLines[i] = line
    end

    -- settings + info
    settingsPanel = CreateFrame("Frame", "TalentCrafterSettings", UIParent)
    settingsPanel:SetWidth(250); settingsPanel:SetHeight(120)
    settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ApplyDialogBackdrop(settingsPanel); settingsPanel:Hide()
    settingsPanel:SetMovable(true); settingsPanel:EnableMouse(true)
    settingsPanel:RegisterForDrag("LeftButton")
    settingsPanel:SetScript("OnDragStart", function() this:StartMoving() end)
    settingsPanel:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    local sTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sTitle:SetPoint("TOP", settingsPanel, "TOP", 0, -10); sTitle:SetText("|cFFDAA520TalentCrafter|r — Settings")
    local sClose = CreateFrame("Button", nil, settingsPanel)
    sClose:SetWidth(16); sClose:SetHeight(16); sClose:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -5, -5)
    local sc = sClose:CreateTexture(nil, "ARTWORK"); sc:SetAllPoints(); sc:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    sClose:SetScript("OnClick", function() settingsPanel:Hide() end)

    infoPanel = CreateFrame("Frame", "TalentCrafterInfo", UIParent)
    infoPanel:SetWidth(300); infoPanel:SetHeight(180)
    infoPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ApplyDialogBackdrop(infoPanel); infoPanel:Hide()
    infoPanel:SetMovable(true); infoPanel:EnableMouse(true)
    infoPanel:RegisterForDrag("LeftButton")
    infoPanel:SetScript("OnDragStart", function() this:StartMoving() end)
    infoPanel:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    local iTitle = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    iTitle:SetPoint("TOP", infoPanel, "TOP", 0, -10); iTitle:SetText("|cFFDAA520TalentCrafter|r — Info")
    local iClose = CreateFrame("Button", nil, infoPanel)
    iClose:SetWidth(16); iClose:SetHeight(16); iClose:SetPoint("TOPRIGHT", infoPanel, "TOPRIGHT", -5, -5)
    local ic = iClose:CreateTexture(nil, "ARTWORK"); ic:SetAllPoints(); ic:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    iClose:SetScript("OnClick", function() infoPanel:Hide() end)
    local infoText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", infoPanel, "TOPLEFT", 15, -40)
    infoText:SetWidth(270); infoText:SetJustifyH("LEFT")
    infoText:SetText("Track talent progressions.\nCommands: /TC calc, /TC settings, /TC reset, /TC lock, /TC unlock")

    local settingsButton = CreateFrame("Button", nil, mainFrame)
    settingsButton:SetWidth(16); settingsButton:SetHeight(16)
    settingsButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)
    local sb = settingsButton:CreateTexture(nil, "ARTWORK"); sb:SetAllPoints(); sb:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    settingsButton:SetScript("OnClick", addon.ToggleSettingsPanel)

    local infoButton = CreateFrame("Button", nil, settingsPanel)
    infoButton:SetWidth(16); infoButton:SetHeight(16)
    infoButton:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -10, 10)
    local ib = infoButton:CreateTexture(nil, "ARTWORK"); ib:SetAllPoints(); ib:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    infoButton:SetScript("OnClick", function() settingsPanel:Hide(); infoPanel:Show() end)
    local iText = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iText:SetPoint("RIGHT", infoButton, "LEFT", -5, 0); iText:SetText("Info")

    local tie = CreateFrame("CheckButton", "TC_TieToTalentCheckbox", settingsPanel, "UICheckButtonTemplate")
    tie:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 20, -40)
    getglobal(tie:GetName() .. "Text"):SetText("Only show with Talent panel")
    tie:SetScript("OnClick", function()
        TC_SavedSettings.tieToTalent = this:GetChecked()
        local TF = getglobal("TalentFrame")
        if this:GetChecked() then if not TF or not TF:IsShown() then addon:Hide() end else addon:Show() end
    end)
    tie:SetChecked(TC_SavedSettings.tieToTalent or false)

    -- compute dynamic height after talent data is ensured present
    local maxTier = (function()
        local m = 1
        local tabs = GetNumTalentTabs() or 0
        for tab = 1, tabs do
            for i = 1, GetNumTalents(tab) do
                local _, _, t = GetTalentInfo(tab, i)
                if t and t > m then m = t end
            end
        end
        return m
    end)()
    TREE_H  = TOP_PAD + BOTTOM_PAD + (maxTier - 1) * GRID_SPACING + ICON_SIZE
    INITIAL_X = ComputeInitialX(TREE_W)
    INITIAL_Y = ComputeInitialY(TREE_H, maxTier)

    -- calculator frame
    calculatorFrame = CreateFrame("Frame", "TC_TalentCalculator", UIParent)
    calculatorFrame:SetWidth(3 * (TREE_W + 20) + 40); calculatorFrame:SetHeight(TREE_H + 100)
    calculatorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ApplyDialogBackdrop(calculatorFrame); calculatorFrame:Hide()
    calculatorFrame:SetMovable(true); calculatorFrame:EnableMouse(true)
    calculatorFrame:RegisterForDrag("LeftButton")
    calculatorFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    calculatorFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    local calcTitle = calculatorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    calcTitle:SetPoint("TOP", calculatorFrame, "TOP", 0, -10)
    local _, classToken = UnitClass("player")
    local className = classToken or "UNKNOWN"
    calcTitle:SetText(className .. " Talent Calculator")
    local calcClose = CreateFrame("Button", nil, calculatorFrame)
    calcClose:SetWidth(16); calcClose:SetHeight(16)
    calcClose:SetPoint("TOPRIGHT", calculatorFrame, "TOPRIGHT", -5, -5)
    local cc = calcClose:CreateTexture(nil, "ARTWORK"); cc:SetAllPoints(); cc:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    calcClose:SetScript("OnClick", function() calculatorFrame:Hide() end)

    -- trees + backgrounds
    for tab = 1, 3 do
        local name, _, _, background = GetTalentTabInfo(tab)
        local tree = CreateFrame("Frame", "TC_CalcTree" .. tab, calculatorFrame)
        tree._tab = tab
        tree:SetWidth(TREE_W); tree:SetHeight(TREE_H)
        tree:SetPoint("TOPLEFT", calculatorFrame, "TOPLEFT", (tab - 1) * (TREE_W + 20) + 20, -40)
        ApplyGoldBorder(tree)

        local gridHeight = (maxTier - 1) * GRID_SPACING + ICON_SIZE
        local bgFrame = CreateFrame("Frame", nil, tree)
        bgFrame:SetWidth(TREE_W - (BG_INSET_L + BG_INSET_R))
        bgFrame:SetHeight(gridHeight)
        bgFrame:SetPoint("TOPLEFT", tree, "TOPLEFT", BG_INSET_L, -BG_INSET_TOP)
        bgFrame:SetFrameLevel(tree:GetFrameLevel() - 1)
        tree.bgFrame = bgFrame

        local base = background or ""
        local slash = string.find(base, "[/\\][^/\\]*$")
        if slash then base = string.sub(base, slash + 1) end
        if base ~= "" then BuildTalentBackground(bgFrame, base) end

        local tfs = tree:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tfs:SetPoint("TOP", tree, "TOP", 0, -8)
        tfs:SetText(name or ("Tree " .. tab))

        tree.branchLayer = CreateFrame("Frame", nil, tree)
        tree.branchLayer:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, 0)
        tree.branchLayer:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)
        tree.arrowLayer = CreateFrame("Frame", nil, tree)
        tree.arrowLayer:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, 0)
        tree.arrowLayer:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)
        EnsurePools(tree)
    end

    -- buttons (talent icons)
    for tab = 1, GetNumTalentTabs() do
        addon.calcTalents[tab] = {}
        local parent = getglobal("TC_CalcTree" .. tab)
        for idx = 1, GetNumTalents(tab) do
            local _, icon, tier, col = GetTalentInfo(tab, idx)
            local btn = CreateFrame("Button", nil, parent)
            btn:SetWidth(ICON_SIZE); btn:SetHeight(ICON_SIZE)
            local x = INITIAL_X + (col - 1) * GRID_SPACING - ICON_SIZE / 2
            local y = INITIAL_Y + (tier - 1) * GRID_SPACING - ICON_SIZE / 2
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            btn.icon = btn:CreateTexture(nil, "ARTWORK"); btn.icon:SetAllPoints(true); btn.icon:SetTexture(icon)
            btn.border = btn:CreateTexture(nil, "OVERLAY"); btn.border:SetAllPoints(true); btn.border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress"); btn.border:Hide()
            btn.orderText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); btn.orderText:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local T, I = tab, idx
            btn:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then addon:OnTalentClick(T, I) else addon:OnTalentRightClick(T, I) end
            end)
            addon.calcTalents[tab][idx] = btn
        end
        addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
    end

    -- export/import
    exportFrame = CreateFrame("Frame", "TC_ExportFrame", calculatorFrame)
    exportFrame:SetWidth(420); exportFrame:SetHeight(100)
    exportFrame:SetPoint("CENTER", calculatorFrame, "CENTER", 0, 0)
    ApplyDialogBackdrop(exportFrame); exportFrame:Hide()
    local exportBox = CreateFrame("EditBox", "TC_ExportBox", exportFrame, "InputBoxTemplate")
    exportBox:SetWidth(380); exportBox:SetHeight(32); exportBox:SetPoint("CENTER", exportFrame, "CENTER", 0, 10); exportBox:SetAutoFocus(false)
    local exportClose = CreateFrame("Button", "TC_ExportClose", exportFrame, "UIPanelButtonTemplate")
    exportClose:SetWidth(80); exportClose:SetHeight(24); exportClose:SetText("Close"); exportClose:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 15)
    exportClose:SetScript("OnClick", function() exportFrame:Hide() end)

    importFrame = CreateFrame("Frame", "TC_ImportFrame", calculatorFrame)
    importFrame:SetWidth(420); importFrame:SetHeight(100)
    importFrame:SetPoint("CENTER", calculatorFrame, "CENTER", 0, 0)
    ApplyDialogBackdrop(importFrame); importFrame:Hide()
    local importBox = CreateFrame("EditBox", "TC_ImportBox", importFrame, "InputBoxTemplate")
    importBox:SetWidth(380); importBox:SetHeight(32); importBox:SetPoint("CENTER", importFrame, "CENTER", 0, 10); importBox:SetAutoFocus(true)
    local importAccept = CreateFrame("Button", "TC_ImportAccept", importFrame, "UIPanelButtonTemplate")
    importAccept:SetWidth(80); importAccept:SetHeight(24); importAccept:SetText("Import"); importAccept:SetPoint("BOTTOM", importFrame, "BOTTOM", 45, 15)
    importAccept:SetScript("OnClick", function() addon:ImportFromString(importBox:GetText()); importFrame:Hide() end)
    local importCancel = CreateFrame("Button", "TC_ImportCancel", importFrame, "UIPanelButtonTemplate")
    importCancel:SetWidth(80); importCancel:SetHeight(24); importCancel:SetText("Cancel"); importCancel:SetPoint("BOTTOM", importFrame, "BOTTOM", -45, 15)
    importCancel:SetScript("OnClick", function() importFrame:Hide() end)

    -- bottom buttons
    local clear = CreateFrame("Button", "TC_ClearButton", calculatorFrame, "UIPanelButtonTemplate")
    clear:SetWidth(120); clear:SetHeight(24); clear:SetText("Clear Build")
    clear:SetPoint("BOTTOMLEFT", calculatorFrame, "BOTTOMLEFT", 20, 15)
    clear:SetScript("OnClick", function()
        addon.pickOrder = {}; addon:UpdateCalculatorOverlays()
        for tab = 1, 3 do addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab)) end
    end)

    local save = CreateFrame("Button", "TC_SaveButton", calculatorFrame, "UIPanelButtonTemplate")
    save:SetWidth(120); save:SetHeight(24); save:SetText("Save & Use")
    save:SetPoint("BOTTOMRIGHT", calculatorFrame, "BOTTOMRIGHT", -20, 15)
    save:SetScript("OnClick", function()
        TC_CustomBuilds[playerClass] = addon.pickOrder
        addon:SaveAndUseCustomBuild()
    end)

    local ibtn = CreateFrame("Button", "TC_ImportButton", calculatorFrame, "UIPanelButtonTemplate")
    ibtn:SetWidth(80); ibtn:SetHeight(24); ibtn:SetText("Import")
    ibtn:SetPoint("BOTTOM", calculatorFrame, "BOTTOM", -45, 15)
    ibtn:SetScript("OnClick", function()
        exportFrame:Hide(); getglobal("TC_ImportBox"):SetText(""); importFrame:Show()
    end)

    local ebtn = CreateFrame("Button", "TC_ExportButton", calculatorFrame, "UIPanelButtonTemplate")
    ebtn:SetWidth(80); ebtn:SetHeight(24); ebtn:SetText("Export")
    ebtn:SetPoint("BOTTOM", calculatorFrame, "BOTTOM", 45, 15)
    ebtn:SetScript("OnClick", function()
        importFrame:Hide(); getglobal("TC_ExportBox"):SetText(addon:ExportToString()); getglobal("TC_ExportBox"):HighlightText(); exportFrame:Show()
    end)

    addon.isInitialized = true
end

-- ===== Events ===============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not TC_SavedSettings then TC_SavedSettings = {tieToTalent = false} end
        if not TC_CustomBuilds then TC_CustomBuilds = {} end
        if TC_CustomBuilds[playerClass] then addon.pickOrder = TC_CustomBuilds[playerClass] else addon.pickOrder = {} end
        -- do NOT create frames here; wait until PLAYER_LOGIN when all core data is ready
        this:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        addon:CreateFrames()

        -- Safely hook ToggleTalentFrame after Blizzard_TalentUI is loaded
        if ToggleTalentFrame then
            local origToggle = ToggleTalentFrame
            ToggleTalentFrame = function()
                origToggle()
                if TC_SavedSettings.tieToTalent then
                    local TF = getglobal("TalentFrame")
                    if TF and TF:IsShown() then addon:Show() else addon:Hide() end
                end
            end
        end

        if not TC_SavedSettings.tieToTalent then addon:Show() else addon:Hide() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if addon.isInitialized then
            if not TC_SavedSettings.tieToTalent then addon:Show() else addon:Hide() end
            addon:UpdateGlow()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        if addon.isInitialized and mainFrame:IsShown() then addon:UpdateGlow() end
    end
end)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

-- ===== Slash ================================================================
SLASH_TC1, SLASH_TC2 = "/tc", "/TC"
function SlashCmdList.TC(msg)
    if not addon.isInitialized then return end
    local cmd = string.lower(msg or "")
    if cmd == "settings" then
        settingsPanel:Show()
    elseif cmd == "calc" then
        if UnitLevel("player") < 10 then addon:Print("You must be at least level 10 to use the talent calculator."); return end
        if calculatorFrame:IsShown() then calculatorFrame:Hide() else
            calculatorFrame:Show(); addon:UpdateCalculatorOverlays()
            for tab = 1, 3 do addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab)) end
        end
    elseif cmd == "reset" then
        manualOverride = false
        addon:UpdateTalentDisplay(); addon:UpdateGlow()
        addon:Print("Guide reset to default.")
    elseif cmd == "lock" then
        mainFrame:SetMovable(false); addon:Print("Addon Frame |cFFFF8080Locked|r.")
    elseif cmd == "unlock" then
        mainFrame:SetMovable(true);  addon:Print("Addon Frame |cFF00FF00Unlocked|r.")
    elseif talentGuides[string.upper(cmd)] then
        manualOverride = true
        local sel = string.upper(cmd); talentOrder = talentGuides[sel]
        addon:UpdateTalentDisplay(); addon:UpdateGlow()
        addon:Print("Now showing " .. sel)
    else
        addon:Print("Usage: /tc [calc | settings | reset | lock | unlock]")
    end
end
