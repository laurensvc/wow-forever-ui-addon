# Lumen: a clean UI for WoW Forever

A modular UI addon for World of Warcraft: Forever. Every module can be switched on and off, and every setting lives in the game's own options panel.

| Module | What it does |
|---|---|
| **General** | Color theme (Holy, Shadow, Frost, Ember, Mono), bar texture, font, accent borders |
| **Minimap** | Square or round, adjustable size (120–320 px), mouse-wheel zoom, zone name / coordinates / clock on the map, hide zoom, calendar and tracking buttons |
| **Cast Bars** | Restyles the player, target and focus cast bars: 3 styles (Flat, Accent, Minimal), theme or class color, spell icon, remaining time, width and height |
| **Group Frames** | Party and raid frames for healing: class / dark / green health, missing-health or percent text, incoming heals, shields, range fading, mana bars, dispellable-debuff highlight, your HoTs and shields, debuff icons, role and raid-marker icons, target highlight, sort by group / role / class |
| **Bags** | Combined bag, item level on gear, dimmed junk, free-slot counter, scale, cleaner frame |
| **Chat** | Short channel names (`[2]`, `[G]`, `[RL]`), clickable web links with a copy box, hide side buttons, Shift/Ctrl + wheel fast scrolling |
| **Declutter** | Hide action bar art (gryphons), bag and menu buttons on mouseover or hidden, hide talking heads, hide red error text in combat, hide big zone text and boss banners, collapse the quest tracker in dungeons |

## Install (development)

Link the addon folder into the game so edits show up after `/reload`:

```sh
# Check the folder name in your install: _forever_ (some guides say _classic_beta_)
ln -s "$PWD/Lumen" "/Applications/World of Warcraft/_forever_/Interface/AddOns/Lumen"
```

In game:

- `/lumen` opens the settings (also under Esc → Options → AddOns → Lumen)
- `/lumen move` unlocks the group frames so you can drag them; run it again to lock
- `/lumen reset` resets saved positions
- Move the minimap and the player cast bar with Blizzard's **Edit Mode**

Turn on **Show when solo** in Group Frames to see and position your frame without a group.

## How it works with combat restrictions

Forever runs the Midnight-era (12.x) addon API. In combat, many values (health, auras, range) are **secret**: addons can show them but not read, compare or calculate with them. Lumen follows that rule:

- Numbers go straight into status bars and text (`SetValue`, `SetText`) and are never compared in Lua.
- Incoming heals and shields are bars attached to the end of the health fill, so they need no math.
- Anything that has to read a value (missing-health text, cooldown timers, debuff type colors) checks `issecretvalue` first and falls back gracefully, using Blizzard's secret-aware helpers where they exist.
- Protected frames (group frames, hiding Blizzard frames) are only changed out of combat. Changes made during combat are queued until it ends.
- Cast bars and bags restyle Blizzard's frames rather than replacing them, so Blizzard keeps handling the restricted logic.

## Status: untested in game

This is version 0.1: everything compiles, but nothing has run in the client yet. Things to check first:

1. **Interface number** in `Lumen/Lumen.toc` (`120105`). Check in game with `/dump select(4, GetBuildInfo())`. If it doesn't match, the addon shows as "out of date".
2. Run `/console scriptErrors 1` (or install BugSack) so Lua errors are visible.
3. The parts most likely to need tweaks: cast bar art removal (Blizzard's frame names may differ in Forever), the bag frame skin, and the free-slot counter's position.

## Layout

```
Lumen/
  Lumen.toc          addon manifest
  Core.lua           module registry, saved variables, combat queue, movers, /lumen
  Theme.lua          colors, textures, fonts, bordered backdrops ("General" settings)
  Settings.lua       builds the options panel from each module's `options` list
  Modules/*.lua      one file per feature
```

To add a module, call `Lumen:NewModule(key, { name, defaults, options })` and give it `OnEnable` and `Refresh` methods. The settings panel is generated automatically.
