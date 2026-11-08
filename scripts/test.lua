-- Run: luajit scripts/test.lua   (from the RestedAlts directory)
-- Asserts the rested-XP rules and projection in src/rules.lua, no client needed.
local NS = {}
assert(loadfile("src/rules.lua"))("RestedAlts", NS)
local R = NS.Rules

local failures = 0
local function eq(got, want, what)
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end
local function near(got, want, what, tol)
    if not got or math.abs(got - want) > (tol or 1e-6) then
        failures = failures + 1
        print(string.format("FAIL %s: got %s, want ~%s", what, tostring(got), tostring(want)))
    end
end

local H = 3600
local now = 1000000000

-- Cap and rate
eq(R.Cap(2800, nil), 4200, "cap rank 0")
eq(R.Cap(6500, 5), 11700, "cap rank 5 (x1.2)")
eq(R.Cap(0, 0), 0, "cap with no XP bar")
near(R.RatePerSecond(2800, true, 0) * 8 * H, 140, "inn: 5% of a level per 8h")
near(R.RatePerSecond(2800, false, 0) * 8 * H, 35, "world: a quarter of that")
near(R.RatePerSecond(6500, true, 5) * 8 * H, 390, "rank 5: 6% per 8h")
eq(R.RatePerSecond(2800, false, 0, true), 0, "online, not resting: no gain")
near(R.RatePerSecond(2800, true, 0, true) * 8 * H, 140, "online in an inn: inn rate")

-- Empty to full in an inn is 30 bubbles x 8h = 10 days, at any rank.
local p = R.Project({ xpMax = 2800, rested = 0, resting = true, ts = now }, now)
near(p.fullAt - now, 240 * H, "empty -> full in 10 days")
local p5 = R.Project({ xpMax = 2800, rested = 0, resting = true, rank = 5, ts = now }, now)
near(p5.fullAt - now, 240 * H, "rank 5 also 10 days", 1)
eq(p5.capBubbles, 36, "rank 5 cap in bubbles")
eq(p.isFull, false, "not full at start")
eq(p.paused, false, "not paused")

-- Half way, then past full
local mid = R.Project({ xpMax = 2800, rested = 0, resting = true, ts = now }, now + 120 * H)
near(mid.rested, 2100, "5 days in: half the cap")
near(mid.bubbles, 15, "15 bubbles")
local over = R.Project({ xpMax = 2800, rested = 0, resting = true, ts = now }, now + 300 * H)
eq(over.rested, 4200, "clamped at cap")
eq(over.isFull, true, "full")
near(over.fullAt, now + 240 * H, "fullAt stays at the fill moment")

-- Already full at logout
local full = R.Project({ xpMax = 2800, rested = 4200, resting = true, ts = now }, now + 2 * H)
eq(full.isFull, true, "full at snapshot")
eq(full.fullAt, now, "full since the snapshot")

-- Online outside a rested area: paused, never fills
local paused = R.Project({ xpMax = 2800, rested = 500, resting = false, ts = now }, now + 5 * H, true)
eq(paused.paused, true, "online not resting is paused")
eq(paused.fullAt, nil, "paused never fills")
eq(paused.rested, 500, "paused keeps its value")

-- Max level / no XP bar
eq(R.Project({ maxLevel = true, xpMax = 0, ts = now }, now).maxLevel, true, "max level")
eq(R.Project({ xpMax = 0, ts = now }, now).noData, true, "empty XP bar is missing data, not max level")
eq(R.Project({ xpMax = 0, ts = now }, now).maxLevel, nil, "and not max level")

-- Observe
eq(R.Observe({ ts = now, xpMax = 2800, rested = 0, resting = true, level = 5 },
    { level = 5, xpMax = 2800, rested = 0 }, now + 60), nil, "reload gap ignored")
local o = R.Observe({ ts = now, xpMax = 2800, rested = 696, resting = true, level = 5 },
    { level = 5, xpMax = 2800, rested = 836 }, now + 8 * H)
eq(o.predicted, 836, "predicted after 8h")
eq(o.delta, 0, "matches")
near(o.measuredPctHour, 0.625, "measured %/h")
near(o.formulaPctHour, 0.625, "formula %/h")
eq(o.hitCap, false, "not capped")
eq(o.sameLevel, true, "same level")
local oc = R.Observe({ ts = now, xpMax = 2800, rested = 4100, resting = true, level = 5 },
    { level = 5, xpMax = 2800, rested = 4200 }, now + 48 * H)
eq(oc.hitCap, true, "capped observation flagged")
local ow = R.Observe({ ts = now, xpMax = 2800, rested = 0, resting = false, level = 5 },
    { level = 5, xpMax = 2800, rested = 35 }, now + 8 * H)
eq(ow.delta, 0, "world rate observation")

-- Ruleset labels
eq(R.RulesetLabel(15, "x"), "PvE", "mode 15")
eq(R.RulesetLabel(18, "x"), "RP-PvP", "mode 18")
eq(R.RulesetLabel(99, "CAMWOW US2 Realm 9 RP PvP"), "RP PvP", "fallback keeps both words")
eq(R.RulesetLabel(nil, "Odd Name"), "Odd Name", "fallback without Realm n")
eq(R.RulesetLabel(nil, nil), nil, "nothing to go on")

-- Formatting
eq(R.Duration(2 * 86400 + 6 * H + 59), "2d 6h", "days")
eq(R.Duration(9 * H + 20 * 60), "9h 20m", "hours and minutes")
eq(R.Duration(14 * H + 5 * 60), "14h", "10h+ drops minutes")
eq(R.Duration(45 * 60), "45m", "minutes")
eq(R.CommaNumber(38900), "38,900", "comma")
eq(R.CommaNumber(-1234), "-1,234", "negative comma")
eq(R.CommaNumber(152), "152", "short number")

if failures == 0 then print("all rules tests passed") else print(failures .. " failure(s)"); os.exit(1) end
