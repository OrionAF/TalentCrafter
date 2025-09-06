-- Shared utilities (Vanilla 1.12 / Turtle WoW)
-- Loads early and exposes helpers both globally (for legacy calls) and on the addon table.

local addon = _G.TalentCrafter or {}
_G.TalentCrafter = addon

-- Settings defaults
if not _G.EnsureSettings then
function EnsureSettings()
    if not TC_Settings then
        TC_Settings = {bgRotate = false, bgPreserve = false, bgAspect = 2.0, minimap = {}, bgDebug = false}
    else
        if TC_Settings.bgRotate == nil then TC_Settings.bgRotate = false end
        if TC_Settings.bgPreserve == nil then TC_Settings.bgPreserve = false end
        if not TC_Settings.bgAspect then TC_Settings.bgAspect = 2.0 end
        if type(TC_Settings.minimap) ~= "table" then TC_Settings.minimap = {} end
        if TC_Settings.bgDebug == nil then TC_Settings.bgDebug = false end
    end
end
addon.EnsureSettings = EnsureSettings
end

-- String split helper (Lua 5.0 pattern-safe for 1-char separators)
if not _G.SplitString then
function SplitString(s, sep)
    sep = sep or "%s"
    local t = {}
    if not s or s == "" then return t end
    if sep ~= "%s" and string.len(sep) == 1 then
        local ch = sep
        if ch == "-" or ch == "]" or ch == "^" or ch == "%" then sep = "%" .. ch end
    end
    for str in string.gfind(s, "([^" .. sep .. "]+)") do tinsert(t, str) end
    return t
end
addon.SplitString = SplitString
end

-- Desaturate texture with fallback for early clients
if not _G.SetTexDesaturated then
function SetTexDesaturated(tex, desaturate)
    if not tex then return end
    if tex.SetDesaturated then
        tex:SetDesaturated(desaturate)
    else
        local v = desaturate and 0.4 or 1
        tex:SetVertexColor(v, v, v)
    end
end
addon.SetTexDesaturated = SetTexDesaturated
end

-- Lookup talent by (tab, tier, column), uses cache when available
if not _G.FindTalentByPosition then
function FindTalentByPosition(tabIndex, tier, column)
    if addon.posIndex and addon.posIndex[tabIndex] and addon.posIndex[tabIndex][tier] and addon.posIndex[tabIndex][tier][column] then
        return addon.posIndex[tabIndex][tier][column]
    end
    for i = 1, GetNumTalents(tabIndex) do
        local _, _, t, c = GetTalentInfo(tabIndex, i)
        if t == tier and c == column then return i end
    end
end
addon.FindTalentByPosition = FindTalentByPosition
end

