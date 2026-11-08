local _, NS = ...
local DB, R, T = NS.DB, NS.Rules, NS.Tracker

-- The /rested window: one row per character, built once and repainted.

local UI = {}
NS.UI = UI

local WIDTH, PAD = 744, 14
local ROW_H, MAX_ROW_H = 40, 28
local COL = { name = 14, level = 206, where = 246, rested = 456, restedW = 160 }

local C = {
    border = { 0.54, 0.43, 0.17 },
    bg = { 0.055, 0.055, 0.063, 0.96 },
    header = { 0.09, 0.08, 0.06, 1 },
    line = { 0.14, 0.12, 0.09, 1 },
    text = "ffe6e0d0",
    dim = "ffa39c8e",
    gold = "ffffd100",
    blue = "ff7fa9ff",
    orange = "ffffa94d",
    red = "ffff8a7a",
    maxText = "ff8a8478",
}
local BAR = {
    full = { 0.88, 0.44, 0.37 },
    resting = { 0.30, 0.53, 1.00 },
    world = { 0.79, 0.51, 0.18 },
}

local function paint(s, color) return "|c" .. color .. s .. "|r" end

local frame, colHeader, footer, empty
local rows, maxRows = {}, {}
local ticker

-- ---------------------------------------------------------------- data -----

