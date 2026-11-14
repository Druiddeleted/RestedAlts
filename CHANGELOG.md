# Changelog

## 0.1.1

- Fixed: Well Rested was detected as rank 5 on every character, because the
  game shows the top rank's description even at rank 0. Characters that don't
  know the talent now read rank 0, and the wrong rank 5 is cleared on update
  (each character re-detects the next time you log into it).
- `/rested rank` with no argument shows this character's current rank, and its
  usage text shows "auto" in full.
- The row tooltip explains the "?" on Full in.

## 0.1.0

First release, for WoW Forever 1.60.1.

- Tracks rested XP for every character on the account, across all Forever
  rulesets, shown by full name ("First Family").
- `/rested` window (or the minimap button): one row per character with where it
  logged out (inn / city or world), rested bubbles and bar, and time until full.
  The character you're playing is pinned at the top. Max-level characters are
  dimmed at the bottom or hidden.
- Row tooltip with exact numbers; right-click a row to set its Well Rested rank,
  stop tracking it, or forget it.
- Well Rested (Legacy talent) rank is detected automatically, with a manual
  override per character.
- Login summary of alts that are full or filling soon, and a warning when you
  log out outside an inn or city.
- Settings in Options → AddOns → RestedAlts, with a "This character" page.

## 0.1.0-alpha1

First alpha, for WoW Forever 1.60.1.

- Tracks rested XP for every character on the account, across all Forever
  rulesets, shown by full name ("First Family").
- `/rested` window (or the minimap button): one row per character with where it
  logged out (inn / city or world), rested bubbles and bar, and time until full.
  The character you're playing is pinned at the top. Max-level characters are
  dimmed at the bottom or hidden.
- Row tooltip with exact numbers; right-click a row to set its Well Rested rank,
  stop tracking it, or forget it.
- Well Rested (Legacy talent) rank is detected automatically, with a manual
  override per character.
- Login summary of alts that are full or filling soon, and a warning when you
  log out outside an inn or city.
- Settings in Options → AddOns → RestedAlts, with a "This character" page.
