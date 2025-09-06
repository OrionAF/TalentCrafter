-- Background rotator and helpers (Vanilla 1.12 / Turtle WoW)
-- Loads early; relies on the shared global addon table created by TalentCrafter_Boot.lua

local addon = _G.TalentCrafter or {}
_G.TalentCrafter = addon

-- Provide defaults if the main file hasn't populated them yet
addon.BG_ROTATE_PERIOD = addon.BG_ROTATE_PERIOD or 12
addon.BG_FADE_DURATION = addon.BG_FADE_DURATION or 2

-- Scheduler helper (AceTimer if present, otherwise one-shot OnUpdate)
if not addon.After then
function addon:After(delay, fn)
    if self.ScheduleTimer then
        self:ScheduleTimer(function() pcall(fn) end, delay)
    else
        local f = CreateFrame("Frame")
        local t = 0
        f:SetScript("OnUpdate", function() t = t + arg1; if t >= delay then f:SetScript("OnUpdate", nil); pcall(fn) end end)
    end
end
end

-- Init rotator (safe to call repeatedly)
if not addon.InitBackgroundRotator then
function addon:InitBackgroundRotator(frame)
    if not frame or frame._bgFrames then return end
    local list = addon.ROTATING_BACKGROUNDS
    if not list or table.getn(list) == 0 then return end
    local frames = {}
    local inset = 4

    local function trySetTexture(tex, path)
        if not path or path == "" then return false end
        tex:SetTexture(path)
        return tex:GetTexture() ~= nil
    end

    for i, art in ipairs(list) do
        local holder = CreateFrame("Frame", nil, frame)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        holder:EnableMouse(false)
        holder:SetFrameStrata(frame:GetFrameStrata())
        holder:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)

        local tex = holder:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(holder)
        local ok = false
        if type(art.texture) == "string" then
            local base = art.texture
            base = string.gsub(base, "%.tga$", "")
            base = string.gsub(base, "%.TGA$", "")
            base = string.gsub(base, "%.blp$", "")
            base = string.gsub(base, "%.BLP$", "")
            ok = trySetTexture(tex, base) or trySetTexture(tex, base .. ".tga") or trySetTexture(tex, base .. ".TGA")
                or trySetTexture(tex, base .. ".blp") or trySetTexture(tex, base .. ".BLP")
        end
        if not ok then ok = trySetTexture(tex, art.texture) end
        holder.tex = tex
        if not ok then
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetVertexColor(0.08, 0.07, 0.10, 0.7)
        end
        tinsert(frames, holder)
    end

    if table.getn(frames) == 0 then return end
    frame._bgFrames = frames
    EnsureSettings()
    local n = table.getn(frames)
    local startIndex = tonumber(TC_Settings and TC_Settings.bgIndex) or 1
    if startIndex < 1 then startIndex = 1 end
    if startIndex > n then
        local a = (startIndex - 1)
        startIndex = (a - math.floor(a / n) * n) + 1
    end
    frame._bgStart = startIndex
    TC_Settings.bgIndex = startIndex
    local cycle = (addon.BG_ROTATE_PERIOD + addon.BG_FADE_DURATION)
    frame._bgBase = GetTime() - (startIndex - 1) * cycle

    local function StepBackgroundTime()
        if not frame or not frame._bgFrames then return end
        if not frame:IsShown() then return end
        if frame._bgPaused then return end
        local now = GetTime()
        local elapsed = now - (frame._bgBase or now)
        local k = math.floor(elapsed / cycle)
        local t = elapsed - k * cycle
        local start = frame._bgStart or 1
        local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
        local nextIndex = (active < n) and (active + 1) or 1
        if t < addon.BG_ROTATE_PERIOD then
            frame._bgFrames[active]:SetAlpha(1)
            frame._bgFrames[nextIndex]:SetAlpha(0)
        else
            local f = (t - addon.BG_ROTATE_PERIOD) / addon.BG_FADE_DURATION
            if f > 1 then f = 1 end
            frame._bgFrames[active]:SetAlpha(1 - f)
            frame._bgFrames[nextIndex]:SetAlpha(f)
        end
        for i = 1, n do if i ~= active and i ~= nextIndex then frame._bgFrames[i]:SetAlpha(0) end end
        if t < addon.BG_ROTATE_PERIOD then
            if TC_Settings and TC_Settings.bgIndex ~= active then
                TC_Settings.bgIndex = active
            end
        end
    end

    frame._bgStep = StepBackgroundTime
    frame._bgStep()
    if addon.ScheduleRepeatingTimer and addon.CancelTimer then
        frame._bgStepper = "timer"
        frame._bgTimerHandle = addon:ScheduleRepeatingTimer(function() frame._bgStep() end, 0.05)
    else
        frame._bgStepper = "onupdate"
        frame:SetScript("OnUpdate", function() frame._bgStep() end)
    end
