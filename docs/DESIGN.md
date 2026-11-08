# RestedAlts — design

Status: draft for review. Nothing below is built yet beyond the scaffold.

## What it's for

You have several leveling alts. Each one gains rested XP while logged out, and
the pool stops growing once it's full. Rested XP that would have accumulated
after that point is wasted. The addon answers three questions:

1. **Who should I play next?** The character closest to full, or already full.
2. **Am I about to waste rested?** Warn before a character caps.
3. **Did I log out somewhere bad?** Logging out outside an inn or city builds
   rested about 4× slower.

A fourth, temporary job: **record enough data to confirm the Well Rested
numbers** (rate and cap per rank, and the out-of-inn rate) without spending
Legacy points on tests.

## Rules it assumes (Forever, from online sources)

| | Value | Confidence |
|---|---|---|
| Rate in an inn, city or Cozy Sleeping Bag | 5% of the level's XP per 8h | confirmed by several sources |
| Rate logged out in the world | 1/4 of the inn rate | Classic rule, **unconfirmed for Forever** |
| Rate while online and not resting | none | Classic rule |
| Cap | 150% of a level (30 bubbles) | confirmed |
| Well Rested (per rank, max 5) | +4% rate, +4% cap | confirmed; whether the cap is ×1.2 or +20 points is **unknown** |
| Time to fill from empty in an inn | about 10 days at any rank | follows from the two above |

Each value is a named constant in one module. The addon logs what it predicted
next to what actually happened, so wrong constants show up in the log.

## Data: what gets recorded

**Character identity.** Retail identifies a character by name + realm +
region. Forever has rulesets instead of realms, and a name is unique across
all rulesets, so `Realm-Name` is the wrong key. Plan:

- **Key by `UnitGUID("player")`.** It is unique per character whatever the
  realm or ruleset model is, and survives a rename. Name, ruleset and region
  are stored as display fields, not as part of the key.
- **Fallback if the GUID turns out unstable** (to check: it should not change
  between logins): key by `region + name`, since names are unique per region.
- **Ruleset** is shown in the tooltip, and as a tag in the window only when
  characters span more than one ruleset.
- **Unknown until probed:** what `GetRealmName()` returns on Forever (a ruleset
  name, a server name, something else), and which API names the ruleset. The
  scaffold logs every candidate on login (see "Identity probe" below).

**Probe results (2026-11-07: three PvE characters on both factions, one PvP):**

| Ruleset | GUID prefix | `GetRealmName` | Game mode ID | Family name |
|---|---|---|---|---|
| PvE (Horde + Alliance) | `Player-6796-` | `CAMWOW US2 Realm 1 PvE` | 15 | Druborne |
| PvP | `Player-6922-` | `CAMWOW US1 Realm 4 PvP` | 14 | Chamberlyn |
| RP | `Player-7055-` | `CAMWOW US2 Realm 11 RP` | 16 | Dawnstone |
| RP-PvP | `Player-6935-` | `CAMWOW US2 Realm 9 RP PvP` | 18 | Bastiane |

Game modes 4 and 8 are also listed by the client; unknown which rulesets they
are (Hardcore and/or another mode).

- **Key = `UnitGUID`.** Unique per character, stable across reloads; the
  server ID inside it differs per ruleset.
- **Ruleset label:** map game-mode record ID (15 PvE, 14 PvP, 16 RP,
  18 RP-PvP), falling back to whatever follows `Realm <n> ` in `GetRealmName`
  (not just its last word, which would turn "RP PvP" into "PvP"). Game-mode display
  info carries no names.
- **Family name:** `UnitName` returns `first, familyName`, with the family name
  where the realm normally is. It differs per ruleset (one per server), so show
  it per character; never build a key from it.
- **Max level:** decided by `UnitLevel("player") >= GetMaxPlayerLevel()`, not
  by what the XP calls return (unknown at max level; guard against
  `UnitXPMax` = 0 and nil rested).
- **`GetXPExhaustion()` returns nil** for no rested XP (new level-1 character):
  treat as 0.
- **`GetZoneText()` is empty at `PLAYER_LOGIN`:** record zone on zone-change
  events and at logout. `IsResting()` is correct at login.

**Per character** (account-wide saved variable, keyed by GUID):

- GUID, name, ruleset/realm string as reported, region, class, level, faction
- XP, XP to level, rested XP
- resting flag (`IsResting()`) and zone/subzone **at the moment of the snapshot**
- snapshot time
- Well Rested rank: detected (if the API exposes it) or set by hand; otherwise unknown
- measured rate/cap from past logins (see calibration)

**When a snapshot is taken:** logout, plus whenever rested XP, XP, level,
resting state or zone changes, so a crash still leaves a recent snapshot.

**On login,** before taking any new snapshot, compare the stored logout
snapshot to the live values and write one **observation** to the log.

## Calibration (the "see the difference later" part)

Each observation records: hours offline, inn or world, level, XP to level,
rested before → after, what the formula predicted, and the Well Rested rank
as best known.

- If the pool **didn't hit the cap**, the observation gives a measured rate.
- If the pool **was full on both sides** of a long gap, it gives a measured
  cap.
- Gaps under 10 minutes (a `/reload`) are logged but ignored for calibration.

**v1 only logs and displays the measurements; it doesn't act on them.** Once
we've read the logs and fixed the constants, a later version can use measured
values per character. That keeps v1 predictable.

