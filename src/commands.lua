local _, NS = ...
local DB, R, T = NS.DB, NS.Rules, NS.Tracker

local HELP = {
    "/rested — toggle the window",
    "/rested config — open settings",
    "/rested rank [0-5||auto] — show or set this character's Well Rested rank (auto = detect)",
    "/rested forget <name> — remove a character (first or full name)",
    "/rested summary — print the login summary now",
}

if NS.DEV then
    HELP[#HELP + 1] = "/rested probe — log what the game reports (identity, Well Rested)"
    HELP[#HELP + 1] = "/rested log [n] — show the last n log lines (default 20)"
    HELP[#HELP + 1] = "/rested log clear — clear the log"
end

local function forget(name)
    name = name:lower()
    local hits = {}
    for g, c in pairs(DB.Chars()) do
        if (c.name or ""):lower() == name or NS.FullName(c):lower() == name then hits[#hits + 1] = g end
    end
    if #hits == 0 then return NS.Say("no character named " .. name) end
    if #hits > 1 then return NS.Say("more than one " .. name .. "; right-click its row in the window instead") end
    local c = DB.Char(hits[1])
    DB.Forget(hits[1])
    NS.Say("forgot " .. NS.ColoredName(c))
    if NS.UI then NS.UI.Refresh() end
end

SLASH_RESTEDALTS1 = "/rested"
SlashCmdList.RESTEDALTS = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        NS.UI.Toggle()
    elseif cmd == "config" or cmd == "options" then
        NS.Options.Open()
    elseif cmd == "rank" then
        local c = T.Current()
        local v = rest:lower()
        local n = tonumber(v)
        if not c then return end
        local function report()
            NS.Say("Well Rested rank for " .. NS.ColoredName(c) .. ": " .. (c.rankManual and (tostring(c.rankManual) .. " (set by hand)") or ("auto (" .. tostring(c.rankDetected or "not detected") .. ")")))
        end
        if v == "" then return report() end
        if v == "auto" or v == "unknown" or v == "?" then
            c.rankManual = nil
        elseif n and n >= 0 and n <= R.MAX_RANK and n == math.floor(n) then
            c.rankManual = n
        else
            return NS.Say("usage: /rested rank [0-" .. R.MAX_RANK .. "||auto]")
        end
        T.ApplyRank(c)
        DB.Log("rank %s set to %s by hand", c.name or "?", tostring(c.rankManual))
        report()
        if NS.UI then NS.UI.Refresh() end
    elseif cmd == "forget" and rest ~= "" then
        forget(rest)
    elseif cmd == "summary" then
        T.LoginSummary()
    elseif cmd == "probe" and NS.DEV then
        T.ProbeIdentity()
        T.ProbeWellRested("probe")
        NS.Say("probe logged — /reload to write it to disk")
    elseif cmd == "log" and NS.DEV then
        if rest == "clear" then
            DB.ClearLog()
            return NS.Say("log cleared")
        end
        local n = tonumber(rest) or 20
        local log = RestedAltsLog
        for i = math.max(1, #log - n + 1), #log do print(log[i]) end
    else
        for _, line in ipairs(HELP) do NS.Say(line) end
    end
end
