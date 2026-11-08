local _, NS = ...
local DB, R = NS.DB, NS.Rules

-- Snapshots of the logged-in character, the login measurement against the
-- previous snapshot, the login summary and the logout warning.

local T = {}
NS.Tracker = T

T.WELL_RESTED = 1225478

local guid
local ready = false -- no snapshot until the login measurement has read the old one

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function show(v)
    if v == nil then return "nil" end
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. show(x) end
        table.sort(parts)
        return "{" .. table.concat(parts, "; ") .. "}"
    end
    return tostring(v)
end

local function live()
    local level = UnitLevel("player") or 0
    local cap = call(GetMaxPlayerLevel)
    return {
        level = level,
        maxLevel = cap ~= nil and level >= cap,
        xp = UnitXP("player") or 0,
        xpMax = UnitXPMax("player") or 0,
        rested = GetXPExhaustion() or 0, -- nil when there is none
        resting = IsResting() and true or false,
    }
end

function T.GUID() return guid end
function T.Current() return DB.Char(guid) end
function T.IsCurrent(g) return g == guid end

-- Class-coloured first name.
function NS.ColoredName(c)
    local color = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    local name = c.name or "?"
    if color and color.colorStr then return "|c" .. color.colorStr .. name .. "|r" end
    return name
end

-- Well Rested's spell description carries the current rank's bonus ("accumulates
-- 20% faster" at rank 5) and is nil at rank 0 while the spell name still loads.
-- Returns the rank, or nil when the spell data isn't loaded yet.
function T.DetectRank()
    if not C_Spell then return nil end
    local info = call(C_Spell.GetSpellInfo, T.WELL_RESTED)
    if not (info and info.name) then return nil end
    local desc = call(C_Spell.GetSpellDescription, T.WELL_RESTED)
    if not desc or desc == "" then return 0 end
    local pct = tonumber(desc:match("(%d+)%%"))
    if not pct then return nil end
    local rank = math.floor(pct / (R.RANK_BONUS * 100) + 0.5)
    if rank < 0 or rank > R.MAX_RANK then return nil end
    return rank
end

-- A rank set by hand wins over the detected one.
function T.ApplyRank(c)
    if c.rankManual ~= nil then c.rank = c.rankManual else c.rank = c.rankDetected end
end

function T.Snapshot(reason)
    if not ready then return end
    local c = DB.EnsureChar(guid)
    if reason == "logout" then
        -- At a real logout UnitXPMax (and possibly the rest) already read 0, so
        -- trust the event-driven snapshots for the values and only stamp the time.
        c.ts = time()
        if DB.Get("recordMeasurements") then
            local l = live()
            DB.Log("logout %s: L%d rested %s/%s (%.1f%% of a level) %s in %s, rank %s [at logout the API said rested %s/%s, resting %s]",
                c.name or "?", c.level or 0, R.CommaNumber(c.rested), R.CommaNumber(c.xpMax),
                (c.xpMax or 0) > 0 and c.rested / c.xpMax * 100 or 0,
                c.resting and "RESTING" or "world", c.zone or "?", tostring(c.rank),
                R.CommaNumber(l.rested), R.CommaNumber(l.xpMax), tostring(l.resting))
        end
        return
    end
    local name, family = UnitName("player")
    c.name, c.family = name, family -- Forever: 2nd value is the family name, not a realm
    c.class = select(2, UnitClass("player"))
    c.faction = UnitFactionGroup("player")
    c.realm = GetRealmName()
    c.region = call(GetCurrentRegionName)
    if C_GameRules then
        c.modeID = call(C_GameRules.GetCurrentGameModeRecordID)
        c.expPreset = call(C_GameRules.GetForeverExperiencePreset)
    end
    c.ruleset = R.RulesetLabel(c.modeID, c.realm)

    local l = live()
    c.level, c.maxLevel = l.level, l.maxLevel
    if l.xpMax > 0 or l.maxLevel then
        c.xp, c.xpMax, c.rested = l.xp, l.xpMax, l.rested
    end
    c.resting = l.resting
    -- Zone text is empty at login; keep the last real one rather than blanking it.
    local zone = GetZoneText()
    if zone and zone ~= "" then
        c.zone = zone
        local sub = GetSubZoneText()
        c.subzone = (sub and sub ~= "") and sub or nil
    end
    local detected = T.DetectRank()
    if detected ~= nil then c.rankDetected = detected end
    T.ApplyRank(c)
    c.ts = time()
    if NS.UI then NS.UI.Refresh() end
end

-- Rested XP and zone events arrive in bursts; one snapshot per frame is plenty.
local pending = false
function T.SnapshotSoon()
    if pending or not ready then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        T.Snapshot("update")
    end)
end

