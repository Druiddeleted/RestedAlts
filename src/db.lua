local _, NS = ...

-- Dev build flag. The BigWigs packager comments out @debug@ blocks, so a
-- CurseForge zip has NS.DEV = nil; a ./sync'd checkout has it true.
--@debug@
NS.DEV = true
--@end-debug@

-- Owns the saved-variable schema. Everything else reads and writes through here.
--
-- RestedAltsDB (account-wide):
--   version
--   settings   account-wide options (DEFAULTS below)
--   chars      [guid] = character record (see Tracker.Snapshot for fields)
-- RestedAltsLog: timestamped diagnostic lines, newest last.

local DB = {}
NS.DB = DB

local SCHEMA = 2
local LOG_MAX = 1000

DB.DEFAULTS = {
    restedFormat = "bubbles",   -- bubbles | percent | both
    maxLevel = "section",       -- section | hidden
    sortBy = "soonest",         -- soonest | name | level
    loginSummary = true,
    loginSoon = true,
    soonHours = 24,
    logoutWarn = true,
    recordMeasurements = true,
    minimap = { hide = false },  -- LibDBIcon's own table
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

function DB.Init()
    if type(RestedAltsDB) ~= "table" then RestedAltsDB = {} end
    -- Production builds never write the diagnostic log; drop any left over.
    if NS.DEV then
        if type(RestedAltsLog) ~= "table" then RestedAltsLog = {} end
    else
        RestedAltsLog = nil
    end
    local db = RestedAltsDB
    db.chars = db.chars or {}
    -- Schema 2: ranks detected before 0.1.1 read the top-rank description and
    -- came out 5 on every character; drop them so the next login re-detects.
    if (db.version or SCHEMA) < 2 then
        for _, c in pairs(db.chars) do
            c.rankDetected = nil
            c.rank = c.rankManual
        end
    end
    db.version = SCHEMA
    db.settings = db.settings or {}
    for k, v in pairs(DB.DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = copy(v) end
    end
end

function DB.Get(key) return RestedAltsDB.settings[key] end

function DB.Set(key, value)
    RestedAltsDB.settings[key] = value
    if NS.OnSettingChanged then NS.OnSettingChanged(key, value) end
end

function DB.Settings() return RestedAltsDB.settings end

function DB.Chars() return RestedAltsDB.chars end

function DB.Char(guid) return guid and RestedAltsDB.chars[guid] end

function DB.EnsureChar(guid)
    local c = RestedAltsDB.chars[guid]
    if not c then
        c = { guid = guid }
        RestedAltsDB.chars[guid] = c
    end
    return c
end

function DB.Forget(guid) RestedAltsDB.chars[guid] = nil end

-- Diagnostics are dev-build only: measurements, probes, logout lines.
function DB.Recording()
    return NS.DEV and DB.Get("recordMeasurements") and true or false
end

function DB.Log(fmt, ...)
    if not NS.DEV then return end
    local line = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    local log = RestedAltsLog
    log[#log + 1] = date("%Y-%m-%d %H:%M:%S ") .. line
    if #log > LOG_MAX then
        local drop = #log - LOG_MAX
        for i = 1, #log - drop do log[i] = log[i + drop] end
        for i = #log, #log - drop + 1, -1 do log[i] = nil end
    end
end

function DB.ClearLog() if RestedAltsLog then wipe(RestedAltsLog) end end