## UI

### 1. Login line (chat)

One line, only when something needs attention:

```
[RestedAlts] Full: Gromthar (wasting 2d) · Filling soon: Kharuun (9h)
```

- "Full": already capped (excludes the character you just logged into).
- "Filling soon": caps within 24h (threshold configurable).
- Nothing printed when nothing is urgent.

### 2. Main window (`/rested`)

A small movable window, one row per character, sorted by "full soonest". Full
ones go first, ordered by how long they've been wasting rested.

```
┌─ RestedAlts ─────────────────────────────────────────────────────┐
│ Character        Lvl  Logged out at          Rested      Full in │
│ Gromthar         22   Orgrimmar  ● rested    30/30 ███   FULL 2d │
│ Kharuun          13   Thunder Bluff ● rested 27/30 ██▉   9h      │
│ Mistleaf          8   Teldrassil  ● rested   11/30 █▏    6d 8h   │
│ Brakka           17   Barrens ▲ world         4/30 ▍     34d     │
│ ───────────────────────────────────────────────────────────────  │
│ Oldmain          60   —                      max level           │
└──────────────────────────────────────────────────────────────────┘
```

- **Name** in class colour; the current character marked and shown live.
- **Logged out at:** zone plus a resting marker. "World" is shown in a warning
  colour because it's the 4× slower case.
- **Rested:** bubbles out of the cap (30 at rank 0, more with Well Rested) and
  a small bar.
- **Full in:** time until capped, or "FULL" plus how long it's been full.
  A `?` suffix when the Well Rested rank is unknown and could change the cap.
- **Max-level characters** go in a dimmed section at the bottom (or are hidden;
  see open questions).

**Row tooltip:** exact rested XP / cap, % of a level, snapshot time, location,
Well Rested rank and where that came from (detected / set / unknown), and the
last measured rate compared to the formula.

**Right-click a row:** set Well Rested rank, or forget this character (for
deleted alts).

### 3. Logout nudge

When you start a logout outside a rested area (`PLAYER_CAMPING`), print one
line:

```
[RestedAlts] Not in a rested area — this character will build rested 4× slower.
```

Logging out still goes ahead; the line is only a reminder. Cozy Sleeping Bag
counts as rested, since `IsResting()` should report it — to verify.

### 4. Settings (in the game's own settings panel)

Settings live in Blizzard's panel under **Options › AddOns › RestedAlts**, built
with the native `Settings` API (vertical layout, proxy settings), the same way
CastHistory does it (`CastHistory/src/options.lua`; pattern in
`docs/ADDON-PATTERNS.md`, "Settings panel"). That gives the stock checkboxes,
sliders, arrow dropdowns, search and the Defaults button for free.

- **RestedAlts** page: account-wide settings, grouped Window / Alerts / Debug.
- **RestedAlts › This character** subcategory: the per-character settings for
  whoever is logged in.
- The gear button in the window and `/rested config` both call
  `Settings.OpenToCategory` on the RestedAlts page.

| Setting | Options | Default |
|---|---|---|
| Show rested as | bubbles / percent of a level / both | bubbles |
| Max-level characters | dimmed at bottom / hidden | dimmed |
| Sort by | full soonest / name / level | full soonest |
| Minimap button | on / off | on |
| Login summary in chat | on / off | on |
| … include "filling soon" | on / off | on |
| "Filling soon" threshold | 6–72h | 24h |
| Logout warning outside a rested area | on / off | on |
| Well Rested rank (per character) | auto-detect / 0–5 | auto-detect |
| Don't track this character (per character) | on / off | off |
| Record login measurements to the log | on / off | on |

### 5. Slash commands

| Command | Does |
|---|---|
| `/rested` | toggle the window |
| `/rested config` | open settings |
| `/rested rank <0-5>` | set this character's Well Rested rank |
| `/rested forget <name>` | remove a character |
| `/rested log` / `log clear` | show / clear the debug log |
| `/rested probe` | log what the API says about Well Rested on this character |

Visual design: the "RestedAlts UI" canvas (Claude Design), which has the main
window, row tooltip, chat output and settings boards.

## Identity probe (in the scaffold now)

On every login the scaffold logs: `UnitGUID`, `UnitName`, `GetRealmName`,
`GetNormalizedRealmName`, `GetRealmID`, `GetCurrentRegion` /
`GetCurrentRegionName`, and any `C_GameRules` functions the client has (name
and return value), plus the build. Log into two characters on different
rulesets, `/reload`, then `./svlog RestedAlts RestedAltsLog`.

## Well Rested rank detection

Resolved 2026-11-07 on the druid: `IsPlayerSpell` / `IsSpellKnown` stay false
and there is no aura, but `C_Spell.GetSpellDescription(1225478)` is nil at rank 0
and reads "accumulates 20% faster … cap is increased by 20%" at rank 5. The
addon parses that % (÷4 = rank). nil description with a loaded spell name = rank
0; no spell name yet = not detected. A rank set by hand overrides detection.

Also found: at a real logout `UnitXPMax` already reads 0, so the logout snapshot
only stamps the time and keeps the event-driven values.

## Out of scope for v1

- Legacy point tracking beyond the Well Rested rank.
- XP-bar tooltip integration.
- Cross-account tracking (saved variables are per WoW account).
- Hardcore characters get no special handling.
