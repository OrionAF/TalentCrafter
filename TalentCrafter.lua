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
local BG_FADE_DURATION = 2 -- seconds crossfade

-- Rotating background artwork and credits
local ROTATING_BACKGROUNDS = {
    {
        title = "Kruul Artwork",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Kruul_Artwork",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Grim Reaches Illustration",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Grim_Reaches_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Lava Boss Illustration",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Lava_Boss_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Ironforge Music Artwork",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\ironforge_music",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Development Basement Artwork",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Development_Basement_Artwork",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Game Master Artwork",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\GM_Artwork_2",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Northwind Artwork",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\northwind_art",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Northwind Artwork 2",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\northwind_art_2",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Priest T3.5",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\priest_t35",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Rogue/Mage T3.5",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\rogue_mage",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Shaman/Warrior T3.5",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Shaman_Warrior_T35",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Paladin/Warlock T3.5",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\paladin_lock",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Grim Illustration",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Grim_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Level One Lunatic",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Lvl1_Lunatic_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Sorrowguard Keep",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\sorrowguard_keep",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Undead Hunter Tier 3.5",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Undead_Hunter_Tier35",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Turtle WoW Anniversary",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Turtle_Wow_Anniversary_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Rooting out the Evil",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Druid_Tier_Illustration_4k",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Gnarlmoon",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Gnarlmoon2",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Karazhan Anomalus",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Karazhan-Anomalus-Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Stormwrought Ruins",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Balor_Illustration",
        artist = "Lionel Schramm",
        website = "https://lionelschramm.carrd.co/"
    },
    {
        title = "Beyond the Greymane Wall",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\art_giln",
        artist = "Stonegut"
    },
    {
        title = "Deep in the Green",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\Deep_in_the_Green",
        artist = "Mikkel Lund Molberg"
    },
    {
        title = "Mysteries of Azeroth",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\art_adventurers",
        artist = "Misho Tenev"
    },
    {
        title = "Crescent Grove",
        texture = "Interface\\AddOns\\TalentCrafter\\Art\\art_crescent_grove_no_logo",
        artist = "Ghor"
    }
}

-- ===== Helpers ==============================================================

-- Settings defaults
local function EnsureSettings()
    if not TC_Settings then
        TC_Settings = {bgRotate = false, bgPreserve = false, bgAspect = 2.0, minimap = {}, bgDebug = false}
    else
        if TC_Settings.bgRotate == nil then
            TC_Settings.bgRotate = false
        end
        if TC_Settings.bgPreserve == nil then
            TC_Settings.bgPreserve = false
        end
        if not TC_Settings.bgAspect then
            TC_Settings.bgAspect = 2.0
        end
        if type(TC_Settings.minimap) ~= "table" then
            TC_Settings.minimap = {}
        end
        if TC_Settings.bgDebug == nil then
            TC_Settings.bgDebug = false
        end
    end
end

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFDAA520[TC]|r " .. (msg or ""), 1, 1, 1)
end

function addon:Debug(msg)
    EnsureSettings()
    if TC_Settings and TC_Settings.bgDebug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFDAA520[TC-DBG]|r " .. (msg or ""), 0.7, 0.9, 1)
    end
end

-- settings UI removed

local function SplitString(s, sep)
    sep = sep or "%s"
    local t = {}
    if not s or s == "" then
        return t
    end
    -- Only single-char separators are expected (":", "-", ",").
    -- Escape magic characters when building the class for Lua 5.0 patterns.
    if sep ~= "%s" and string.len(sep) == 1 then
        local ch = sep
        if ch == "-" or ch == "]" or ch == "^" or ch == "%" then
            sep = "%" .. ch
        end
    end
    for str in string.gfind(s, "([^" .. sep .. "]+)") do
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
    -- Prefer cached lookup if available
    if
        addon.posIndex and addon.posIndex[tabIndex] and addon.posIndex[tabIndex][tier] and
            addon.posIndex[tabIndex][tier][column]
     then
        return addon.posIndex[tabIndex][tier][column]
    end
    -- Fallback to linear scan
    for i = 1, GetNumTalents(tabIndex) do
        local _, _, t, c = GetTalentInfo(tabIndex, i)
        if t == tier and c == column then
            return i
        end
    end
end

-- ===== Ace3v/Lib integration (optional, detected at runtime) ==============

-- Embed AceHook and AceTimer into our addon table when available,
-- and prepare LibDataBroker/LibDBIcon launcher support.
do
    local AceHook = LibStub and LibStub("AceHook-3.0", true)
    local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
    if AceHook and AceHook.Embed then
        AceHook:Embed(addon)
    end
    if AceTimer and AceTimer.Embed then
        AceTimer:Embed(addon)
    end

    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    -- Hook TalentFrame::OnShow using AceHook if available
    function addon:InstallTalentFrameHook()
        local TF = getglobal("TalentFrame")
        if not TF then
            return
        end
        if self.HookScript and not self._aceHookedTF then
            self:HookScript(
                TF,
                "OnShow",
                function()
                    if not addon.isInitialized then
                        addon:TryInitializeNow()
                    end
                end
            )
            self._aceHookedTF = true
        else
            -- Fallback: use the original wrapper hook
            if addon.LegacyHookTalentFrameOnShow then
                addon:LegacyHookTalentFrameOnShow()
            end
        end
    end

    -- Minimap/LDB launcher
    function addon:InitLauncher()
        if not LDB or not DBIcon then
            return
        end
        if self._ldb then
            return
        end
        EnsureSettings()
        self._ldb =
            LDB:NewDataObject(
            "TalentCrafter",
            {
                type = "launcher",
                label = "TalentCrafter",
                icon = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        -- Toggle calculator
                        if not addon.isInitialized then
                            addon:TryInitializeNow()
                        end
                        if calculatorFrame and calculatorFrame:IsShown() then
                            calculatorFrame:Hide()
                        else
                            if calculatorFrame then
                                calculatorFrame:Show()
                                addon:UpdateCalculatorOverlays()
                                for tab = 1, 3 do
                                    addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
                                end
                            end
                        end
                    else
                        addon:ToggleInfo()
                    end
                end,
                OnTooltipShow = function(tt)
                    tt:AddLine("TalentCrafter")
                    tt:AddLine("Left-click: Toggle calculator", 0.8, 0.8, 0.8)
                    tt:AddLine("Right-click: Info", 0.8, 0.8, 0.8)
                end
            }
        )
        DBIcon:Register("TalentCrafter", self._ldb, TC_Settings.minimap)
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

