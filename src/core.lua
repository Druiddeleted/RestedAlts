local ADDON_NAME, NS = ...
local DB, T = NS.DB, NS.Tracker

function NS.Say(msg)
    print("|cff33ff99[RestedAlts]|r " .. msg)
end

function NS.OnSettingChanged()
    if NS.UI then NS.UI.Refresh() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

local SNAPSHOT_EVENTS = {
    "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
}

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then DB.Init() end
    elseif event == "PLAYER_LOGIN" then
        T.Login()
        NS.Options.Register()
        NS.Minimap.Init()
        for _, e in ipairs(SNAPSHOT_EVENTS) do f:RegisterEvent(e) end
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("PLAYER_LOGOUT")
        f:RegisterEvent("PLAYER_CAMPING")
        f:RegisterEvent("PLAYER_QUITING")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Zone text is filled in by now; the login snapshot couldn't read it.
        T.SnapshotSoon()
        if arg1 then -- isInitialLogin: not a /reload or a zone-in
            C_Timer.After(5, T.LoginSummary)
        end
    elseif event == "PLAYER_LOGOUT" then
        T.Snapshot("logout")
    elseif event == "PLAYER_CAMPING" or event == "PLAYER_QUITING" then
        T.LogoutWarning()
    else
        T.SnapshotSoon()
    end
end)
