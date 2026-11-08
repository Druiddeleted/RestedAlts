# Changelog

## 0.1.0 (unreleased)

- Tracks every character's rested XP (keyed by character GUID, so Forever's
  rulesets and family names are handled), snapshotting at logout and whenever
  rested, XP, level, resting state or zone change.
- `/rested` window: one row per character with logout zone, inn/world marker,
  rested bubbles and bar, and time until full; tooltip with exact numbers;
  right-click for Well Rested rank, don't track, forget.
- Settings in Options › AddOns › RestedAlts (and a "This character" sub-page).
- Login summary of full and filling-soon characters; logout warning outside
  rested areas; minimap button.
- The character you are playing is pinned to the top of the window, highlighted
  and divided from the alts, and kept out of the sort.
- Well Rested rank is auto-detected from the talent's description (its % is the
  current rank's bonus); a rank set by hand still wins.
- Logout no longer overwrites XP data: the client reports 0 XP-to-level at
  logout, which made characters show as max level.
- Debug: each login logs predicted vs actual rested XP and what the game reports
  about the Well Rested talent (`/rested log`, `/rested probe`).