-- Adjust tree backdrops to better reveal rotating background art
function addon:RefreshTreeBackdrops()
    local alpha = 0.25
    if TC_Settings and TC_Settings.bgRotate then
        alpha = 0.10
    end
    for tab = 1, 3 do
        local tree = getglobal("TC_CalcTree" .. tab)
        if tree and tree.SetBackdropColor then
            tree:SetBackdropColor(0, 0, 0, alpha)
        end
    end
end

-- Adjust calculator backdrop fill to keep border visible while showing art
function addon:RefreshCalcBackdrop()
    if not calculatorFrame or not calculatorFrame.SetBackdropColor then
        return
    end
    if TC_Settings and TC_Settings.bgRotate then
        calculatorFrame:SetBackdropColor(0, 0, 0, 0.00)
    else
        calculatorFrame:SetBackdropColor(0, 0, 0, 0.35)
    end
end

-- Info window showing background credits
local function BuildInfoFrame()
    if addon.infoFrame then
        return
    end
    local f = CreateFrame("Frame", "TC_InfoFrame", UIParent)
    f:SetWidth(420)
    f:SetHeight(480)
    f:SetPoint("CENTER")
    ApplyDialogBackdrop(f)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("TalentCrafter Info")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", -32, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(360)
    scroll:SetScrollChild(content)

    local y = 0
    local intro = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 0, y)
    intro:SetWidth(360)
    intro:SetJustifyH("LEFT")
    intro:SetText("Background artwork credits:")
    y = y - 18

    for _, art in ipairs(ROTATING_BACKGROUNDS) do
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", 0, y)
        line:SetWidth(360)
        line:SetJustifyH("LEFT")
        local txt = art.title .. " — " .. art.artist
        if art.website then
            txt = txt .. " (" .. art.website .. ")"
        end
        line:SetText(txt)
        y = y - 14
    end
    content:SetHeight(-y + 20)
    addon.infoFrame = f
end

function addon:ToggleInfo()
    if not addon.infoFrame then
        BuildInfoFrame()
    end
    if addon.infoFrame:IsShown() then
        addon.infoFrame:Hide()
    else
        addon.infoFrame:Show()
    end
end

-- Stitch 4 tiles to fill exactly the 'frame' rect
local BG_OVERSCAN = 1.15
local function BuildTalentBackground(frame, basename)
    -- Wait for valid size before drawing
    local W, H = frame:GetWidth(), frame:GetHeight()
    if not W or not H or W <= 0 or H <= 0 then
        frame:SetScript(
            "OnSizeChanged",
            function(self)
                self:SetScript("OnSizeChanged", nil)
                BuildTalentBackground(self, basename)
            end
        )
        return
    end

    -- Crop via ScrollFrame so oversized tiles never bleed outside the tree
    local atlasW, atlasH = 320, 384
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
    if not addon.isInitialized then
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
    if addon._descCache then
        return true
    end
    if not Turtle_TalentsData then
        if LoadAddOn then
            pcall(LoadAddOn, "Turtle_InspectTalentsUI")
            if not Turtle_TalentsData then
                -- Try common alternate name just in case
                pcall(LoadAddOn, "Turtle_InspectTalentUI")
            end
        end
    end
    if not Turtle_TalentsData then
        return false
    end
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