end
end

if not addon.DisableBackgroundRotator then
function addon:DisableBackgroundRotator(frame)
    frame = frame or _G.TC_TalentCalculator
    if not frame or not frame._bgFrames then return end
    if addon.CancelTimer and frame._bgTimerHandle then
        addon:CancelTimer(frame._bgTimerHandle, true); frame._bgTimerHandle = nil
    end
    frame:SetScript("OnUpdate", nil)
    for _, h in ipairs(frame._bgFrames) do h:Hide() end
    frame._bgFrames = nil
end
end

if not addon.PauseBackgroundRotator then
function addon:PauseBackgroundRotator(frame)
    frame = frame or _G.TC_TalentCalculator
    if not frame or not frame._bgFrames then return end
    EnsureSettings()
    local n = table.getn(frame._bgFrames)
    if n == 0 then return end
    frame._bgPaused = true
    frame._bgPausedWasEnabled = true
    addon:DisableBackgroundRotator(frame)
end
end

if not addon.ResumeBackgroundRotator then
function addon:ResumeBackgroundRotator(frame)
    frame = frame or _G.TC_TalentCalculator
    if not frame then return end
    local want = (TC_Settings and TC_Settings.bgRotate) and frame._bgPausedWasEnabled
    frame._bgPaused = false
    frame._bgPausedWasEnabled = nil
    if not want then return end
    addon:After(0.10, function()
        if not frame._bgFrames and (TC_Settings and TC_Settings.bgRotate) then
            addon:InitBackgroundRotator(frame)
        end
    end)
end
end

if not addon.FreezeBackgroundRotator then
function addon:FreezeBackgroundRotator(frame)
    frame = frame or _G.TC_TalentCalculator
    if not frame or not frame._bgFrames then return end
    local n = table.getn(frame._bgFrames)
    if n == 0 then return end
    local cycle = (addon.BG_ROTATE_PERIOD + addon.BG_FADE_DURATION)
    local now = GetTime()
    local elapsed = now - (frame._bgBase or now)
    local k = math.floor(elapsed / cycle)
    local start = frame._bgStart or 1
    local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
    for i = 1, n do frame._bgFrames[i]:SetAlpha(0) end
    frame._bgFrames[active]:SetAlpha(1)
    frame._bgPaused = true
    if TC_Settings then TC_Settings.bgIndex = active end
end
end

if not addon.UnfreezeBackgroundRotator then
function addon:UnfreezeBackgroundRotator(frame)
    frame = frame or _G.TC_TalentCalculator
    if not frame or not frame._bgFrames then return end
    local n = table.getn(frame._bgFrames)
    if n == 0 then return end
    local cycle = (addon.BG_ROTATE_PERIOD + addon.BG_FADE_DURATION)
    local now = GetTime()
    local elapsed = now - (frame._bgBase or now)
    local k = math.floor(elapsed / cycle)
    local start = frame._bgStart or 1
    local active = 1 + (((start - 1) + k) - math.floor(((start - 1) + k) / n) * n)
    frame._bgStart = active
    frame._bgBase = GetTime() - (active - 1) * cycle
    frame._bgPaused = false
    if frame._bgStep then frame._bgStep() end
end
end