local function entries()
    local now = time()
    local list, maxed, rulesets = {}, {}, {}
    local nRulesets, pinned = 0, nil
    for g, c in pairs(DB.Chars()) do
        if not c.ignored and c.ts then
            local e = { guid = g, c = c, current = T.IsCurrent(g) }
            e.p = R.Project(c, now, e.current)
            if e.current and not e.p.maxLevel then
                -- The character you're playing sits above the sort, not in it.
                e.pinned = true
                pinned = e
            elseif e.p.maxLevel then
                maxed[#maxed + 1] = e
            else
                list[#list + 1] = e
            end
            local rs = c.ruleset or "?"
            if not rulesets[rs] then rulesets[rs] = true; nRulesets = nRulesets + 1 end
        end
    end
    local sortBy = DB.Get("sortBy")
    local function byName(a, b) return (a.c.name or "") < (b.c.name or "") end
    if sortBy == "name" then
        table.sort(list, byName)
    elseif sortBy == "level" then
        table.sort(list, function(a, b)
            if a.c.level ~= b.c.level then return (a.c.level or 0) > (b.c.level or 0) end
            return byName(a, b)
        end)
    else
        -- Full soonest: already full first (longest-wasting at the top), then by
        -- fill time; characters that never fill (online, not resting) last.
        table.sort(list, function(a, b)
            local fa, fb = a.p.fullAt or math.huge, b.p.fullAt or math.huge
            if fa ~= fb then return fa < fb end
            return byName(a, b)
        end)
    end
    table.sort(maxed, byName)
    if pinned then table.insert(list, 1, pinned) end
    return list, maxed, nRulesets > 1, now
end

function UI.RestedText(p)
    local fmt = DB.Get("restedFormat")
    local pct = math.floor(p.bubbles * R.BUBBLE * 100 + 0.5)
    local b = string.format("%d / %d", math.floor(p.bubbles), math.floor(p.capBubbles + 0.5))
    if fmt == "percent" then return pct .. "% of a level" end
    if fmt == "both" then return b .. " · " .. pct .. "%" end
    return b .. " bubbles"
end

local function uncertain(c)
    return c.rank == nil or not c.resting
end

-- ------------------------------------------------------------- tooltip -----

local function className(token)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token or "?"
end

local function showTooltip(row)
    local e = row.entry
    if not e then return end
    local c, p, now = e.c, e.p, time()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(NS.ColoredName(c))
    GameTooltip:AddLine(string.format("Level %d %s · %s", c.level or 0, className(c.class),
        c.ruleset or "?"), 0.64, 0.61, 0.56)
    if p.maxLevel then
        GameTooltip:AddLine("Max level — no rested XP", 0.64, 0.61, 0.56)
        GameTooltip:Show()
        return
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Rested now", R.CommaNumber(p.rested) .. " / " .. R.CommaNumber(p.cap) .. " XP", 0.64, 0.61, 0.56, 1, 1, 1)
    GameTooltip:AddDoubleLine("Bubbles", string.format("%d / %d · %d%% of a level",
        math.floor(p.bubbles), math.floor(p.capBubbles + 0.5), math.floor(p.bubbles * 5 + 0.5)), 0.64, 0.61, 0.56, 1, 1, 1)
    local fullLine
    if p.isFull then
        fullLine = "full for " .. R.Duration(now - p.fullAt)
    elseif p.fullAt then
        fullLine = R.Duration(p.fullAt - now) .. " (" .. date("%a %H:%M", p.fullAt) .. ")"
    else
        fullLine = "paused — not resting"
    end
    GameTooltip:AddDoubleLine("Full in", fullLine, 0.64, 0.61, 0.56, 1, 1, 1)
    GameTooltip:AddLine(" ")
    local where = c.zone or "?"
    if c.subzone then where = c.subzone .. ", " .. where end
    if e.current then
        GameTooltip:AddDoubleLine("Now", where, 0.64, 0.61, 0.56, 1, 1, 1)
    else
        GameTooltip:AddDoubleLine("Logged out", where .. " · " .. date("%a %H:%M", c.ts), 0.64, 0.61, 0.56, 1, 1, 1)
    end
    local per8 = (p.rate or 0) * 8 * 3600 / (c.xpMax or 1) * 100
    if c.resting then
        GameTooltip:AddDoubleLine("Resting", string.format("inn / city — %.1f%% per 8h", per8), 0.64, 0.61, 0.56, 0.5, 0.66, 1)
    elseif e.current then
        GameTooltip:AddDoubleLine("Resting", "no — not gaining while online", 0.64, 0.61, 0.56, 1, 0.66, 0.3)
    else
        GameTooltip:AddDoubleLine("Resting", string.format("world — %.1f%% per 8h (unconfirmed)", per8), 0.64, 0.61, 0.56, 1, 0.66, 0.3)
    end
    local rankText
    if c.rankManual ~= nil then rankText = "rank " .. c.rankManual .. " (set by hand)"
    elseif c.rank ~= nil then rankText = "rank " .. c.rank .. " (detected)"
    else rankText = "not detected — assumed 0" end
    GameTooltip:AddDoubleLine("Well Rested", rankText,
        0.64, 0.61, 0.56, 1, 1, 1)
    local m = NS.DEV and c.lastMeasure
    if m then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Measured on last login", 0.64, 0.61, 0.56)
        if m.hitCap then
            GameTooltip:AddLine(string.format("at cap: %d%% of a level", math.floor(m.afterPctLevel + 0.5)), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format("%.3f%% of a level / hour (formula %.3f%%)", m.measured, m.formula), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click: Well Rested rank · don't track · forget", 0.2, 1, 0.6)
    GameTooltip:Show()
end

-- ---------------------------------------------------------------- menu -----

local function openMenu(row)
    local e = row.entry
    if not (e and MenuUtil and MenuUtil.CreateContextMenu) then return end
    local c = e.c
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(NS.FullName(c))
        local rank = root:CreateButton("Well Rested rank")
        local function isRank(v) return c.rankManual == v end
        local function setRank(v)
            c.rankManual = v
            T.ApplyRank(c)
            UI.Refresh()
        end
        rank:CreateRadio("Auto-detect", function() return c.rankManual == nil end, function() setRank(nil) end)
        for r = 0, R.MAX_RANK do
            rank:CreateRadio(tostring(r), isRank, setRank, r)
        end
        root:CreateButton("Don't track", function()
            c.ignored = true
            UI.Refresh()
        end)
        root:CreateButton("Forget character", function()
            DB.Forget(e.guid)
            UI.Refresh()
        end)
    end)
end

-- --------------------------------------------------------------- build -----

local function text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function solid(parent, layer, rgba)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
    return t
end

local function makeRow(i)
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 4, ROW_H)
    row:RegisterForClicks("RightButtonUp")
    local line = solid(row, "BORDER", C.line)
    line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.06)
    -- Shown only on the pinned current-character row.
    row.pinBg = solid(row, "BACKGROUND", { 1, 0.82, 0, 0.07 })
    row.pinBg:SetAllPoints()
    row.divider = solid(row, "BORDER", { C.border[1], C.border[2], C.border[3], 1 })
    row.divider:SetPoint("BOTTOMLEFT"); row.divider:SetPoint("BOTTOMRIGHT"); row.divider:SetHeight(2)

    row.name = text(row, "GameFontNormal")
    row.name:SetWidth(COL.level - COL.name - 8)
    row.nameSub = text(row, "GameFontDisableSmall")
    row.nameSub:SetPoint("BOTTOMLEFT", COL.name, 7)
    row.nameSub:SetWidth(COL.level - COL.name - 8)
    row.level = text(row, "GameFontHighlight")
    row.level:SetPoint("LEFT", COL.level, 0)
    row.zone = text(row, "GameFontHighlightSmall")
    row.zone:SetPoint("TOPLEFT", COL.where, -7)
    row.zone:SetWidth(COL.rested - COL.where - 10)
    row.rest = text(row, "GameFontHighlightSmall")
    row.rest:SetPoint("BOTTOMLEFT", COL.where, 7)
    row.restedText = text(row, "GameFontHighlightSmall")
    row.restedText:SetPoint("TOPLEFT", COL.rested, -7)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetSize(COL.restedW, 6)
    row.bar:SetPoint("BOTTOMLEFT", COL.rested, 9)
    local barBg = solid(row.bar, "BACKGROUND", { 0.15, 0.13, 0.11, 1 })
    barBg:SetAllPoints()
    row.full = text(row, "GameFontNormal", "RIGHT")
    row.full:SetPoint("TOPRIGHT", -PAD, -6)
    row.fullSub = text(row, "GameFontDisableSmall", "RIGHT")
    row.fullSub:SetPoint("BOTTOMRIGHT", -PAD, 7)

    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then openMenu(self) end
    end)
    rows[i] = row
    return row