-- Display talent tooltip with Turtle per-rank data
function addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex)
    if not ownerBtn or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(ownerBtn, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Always base tooltip on calculator state, not character talents.
    local name, _, tier, column, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    local counts = currentRankCounts()
    local id = tabIndex .. "-" .. talentIndex
    -- Try to read the displayed rank directly from the button text first
    local plannedFromText, maxFromText
    if ownerBtn and ownerBtn.rankText and ownerBtn.rankText.GetText then
        local rt = ownerBtn.rankText:GetText()
        if type(rt) == "string" then
            -- Lua 5.0: use string.find captures instead of string.match
            local _, _, a, b = string.find(rt, "^(%d+)%s*/%s*(%d+)$")
            if a then
                plannedFromText = tonumber(a)
            end
            if b then
                maxFromText = tonumber(b)
            end
        end
    end
    -- Prefer button-cached values if available (most accurate mid-click),
    -- then recomputed counts, then the parsed text from the icon (last resort)
    local planned = (ownerBtn and ownerBtn._planned) or counts[id] or plannedFromText or 0
    maxRank = (ownerBtn and ownerBtn._maxRank) or maxFromText or maxRank or 0

    -- Header + planned rank
    GameTooltip:AddLine(name or "(unknown)", 1, 1, 1)
    GameTooltip:AddLine("Rank " .. planned .. "/" .. maxRank, 0.9, 0.9, 0.9)

    -- Current and next rank descriptions from Turtle data (if available)
    if EnsureTurtleTalentData() then
        local descTable = addon._descCache and addon._descCache[playerClass]
        local list = descTable and descTable[tabIndex] and descTable[tabIndex][name]
        if type(list) == "table" then
            if planned > 0 then
                local curText = list[planned]
                if type(curText) == "string" and curText ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Current rank:", 1, 0.82, 0)
                    GameTooltip:AddLine(curText, 1, 1, 1, true)
                end
            end
            if planned < (maxRank or 0) then
                local nextText = list[planned + 1]
                if type(nextText) == "string" and nextText ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Next rank:", 1, 0.82, 0)
                    GameTooltip:AddLine(nextText, 1, 1, 1, true)
                end
            end
        end
    end

    -- Requirements based on calculator state
    local reqPoints = ((tier or 1) - 1) * 5
    if reqPoints and reqPoints > 0 then
        local tabSpent = 0
        for k, v in pairs(counts) do
            local dash = string.find(k, "-")
            if dash then
                local t = tonumber(string.sub(k, 1, dash - 1))
                if t == tabIndex then
                    tabSpent = tabSpent + v
                end
            end
        end
        local ok = tabSpent >= reqPoints
        local r, g, b = (ok and 0.7 or 1), (ok and 0.9 or 0), (ok and 0.7 or 0)
        local tabName = GetTalentTabInfo(tabIndex)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Requires " .. reqPoints .. " points in " .. (tabName or "this tree"), r, g, b)
    end

    local pTier, pCol = GetTalentPrereqs(tabIndex, talentIndex)
    if pTier and pCol then
        local preIndex = FindTalentByPosition(tabIndex, pTier, pCol)
        if preIndex then
            local preName, _, _, _, _, preMaxRank = GetTalentInfo(tabIndex, preIndex)
            local havePre = counts[tabIndex .. "-" .. preIndex] or 0
            local ok = preMaxRank and havePre >= preMaxRank
            local r, g, b = (ok and 0.7 or 1), (ok and 0.9 or 0), (ok and 0.7 or 0)
            GameTooltip:AddLine("Requires max rank in " .. (preName or "that talent"), r, g, b)
        end
    end

    GameTooltip:Show()
end

-- Rebuild pickOrder by applying each pick in sequence and dropping any that
-- no longer meet tree points or prerequisite max-rank requirements.
function addon:RevalidatePickOrder()
    local newOrder = {}
    local counts = {}
    local tabSpent = {[1] = 0, [2] = 0, [3] = 0}
    local function addCount(id)
        counts[id] = (counts[id] or 0) + 1
        local dash = string.find(id, "-")
        if dash then
            local t = tonumber(string.sub(id, 1, dash - 1))
            if t then
                tabSpent[t] = (tabSpent[t] or 0) + 1
            end
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
    local tabTotals = {[1] = 0, [2] = 0, [3] = 0}
    for k, v in pairs(counts) do
        local dash = string.find(k, "-")
        if dash then
            local t = tonumber(string.sub(k, 1, dash - 1))
            if t and tabTotals[t] then
                tabTotals[t] = tabTotals[t] + (v or 0)
            end
        end
    end
    local totalSpent = (tabTotals[1] + tabTotals[2] + tabTotals[3])
    for tab, t in pairs(addon.calcTalents) do
        for idx, btn in pairs(t) do
            local id = tab .. "-" .. idx
            local _, _, tier, _, _, maxRank = GetTalentInfo(tab, idx)
            local r = counts[id] or 0
            -- expose planned/max for tooltip to read
            btn._planned = r
            btn._maxRank = maxRank or 0
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
        calculatorFrame.summaryText:SetText(
            string.format(
                "%s %d/%d/%d  |  Points left: %d",
                className,
                tabTotals[1] or 0,
                tabTotals[2] or 0,
                tabTotals[3] or 0,
                max(0, left)
            )
        )
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
    maxRank = maxRank or 0
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
        -- Prime the hovered button with the post-click planned rank so
        -- tooltip refresh uses the up-to-date value even before overlays run.
        if ownerBtn then
            ownerBtn._planned = (have or 0) + 1
            ownerBtn._maxRank = maxRank or 0
        end
        self:UpdateCalculatorOverlays()
        for t = 1, 3 do
            self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t))
        end
        if ownerBtn and GameTooltip then
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
            if self.RevalidatePickOrder then
                self:RevalidatePickOrder()
            end
            -- Update cached planned rank for hovered button before overlays
            if ownerBtn then
                local counts = currentRankCounts()
                ownerBtn._planned = counts[id] or 0
                local _, _, _, _, _, maxRank2 = GetTalentInfo(tabIndex, talentIndex)
                ownerBtn._maxRank = maxRank2 or 0
            end
            self:UpdateCalculatorOverlays()
            for t = 1, 3 do
                self:DrawPrereqGraph(getglobal("TC_CalcTree" .. t))
            end
            if ownerBtn and GameTooltip then
                addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex)
            end
            return
        end
    end
end

