# RestedAlts

Rested XP for **every** character, not just the one you're on, in **World of Warcraft: Forever**.

Each alt keeps building rested XP while it's logged out, until it hits the cap. After that, the extra rest is wasted. RestedAlts remembers where and when each character logged out and estimates how full its pool is now. That way you know which alt to play next, before its rest goes to waste.

## What it shows

Type `/rested` or click the minimap button to open a window with one row per character:

- **Rested now:** shown as bubbles (`27 / 30`), as a percent of a level, or both.
- **Full in:** how long until the pool caps, or how long it has been full.
- **Where it logged out:** *inn / city* or *world — slow*. Logging out in the world builds rest about four times slower.
- **Well Rested rank:** the rank of the Legacy talent, which raises both the rate and the cap.

The character you're playing is pinned at the top. Characters at max level go to a dimmed section at the bottom, or can be hidden. Hover a row for the full detail: logout time and place, the rate it's resting at, and its Well Rested rank.

## Alerts

- **Login summary:** a chat line listing alts that are full, and optionally ones that fill within a set number of hours.
- **Logout warning:** if you start logging out outside an inn or city, it tells you that rest will build slowly there.

## Well Rested (Legacy talent)

The addon reads your Well Rested rank from the talent itself, so there's nothing to set up. If detection ever gets it wrong, you can set the rank by hand per character, under the settings or with `/rested rank <0-5|auto>`.

## Forever-aware

- Characters are tracked across all rulesets (PvE, PvP, RP, RP-PvP) and labelled by ruleset.
- Forever's family names are shown correctly.
- Data is saved account-wide, so every character on the account shows up in one list.

## Settings

All options are in the game's own menu: **Options → AddOns → RestedAlts**. A **This character** page holds the per-character Well Rested rank and a "Don't track" switch.

## Commands

- `/rested`: toggle the window
- `/rested config`: open settings
- `/rested rank <0-5|auto>`: this character's Well Rested rank
- `/rested forget <name>`: remove a character
- `/rested summary`: print the login summary now

## How accurate is it?

The estimates use these rules:

- In an inn or city, rest builds 5% of a level per 8 hours.
- The pool caps at 150% of a level.
- Each Well Rested rank adds 4% to both the rate and the cap.

Two of the numbers aren't confirmed for Forever yet: the out-in-the-world rate, and exactly how Well Rested raises the cap. If an estimate looks off when you log a character back in, please open an issue on GitHub.

## Good to know

- A character appears after you log into it once with the addon installed.
- Estimates assume the character stayed logged out. Playing it on another PC or with another install isn't seen.
- Nothing is uploaded. All data stays in your SavedVariables.

Built for **WoW Forever 1.60.1**. Feedback and bug reports are welcome on [GitHub](https://github.com/Druiddeleted/RestedAlts/issues).