end

local function makeMaxRow(i)
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 4, MAX_ROW_H)
    row:RegisterForClicks("RightButtonUp")
    local bg = solid(row, "BACKGROUND", { 0.07, 0.066, 0.063, 1 })
    bg:SetAllPoints()
    local line = solid(row, "BORDER", C.line)
    line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
    row.name = text(row, "GameFontDisable")
    row.name:SetPoint("LEFT", COL.name, 0)
    row.level = text(row, "GameFontDisable")
    row.level:SetPoint("LEFT", COL.level, 0)
    row.note = text(row, "GameFontDisableSmall")
    row.note:SetPoint("LEFT", COL.rested, 0)
    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then openMenu(self) end
    end)
    maxRows[i] = row
    return row
end

local function savePosition()
    local point, _, rel, x, y = frame:GetPoint(1)
    DB.Settings().window = { point = point, rel = rel, x = x, y = y }
end

local function build()
    frame = CreateFrame("Frame", "RestedAltsFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(unpack(C.bg))
    frame:SetBackdropBorderColor(unpack(C.border))
    local pos = DB.Settings().window
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
    else
        frame:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "RestedAltsFrame") -- Escape closes it

    local head = solid(frame, "BORDER", C.header)
    head:SetPoint("TOPLEFT", 2, -2); head:SetPoint("TOPRIGHT", -2, -2); head:SetHeight(38)
    local title = text(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -13)
    title:SetText("RestedAlts")
    frame.subtitle = text(frame, "GameFontDisableSmall")
    frame.subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local gear = CreateFrame("Button", nil, frame)
    gear:SetSize(20, 20)
    gear:SetPoint("RIGHT", close, "LEFT", -4, 0)
    gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function() if NS.Options then NS.Options.Open() end end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Settings")
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    colHeader = CreateFrame("Frame", nil, frame)
    colHeader:SetSize(WIDTH - 4, 24)
    colHeader:SetPoint("TOPLEFT", 2, -40)
    local function col(label, x, justify)
        local fs = text(colHeader, "GameFontDisableSmall", justify)
        fs:SetText(label:upper())
        if justify == "RIGHT" then fs:SetPoint("RIGHT", -PAD, 0) else fs:SetPoint("LEFT", x, 0) end
    end
    col("Character", COL.name)
    col("Lvl", COL.level)
    col("Logged out at", COL.where)
    col("Rested", COL.rested)
    col("Full in", 0, "RIGHT")

    empty = text(frame, "GameFontDisable", "CENTER")
    empty:SetText("No characters yet. Log in to each alt once and it will appear here.")

    footer = CreateFrame("Frame", nil, frame)
    footer:SetSize(WIDTH - 4, 26)
    local fl = solid(footer, "BORDER", C.line)
    fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
    local left = text(footer, "GameFontDisableSmall")
    left:SetPoint("LEFT", PAD, 0)
    left:SetText("? = estimate: Well Rested rank not detected, or out-of-inn rate unconfirmed")
    local right = text(footer, "GameFontDisableSmall", "RIGHT")
    right:SetPoint("RIGHT", -PAD, 0)
    right:SetText("Right-click a row for options")

    frame:SetScript("OnShow", function()
        UI.Refresh()
        if not ticker then ticker = C_Timer.NewTicker(30, UI.Refresh) end
    end)
    frame:SetScript("OnHide", function()
        if ticker then ticker:Cancel(); ticker = nil end
    end)
    frame:Hide()
end