-- QoL helpers
function addon:FillTalentToMax(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
    maxRank = maxRank or 0
    local prevCount = -1
    for _i = 1, maxRank do
        local counts = currentRankCounts()
        local have = counts[id] or 0
        if have == prevCount then
            break
        end
        prevCount = have
        if have >= maxRank then
            break
        end
        local before = table.getn(self.pickOrder)
        self:OnTalentClick(tabIndex, talentIndex, ownerBtn)
        if table.getn(self.pickOrder) == before then
            break -- hit a gate or cap; stop trying
        end
    end
end

function addon:ClearTalentAllRanks(tabIndex, talentIndex, ownerBtn)
    local id = tabIndex .. "-" .. talentIndex
    local changed = false
    while true do
        local before = table.getn(self.pickOrder)
        self:OnTalentRightClick(tabIndex, talentIndex, ownerBtn)
        if table.getn(self.pickOrder) == before then
            break
        end
        changed = true
    end
    if changed and ownerBtn and GameTooltip then
        addon:ShowTalentTooltip(ownerBtn, tabIndex, talentIndex)
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
    if self.RevalidatePickOrder then
        self:RevalidatePickOrder()
    end
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
            if not addon._poolWarnedBranches then
                addon._poolWarnedBranches = true
                addon:Print("Branch pool limit reached; some lines may not render.")
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
                addon:Print("Arrow pool limit reached; some arrows may not render.")
            end
            return nil
        end
    end
    tree._arrowTexIndex = i + 1
    t:Show()
    return t
end
local function HideUnused(tree)
    for i = tree._branchTexIndex, table.getn(tree._branches) do
        if tree._branches[i] then
            tree._branches[i]:Hide()
        end
    end
    for i = tree._arrowTexIndex, table.getn(tree._arrows) do
        if tree._arrows[i] then
            tree._arrows[i]:Hide()
        end
    end
end

local function BranchXY(col, tier)
    -- Align to exact icon centers; avoid extra fudge to prevent gaps
    local x = ((col - 1) * GRID_SPACING) + INITIAL_X
    local y = -((tier - 1) * GRID_SPACING) - INITIAL_Y
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
    -- Strategy: always use atlas variant 1 UVs; drive unmet color via desaturation
    local uv = SafeGetCoord(TALENT_BRANCH_TEXTURECOORDS, kind, 1)
    if not uv then return end
    local t = GetBranchTex(tree)
    if not t then
        return
    end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(BRANCH_W)
    t:SetHeight(BRANCH_H)
    local isUnmet = (addon and addon._drawingUnmet) or (color == COLOR_DISABLED)
    if isUnmet then
        if t.SetDesaturated then
            t:SetDesaturated(true)
            t:SetVertexColor(1, 1, 1, 1)
        else
            -- Fallback: approximate gray
            t:SetVertexColor(0.6, 0.6, 0.6, 1)
        end
    else
        if t.SetDesaturated then
            t:SetDesaturated(false)
        end
        local c = color or COLOR_ENABLED
        t:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    t:ClearAllPoints()
    t:SetPoint("CENTER", tree.branchLayer, "TOPLEFT", x, y)
end

local function SetArrowTex(tree, dir, variant, x, y, color)
    -- Strategy: always use atlas variant 1 UVs; drive unmet color via desaturation
    local uv = SafeGetCoord(TALENT_ARROW_TEXTURECOORDS, dir, 1)
    if not uv then return end
    local t = GetArrowTex(tree)
    if not t then
        return
    end
    t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
    t:SetWidth(ARROW_W)
    t:SetHeight(ARROW_H)
    local isUnmet = (addon and addon._drawingUnmet) or (color == COLOR_DISABLED)
    if isUnmet then
        if t.SetDesaturated then
            t:SetDesaturated(true)
            t:SetVertexColor(1, 1, 1, 1)
        else
            t:SetVertexColor(0.6, 0.6, 0.6, 1)
        end
    else
        if t.SetDesaturated then
            t:SetDesaturated(false)
        end
        local c = color or COLOR_ENABLED
        t:SetVertexColor(c[1], c[2], c[3], c[4])
    end
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
            -- Use a single variant index for presence; color selects atlas row
            local flag = 1

            if bCol == pCol then
                -- vertical
                for t = pTier, bTier - 1 do
                    target[t][bCol].down = flag
                    if (t + 1) < bTier then
                        target[t + 1][bCol].up = flag
                    else
                        -- ensure last segment reaches into the child cell
                        target[bTier][bCol].up = flag
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
                -- Use Blizzard/Vanilla placement that the atlas is authored for
                if n.up ~= 0 then
                    -- From icon edge outward by half a branch tile
                    SetBranchTex(tree, "up", n.up, x, y + (ICON_SIZE / 2 + BRANCH_H / 2), color)
                end
                if n.down ~= 0 then
                    SetBranchTex(tree, "down", n.down, x, y - (ICON_SIZE / 2 + BRANCH_H / 2) + 1, color)
                end
                if n.left ~= 0 then
                    SetBranchTex(tree, "left", n.left, x - (ICON_SIZE / 2 + BRANCH_W / 2), y, color)
                end
                if n.right ~= 0 then
                    SetBranchTex(tree, "right", n.right, x + (ICON_SIZE / 2 + BRANCH_W / 2) + 1, y, color)
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
                    -- Bottom half of the vertical segment in this cell
                    SetBranchTex(tree, "down", n.down, x, y - (BRANCH_H / 2), color)
                elseif n.left ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomright", n.left, x, y, color)
                elseif n.left ~= 0 and n.right ~= 0 then
                    SetBranchTex(tree, "right", n.right, x + ICON_SIZE, y, color)
                    SetBranchTex(tree, "left", n.left, x + 1, y, color)
                elseif n.right ~= 0 and n.down ~= 0 then
                    SetBranchTex(tree, "topleft", n.right, x, y, color)
                    SetBranchTex(tree, "down", n.down, x, y - (BRANCH_H / 2), color)
                elseif n.right ~= 0 and n.up ~= 0 then
                    SetBranchTex(tree, "bottomleft", n.right, x, y, color)
                elseif n.up ~= 0 and n.down ~= 0 then
                    -- Place vertical halves to meet in the middle of the cell
                    SetBranchTex(tree, "up", n.up, x, y + (BRANCH_H / 2), color)
                    SetBranchTex(tree, "down", n.down, x, y - (BRANCH_H / 2), color)
                elseif n.down ~= 0 then
                    -- single vertical continuation (bottom half)
                    SetBranchTex(tree, "down", n.down, x, y - (BRANCH_H / 2), color)
                elseif n.up ~= 0 then
                    -- single vertical continuation (top half)
                    SetBranchTex(tree, "up", n.up, x, y + (BRANCH_H / 2), color)
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
    -- Draw unmet in gray (atlas gray if available, else tint), met in gold
    addon._drawingUnmet = true
    DrawFromNodes(tree, unmet, COLOR_DISABLED)
    addon._drawingUnmet = false
    DrawFromNodes(tree, met, COLOR_ENABLED)
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
        toggle:SetScript(
            "OnClick",
            function()
                addon.viewerCollapsed = not addon.viewerCollapsed
                if addon.viewerCollapsed then
                    mainFrame:Hide()
                else
                    mainFrame:Show()
                end
                UpdateToggleIcon()
            end
        )
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

    -- settings panel removed

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
            m = 7
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
    -- Use a dialog backdrop; adjust fill alpha based on background setting
    ApplyDialogBackdrop(calculatorFrame)
    addon:RefreshCalcBackdrop()
    calculatorFrame:Hide()
    if UISpecialFrames then
        tinsert(UISpecialFrames, "TC_TalentCalculator")
    end
    -- Rotating global background (lazy-init; can be toggled via /tc bg on)
    EnsureSettings()
    if TC_Settings.bgRotate then
        addon:InitBackgroundRotator(calculatorFrame)
    end
    calculatorFrame:SetMovable(false)
    calculatorFrame:EnableMouse(true)
    -- Intentionally disable StartMoving/StopMoving on 1.12; we provide a safe Move mode instead.
    calculatorFrame:SetScript("OnDragStart", nil)
    calculatorFrame:SetScript("OnDragStop", nil)
    -- Restore calculator position if saved
    EnsureSettings()
    if TC_Settings and TC_Settings.calcPos then
        local pos = TC_Settings.calcPos
        calculatorFrame:ClearAllPoints()
        local rel = getglobal(pos.relativeTo or "UIParent") or UIParent
        calculatorFrame:SetPoint(pos.point or "CENTER", rel, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Move mode overlay (manual drag without StartMoving/StopMoving)
    local mover = CreateFrame("Frame", "TC_MoveOverlay", calculatorFrame)
    mover:SetAllPoints(calculatorFrame)
    mover:SetFrameStrata(calculatorFrame:GetFrameStrata())
    mover:SetFrameLevel((calculatorFrame:GetFrameLevel() or 0) + 3)
    mover:Hide()
    mover:EnableMouse(true)
    ApplyGoldBorder(mover)
    mover:SetBackdropColor(0, 0, 0, 0.35)
    local mvText = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mvText:SetPoint("TOP", mover, "TOP", 0, -8)
    mvText:SetText("Move Mode – drag anywhere")
    mover.text = mvText

    local dragging = false
    local dx, dy = 0, 0
    mover:SetScript(
        "OnMouseDown",
        function()
            local scale = UIParent:GetScale() or 1
            local x, y = GetCursorPosition()
            x, y = x / scale, y / scale
            local left = calculatorFrame:GetLeft() or 0
            local bottom = calculatorFrame:GetBottom() or 0
            dx = x - left
            dy = y - bottom
            dragging = true
        end
    )
    mover:SetScript(
        "OnMouseUp",
        function()
            dragging = false
            -- persist position once after release
            EnsureSettings()
            if TC_Settings then
                local ok, p, rel, rp, x, y = pcall(calculatorFrame.GetPoint, calculatorFrame)
                if ok then
                    local relName = "UIParent"
                    if rel and rel.GetName then
                        local ok2, name = pcall(rel.GetName, rel)
                        if ok2 and name then
                            relName = name
                        end
                    end
                    TC_Settings.calcPos = {
                        point = p or "BOTTOMLEFT",
                        relativeTo = relName,
                        relativePoint = rp or "BOTTOMLEFT",
                        x = x or 0,
                        y = y or 0
                    }
                end
            end
        end
    )
    mover:SetScript(
        "OnUpdate",
        function()
            if not dragging then
                return
            end
            local scale = UIParent:GetScale() or 1
            local x, y = GetCursorPosition()
            x, y = x / scale, y / scale
            local newLeft = x - (dx or 0)
            local newBottom = y - (dy or 0)
            calculatorFrame:ClearAllPoints()
            calculatorFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newLeft, newBottom)
        end
    )
    addon._moveOverlay = mover
    -- Put summary text on a tiny overlay frame above the rotator and trees
    local calcOverlay = CreateFrame("Frame", nil, calculatorFrame)
    calcOverlay:SetAllPoints(calculatorFrame)
    calcOverlay:SetFrameStrata(calculatorFrame:GetFrameStrata())
    calcOverlay:SetFrameLevel((calculatorFrame:GetFrameLevel() or 0) + 3)
    calcOverlay:EnableMouse(false)
    local calcTitle = calcOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    calcTitle:SetPoint("TOP", calcOverlay, "TOP", 0, -10)
    local _, classToken = UnitClass("player")
    local className = classToken or "UNKNOWN"
    calcTitle:SetText(className .. " 0/0/0  |  Points left: 51")
    calculatorFrame.summaryText = calcTitle
    calculatorFrame.calcOverlay = calcOverlay
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

    -- Move button (top-left)
    local moveBtn = CreateFrame("Button", "TC_MoveButton", calculatorFrame, "UIPanelButtonTemplate")
    moveBtn:SetWidth(48)
    moveBtn:SetHeight(20)
    moveBtn:SetPoint("TOPLEFT", calculatorFrame, "TOPLEFT", 8, -6)
    moveBtn:SetText("Move")
    -- Ensure the button is above the move overlay so it remains clickable
    moveBtn:SetFrameStrata(calculatorFrame:GetFrameStrata())
    moveBtn:SetFrameLevel((mover:GetFrameLevel() or 0) + 1)
    moveBtn:SetScript(
        "OnClick",
        function()
            if addon._moveMode then
                -- Exit move mode
                addon._moveMode = false
                dragging = false
                if addon._moveOverlay then
                    addon._moveOverlay:Hide()
                end
                moveBtn:SetText("Move")
                -- Safely re-enable background rotator shortly after exiting move mode
                EnsureSettings()
                if TC_Settings.bgRotate and calculatorFrame and not calculatorFrame._bgFrames then
                    addon:After(
                        0.10,
                        function()
                            -- Re-check guards inside delayed call
                            if TC_Settings.bgRotate and calculatorFrame and not calculatorFrame._bgFrames then
                                addon:InitBackgroundRotator(calculatorFrame)
                            end
                        end
                    )
                end
            else
                -- Enter move mode: freeze rotator and show overlay for manual drag
                addon._moveMode = true
                addon:FreezeBackgroundRotator(calculatorFrame)
                if addon._moveOverlay then
                    addon._moveOverlay:Show()
                end
                moveBtn:SetText("Done")
            end
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
        -- Ensure trees render above any rotating background holders
        tree:SetFrameLevel((calculatorFrame:GetFrameLevel() or 0) + 2)
        ApplyGoldBorder(tree)
        -- When global rotator is active, reduce the fill alpha so art shows through
        if TC_Settings and TC_Settings.bgRotate and tree.SetBackdropColor then
            tree:SetBackdropColor(0, 0, 0, 0.10)
        end

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
        -- remove old dark backing overlay to let the global background show through
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
        clearTree:SetScript(
            "OnClick",
            function()
                local keep = {}
                for _, id in ipairs(addon.pickOrder) do
                    local dash = string.find(id, "-")
                    local t = tonumber(string.sub(id, 1, dash - 1))
                    if t ~= tree._tab then
                        tinsert(keep, id)
                    end
                end
                addon.pickOrder = keep
                if addon.RevalidatePickOrder then
                    addon:RevalidatePickOrder()
                end
                addon:UpdateCalculatorOverlays()
                for i = 1, 3 do
                    addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. i))
                end
            end
        )
    end

    -- buttons (talent icons)
    for tab = 1, GetNumTalentTabs() do
        addon.calcTalents[tab] = {}
        addon.posIndex = addon.posIndex or {}
        addon.posIndex[tab] = addon.posIndex[tab] or {}
        local parent = getglobal("TC_CalcTree" .. tab)
        for idx = 1, GetNumTalents(tab) do
            local _, icon, tier, col = GetTalentInfo(tab, idx)
            -- build fast lookup: (tab,tier,col) -> talentIndex
            addon.posIndex[tab][tier] = addon.posIndex[tab][tier] or {}
            addon.posIndex[tab][tier][col] = idx
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
            -- cache indices for reliable tooltip refresh
            btn._tabIndex = tab
            btn._talentIndex = idx
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local T, I = tab, idx
            -- Vanilla 1.12 scripts do not pass 'self'; use captured btn
            btn:SetScript(
                "OnEnter",
                function()
                    addon:ShowTalentTooltip(btn, T, I)
                end
            )
            btn:SetScript(
                "OnLeave",
                function()
                    GameTooltip:Hide()
                end
            )
            btn:SetScript(
                "OnClick",
                function()
                    local b = arg1
                    if (b == "LeftButton" or b == "LeftButtonUp") and IsShiftKeyDown() then
                        addon:FillTalentToMax(T, I, btn)
                    elseif (b == "RightButton" or b == "RightButtonUp") and IsControlKeyDown() then
                        addon:ClearTalentAllRanks(T, I, btn)
                    elseif b == "LeftButton" or b == "LeftButtonUp" then
                        addon:OnTalentClick(T, I, btn)
                    elseif b == "RightButton" or b == "RightButtonUp" then
                        addon:OnTalentRightClick(T, I, btn)
                    end
                end
            )
            addon.calcTalents[tab][idx] = btn
        end
        addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
    end
    -- Ensure tree backdrops reflect current background setting on first build
    addon:RefreshTreeBackdrops()

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
function addon:LegacyHookTalentFrameOnShow()
    local TF = getglobal("TalentFrame")
    if TF and not TF._tcHooked then
        TF._tcHooked = true
        local prev = TF:GetScript("OnShow")
        TF:SetScript(
            "OnShow",
            function()
                if prev then
                    prev()
                end
                if not addon.isInitialized then
                    addon:TryInitializeNow()
                end
            end
        )
    end
