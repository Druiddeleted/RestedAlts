local _, NS = ...

-- Rested-XP rules and projection. No frames, no WoW calls: loaded under luajit
-- by scripts/test.lua. Every number the addon assumes about Forever lives here,
-- and the login measurement (Observe) is how we find out which ones are wrong.

local R = {}
NS.Rules = R

R.BUBBLE = 0.05          -- one bubble on the XP bar = 5% of a level
R.HOURS_PER_BUBBLE = 8   -- logged out in an inn, city or Cozy Sleeping Bag
R.WORLD_FACTOR = 0.25    -- logged out in the world: Classic rule, unconfirmed for Forever
R.BASE_CAP = 1.5         -- cap = 150% of a level (30 bubbles)
R.RANK_BONUS = 0.04      -- Well Rested, per rank, on both rate and cap (assumed multiplicative)
R.MAX_RANK = 5
R.MIN_OBSERVE_SECONDS = 600 -- shorter gaps (a /reload) say nothing about the rate

-- C_GameRules.GetCurrentGameModeRecordID values seen on live Forever (2026-11-07).
R.MODES = { [14] = "PvP", [15] = "PvE", [16] = "RP", [18] = "RP-PvP" }

function R.RulesetLabel(modeID, realmName)
    if modeID and R.MODES[modeID] then return R.MODES[modeID] end
    if type(realmName) == "string" and realmName ~= "" then
        -- "CAMWOW US2 Realm 9 RP PvP" -> "RP PvP" (not just the last word).
        return realmName:match("Realm %d+ (.+)$") or realmName
    end
    return nil
end

local function modifier(rank) return 1 + R.RANK_BONUS * (rank or 0) end

function R.Cap(xpMax, rank)
    if not xpMax or xpMax <= 0 then return 0 end
    return math.floor(xpMax * R.BASE_CAP * modifier(rank))
end

-- Rested XP gained per second. `online` covers the logged-in character: online
-- and not resting gains nothing; online in an inn gains at the inn rate.
function R.RatePerSecond(xpMax, resting, rank, online)
    if not xpMax or xpMax <= 0 then return 0 end
    if online and not resting then return 0 end
    local perHour = xpMax * R.BUBBLE / R.HOURS_PER_BUBBLE * modifier(rank)
    if not resting then perHour = perHour * R.WORLD_FACTOR end
    return perHour / 3600
end

-- Project a snapshot to `now`. snap: { xpMax, rested, resting, rank, ts, maxLevel }.
-- Returns a table:
--   rested, cap          XP now (estimated) and the cap
--   bubbles, capBubbles  the same in bubbles
--   fullAt               epoch the pool fills (or filled); nil if it never will
--   isFull               already at the cap
--   paused               not gaining at all (online outside a rested area)
function R.Project(snap, now, online)
    local p = { rested = 0, cap = 0, bubbles = 0, capBubbles = 0 }
    if snap.maxLevel then
        p.maxLevel = true
        return p
    end
    if not snap.xpMax or snap.xpMax <= 0 then
        p.noData = true -- e.g. a record written while the XP API read 0
        return p
    end
    local cap = R.Cap(snap.xpMax, snap.rank)
    local rate = R.RatePerSecond(snap.xpMax, snap.resting, snap.rank, online)
    local ts = snap.ts or now
    local start = math.min(snap.rested or 0, cap)
    local rested = math.min(cap, start + rate * math.max(0, now - ts))
    local bubble = snap.xpMax * R.BUBBLE

    p.rested, p.cap = rested, cap
    p.bubbles, p.capBubbles = rested / bubble, cap / bubble
    p.rate = rate
    if start >= cap then
        p.fullAt = ts
    elseif rate > 0 then
        p.fullAt = ts + (cap - start) / rate
    end
    p.isFull = p.fullAt ~= nil and p.fullAt <= now
    p.paused = rate == 0
    return p
end

-- Compare the logout snapshot with what the server says at the next login.
-- live: { level, xpMax, rested }. Returns nil for gaps too short to mean anything.
function R.Observe(snap, live, now)
    if not snap or not snap.ts or snap.maxLevel then return nil end
    local elapsed = now - snap.ts
    if elapsed < R.MIN_OBSERVE_SECONDS then return nil end
    local o = {
        hours = elapsed / 3600,
        resting = snap.resting and true or false,
        rank = snap.rank,
        level = snap.level,
        xpMax = snap.xpMax,
        before = snap.rested or 0,
        after = live.rested or 0,
    }
    o.sameLevel = live.level == snap.level and live.xpMax == snap.xpMax
    local cap = R.Cap(snap.xpMax, snap.rank)
    local rate = R.RatePerSecond(snap.xpMax, snap.resting, snap.rank, false)
    o.predicted = math.floor(math.min(cap, o.before + rate * elapsed) + 0.5)
    o.delta = o.after - o.predicted
    o.cap = cap
    -- Rates as % of a level per hour, the unit the rules are written in.
    if snap.xpMax and snap.xpMax > 0 then
        o.formulaPctHour = rate * 3600 / snap.xpMax * 100
        o.measuredPctHour = (o.after - o.before) / snap.xpMax * 100 / o.hours
        o.afterPctLevel = o.after / snap.xpMax * 100
    end
    -- A capped pool measures the cap, not the rate.
    o.hitCap = o.predicted >= cap or o.after >= cap
    return o
end

function R.Duration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h >= 10 then return string.format("%dh", h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

function R.CommaNumber(n)
    n = math.floor((n or 0) + 0.5)
    local sign = n < 0 and "-" or ""
    local out = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return sign .. out:gsub("^,", "")
end
