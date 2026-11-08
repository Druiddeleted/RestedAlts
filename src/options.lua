local _, NS = ...
local DB, R, T = NS.DB, NS.Rules, NS.Tracker

-- Options › AddOns › RestedAlts, on Blizzard's native vertical layout (same
-- approach as CastHistory/src/options.lua). Proxy settings read and write
-- through NS.DB so the saved variable stays the source of truth.

local O = {}
NS.Options = O

local createCheckbox, createDropdown

local function varType(value)
    local t = type(value)
    local vt = Settings.VarType
    if vt then return ({ boolean = vt.Boolean, number = vt.Number, string = vt.String })[t] or t end
    return t
end

-- Setting variable names are global across addons: prefix them.
local function proxy(category, key, label, default, get, set)
    return Settings.RegisterProxySetting(category, "RestedAlts_" .. key, varType(default), label, default, get, set)
end

local function header(layout, label)
    if CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label))
    end
end

local function toggle(category, key, label, tooltip)
    local s = proxy(category, key, label, DB.DEFAULTS[key],
        function() return DB.Get(key) end,
        function(v) DB.Set(key, v and true or false) end)
    createCheckbox(category, s, tooltip)
end

local function choice(category, key, label, values, tooltip)
    local s = proxy(category, key, label, DB.DEFAULTS[key],
        function() return DB.Get(key) end,
        function(v) DB.Set(key, v) end)
    createDropdown(category, s, function()
        local c = Settings.CreateControlTextContainer()
        for _, v in ipairs(values) do c:Add(v[1], v[2]) end
        return c:GetData()
    end, tooltip)
end

local function slider(category, key, label, min, max, step, tooltip)
    local s = proxy(category, key, label, DB.DEFAULTS[key],
        function() return DB.Get(key) end,
        function(v) DB.Set(key, math.floor(v / step + 0.5) * step) end)
    local opts = Settings.CreateSliderOptions(min, max, step)
    if MinimalSliderWithSteppersMixin then
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
            return tostring(math.floor(v + 0.5))
        end)
    end
    Settings.CreateSlider(category, s, opts, tooltip)
end

local function registerCharacter(parent)
    if not Settings.RegisterVerticalLayoutSubcategory then return end
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "This character")
    local c = T.Current()
    if not c then return end
    header(layout, string.format("%s — Level %d", c.name or "?", c.level or 0))

    -- -1 stands for "auto-detect": the dropdown needs a value of the same type.
    local rank = proxy(category, "rank", "Well Rested rank", -1,
        function() return c.rankManual or -1 end,
        function(v)
            c.rankManual = (v and v >= 0) and v or nil
            T.ApplyRank(c)
            if NS.UI then NS.UI.Refresh() end
        end)
    createDropdown(category, rank, function()
        local box = Settings.CreateControlTextContainer()
        box:Add(-1, "Auto-detect")
        for r = 0, R.MAX_RANK do box:Add(r, tostring(r)) end
        return box:GetData()
    end, "Your Well Rested Legacy talent rank on this character. Raises the rested cap and rate by 4% per rank. Auto-detect reads it from the talent's description; set it by hand only if detection is wrong.")

    local ignore = proxy(category, "ignore", "Don't track", false,
        function() return c.ignored == true end,
        function(v)
            c.ignored = v and true or nil
            if NS.UI then NS.UI.Refresh() end
        end)
    createCheckbox(category, ignore, "Hide this character from the window and the login summary.")
end

function O.Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    createCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
    createDropdown = Settings.CreateDropdown or Settings.CreateDropDown

    local category, layout = Settings.RegisterVerticalLayoutCategory("RestedAlts")

    header(layout, "Window")
    choice(category, "restedFormat", "Show rested as", {
        { "bubbles", "Bubbles (27 / 30)" }, { "percent", "Percent of a level" }, { "both", "Both" },
    }, "How the Rested column reads. One bubble is 5% of a level; the cap is 30 bubbles (more with Well Rested).")
    choice(category, "maxLevel", "Max-level characters", {
        { "section", "Dimmed at bottom" }, { "hidden", "Hidden" },
    }, "Max-level characters don't gain rested XP.")
    choice(category, "sortBy", "Sort by", {
        { "soonest", "Full soonest" }, { "name", "Name" }, { "level", "Level" },
    })
    local mm = proxy(category, "minimap", "Minimap button", true,
        function() return not DB.Get("minimap").hide end,
        function(v) NS.Minimap.SetShown(v) end)
    createCheckbox(category, mm, "Left-click opens the window, right-click opens these settings.")

    header(layout, "Alerts")
    toggle(category, "loginSummary", "Login summary in chat",
        "On login, list characters whose rested XP is full, and optionally ones about to fill.")
    toggle(category, "loginSoon", 'Include "filling soon"',
        "Also list characters that fill within the threshold below.")
    slider(category, "soonHours", '"Filling soon" within (h)', 6, 72, 6,
        "How close to full counts as filling soon, in hours.")
    toggle(category, "logoutWarn", "Logout warning",
        "When you start logging out outside an inn or city, say so: rested XP builds about 4x slower out in the world.")

    if NS.DEV then
        header(layout, "Debug")
        toggle(category, "recordMeasurements", "Record login measurements",
            "Log predicted vs actual rested XP on each login, and what the game reports about Well Rested. Read with /rested log.")
    end

    Settings.RegisterAddOnCategory(category)
    O.category = category
    registerCharacter(category)
end

function O.Open()
    if O.category then Settings.OpenToCategory(O.category:GetID()) end
end