end
eventFrame:SetScript(
    "OnEvent",
    function()
        if event == "ADDON_LOADED" then
            if arg1 == ADDON_NAME then
                if not TC_CustomBuilds then
                    TC_CustomBuilds = {}
                end
                -- Re-evaluate class to be safe on late cores
                _, playerClass = UnitClass("player")
                if TC_CustomBuilds[playerClass] then
                    addon.pickOrder = TC_CustomBuilds[playerClass]
                else
                    addon.pickOrder = {}
                end
                if addon.InitLauncher then
                    addon:InitLauncher()
                end
            elseif arg1 == "Blizzard_TalentUI" then
                -- If Blizzard Talent UI just loaded, try to initialize now
                if not addon.isInitialized then
                    addon:TryInitializeNow()
                end
                addon:InstallTalentFrameHook()
            end
        elseif event == "PLAYER_LOGIN" then
            -- Try to initialize immediately; fall back to SPELLS_CHANGED if not ready
            if not addon:TryInitializeNow() then
                eventFrame:RegisterEvent("SPELLS_CHANGED")
            end
            addon:InstallTalentFrameHook()
            if addon.InitLauncher then
                addon:InitLauncher()
            end
        elseif event == "SPELLS_CHANGED" then
            -- Viewer now anchors to TalentFrame and inherits its visibility.
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

function addon:TryInitializeNow()
    if addon.isInitialized then
        return true
    end
    -- Try to load Blizzard Talent UI and create frames if data is ready
    if not IsAddOnLoaded("Blizzard_TalentUI") then
        if TalentFrame_LoadUI then
            TalentFrame_LoadUI()
        else
            LoadAddOn("Blizzard_TalentUI")
        end
    end
    -- Readiness: at least one tab and talents populated
    local tabs = GetNumTalentTabs() or 0
    if tabs > 0 then
        local ok = true
        for t = 1, tabs do
            if (GetNumTalents(t) or 0) == 0 then
                ok = false
                break
            end
        end
        if ok and not addon.isInitialized then
            addon:CreateFrames()
        end
    end
    return addon.isInitialized
end

-- NEWLY IMPLEMENTED FUNCTION
function addon:DumpZOrder()
    self:Print("|cFFDAA520--- TalentCrafter Z-Order ---|r")

    -- Helper to print frame details
    local function printInfo(frame, label)
        if not frame then
            self:Print(string.format("%s: |cFFFF8080Not found.|r", label))
            return
        end

        local name = label or (frame.GetName and frame:GetName()) or "(anonymous)"
        local level = frame:GetFrameLevel() or -1
        local strata = frame:GetFrameStrata() or "UNKNOWN"
        local shown = "hidden"
        if frame:IsShown() then
            shown = "shown"
        end

        self:Print(string.format("%s: Level %d, Strata %s [%s]", name, level, strata, shown))
    end

    -- Print info for major frames
    printInfo(mainFrame, "Main Guide (TalentCrafterFrame)")
    printInfo(calculatorFrame, "Calculator (TC_TalentCalculator)")

    if calculatorFrame then
        if calculatorFrame._bgFrames and calculatorFrame._bgFrames[1] then
            printInfo(calculatorFrame._bgFrames[1], "  |-- BG Rotator Holder 1")
        end
        printInfo(calculatorFrame.calcOverlay, "  |-- Calc Overlay (text)")
        printInfo(getglobal("TC_MoveButton"), "  |-- Move Button")
        printInfo(addon._moveOverlay, "  |-- Move Overlay")

        for i = 1, 3 do
            printInfo(getglobal("TC_CalcTree" .. i), string.format("  |-- Tree %d", i))
            local tree = getglobal("TC_CalcTree" .. i)
            if tree then
                printInfo(tree.branchLayer, string.format("      |-- Tree %d Branch Layer", i))
                printInfo(tree.arrowLayer, string.format("      |-- Tree %d Arrow Layer", i))
            end
        end
    end
end

function SlashCmdList.TC(msg)
    if not addon.isInitialized then
        if not addon:TryInitializeNow() then
            addon:Print("Talent data not ready yet; try again in a moment.")
            return
        end
    end
    local cmd = string.lower(msg or "")
    if cmd == "calc" then
        addon:RefreshTalentIcons()
        if calculatorFrame:IsShown() then
            calculatorFrame:Hide()
        else
            calculatorFrame:Show()
            -- Re-initialize rotator on open if desired but missing
            EnsureSettings()
            if TC_Settings.bgRotate and (not calculatorFrame._bgFrames) then
                addon:InitBackgroundRotator(calculatorFrame)
            end
            addon:UpdateCalculatorOverlays()
            for tab = 1, 3 do
                addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
            end
        end
    elseif cmd == "export" then
        if not addon.isInitialized then
            return
        end
        if exportFrame and getglobal("TC_ExportBox") then
            importFrame:Hide()
            getglobal("TC_ExportBox"):SetText(addon:ExportToString())
            getglobal("TC_ExportBox"):HighlightText()
            exportFrame:Show()
        end
    elseif cmd == "import" then
        if not addon.isInitialized then
            return
        end
        if importFrame and getglobal("TC_ImportBox") then
            exportFrame:Hide()
            getglobal("TC_ImportBox"):SetText("")
            importFrame:Show()
        end
    elseif cmd == "reset" then
        manualOverride = false
        addon.pickOrder = {}
        addon:UpdateTalentDisplay()
        addon:UpdateGlow()
        addon:UpdateCalculatorOverlays()
        for tab = 1, 3 do
            addon:DrawPrereqGraph(getglobal("TC_CalcTree" .. tab))
        end
        addon:Print("Guide reset to default.")
    elseif cmd == "info" then
        addon:ToggleInfo()
    elseif cmd == "z" or string.find(cmd, "^layers") or string.find(cmd, "^zorder") then
        addon:DumpZOrder()
    elseif string.find(cmd, "^bg%s+debug%s+on") then
        EnsureSettings()
        TC_Settings.bgDebug = true
        addon:Print("BG debug: ON")
    elseif string.find(cmd, "^bg%s+debug%s+off") then
        EnsureSettings()
        TC_Settings.bgDebug = false
        addon:Print("BG debug: OFF")
    elseif string.find(cmd, "^bg%s+status") then
        local n = (calculatorFrame and calculatorFrame._bgFrames and table.getn(calculatorFrame._bgFrames)) or 0
        local idx = 0
        if calculatorFrame and calculatorFrame._bgFrames and n > 0 then
            local cycle = (BG_ROTATE_PERIOD + BG_FADE_DURATION)
            local now = GetTime()
            local elapsed = now - (calculatorFrame._bgBase or now)
            local k = math.floor(elapsed / cycle)
            local start = calculatorFrame._bgStart or 1
            idx = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
        end
        EnsureSettings()
        addon:Print("BG status: active=" .. idx .. "/" .. n .. ", saved=" .. (TC_Settings.bgIndex or 0))
    elseif string.find(cmd, "^bg%s+reset") then
        EnsureSettings()
        TC_Settings.bgIndex = 1
        addon:Print("BG index reset to 1")
    elseif string.find(cmd, "^bg%s+set%s+%d+") then
        local _, _, num = string.find(cmd, "^bg%s+set%s+(%d+)")
        if num then
            EnsureSettings()
            TC_Settings.bgIndex = tonumber(num)
            addon:Print("BG index set to " .. num .. "; reinit with /tc bg on")
        end
    elseif string.find(cmd, "^bg%s+on") then
        EnsureSettings()
        TC_Settings.bgRotate = true
        if calculatorFrame and not calculatorFrame._bgFrames then
            addon:InitBackgroundRotator(calculatorFrame)
        end
        if calculatorFrame and calculatorFrame._bgFrames then
            for _, h in ipairs(calculatorFrame._bgFrames) do
                h:Show()
            end
        end
        addon:RefreshTreeBackdrops()
        addon:RefreshCalcBackdrop()
        addon:Print("Background rotator: ON")
    elseif string.find(cmd, "^bg%s+off") then
        EnsureSettings()
        TC_Settings.bgRotate = false
        addon:DisableBackgroundRotator(calculatorFrame)
        addon:RefreshTreeBackdrops()
        addon:RefreshCalcBackdrop()
        addon:Print("Background rotator: OFF")
    else
        addon:Print(
            "Usage: /tc [calc | reset | info | export | import | bg on | bg off | bg debug on|off | bg status | bg reset]"
        )
    end
end
-- Rotating background for calculator
function addon:InitBackgroundRotator(frame)
    if frame._bgFrames then
        return
    end
    if not ROTATING_BACKGROUNDS or table.getn(ROTATING_BACKGROUNDS) == 0 then
        return
    end
    local frames = {}
    -- Match the dialog backdrop insets so the art does not cover the rounded edge
    local inset = 4

    local function trySetTexture(tex, path)
        if not path or path == "" then
            return false
        end
        tex:SetTexture(path)
        return tex:GetTexture() ~= nil
    end

    for i, art in ipairs(ROTATING_BACKGROUNDS) do
        local holder = CreateFrame("Frame", nil, frame)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        holder:EnableMouse(false)
        -- Ensure we render above calculator backdrop but beneath tree widgets
        holder:SetFrameStrata(frame:GetFrameStrata())
        -- Keep below tree frames (which are set to parent level + 2)
        holder:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)

        local tex = holder:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(holder)

        -- Try extensionless first (client may resolve), then prefer TGA, then BLP, then original path.
        local ok = false
        if type(art.texture) == "string" then
            local base = art.texture
            base = string.gsub(base, "%.tga$", "")
            base = string.gsub(base, "%.TGA$", "")
            base = string.gsub(base, "%.blp$", "")
            base = string.gsub(base, "%.BLP$", "")
            ok =
                trySetTexture(tex, base) or trySetTexture(tex, base .. ".tga") or trySetTexture(tex, base .. ".TGA") or
                trySetTexture(tex, base .. ".blp") or
                trySetTexture(tex, base .. ".BLP")
        end
        if not ok then
            ok = trySetTexture(tex, art.texture)
        end

        holder.tex = tex
        if not ok then
            -- Fallback to a tinted solid so there's always a visible background
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetVertexColor(0.08, 0.07, 0.10, 0.7)
        end
        tinsert(frames, holder)
    end

    if table.getn(frames) == 0 then
        return
    end
    frame._bgFrames = frames
    EnsureSettings()
    local n = table.getn(frame._bgFrames)
    -- Choose starting index from saved; clamp to [1..n]
    local startIndex = tonumber(TC_Settings and TC_Settings.bgIndex) or 1
    if startIndex < 1 then
        startIndex = 1
    end
    if startIndex > n then
        local a = (startIndex - 1)
        startIndex = (a - math.floor(a / n) * n) + 1
    end
    frame._bgStart = startIndex
    TC_Settings.bgIndex = startIndex
    local cycle = (BG_ROTATE_PERIOD + BG_FADE_DURATION)
    frame._bgBase = GetTime() - (startIndex - 1) * cycle
    addon:Debug("BG init (time-base): n=" .. n .. " start=" .. startIndex)

    local function StepBackgroundTime()
        if not frame or not frame._bgFrames then
            return
        end
        if not frame:IsShown() then
            return
        end
        if frame._bgPaused then
            return
        end
        local now = GetTime()
        local elapsed = now - (frame._bgBase or now)
        local k = math.floor(elapsed / cycle)
        local t = elapsed - k * cycle
        local start = frame._bgStart or 1
        local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
        local nextIndex = (active < n) and (active + 1) or 1
        if t < BG_ROTATE_PERIOD then
            frame._bgFrames[active]:SetAlpha(1)
            frame._bgFrames[nextIndex]:SetAlpha(0)
            addon:Debug("BG step: hold active=" .. active .. " next=" .. nextIndex .. " t=" .. string.format("%.2f", t))
        else
            local f = (t - BG_ROTATE_PERIOD) / BG_FADE_DURATION
            if f > 1 then
                f = 1
            end
            frame._bgFrames[active]:SetAlpha(1 - f)
            frame._bgFrames[nextIndex]:SetAlpha(f)
            addon:Debug("BG fade: active=" .. active .. " -> next=" .. nextIndex .. " f=" .. string.format("%.2f", f))
        end
        -- Zero all other frames to avoid ghost alphas
        for i = 1, n do
            if i ~= active and i ~= nextIndex then
                frame._bgFrames[i]:SetAlpha(0)
            end
        end
        -- Persist saved index during hold for stable resume
        if t < BG_ROTATE_PERIOD then
            if TC_Settings and TC_Settings.bgIndex ~= active then
                TC_Settings.bgIndex = active
                addon:Debug("BG save: active=" .. active)
            end
        end
    end

    -- Expose stepper so pause/resume can reuse it
    frame._bgStep = StepBackgroundTime

    -- Initialize alphas once using the same math
    frame._bgStep()

    -- Prefer AceTimer if embedded, otherwise use OnUpdate
    if addon.ScheduleRepeatingTimer and addon.CancelTimer then
        frame._bgStepper = "timer"
        frame._bgTimerHandle =
            addon:ScheduleRepeatingTimer(
            function()
                frame._bgStep()
            end,
            0.05
        )
    else
        frame._bgStepper = "onupdate"
        frame:SetScript(
            "OnUpdate",
            function()
                frame._bgStep()
            end
        )
    end