local function logObservation(c, o)
    if o.sameLevel then
        c.lastMeasure = {
            ts = time(), hours = o.hours, hitCap = o.hitCap, afterPctLevel = o.afterPctLevel,
            measured = o.measuredPctHour, formula = o.formulaPctHour,
        }
    end
    local fmtPct = function(v) return v and string.format("%.3f%%/h", v) or "?" end
    DB.Log("measure %s (%s): offline %.2fh %s, L%d, rank %s, rested %s -> %s (predicted %s, diff %s, now %.1f%% of a level); measured %s vs formula %s%s%s",
        c.name or "?", c.ruleset or "?", o.hours, o.resting and "RESTING" or "world",
        o.level or 0, tostring(o.rank),
        R.CommaNumber(o.before), R.CommaNumber(o.after), R.CommaNumber(o.predicted),
        R.CommaNumber(o.delta), o.afterPctLevel or 0,
        fmtPct(o.measuredPctHour), fmtPct(o.formulaPctHour),
        o.hitCap and " [at cap: measures the cap, not the rate]" or "",
        o.sameLevel and "" or " [level/XP changed: ignore]")
end

-- Everything the API will say about the Well Rested talent on this character.
-- Nobody knows yet whether its rank is readable; this is how we find out.
function T.ProbeWellRested(why)
    local id = T.WELL_RESTED
    local info = C_Spell and call(C_Spell.GetSpellInfo, id)
    local aura = C_UnitAuras and call(C_UnitAuras.GetPlayerAuraBySpellID, id)
    DB.Log("wellrested %s %s: IsPlayerSpell=%s IsSpellKnown=%s IsSpellKnownOrOverridesKnown=%s name=%s subtext=%s",
        why or "probe", UnitName("player") or "?",
        show(call(IsPlayerSpell, id)), show(call(IsSpellKnown, id)),
        show(call(IsSpellKnownOrOverridesKnown, id)),
        show(info and info.name), show(C_Spell and call(C_Spell.GetSpellSubtext, id)))
    DB.Log("  description=%s", show(C_Spell and call(C_Spell.GetSpellDescription, id)))
    DB.Log("  aura=%s detectedRank=%s", show(aura), show(T.DetectRank()))
end

-- Identity values, for the record. The design was built on these (DESIGN.md).
function T.ProbeIdentity()
    DB.Log("identity %s: guid=%s realm=%s realmID=%s region=%s mode=%s preset=%s",
        UnitName("player") or "?", show(UnitGUID("player")), show(GetRealmName()),
        show(call(GetRealmID)), show(call(GetCurrentRegionName)),
        show(C_GameRules and call(C_GameRules.GetCurrentGameModeRecordID)),
        show(C_GameRules and call(C_GameRules.GetForeverExperiencePreset)))
end

function T.Login()
    guid = UnitGUID("player")
    local prev = DB.Char(guid)
    if prev and DB.Get("recordMeasurements") then
        local o = R.Observe(prev, live(), time())
        if o then logObservation(prev, o) end
    end
    if DB.Get("recordMeasurements") then T.ProbeWellRested("login") end
    ready = true
    T.Snapshot("login")
end

function T.LoginSummary()
    if not DB.Get("loginSummary") then return end
    local now = time()
    local soonSecs = (DB.Get("soonHours") or 24) * 3600
    local full, soon = {}, {}
    for g, c in pairs(DB.Chars()) do
        if g ~= guid and not c.ignored and c.ts then
            local p = R.Project(c, now)
            if not p.maxLevel and p.fullAt then
                if p.isFull then
                    full[#full + 1] = { c = c, t = now - p.fullAt }
                elseif DB.Get("loginSoon") and p.fullAt - now <= soonSecs then
                    soon[#soon + 1] = { c = c, t = p.fullAt - now }
                end
            end
        end
    end
    if #full == 0 and #soon == 0 then return end
    table.sort(full, function(a, b) return a.t > b.t end)
    table.sort(soon, function(a, b) return a.t < b.t end)
    local parts = {}
    local function list(items, fmt)
        local out = {}
        for _, it in ipairs(items) do
            out[#out + 1] = string.format(fmt, NS.ColoredName(it.c), R.Duration(it.t))
        end
        return table.concat(out, ", ")
    end
    if #full > 0 then parts[#parts + 1] = "Full: " .. list(full, "%s (wasting %s)") end
    if #soon > 0 then parts[#parts + 1] = "Filling soon: " .. list(soon, "%s (%s)") end
    NS.Say(table.concat(parts, " · ") .. " — /rested for all")
end

function T.LogoutWarning()
    if not DB.Get("logoutWarn") or IsResting() then return end
    local c = T.Current()
    if c and (c.maxLevel or c.ignored) then return end
    NS.Say("|cffffa94dNot in a rested area|r — " .. (c and NS.ColoredName(c) or "this character")
        .. " will build rested 4× slower here.")
end