-- --------------------------------------------------------------- paint -----

local function paintRow(row, e, showRuleset, now)
    local c, p = e.c, e.p
    row.entry = e
    -- Full name on top; ruleset and "playing now" go on the line under it.
    row.name:SetText(NS.ColoredName(c))
    local sub = {}
    if showRuleset and c.ruleset then sub[#sub + 1] = c.ruleset end
    if e.current then sub[#sub + 1] = "playing now" end
    row.name:ClearAllPoints()
    if #sub > 0 then
        row.name:SetPoint("TOPLEFT", COL.name, -7)
        row.nameSub:SetText(table.concat(sub, " · "))
    else
        row.name:SetPoint("LEFT", COL.name, 0)
        row.nameSub:SetText("")
    end
    row.level:SetText(c.level or "?")
    row.zone:SetText(c.zone or "?")
    if c.resting then
        row.rest:SetText(paint("inn / city", C.blue))
    elseif e.current then
        row.rest:SetText(paint("not resting", C.orange))
    else
        row.rest:SetText(paint("world — slow", C.orange))
    end
    row.restedText:SetText(UI.RestedText(p))
    row.bar:SetValue(p.cap > 0 and p.rested / p.cap or 0)
    local bar = p.isFull and BAR.full or (c.resting and BAR.resting or BAR.world)
    row.bar:SetStatusBarColor(bar[1], bar[2], bar[3])

    row.pinBg:SetShown(e.pinned == true)
    row.divider:SetShown(e.pinned == true)

    local q = uncertain(c) and " ?" or ""
    if p.noData then
        row.restedText:SetText(paint("no XP data yet", C.dim))
        row.full:SetText(paint("—", C.dim))
        row.fullSub:SetText("log in once to fix")
    elseif e.pinned and not p.isFull and not c.resting then
        row.full:SetText(paint("online", C.text))
        row.fullSub:SetText("not gaining")
    elseif e.pinned and not p.isFull and p.fullAt then
        row.full:SetText(paint(R.Duration(p.fullAt - now) .. (c.rank == nil and " ?" or ""), C.text))
        row.fullSub:SetText("resting now")
    elseif p.isFull then
        row.full:SetText(paint("FULL", C.red))
        row.fullSub:SetText("wasting " .. R.Duration(now - p.fullAt))
    elseif not p.fullAt then
        row.full:SetText(paint("paused", C.dim))
        row.fullSub:SetText("rest in an inn or city")
    else
        local left = p.fullAt - now
        local soon = left <= (DB.Get("soonHours") or 24) * 3600
        local color = soon and C.gold or (c.resting and C.text or C.orange)
        row.full:SetText(paint(R.Duration(left) .. q, color))
        if soon then
            row.fullSub:SetText("filling soon")
        elseif not c.resting then
            row.fullSub:SetText("4× slower")
        elseif c.rank then
            row.fullSub:SetText("Well Rested " .. c.rank)
        else
            row.fullSub:SetText(e.current and "online" or "")
        end
    end
    row:Show()
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local list, maxed, showRuleset, now = entries()
    if DB.Get("maxLevel") == "hidden" then maxed = {} end

    local y = -64
    for i, e in ipairs(list) do
        local row = rows[i] or makeRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, y)
        paintRow(row, e, showRuleset, now)
        y = y - ROW_H
    end
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end

    for i, e in ipairs(maxed) do
        local row = maxRows[i] or makeMaxRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, y)
        row.entry = e
        row.name:SetText(NS.FullName(e.c) .. ((showRuleset and e.c.ruleset) and (" · " .. e.c.ruleset) or ""))
        row.level:SetText(e.c.level or "?")
        row.note:SetText("max level")
        row:Show()
        y = y - MAX_ROW_H
    end
    for i = #maxed + 1, #maxRows do maxRows[i]:Hide(); maxRows[i].entry = nil end

    local count = #list + #maxed
    if count == 0 then
        empty:ClearAllPoints()
        empty:SetPoint("TOP", frame, "TOP", 0, y - 16)
        empty:Show()
        y = y - 48
    else
        empty:Hide()
    end
    footer:ClearAllPoints()
    footer:SetPoint("TOPLEFT", 2, y)
    frame:SetHeight(-y + 28)

    local sortLabel = ({ soonest = "full soonest", name = "name", level = "level" })[DB.Get("sortBy")] or "full soonest"
    frame.subtitle:SetText(string.format("%d character%s · sorted by %s", count, count == 1 and "" or "s", sortLabel))
end

function UI.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end

function UI.Show()
    if not frame then build() end
    frame:Show()
end