end

-- Tiny scheduler helper (AceTimer if present, or one-shot OnUpdate)
function addon:After(delay, fn)
    if self.ScheduleTimer then
        self:ScheduleTimer(
            function()
                pcall(fn)
            end,
            delay
        )
    else
        local f = CreateFrame("Frame")
        local t = 0
        f:SetScript(
            "OnUpdate",
            function()
                t = t + arg1
                if t >= delay then
                    f:SetScript("OnUpdate", nil)
                    pcall(fn)
                end
            end
        )
    end
end

function addon:DisableBackgroundRotator(frame)
    frame = frame or calculatorFrame
    if not frame or not frame._bgFrames then
        return
    end
    if addon.CancelTimer and frame._bgTimerHandle then
        addon:CancelTimer(frame._bgTimerHandle, true)
        frame._bgTimerHandle = nil
    end
    frame:SetScript("OnUpdate", nil)
    for _, h in ipairs(frame._bgFrames) do
        h:Hide()
    end
    frame._bgFrames = nil
end

-- Pause/resume rotator during drag to avoid old-client instability
function addon:PauseBackgroundRotator(frame)
    frame = frame or calculatorFrame
    if not frame or not frame._bgFrames then
        return
    end
    EnsureSettings()
    local n = table.getn(frame._bgFrames)
    if n == 0 then
        return
    end
    -- Fully disable rotator (safest on 1.12 during re-anchoring)
    frame._bgPaused = true
    frame._bgPausedWasEnabled = true
    addon:DisableBackgroundRotator(frame)
