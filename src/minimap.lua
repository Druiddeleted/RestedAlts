local ADDON_NAME, NS = ...
local DB, R = NS.DB, NS.Rules

-- Minimap button via LibDataBroker + LibDBIcon (vendored under Libs/).
-- Left-click toggles the window, right-click opens settings.

local M = {}
NS.Minimap = M

local icon

function M.Init()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (LDB and icon) then return end
    local obj = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = "RestedAlts",
        icon = "Interface\\Icons\\Spell_Nature_Sleep",
        OnClick = function(_, button)
            if button == "RightButton" then NS.Options.Open() else NS.UI.Toggle() end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("RestedAlts")
            local now, full, soon = time(), 0, 0
            local soonSecs = (DB.Get("soonHours") or 24) * 3600
            for g, c in pairs(DB.Chars()) do
                if not c.ignored and c.ts and not NS.Tracker.IsCurrent(g) then
                    local p = R.Project(c, now)
                    if p.isFull then full = full + 1
                    elseif p.fullAt and p.fullAt - now <= soonSecs then soon = soon + 1 end
                end
            end
            tt:AddDoubleLine("Full", tostring(full), 1, 0.82, 0, 1, 1, 1)
            tt:AddDoubleLine("Filling soon", tostring(soon), 1, 0.82, 0, 1, 1, 1)
            tt:AddLine(" ")
            tt:AddLine("|cffaaaaaaLeft-click: window.  Right-click: settings.|r")
        end,
    })
    icon:Register(ADDON_NAME, obj, DB.Get("minimap"))
end

function M.SetShown(show)
    DB.Get("minimap").hide = not show
    if not icon then return end
    if show then icon:Show(ADDON_NAME) else icon:Hide(ADDON_NAME) end
end