end

function addon:ResumeBackgroundRotator(frame)
    frame = frame or calculatorFrame
    if not frame then
        return
    end
    local want = (TC_Settings and TC_Settings.bgRotate) and frame._bgPausedWasEnabled
    frame._bgPaused = false
    frame._bgPausedWasEnabled = nil
    if not want then
        return
    end
    -- Recreate after a tiny delay to avoid post-drop engine instability
    addon:After(
        0.10,
        function()
            if not frame._bgFrames and (TC_Settings and TC_Settings.bgRotate) then
                addon:InitBackgroundRotator(frame)
            end
        end
    )
end

-- Freeze/unfreeze rotator without destroying frames (for Move Mode)
function addon:FreezeBackgroundRotator(frame)
    frame = frame or calculatorFrame
    if not frame or not frame._bgFrames then
        return
    end
    local n = table.getn(frame._bgFrames)
    if n == 0 then
        return
    end
    local cycle = (BG_ROTATE_PERIOD + BG_FADE_DURATION)
    local now = GetTime()
    local elapsed = now - (frame._bgBase or now)
    local k = math.floor(elapsed / cycle)
    local start = frame._bgStart or 1
    local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
    -- Show only the active slide
    for i = 1, n do
        frame._bgFrames[i]:SetAlpha(0)
    end
    frame._bgFrames[active]:SetAlpha(1)
    frame._bgPaused = true
    if TC_Settings then
        TC_Settings.bgIndex = active
    end
end

function addon:UnfreezeBackgroundRotator(frame)
    frame = frame or calculatorFrame
    if not frame or not frame._bgFrames then
        return
    end
    local n = table.getn(frame._bgFrames)
    if n == 0 then
        return
    end
    local cycle = (BG_ROTATE_PERIOD + BG_FADE_DURATION)
    local now = GetTime()
    local elapsed = now - (frame._bgBase or now)
    local k = math.floor(elapsed / cycle)
    local start = frame._bgStart or 1
    local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
    -- Re-base so we resume holding on the current active
    frame._bgStart = active
    frame._bgBase = GetTime() - (active - 1) * cycle
    frame._bgPaused = false
    if frame._bgStep then
        frame._bgStep()
    end
end
